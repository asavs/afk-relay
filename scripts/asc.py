"""Minimal App Store Connect client.

The JWT construction mirrors scripts/submit-beta.py, including its two
deliberate choices: openssl signs the token so no third-party crypto package
is required, and curl receives the bearer on stdin rather than argv so it
never appears in a process listing.
"""

import base64
import json
import os
import subprocess
import sys
import time

BASE = "https://api.appstoreconnect.apple.com"


def die(message):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


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


def token():
    key_id = os.environ.get("ASC_KEY_ID") or die("ASC_KEY_ID is not set")
    key_path = os.environ.get("ASC_KEY_PATH") or os.path.expanduser(
        f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8"
    )
    if not os.path.isfile(key_path):
        die(f"no App Store Connect key at {key_path}")
    issuer = os.environ.get("ASC_ISSUER_ID") or die("ASC_ISSUER_ID is not set")
    now = int(time.time())
    header = _b64(json.dumps(
        {"alg": "ES256", "kid": key_id, "typ": "JWT"}, separators=(",", ":")
    ).encode())
    payload = _b64(json.dumps(
        {"iss": issuer, "iat": now, "exp": now + 1200,
         "aud": "appstoreconnect-v1"}, separators=(",", ":")
    ).encode())
    signing_input = f"{header}.{payload}".encode()
    signature = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=signing_input, capture_output=True, check=True,
    ).stdout
    return f"{header}.{payload}.{_b64(_der_to_raw(signature))}"


def api(bearer, method, path, body=None):
    url = path if path.startswith("http") else BASE + path
    args = ["curl", "-sS", "--config", "-", "-X", method, url,
            "-w", "\n%{http_code}"]
    if body is not None:
        args += ["-H", "Content-Type: application/json", "-d", json.dumps(body)]
    result = subprocess.run(
        args, input=f'header = "Authorization: Bearer {bearer}"\n',
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        die(f"curl failed: {result.stderr.strip()}")
    head, _, tail = result.stdout.rpartition("\n")
    status = int(tail) if tail.strip().isdigit() else 0
    try:
        return status, (json.loads(head) if head.strip() else None)
    except json.JSONDecodeError:
        return status, head
