#!/bin/bash
# Called only by the release workflow or explicitly by the maintainer.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GITHUB_REPOSITORY:?Set owner/repository}"
: "${RELEASE_TAG:?Set a unique release tag}"
: "${SPARKLE_PRIVATE_KEY_FILE:?Set the exported Sparkle private key file path}"
: "${BUILD_NUMBER:?Set an increasing build number}"
: "${GITHUB_SHA:?Set the commit to release}"
BUILD_PATH="${BUILD_PATH:-$PWD/.build}"
RELEASE_DIR="$(mktemp -d /private/tmp/local-dictation-release.XXXXXX)"
trap 'rm -rf "$RELEASE_DIR"' EXIT
cp 'dist/Local Dictation.zip' "$RELEASE_DIR/LocalDictation-$BUILD_NUMBER.zip"
"$BUILD_PATH/artifacts/sparkle/Sparkle/bin/generate_appcast" \
    --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" \
    --download-url-prefix "https://github.com/$GITHUB_REPOSITORY/releases/download/$RELEASE_TAG/" "$RELEASE_DIR"
test -s "$RELEASE_DIR/appcast.xml"
swift scripts/verify-appcast.swift "$RELEASE_DIR/appcast.xml" "$RELEASE_DIR/LocalDictation-$BUILD_NUMBER.zip"
# The latest feed switches only after every asset has been uploaded to the draft.
gh release create "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --target "$GITHUB_SHA" \
    --draft --title "Local Dictation — build $BUILD_NUMBER" --generate-notes \
    "$RELEASE_DIR/LocalDictation-$BUILD_NUMBER.zip" "$RELEASE_DIR/appcast.xml"
gh release edit "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --draft=false --latest
