#!/bin/bash
#
# release.sh
#
# This file is part of Nightcap.
#
# Nightcap is free software: you can redistribute it and/or modify it under the terms
# of the GNU General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Nightcap is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with Nightcap.
# If not, see https://www.gnu.org/licenses/.
#
# Builds, signs, notarizes, staples, and packages Nightcap.app as a DMG.
#
# Prerequisites:
#   - Developer ID Application certificate installed in Keychain
#   - notarytool credentials stored under the profile named by NOTARY_PROFILE.
#     Without them the DMG is still built and signed, only not notarized.
#
# Usage: scripts/release.sh <version>
# Example: scripts/release.sh 3.0.0

set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version>}"
NOTARY_PROFILE="${NOTARY_PROFILE:-vsg-notary}"

# The build number has to rise with every release, so derive it from the
# version unless one is given: 1.0.0 -> 10000, 1.2.3 -> 10203.
BUILD_NUMBER="${BUILD_NUMBER:-$(echo "$VERSION" | awk -F. '{printf "%d%02d%02d", $1, $2, $3}')}"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/release"
ARCHIVE_PATH="$BUILD_DIR/Nightcap.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
STAGE_PATH="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/Nightcap-$VERSION.dmg"

cd "$PROJECT_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving Nightcap $VERSION (build $BUILD_NUMBER)"
# The version is injected rather than read from the project, so the version in
# the DMG name and the version the app reports can never disagree.
xcodebuild \
    -project Nightcap.xcodeproj \
    -scheme Nightcap \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    archive

echo "==> Exporting and re-signing with Developer ID"
rm -rf "$EXPORT_PATH"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist scripts/exportOptions.plist \
    -allowProvisioningUpdates

APP_PATH="$EXPORT_PATH/Nightcap.app"
[ -d "$APP_PATH" ] || { echo "Nightcap.app not found at $APP_PATH"; exit 1; }

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# Notarization needs an Apple ID and an app-specific password stored under
# NOTARY_PROFILE. A local build is perfectly installable without it -- the
# difference only shows when someone else downloads it, because Gatekeeper then
# has no ticket to check. Skipped rather than fatal so a signed local release
# does not require credentials.
notarize_available() {
    [ "${SKIP_NOTARIZE:-0}" != "1" ] &&
        xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1
}

if notarize_available; then
    # The app is notarized and stapled before it goes into the DMG. Stapling the
    # DMG alone leaves the app relying on an online check once it is dragged
    # out, which fails on a machine that is offline the first time it runs.
    echo "==> Notarizing the app (this can take several minutes)"
    APP_ZIP="$BUILD_DIR/Nightcap-app.zip"
    rm -f "$APP_ZIP"
    ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
    xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    rm -f "$APP_ZIP"
    echo "==> Stapling the app"
    xcrun stapler staple "$APP_PATH"
    xcrun stapler validate "$APP_PATH"
else
    echo "==> Skipping notarization (no credentials under '$NOTARY_PROFILE', or SKIP_NOTARIZE=1)"
    echo "    The build is signed and installs locally. To notarize for distribution:"
    echo "      xcrun notarytool store-credentials \"$NOTARY_PROFILE\" \\"
    echo "          --apple-id <your-apple-id> --team-id Y67X4P87LT"
fi

echo "==> Building DMG"
rm -f "$DMG_PATH"
# Staged with a symlink beside the app so the window offers a drop target:
# dragging onto it is also how an existing install is replaced.
rm -rf "$STAGE_PATH"
mkdir -p "$STAGE_PATH"
ditto "$APP_PATH" "$STAGE_PATH/Nightcap.app"
ln -s /Applications "$STAGE_PATH/Applications"
hdiutil create \
    -volname "Nightcap $VERSION" \
    -srcfolder "$STAGE_PATH" \
    -ov -format UDZO \
    "$DMG_PATH"

echo "==> Signing DMG"
codesign --sign "Developer ID Application" --timestamp "$DMG_PATH"

# The DMG is notarized in its own right, so the disk image also opens without a
# Gatekeeper prompt -- the ticket stapled to the app inside does not cover it.
if notarize_available; then
    echo "==> Notarizing the DMG (this can take several minutes)"
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    echo "==> Stapling the DMG"
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
fi

echo "==> Verifying DMG signature"
codesign --verify --strict --verbose=2 "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH" || true

echo
echo "Build artifact: $DMG_PATH"
shasum -a 256 "$DMG_PATH"
