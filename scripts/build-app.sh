#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD_PATH="${BUILD_PATH:-$PWD/.build}"
ARGS=(--scratch-path "$BUILD_PATH" -c release)
if [ "${UNIVERSAL_BUILD:-0}" = 1 ]; then ARGS+=(--arch arm64 --arch x86_64); fi
STAGING="$(mktemp -d /private/tmp/local-dictation-build.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Local Dictation.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp Resources/Info.plist "$APP/Contents/Info.plist"
python3 scripts/configure-release.py "$APP/Contents/Info.plist"
swift build "${ARGS[@]}"
BIN="$(swift build "${ARGS[@]}" --show-bin-path)"
cp "$BIN/LocalDictation" "$APP/Contents/MacOS/LocalDictation"
cp -R Resources/Licenses "$APP/Contents/Resources/"
cp LICENSE "$APP/Contents/Resources/Licenses/LocalDictation-LICENSE.txt"
cp -R Resources/Sounds "$APP/Contents/Resources/"
for bundle in "$BIN"/*.bundle; do
    [ -e "$bundle" ] || continue
    cp -R "$bundle" "$APP/Contents/Resources/"
done
SPARKLE="$BUILD_PATH/artifacts/sparkle/Sparkle"
FRAMEWORK="$SPARKLE/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
test -d "$FRAMEWORK"
ditto --norsrc "$FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$SPARKLE/LICENSE" "$APP/Contents/Resources/Licenses/Sparkle.txt"
xattr -cr "$APP"
IDENTITY="${CODE_SIGN_IDENTITY:--}"
SIGN=(--force --sign "$IDENTITY")
if [ "$IDENTITY" != - ]; then SIGN+=(--options runtime --timestamp); fi
# Sign nested helpers inside-out, preserving the framework's symlinks.
BASE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for target in "$BASE/XPCServices/Downloader.xpc" "$BASE/XPCServices/Installer.xpc" "$BASE/Autoupdate" "$BASE/Updater.app" "$APP/Contents/Frameworks/Sparkle.framework"; do
    codesign "${SIGN[@]}" "$target"
done
codesign "${SIGN[@]}" --entitlements Resources/Entitlements.plist "$APP"
codesign --verify --deep --strict "$APP"
mkdir -p dist
# A release is notarized and stapled before its final archive is signed by Sparkle.
if [ "${RELEASE_BUILD:-0}" = 1 ]; then
    : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a stored notarytool credentials profile}"
    ditto --norsrc -c -k --keepParent "$APP" "$STAGING/notarize.zip"
    xcrun notarytool submit "$STAGING/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
fi
ditto --norsrc -c -k --keepParent "$APP" "$PWD/dist/Local Dictation.zip"
printf '%s\n' "$PWD/dist/Local Dictation.zip"
