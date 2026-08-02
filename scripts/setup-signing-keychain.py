#!/usr/bin/env python3
"""Create a dedicated code-signing keychain, headlessly.

The login keychain refuses to export a private key over SSH — that is a GUI
authorization macOS will not grant to a non-Aqua session, and no amount of
unlocking changes it. So nothing is exported. A fresh key is generated here,
App Store Connect issues a certificate for it, and the pair lands in a
keychain of its own with a random password.

What that buys: the login keychain is never touched, no login password is
stored anywhere, and if the keychain password leaks the blast radius is one
development certificate that can be revoked in seconds.
"""

import base64
import os
import secrets
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asc  # noqa: E402

KEYCHAIN = os.path.expanduser("~/Library/Keychains/afkrelay-signing.keychain-db")
ENV_FILE = os.path.expanduser("~/.appstoreconnect/env.sh")
WWDR_URL = "https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer"
COMMON_NAME = "AFK Relay headless signing"


def run(args, **kwargs):
    result = subprocess.run(args, capture_output=True, text=True, **kwargs)
    if result.returncode != 0:
        asc.die(f"{args[0]} failed: {(result.stderr or result.stdout).strip()}")
    return result.stdout


def step(number, text):
    print(f"\n== {number}/7  {text} ==")


def main():
    # A fixed directory rather than a fresh temp one, deleted only on success.
    # Apple allows a single current development certificate, so a failure that
    # threw away the key would leave that slot occupied by a certificate
    # nothing can use, and the retry would be refused. Keeping the key lets a
    # retry reuse the certificate already issued.
    work = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "signing-work")
    os.makedirs(work, mode=0o700, exist_ok=True)
    key_path = os.path.join(work, "key.pem")
    csr_path = os.path.join(work, "req.csr")
    cer_path = os.path.join(work, "cert.cer")
    p12_path = os.path.join(work, "identity.p12")
    wwdr_path = os.path.join(work, "wwdr.cer")
    p12_password = secrets.token_hex(16)
    keychain_password = secrets.token_hex(16)

    try:
        resuming = os.path.exists(key_path) and os.path.exists(cer_path)

        step(1, "Generating a private key and certificate request")
        if resuming:
            print("reusing the key from the previous attempt")
        else:
            run(["openssl", "genrsa", "-out", key_path, "2048"])
            os.chmod(key_path, 0o600)
            run(["openssl", "req", "-new", "-key", key_path, "-out", csr_path,
                 "-subj", f"/CN={COMMON_NAME}/O=Asa Schaeffer/C=US"])
            print("ok")

        step(2, "Asking App Store Connect for a development certificate")
        if resuming:
            print("reusing the certificate already issued for that key")
        else:
            with open(csr_path) as handle:
                csr = handle.read()
            bearer = asc.token()
            status, data = asc.api(bearer, "POST", "/v1/certificates", {
                "data": {
                    "type": "certificates",
                    "attributes": {
                        "certificateType": "DEVELOPMENT",
                        "csrContent": csr,
                    },
                }
            })
            if status not in (200, 201):
                detail = ""
                if isinstance(data, dict):
                    detail = "; ".join(
                        f"{e.get('title')}: {e.get('detail')}"
                        for e in data.get("errors", [])
                    )
                asc.die(f"certificate creation returned HTTP {status}. {detail}")
            attributes = data["data"]["attributes"]
            with open(cer_path, "wb") as handle:
                handle.write(base64.b64decode(attributes["certificateContent"]))
            print(f"issued, serial {attributes.get('serialNumber', '?')}, "
                  f"expires {attributes.get('expirationDate', '')[:10]}")

        step(3, "Packaging the key and certificate together")
        pem = run(["openssl", "x509", "-inform", "DER", "-in", cer_path])
        cert_pem_path = os.path.join(work, "cert.pem")
        with open(cert_pem_path, "w") as handle:
            handle.write(pem)
        # Apple's intermediate travels with the identity so the keychain can
        # build a full chain without depending on the login keychain.
        run(["curl", "-sS", "-o", wwdr_path, WWDR_URL])
        wwdr_pem = run(["openssl", "x509", "-inform", "DER", "-in", wwdr_path])
        wwdr_pem_path = os.path.join(work, "wwdr.pem")
        with open(wwdr_pem_path, "w") as handle:
            handle.write(wwdr_pem)
        # No -legacy: macOS ships LibreSSL, which does not take that flag and
        # already defaults to the algorithms `security import` accepts.
        run(["openssl", "pkcs12", "-export",
             "-inkey", key_path, "-in", cert_pem_path,
             "-certfile", wwdr_pem_path,
             "-name", COMMON_NAME,
             "-out", p12_path, "-passout", f"pass:{p12_password}"])
        print("ok")

        step(4, "Creating the signing keychain")
        subprocess.run(["security", "delete-keychain", KEYCHAIN],
                       capture_output=True)
        run(["security", "create-keychain", "-p", keychain_password, KEYCHAIN])
        # No idle timeout and no locking on sleep: a keychain that relocked
        # would put every future headless build back where this started.
        run(["security", "set-keychain-settings", KEYCHAIN])
        print("ok")

        step(5, "Importing the identity")
        # The .p12 already carries Apple's intermediate through -certfile, so
        # this one import brings the whole chain. Importing the intermediate
        # again afterwards fails as a duplicate.
        run(["security", "import", p12_path, "-k", KEYCHAIN,
             "-P", p12_password,
             "-T", "/usr/bin/codesign", "-T", "/usr/bin/security"])
        # Lets codesign reach the key without a prompt it could never display.
        run(["security", "set-key-partition-list",
             "-S", "apple-tool:,apple:,codesign:", "-s",
             "-k", keychain_password, KEYCHAIN])
        print("ok")

        step(6, "Adding it to the keychain search list")
        existing = [
            line.strip().strip('"')
            for line in run(["security", "list-keychains", "-d", "user"]).splitlines()
            if line.strip()
        ]
        if KEYCHAIN in existing:
            print("already present")
        else:
            # -s replaces the list, so the current entries are preserved
            # explicitly. Dropping the login keychain here would break
            # unrelated tools.
            run(["security", "list-keychains", "-d", "user", "-s",
                 *existing, KEYCHAIN])
            print(f"ok ({len(existing) + 1} keychains)")

        step(7, "Recording the keychain password")
        os.makedirs(os.path.dirname(ENV_FILE), exist_ok=True)
        lines = []
        if os.path.exists(ENV_FILE):
            with open(ENV_FILE) as handle:
                lines = [
                    line for line in handle.read().splitlines()
                    if not line.startswith("export AFKRELAY_KEYCHAIN")
                ]
        lines += [
            f'export AFKRELAY_KEYCHAIN_PATH="{KEYCHAIN}"',
            f'export AFKRELAY_KEYCHAIN_PASSWORD="{keychain_password}"',
        ]
        with open(ENV_FILE, "w") as handle:
            handle.write("\n".join(lines) + "\n")
        os.chmod(ENV_FILE, 0o600)
        print(f"written to {ENV_FILE} (mode 600)")

        print("\n== Verifying ==")
        run(["security", "unlock-keychain", "-p", keychain_password, KEYCHAIN])
        identities = run(["security", "find-identity", "-v", "-p",
                          "codesigning", KEYCHAIN])
        print(identities.strip())
        if "0 valid identities" in identities:
            asc.die("the identity is present but not valid for codesigning")
        probe = os.path.join(work, "probe")
        subprocess.run(["cp", "/bin/echo", probe], check=True)
        digest = identities.split()[1]
        run(["codesign", "--force", "--sign", digest, "--keychain", KEYCHAIN,
             probe])
        print("\nSIGNING OK — the login keychain was never touched.")
        print(f"To undo: security delete-keychain {KEYCHAIN}")
        # Only now: the key is safely inside the keychain, so the unprotected
        # copies on disk can go.
        run(["rm", "-rf", work])
    except SystemExit:
        print(f"\nKey and certificate kept in {work} so a retry can resume "
              f"without spending another certificate.", file=sys.stderr)
        raise


if __name__ == "__main__":
    main()
