#!/usr/bin/env bash
# Submits a zip, DMG, or pkg to Apple's notary service and fails unless it is
# accepted.
#   scripts/notarize.sh <path>
#
# Requires ASC_KEY_ID, ASC_ISSUER_ID, and ASC_PRIVATE_KEY (base64 of the .p8
# from App Store Connect). The temporary key file is removed on exit.

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: scripts/notarize.sh <zip|dmg|pkg>" >&2
    exit 2
fi

ARTIFACT="$1"
[ -e "$ARTIFACT" ] || { echo "missing $ARTIFACT" >&2; exit 1; }
for name in ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY; do
    [ -n "${!name:-}" ] || { echo "missing $name" >&2; exit 1; }
done

KEY="$(mktemp "${TMPDIR:-/tmp}/parrot-notary.XXXXXX")"
RESULT="$(mktemp "${TMPDIR:-/tmp}/parrot-notary-result.XXXXXX")"
trap 'rm -f "$KEY" "$RESULT"' EXIT

printf '%s' "$ASC_PRIVATE_KEY" | base64 --decode > "$KEY"
chmod 600 "$KEY"

if ! xcrun notarytool submit "$ARTIFACT" \
    --key "$KEY" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" \
    --wait --output-format json > "$RESULT"; then
    cat "$RESULT" >&2
    exit 1
fi

STATUS="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$RESULT")"
if [ "$STATUS" != "Accepted" ]; then
    ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$RESULT")"
    echo "notarization failed: $STATUS ($ID)" >&2
    xcrun notarytool log "$ID" \
        --key "$KEY" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" >&2 || true
    exit 1
fi
echo "notarization accepted"
