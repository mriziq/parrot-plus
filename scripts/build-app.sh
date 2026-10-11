#!/usr/bin/env bash
# Builds the app bundle used to run Parrot locally.
#   scripts/build-app.sh [version]        → build/Parrot Plus.app
#
# The version goes into CFBundleShortVersionString and CFBundleVersion.
#
# Signs with the first "Developer ID Application" identity in the keychain,
# with the hardened runtime and packaging/Parrot.entitlements. The
# designated requirement then names the bundle ID and the team, not a
# cdhash, so macOS keeps the Microphone and Accessibility grants across
# builds. Without an identity the app is ad-hoc signed and every build is a
# new identity; the script says so.
#
#   PARROT_SIGN_IDENTITY   signing identity (default: the keychain's Developer ID)
#   PARROT_TIMESTAMP=none  skip the secure timestamp (local builds, offline)
#   PARROT_BUILD_DIR       output directory (default: build)

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo 0.0.0)}"
VERSION="${VERSION#v}"
OUT="${PARROT_BUILD_DIR:-build}"
APP="$OUT/Parrot Plus.app"

IDENTITY="${PARROT_SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}"

echo "→ building parrot $VERSION (release, arm64)"
swift build -c release --arch arm64 --product parrot
BIN="$(swift build -c release --arch arm64 --show-bin-path)/parrot"

echo "→ assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/parrot"
strip -x "$APP/Contents/MacOS/parrot"
cp packaging/Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# SwiftPM's resource bundles (swift-transformers' fallback tokenizer
# configs, swift-crypto's privacy manifest) are left out, as they were from
# the bare binary: their accessors look beside the .app, where a signed
# bundle can't hold anything.

# docs/assets/app-icon.png is the bird on a white rounded square, drawn by
# scripts/make-app-icon.swift from docs/assets/icon.png.
ICONSET="$OUT/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" docs/assets/app-icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" docs/assets/app-icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

TIMESTAMP="--timestamp"
[ "${PARROT_TIMESTAMP:-}" = "none" ] && TIMESTAMP="--timestamp=none"

if [ -n "$IDENTITY" ]; then
    echo "→ signing as $IDENTITY"
    SIGN_AS="$IDENTITY"
else
    echo "! no Developer ID Application identity; ad-hoc signing."
    echo "  Permissions may need to be granted again after rebuilding."
    SIGN_AS="-"
    TIMESTAMP="--timestamp=none"
fi

codesign --force --options runtime $TIMESTAMP \
    --entitlements packaging/Parrot.entitlements \
    --sign "$SIGN_AS" "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
echo "  designated requirement: $(codesign -d -r- "$APP" 2>&1 | sed -n 's/^designated => //p')"
echo "$APP"
