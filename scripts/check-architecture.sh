#!/bin/sh

set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
app_root=$(CDPATH= cd -- "$script_directory/.." && pwd)
source_root="$app_root/AFKRelay"

failures=0

# grep exits 0 on match, 1 on no match, and >1 on errors such as a malformed
# pattern. A pattern error must fail the script, not read as a clean pass.
searched_matches=""
search() {
    set +e
    searched_matches=$(grep -rEn --include='*.swift' "$@")
    search_status=$?
    set -e
    if [ "$search_status" -gt 1 ]; then
        echo "grep failed (status $search_status): grep -rEn $*" >&2
        exit "$search_status"
    fi
}

check_forbidden_imports() {
    scope=$1
    search '^[[:space:]]*import[[:space:]]+(HealthKit|StoreKit)([[:space:]]|$)' "$scope"
    if [ -n "$searched_matches" ]; then
        echo "Framework boundary violation:"
        echo "$searched_matches"
        failures=1
    fi
}

check_concrete_resources() {
    scope=$1
    search 'SKTexture[[:space:]]*\([[:space:]]*imageNamed:|Image[[:space:]]*\([[:space:]]*"|NamedColor|themeID|catalogID' "$scope"
    if [ -n "$searched_matches" ]; then
        echo "Concrete presentation resource leaked into mechanics:"
        echo "$searched_matches"
        failures=1
    fi
}

if [ -d "$source_root/Domain" ]; then
    check_forbidden_imports "$source_root/Domain"
    check_concrete_resources "$source_root/Domain"
fi

if [ -d "$source_root/Game" ]; then
    check_forbidden_imports "$source_root/Game"
    check_concrete_resources "$source_root/Game"
fi

if [ -d "$source_root/Presentation" ]; then
    check_forbidden_imports "$source_root/Presentation"
fi

if [ -d "$source_root/UI" ]; then
    check_forbidden_imports "$source_root/UI"
fi

search --exclude='Economy.swift' --exclude='*Tests.swift' \
    'lifetimeStepsCredited[[:space:]]*(\+=|=([^=]|$))|availableTokens[[:space:]]*\+=' \
    "$source_root"
if [ -n "$searched_matches" ]; then
    echo "Movement-token minting must remain inside Domain/Economy:"
    echo "$searched_matches"
    failures=1
fi

if [ "$failures" -ne 0 ]; then
    exit 1
fi

echo "Architecture boundaries passed."
