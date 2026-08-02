#!/usr/bin/env python3
"""Puts a released build in front of testers.

    ./scripts/submit-beta.py <tag> <what-to-test-file> [--dry-run]

Uploading a build does not queue anything. External testing needs the build
attached to an external group and submitted for Beta App Review, and the
review will not accept an app missing its description, contact details, or
tester notes. This does all of it, and is safe to re-run: everything is
created if absent and updated if present.

An internal group is a different shape of the same job, so the group decides
rather than a flag: internal testers are App Store Connect users, Apple does
not review builds for them, and attaching is the whole of it. Tester notes
still apply — they are what testers read — but review contact details are
neither required nor sent.

What to test is a file because it is the one part that genuinely differs every
build. Everything else lives in the environment, beside the signing key:

    ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH   (as for release.sh)
    ASC_FEEDBACK_EMAIL      where tester reports land
    ASC_CONTACT_FIRST/LAST/EMAIL/PHONE        for the reviewer
    ASC_BETA_DESCRIPTION_FILE                 optional, app-level blurb
    ASC_REVIEW_NOTES_FILE                     optional, notes to the reviewer
    ASC_BETA_GROUP                            optional, defaults to "beta"

Contact details are deliberately not arguments and not repo files. This
repository is public and they are personal.
"""
import base64
import json
import os
import re
import subprocess
import sys
import time

BASE = "https://api.appstoreconnect.apple.com"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def die(message):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def env(name, required=True):
    value = os.environ.get(name)
    if required and not value:
        die(f"{name} is not set. See the header of this script.")
    return value


# --- authentication ----------------------------------------------------------

def _b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _der_to_raw(der):
    """openssl emits DER; JWS wants the raw r||s pair."""
    index = 2 if der[1] < 0x80 else 3 + (der[1] & 0x7F) - 1
    out = b""
    for _ in range(2):
        length = der[index + 1]
        value = der[index + 2: index + 2 + length]
        out += value.lstrip(b"\x00").rjust(32, b"\x00")
        index += 2 + length
    return out


def _token():
    key_id = env("ASC_KEY_ID")
    key_path = os.environ.get("ASC_KEY_PATH") or os.path.expanduser(
        f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8"
    )
    if not os.path.isfile(key_path):
        die(f"no App Store Connect key at {key_path}")
    now = int(time.time())
    header = _b64(json.dumps(
        {"alg": "ES256", "kid": key_id, "typ": "JWT"}, separators=(",", ":")
    ).encode())
    payload = _b64(json.dumps(
        {"iss": env("ASC_ISSUER_ID"), "iat": now, "exp": now + 1200,
         "aud": "appstoreconnect-v1"}, separators=(",", ":")
    ).encode())
    signing_input = f"{header}.{payload}".encode()
    signature = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=signing_input, capture_output=True, check=True,
    ).stdout
    return f"{header}.{payload}.{_b64(_der_to_raw(signature))}"


BEARER = None


def api(method, path, body=None):
    """curl carries the request: the system trust store is reliable where a
    given python's is not, and the token arrives on stdin rather than argv."""
    url = path if path.startswith("http") else BASE + path
    args = ["curl", "-sS", "--config", "-", "-X", method, url,
            "-w", "\n%{http_code}"]
    if body is not None:
        args += ["-H", "Content-Type: application/json", "-d", json.dumps(body)]
    result = subprocess.run(
        args, input=f'header = "Authorization: Bearer {BEARER}"\n',
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        die(f"curl failed: {result.stderr.strip()}")
    head, _, tail = result.stdout.rpartition("\n")
    status = int(tail) if tail.strip().isdigit() else 0
    try:
        return status, (json.loads(head) if head.strip() else None)
    except ValueError:
        return status, head


def expect(status, payload, *ok):
    if status not in ok:
        die(f"App Store Connect returned {status}: {json.dumps(payload)[:600]}")
    return payload


# --- lookups -----------------------------------------------------------------

def bundle_identifier():
    project = os.path.join(ROOT, "AFKRelay.xcodeproj", "project.pbxproj")
    with open(project) as handle:
        found = re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", handle.read())
    # The test targets suffix the app's identifier, so the shortest wins.
    return min((f.strip() for f in found), key=len)


def find_app(bundle_id):
    status, payload = api(
        "GET", f"/v1/apps?filter%5BbundleId%5D={bundle_id}")
    data = expect(status, payload, 200).get("data") or []
    if not data:
        die(f"no App Store Connect app record for {bundle_id}")
    return data[0]["id"]


def find_build(app_id, tag):
    status, payload = api(
        "GET",
        f"/v1/builds?filter%5Bapp%5D={app_id}&include=preReleaseVersion&limit=50")
    payload = expect(status, payload, 200)
    versions = {i["id"]: i["attributes"].get("version")
                for i in payload.get("included", [])}
    for build in payload.get("data", []):
        relationship = build.get("relationships", {}) \
            .get("preReleaseVersion", {}).get("data")
        if not relationship or versions.get(relationship["id"]) != tag:
            continue
        state = build["attributes"].get("processingState")
        if state != "VALID":
            die(f"build for {tag} is {state}, not VALID — wait for processing")
        return build["id"]
    die(f"no uploaded build for {tag}. Run ./scripts/release.sh first.")


def find_group(app_id, name):
    """The group's id and whether it is internal, which decides the rest."""
    status, payload = api(
        "GET", f"/v1/betaGroups?filter%5Bapp%5D={app_id}&limit=50")
    for group in expect(status, payload, 200).get("data", []):
        attributes = group["attributes"]
        if attributes.get("name") == name:
            return group["id"], bool(attributes.get("isInternalGroup"))
    die(f'no beta group named "{name}". Create it in App Store '
        "Connect, or set ASC_BETA_GROUP.")


def read_file(path, label):
    if not os.path.isfile(path):
        die(f"no {label} at {path}")
    text = open(path).read().strip()
    if not text:
        die(f"{label} at {path} is empty")
    return text


# --- steps -------------------------------------------------------------------

def upsert_app_localization(app_id, description, feedback_email):
    status, payload = api(
        "GET", f"/v1/apps/{app_id}/betaAppLocalizations")
    existing = next(
        (item for item in expect(status, payload, 200).get("data", [])
         if item["attributes"].get("locale") == "en-US"), None)
    attributes = {"feedbackEmail": feedback_email}
    if description:
        attributes["description"] = description
    if existing:
        expect(*api("PATCH", f"/v1/betaAppLocalizations/{existing['id']}", {
            "data": {"type": "betaAppLocalizations", "id": existing["id"],
                     "attributes": attributes}}), 200)
        return "updated"
    attributes["locale"] = "en-US"
    if "description" not in attributes:
        die("first submission needs a description; set "
            "ASC_BETA_DESCRIPTION_FILE")
    expect(*api("POST", "/v1/betaAppLocalizations", {
        "data": {"type": "betaAppLocalizations", "attributes": attributes,
                 "relationships": {"app": {"data": {"type": "apps",
                                                    "id": app_id}}}}}), 201)
    return "created"


def upsert_build_localization(build_id, whats_new):
    status, payload = api(
        "GET", f"/v1/builds/{build_id}/betaBuildLocalizations")
    existing = next(
        (item for item in expect(status, payload, 200).get("data", [])
         if item["attributes"].get("locale") == "en-US"), None)
    if existing:
        expect(*api("PATCH", f"/v1/betaBuildLocalizations/{existing['id']}", {
            "data": {"type": "betaBuildLocalizations", "id": existing["id"],
                     "attributes": {"whatsNew": whats_new}}}), 200)
        return "updated"
    expect(*api("POST", "/v1/betaBuildLocalizations", {
        "data": {"type": "betaBuildLocalizations",
                 "attributes": {"locale": "en-US", "whatsNew": whats_new},
                 "relationships": {"build": {"data": {"type": "builds",
                                                      "id": build_id}}}}}), 201)
    return "created"


def update_review_detail(app_id, notes):
    attributes = {
        "contactFirstName": env("ASC_CONTACT_FIRST"),
        "contactLastName": env("ASC_CONTACT_LAST"),
        "contactEmail": env("ASC_CONTACT_EMAIL"),
        "contactPhone": env("ASC_CONTACT_PHONE"),
        "demoAccountRequired": False,
    }
    if notes:
        attributes["notes"] = notes
    expect(*api("PATCH", f"/v1/betaAppReviewDetails/{app_id}", {
        "data": {"type": "betaAppReviewDetails", "id": app_id,
                 "attributes": attributes}}), 200)


def attach_to_group(group_id, build_id):
    status, payload = api(
        "POST", f"/v1/betaGroups/{group_id}/relationships/builds",
        {"data": [{"type": "builds", "id": build_id}]})
    # Re-running a submission must not fail because the build is already there.
    if status not in (204, 201, 200) and "already" not in json.dumps(payload).lower():
        die(f"could not attach build to group: {status} {json.dumps(payload)[:400]}")


def submit(build_id):
    status, payload = api("POST", "/v1/betaAppReviewSubmissions", {
        "data": {"type": "betaAppReviewSubmissions",
                 "relationships": {"build": {"data": {"type": "builds",
                                                      "id": build_id}}}}})
    if status == 201:
        return payload["data"]["attributes"]["betaReviewState"]

    # A build already in review is refused with INVALID_QC_STATE rather than a
    # conflict. Re-running to correct tester notes is a normal thing to do, so
    # report where the build already stands instead of failing the run.
    body = json.dumps(payload)
    already = status == 409 or "INVALID_QC_STATE" in body
    if already:
        found = api("GET", f"/v1/builds/{build_id}/betaAppReviewSubmission")[1]
        try:
            state = found["data"]["attributes"]["betaReviewState"]
            return f"{state} (was already submitted; metadata updated)"
        except Exception:
            return "already submitted; metadata updated"
    die(f"submission refused: {status} {body[:600]}")


def main():
    arguments = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry_run = "--dry-run" in sys.argv
    if len(arguments) != 2:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        sys.exit(2)
    tag, whats_new_path = arguments

    global BEARER
    BEARER = _token()

    whats_new = read_file(whats_new_path, "what-to-test file")
    description_path = os.environ.get("ASC_BETA_DESCRIPTION_FILE")
    description = read_file(description_path, "description") if description_path else None
    notes_path = os.environ.get("ASC_REVIEW_NOTES_FILE")
    notes = read_file(notes_path, "review notes") if notes_path else None

    app_id = find_app(bundle_identifier())
    build_id = find_build(app_id, tag)
    group_name = os.environ.get("ASC_BETA_GROUP", "beta")
    group_id, internal = find_group(app_id, group_name)

    kind = "internal" if internal else "external"
    print(f"app {app_id} · build {tag} ({build_id}) · {kind} group {group_name}")
    if dry_run:
        print("dry run: everything resolved, nothing submitted")
        return

    print("app localization:", upsert_app_localization(
        app_id, description, env("ASC_FEEDBACK_EMAIL")))
    print("build localization:", upsert_build_localization(build_id, whats_new))
    if not internal:
        update_review_detail(app_id, notes)
        print("review detail: updated")
    attach_to_group(group_id, build_id)
    print(f"attached to {group_name}")

    if internal:
        print("\nInternal testers can install as soon as the build finishes "
              "processing — Apple does not review internal builds.")
        return
    print("submitted:", submit(build_id))
    print("\nBeta App Review takes roughly 24–48 hours on a first submission; "
          "later builds usually clear faster.")


if __name__ == "__main__":
    main()
