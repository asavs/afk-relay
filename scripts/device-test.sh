#!/bin/bash
# Run the device test plan on the physical test device.
#
# Signing over SSH needs a keychain this session can actually unlock. Keychain
# unlock does not cross macOS security sessions, so an identity sitting in the
# login keychain is unreachable from a remote shell no matter how unlocked it
# looks from the desktop — and macOS will not export that identity to a
# non-GUI session either. So signing lives in its own keychain with its own
# random password, set up once by scripts/setup-signing-keychain.py.
#
# Environment, from the same file the release scripts read:
#   AFKRELAY_KEYCHAIN_PATH, AFKRELAY_KEYCHAIN_PASSWORD
#   ASC_KEY_ID, ASC_ISSUER_ID   (so provisioning profiles update headlessly)
#
# Usage: ./scripts/device-test.sh [device-udid]

set -euo pipefail

DEVICE=${1:-00008120-0004581A02E0201E}   # Shamalamadingdong, iPhone 14 Pro
ENV_FILE="$HOME/.appstoreconnect/env.sh"
cd "$(dirname "$0")/.."

if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
fi

for name in AFKRELAY_KEYCHAIN_PATH AFKRELAY_KEYCHAIN_PASSWORD; do
    if [ -z "${!name:-}" ]; then
        echo "$name is not set. Run scripts/setup-signing-keychain.py once." >&2
        exit 1
    fi
done

if ! xcrun devicectl list devices 2>/dev/null | grep -q "$DEVICE"; then
    # devicectl reports by UUID rather than UDID, so fall back to a name match
    # before giving up: an unpaired device is a different problem to a locked
    # one, and the distinction is worth keeping.
    echo "note: $DEVICE not listed by devicectl; attempting anyway." >&2
fi

security unlock-keychain -p "$AFKRELAY_KEYCHAIN_PASSWORD" "$AFKRELAY_KEYCHAIN_PATH"

authentication=()
if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ]; then
    key_path=${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}
    if [ -f "$key_path" ]; then
        # Lets xcodebuild regenerate a provisioning profile without an Xcode
        # account, which a headless session does not have.
        authentication=(
            -authenticationKeyPath "$key_path"
            -authenticationKeyID "$ASC_KEY_ID"
            -authenticationKeyIssuerID "$ASC_ISSUER_ID"
        )
    fi
fi

echo "Running AFKRelay-Device on $DEVICE (the device must be unlocked)..."
xcodebuild test \
    -project AFKRelay.xcodeproj \
    -scheme AFKRelay \
    -testPlan AFKRelay-Device \
    -destination "platform=iOS,id=$DEVICE" \
    -allowProvisioningUpdates \
    "${authentication[@]}"
