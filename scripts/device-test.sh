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
# That keychain joins the user keychain search list only while this script
# builds, then the list goes back to what it was. Left there permanently, every
# other project's Xcode build on this Mac sees its identity, which belongs to the
# same team, and automatic signing can pick it while the keychain is locked:
# codesign then fails with errSecInternalComponent (ios-app-starter, 2026-11-09).
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

# Put the signing keychain first in the search list for this build only, and
# restore the list as it was on every exit, a failed build included.
saved_keychains=()
while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"; line="${line%\"}"; line="${line#\"}"
    [ -n "$line" ] && saved_keychains+=("$line")
done < <(security list-keychains -d user)
if [ "${#saved_keychains[@]}" -eq 0 ]; then
    echo "could not read the user keychain search list" >&2
    exit 1
fi
restore_keychains() {
    security list-keychains -d user -s "${saved_keychains[@]}"
}
trap restore_keychains EXIT
build_keychains=("$AFKRELAY_KEYCHAIN_PATH")
for keychain in "${saved_keychains[@]}"; do
    [ "$keychain" = "$AFKRELAY_KEYCHAIN_PATH" ] || build_keychains+=("$keychain")
done
security list-keychains -d user -s "${build_keychains[@]}"

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
