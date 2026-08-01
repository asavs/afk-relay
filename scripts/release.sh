#!/bin/sh
#
# Builds a tagged release and sends it to App Store Connect.
#
#   ./scripts/release.sh <tag> <build-number> [--validate-only]
#
# The tag is built from a detached worktree, so the working tree is never
# touched and the archive matches the tag exactly rather than whatever happens
# to be checked out.
#
# Authentication is an App Store Connect API key, not an Apple ID password.
# A password authenticates the upload but cannot mint the distribution
# certificate, and this machine holds only a development identity — so a
# password alone fails at signing, before it ever reaches the upload. Set:
#
#   ASC_KEY_ID, ASC_ISSUER_ID, and either ASC_KEY_PATH or a .p8 in
#   ~/.appstoreconnect/private_keys/
#
# Create one at App Store Connect → Users and Access → Integrations →
# App Store Connect API, role App Manager. The .p8 downloads exactly once.

set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
app_root=$(CDPATH= cd -- "$script_directory/.." && pwd)

tag=${1:-}
build_number=${2:-}
mode=${3:-}

if [ -z "$tag" ] || [ -z "$build_number" ]; then
    echo "usage: $0 <tag> <build-number> [--validate-only]" >&2
    exit 2
fi

die() {
    echo "error: $1" >&2
    exit 1
}

step() {
    echo
    echo "==> $1"
}

# --- preconditions -----------------------------------------------------------

git -C "$app_root" rev-parse "$tag" >/dev/null 2>&1 \
    || die "no such tag: $tag"

case "$tag" in
    v*) die "tags are bare version numbers; got '$tag'" ;;
esac

# 90683 is unrecoverable at upload time and costs a full archive to discover,
# so refuse before building rather than after.
tag_plist=$(git -C "$app_root" show "$tag:AFKRelay/Info.plist")
for key in NSHealthShareUsageDescription NSHealthUpdateUsageDescription; do
    echo "$tag_plist" | grep -q "<key>$key</key>" \
        || die "$tag is missing $key in Info.plist; App Store Connect will reject it (90683)"
done

key_path=${ASC_KEY_PATH:-}
if [ -z "$key_path" ] && [ -n "${ASC_KEY_ID:-}" ]; then
    key_path="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
fi

if [ -z "${ASC_KEY_ID:-}" ] || [ -z "${ASC_ISSUER_ID:-}" ] || [ ! -f "$key_path" ]; then
    cat >&2 <<'MSG'
error: no App Store Connect API key found.

  export ASC_KEY_ID=XXXXXXXXXX
  export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  export ASC_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8   # or place it in
                                                       # ~/.appstoreconnect/private_keys/

Create one at App Store Connect → Users and Access → Integrations →
App Store Connect API, role App Manager. The .p8 downloads exactly once.
MSG
    exit 1
fi

work_directory=$(mktemp -d)
worktree="$work_directory/src"
archive="$work_directory/AFKRelay-$tag.xcarchive"
export_directory="$work_directory/export"

cleanup() {
    git -C "$app_root" worktree remove --force "$worktree" >/dev/null 2>&1 || true
    rm -rf "$work_directory"
}
trap cleanup EXIT

# --- build -------------------------------------------------------------------

step "Checking out $tag into a scratch worktree"
git -C "$app_root" worktree add -q --detach "$worktree" "$tag"

step "Archiving $tag as version $tag build $build_number"
xcodebuild \
    -project "$worktree/AFKRelay.xcodeproj" \
    -scheme AFKRelay \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive" \
    MARKETING_VERSION="$tag" \
    CURRENT_PROJECT_VERSION="$build_number" \
    archive

step "Exporting for App Store Connect"
cat > "$work_directory/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>destination</key>
	<string>export</string>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportOptionsPlist "$work_directory/ExportOptions.plist" \
    -exportPath "$export_directory" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$key_path" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"

ipa="$export_directory/AFKRelay.ipa"
[ -f "$ipa" ] || die "export produced no ipa"

shipped_version=$(plutil -extract CFBundleShortVersionString raw \
    "$archive/Products/Applications/AFKRelay.app/Info.plist")
[ "$shipped_version" = "$tag" ] \
    || die "archive declares version $shipped_version but the tag is $tag"

# --- ship --------------------------------------------------------------------

step "Validating against App Store Connect"
xcrun altool --validate-app -f "$ipa" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

if [ "$mode" = "--validate-only" ]; then
    echo
    echo "validated $tag build $build_number (not uploaded)"
    exit 0
fi

step "Uploading"
xcrun altool --upload-app -f "$ipa" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

cat <<MSG

uploaded $tag build $build_number

Processing takes 5–15 minutes. Then, in App Store Connect:

  - Internal testing needs no review; assign the build to a group and it
    installs immediately.
  - External testing — and the only way to get a public link — requires
    Beta App Review, roughly 24–48 hours on a first submission. Later
    builds usually skip it.

Then record the release: ./scripts/check-release-sync.sh
MSG
