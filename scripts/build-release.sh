#!/bin/bash
set -euo pipefail

# Build script for For You — produces a distributable .app bundle
# Usage: ./scripts/build-release.sh [output_dir]

OUTPUT_DIR="${1:-build}"
SCHEME="ForYou"
APP_NAME="ForYou"

echo "==> Installing XcodeGen if needed..."
command -v xcodegen >/dev/null 2>&1 || brew install xcodegen

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Resolving Swift packages..."
xcodebuild -resolvePackageDependencies -scheme "$SCHEME" -quiet

echo "==> Building release..."
xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$OUTPUT_DIR/DerivedData" \
  -quiet \
  build

APP_PATH="$OUTPUT_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"

if [[ -d "$APP_PATH" ]]; then
  mkdir -p "$OUTPUT_DIR"
  cp -R "$APP_PATH" "$OUTPUT_DIR/$APP_NAME.app"
  echo "==> Built successfully: $OUTPUT_DIR/$APP_NAME.app"

  # Create zip for Homebrew distribution
  cd "$OUTPUT_DIR"
  zip -r -q "$APP_NAME.zip" "$APP_NAME.app"
  SHA256=$(shasum -a 256 "$APP_NAME.zip" | awk '{print $1}')
  echo "==> Archive: $OUTPUT_DIR/$APP_NAME.zip"
  echo "==> SHA256: $SHA256"
  echo ""
  echo "Update the Homebrew cask with:"
  echo "  sha256 \"$SHA256\""
else
  echo "ERROR: Build output not found at $APP_PATH"
  exit 1
fi
