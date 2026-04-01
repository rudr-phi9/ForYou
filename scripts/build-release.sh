#!/bin/bash
set -euo pipefail

# Build script for For You — produces a versioned, distributable .app bundle
# Usage: ./scripts/build-release.sh [version]
#   version: optional override (e.g. 1.2.0). Defaults to VERSION file.
#
# Versioning scheme:
#   MARKETING_VERSION  = major.minor.patch from VERSION file  (shown in About)
#   CURRENT_PROJECT_VERSION = git commit count                (build number)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

SCHEME="ForYou"
APP_NAME="ForYou"

# ── Version resolution ──────────────────────────────────────────────────────
if [[ -n "${1:-}" ]]; then
  VERSION="$1"
  echo "$VERSION" > VERSION
else
  VERSION="$(cat VERSION | tr -d '[:space:]')"
fi

BUILD_NUMBER="$(git rev-list --count HEAD)"
OUTPUT_DIR="release"

echo "╔══════════════════════════════════════╗"
echo "║  For You — Release Build             ║"
echo "╠══════════════════════════════════════╣"
echo "║  Version      : $VERSION"
echo "║  Build Number : $BUILD_NUMBER"
echo "║  Output       : $OUTPUT_DIR/"
echo "╚══════════════════════════════════════╝"
echo ""

# ── Patch project.yml ───────────────────────────────────────────────────────
echo "==> Updating version in project.yml..."
# Use sed to update MARKETING_VERSION and CURRENT_PROJECT_VERSION in project.yml
sed -i '' "s/MARKETING_VERSION: \"[^\"]*\"/MARKETING_VERSION: \"$VERSION\"/" project.yml
sed -i '' "s/CURRENT_PROJECT_VERSION: [0-9]*/CURRENT_PROJECT_VERSION: $BUILD_NUMBER/" project.yml

# ── Build ───────────────────────────────────────────────────────────────────
echo "==> Installing XcodeGen if needed..."
command -v xcodegen >/dev/null 2>&1 || brew install xcodegen

echo "==> Generating Xcode project..."
xcodegen generate --quiet

echo "==> Resolving Swift packages..."
xcodebuild -resolvePackageDependencies -project "$APP_NAME.xcodeproj" -scheme "$SCHEME" -quiet

echo "==> Building release (this takes ~1 min)..."
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$OUTPUT_DIR/DerivedData" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  -quiet \
  build

APP_PATH="$OUTPUT_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: Build output not found at $APP_PATH"
  exit 1
fi

# ── Package ─────────────────────────────────────────────────────────────────
echo "==> Packaging..."
rm -rf "$OUTPUT_DIR/$APP_NAME.app" "$OUTPUT_DIR/$APP_NAME-$VERSION.zip"
cp -R "$APP_PATH" "$OUTPUT_DIR/$APP_NAME.app"

cd "$OUTPUT_DIR"
zip -r -q "$APP_NAME-$VERSION.zip" "$APP_NAME.app"
# Also keep a stable ForYou.zip for direct download links
cp "$APP_NAME-$VERSION.zip" "$APP_NAME.zip"
cd "$ROOT_DIR"

SHA256=$(shasum -a 256 "$OUTPUT_DIR/$APP_NAME-$VERSION.zip" | awk '{print $1}')

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Build complete!                                         ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  App    : $OUTPUT_DIR/$APP_NAME.app"
echo "║  Zip    : $OUTPUT_DIR/$APP_NAME-$VERSION.zip"
echo "║  SHA256 : $SHA256"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  To release on GitHub:                                   ║"
echo "║  1. git tag v$VERSION && git push --tags          "
echo "║  2. Upload $APP_NAME-$VERSION.zip to GitHub Releases      "
echo "║  3. Update homebrew-tap/Casks/foryou.rb sha256 above     ║"
echo "╚══════════════════════════════════════════════════════════╝"
