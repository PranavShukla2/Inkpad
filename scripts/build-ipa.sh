#!/bin/zsh
# Builds an unsigned Inkpad.ipa for sideloading (AltStore, SideStore, Sideloadly).
# The installer signs it with each person's own Apple ID.
#
# Usage: scripts/build-ipa.sh            -> build/Inkpad.ipa
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/Inkpad.xcarchive"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild archive \
    -project Inkpad.xcodeproj \
    -scheme Inkpad \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    -quiet

# An .ipa is just the app inside a Payload folder, zipped.
mkdir -p "$BUILD_DIR/Payload"
cp -R "$ARCHIVE/Products/Applications/Inkpad.app" "$BUILD_DIR/Payload/"
(cd "$BUILD_DIR" && zip -qry Inkpad.ipa Payload)
rm -rf "$BUILD_DIR/Payload"

echo "Built $BUILD_DIR/Inkpad.ipa ($(du -h "$BUILD_DIR/Inkpad.ipa" | cut -f1))"
