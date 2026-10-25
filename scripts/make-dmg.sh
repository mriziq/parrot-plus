#!/usr/bin/env bash
# Builds a distributable disk image from the app bundle.
#   scripts/make-dmg.sh [version] [app]   → build/Parrot-Plus-<version>.dmg
#
# The DMG holds Parrot Plus.app and an /Applications symlink. It is not
# signed here; the release workflow signs, notarizes, and staples it.
# Prints the absolute DMG path on stdout.
#
#   PARROT_BUILD_DIR   output directory (default: build)

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo 0.0.0)}"
VERSION="${VERSION#v}"
OUT="${PARROT_BUILD_DIR:-build}"
APP="${2:-$OUT/Parrot Plus.app}"
STAGE="$OUT/dmg-stage"
DMG_NAME="Parrot-Plus-$VERSION.dmg"

if [ ! -d "$APP" ]; then
    echo "missing $APP; run scripts/build-app.sh $VERSION first" >&2
    exit 1
fi

rm -rf "$STAGE"
rm -f "$OUT/$DMG_NAME"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Parrot Plus.app"
ln -s /Applications "$STAGE/Applications"

echo "→ packaging $DMG_NAME" >&2
hdiutil create \
    -volname "Parrot Plus" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$OUT/$DMG_NAME" >&2

rm -rf "$STAGE"
OUT_ABS="$(cd "$OUT" && pwd)"
echo "$OUT_ABS/$DMG_NAME"
