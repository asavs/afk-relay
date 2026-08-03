#!/bin/sh
#
# Reports drift between the four places a release exists: this repository's
# tags, the GitHub releases, the companion wiki's release ledger, and the
# Xcode project's marketing version.
#
# Nothing here changes state. Run it before cutting a release and after
# pushing one.

set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
app_root=$(CDPATH= cd -- "$script_directory/.." && pwd)
wiki_root=$(CDPATH= cd -- "$app_root/../wiki" 2>/dev/null && pwd || echo "")
project_file="$app_root/AFKRelay.xcodeproj/project.pbxproj"
info_plist="$app_root/AFKRelay/Info.plist"
ledger="$wiki_root/implementation-status.md"

failures=0
warnings=0

fail() {
    echo "FAIL  $1"
    failures=$((failures + 1))
}

warn() {
    echo "WARN  $1"
    warnings=$((warnings + 1))
}

pass() {
    echo "ok    $1"
}

# Releases are tagged bare, without a `v` prefix — it is a version number, the
# letter adds nothing. Anything else is ignored here so stray working tags
# (backups, bookmarks) cannot be mistaken for releases.
release_tags() {
    git -C "$app_root" tag -l | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1,1n -k2,2n -k3,3n
}

latest_release_tag() {
    release_tags | tail -1
}

check_prefixed_tags() {
    prefixed=$(git -C "$app_root" tag -l | grep -E '^v[0-9]' || true)
    if [ -n "$prefixed" ]; then
        fail "tags carry a 'v' prefix; releases are tagged bare:"
        echo "$prefixed" | sed 's/^/        /'
    else
        pass "no v-prefixed tags"
    fi
}

check_clean_trees() {
    if [ -n "$(git -C "$app_root" status --porcelain)" ]; then
        warn "app working tree is dirty"
    else
        pass "app working tree clean"
    fi

    if [ -z "$wiki_root" ]; then
        fail "companion wiki not found at ../wiki"
        return
    fi

    if [ -n "$(git -C "$wiki_root" status --porcelain)" ]; then
        warn "wiki working tree is dirty"
    else
        pass "wiki working tree clean"
    fi
}

check_pushed() {
    unpushed=$(git -C "$app_root" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo "?")
    if [ "$unpushed" = "?" ]; then
        warn "app branch has no upstream"
    elif [ "$unpushed" != "0" ]; then
        fail "app has $unpushed unpushed commit(s)"
    else
        pass "app is pushed"
    fi

    [ -n "$wiki_root" ] || return 0

    # The wiki is pushed to the GitHub wiki remote by URL rather than a named
    # remote, so compare against the remote head directly.
    wiki_remote=$(git -C "$app_root" remote get-url origin 2>/dev/null | sed 's/\.git$//').wiki.git
    remote_head=$(git -C "$wiki_root" ls-remote "$wiki_remote" master 2>/dev/null | cut -f1)
    local_head=$(git -C "$wiki_root" rev-parse master 2>/dev/null || echo "")

    if [ -z "$remote_head" ]; then
        warn "wiki remote unreachable or uninitialised (create one page in the web UI first)"
    elif [ "$remote_head" != "$local_head" ]; then
        fail "wiki has unpushed commits (local $(echo "$local_head" | cut -c1-7), remote $(echo "$remote_head" | cut -c1-7))"
    else
        pass "wiki is pushed"
    fi
}

check_marketing_version() {
    latest=$(latest_release_tag)
    [ -n "$latest" ] || { warn "no release tags yet"; return; }

    versions=$(grep -o 'MARKETING_VERSION = [^;]*;' "$project_file" | sed 's/MARKETING_VERSION = //; s/;//' | sort -u)
    count=$(echo "$versions" | wc -l | tr -d ' ')

    if [ "$count" != "1" ]; then
        fail "project has inconsistent MARKETING_VERSION values: $(echo "$versions" | tr '\n' ' ')"
        return
    fi

    if [ "$versions" != "$latest" ]; then
        fail "MARKETING_VERSION is $versions but the latest release tag is $latest"
    else
        pass "MARKETING_VERSION matches latest tag ($latest)"
    fi
}

# Apple rejects any upload carrying the HealthKit entitlement without a write
# purpose string, whether or not the app writes (error 90683). The encryption
# declaration is not required, but its absence stops every upload to ask.
check_privacy_keys() {
    for key in NSHealthShareUsageDescription NSHealthUpdateUsageDescription ITSAppUsesNonExemptEncryption; do
        if grep -q "<key>$key</key>" "$info_plist"; then
            pass "Info.plist declares $key"
        else
            fail "Info.plist is missing $key — uploads will be rejected"
        fi
    done
}

check_github_releases() {
    if ! command -v gh >/dev/null 2>&1; then
        warn "gh not installed; skipping GitHub release checks"
        return
    fi
    # Ask whether a call works, not whether every stored account is healthy.
    # gh auth status fails if any account is broken — a keychain token this
    # session cannot read counts — so it reported "not authenticated" while a
    # working GH_TOKEN sat right beside it, and these checks silently skipped.
    if ! gh api user >/dev/null 2>&1; then
        warn "gh cannot reach GitHub; skipping GitHub release checks"
        return
    fi

    published=$(gh release list --limit 100 --json tagName --jq '.[].tagName' 2>/dev/null || echo "")
    for tag in $(release_tags); do
        if echo "$published" | grep -qx "$tag"; then
            pass "release published for $tag"
        else
            fail "tag $tag has no GitHub release"
        fi
    done
}

check_ledger() {
    [ -n "$wiki_root" ] || return 0
    if [ ! -f "$ledger" ]; then
        fail "wiki has no implementation-status.md to hold the release ledger"
        return
    fi

    for tag in $(release_tags); do
        if grep -q "releases/tag/$tag" "$ledger"; then
            pass "ledger records $tag"
        else
            fail "release $tag is missing from the wiki release ledger"
        fi
    done
}

# Design decisions recorded after the newest release are not yet accounted for
# by any ledger row. That is normal mid-cycle; it is reported so the next
# release remembers to claim them.
check_unledgered_wiki_work() {
    [ -n "$wiki_root" ] || return 0
    latest=$(latest_release_tag)
    [ -n "$latest" ] || return 0

    tag_date=$(git -C "$app_root" log -1 --format=%cI "$latest" 2>/dev/null || echo "")
    [ -n "$tag_date" ] || return 0

    pending=$(git -C "$wiki_root" log --since="$tag_date" --format='%h %s' master 2>/dev/null || echo "")
    if [ -n "$pending" ]; then
        warn "wiki commits since $latest are not in any ledger row:"
        echo "$pending" | sed 's/^/        /'
    else
        pass "no unledgered wiki work"
    fi
}

echo "Release sync — app, GitHub, wiki, Xcode project"
echo

check_clean_trees
check_pushed
check_prefixed_tags
check_marketing_version
check_privacy_keys
check_github_releases
check_ledger
check_unledgered_wiki_work

echo
if [ "$failures" -gt 0 ]; then
    echo "$failures failure(s), $warnings warning(s)"
    exit 1
fi
echo "in sync ($warnings warning(s))"
