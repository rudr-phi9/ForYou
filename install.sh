#!/bin/bash
set -euo pipefail

# One-line installer for "For You"
# Usage: curl -fsSL https://raw.githubusercontent.com/rudraksh/ForYou/main/install.sh | bash

APP_NAME="ForYou"
INSTALL_DIR="/Applications"
REPO="https://github.com/rudraksh/ForYou.git"
TMPDIR_BUILD=$(mktemp -d)

echo ""
echo "  ✦ For You — AI Research Aggregator"
echo "  ──────────────────────────────────"
echo ""

# Check prerequisites
if ! command -v xcodebuild &>/dev/null; then
  echo "  ✕ Xcode Command Line Tools required."
  echo "    Run: xcode-select --install"
  exit 1
fi

if ! command -v brew &>/dev/null; then
  echo "  ✕ Homebrew required for XcodeGen."
  echo "    Run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  exit 1
fi

# Install XcodeGen if needed
if ! command -v xcodegen &>/dev/null; then
  echo "  → Installing XcodeGen..."
  brew install xcodegen
fi

# Clone
echo "  → Cloning repository..."
git clone --depth 1 "$REPO" "$TMPDIR_BUILD/$APP_NAME" 2>/dev/null

cd "$TMPDIR_BUILD/$APP_NAME"

# Generate project
echo "  → Generating Xcode project..."
xcodegen generate --quiet

# Resolve packages
echo "  → Resolving Swift packages..."
xcodebuild -resolvePackageDependencies -scheme "$APP_NAME" -quiet 2>/dev/null

# Build
echo "  → Building (this may take a minute)..."
xcodebuild \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$TMPDIR_BUILD/build" \
  -quiet \
  build 2>/dev/null

APP_PATH="$TMPDIR_BUILD/build/Build/Products/Release/$APP_NAME.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "  ✕ Build failed. Run manually for details:"
  echo "    git clone $REPO && cd ForYou && xcodegen generate && xcodebuild -scheme ForYou build"
  rm -rf "$TMPDIR_BUILD"
  exit 1
fi

# Install
echo "  → Installing to $INSTALL_DIR..."
if [[ -d "$INSTALL_DIR/$APP_NAME.app" ]]; then
  rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi
cp -R "$APP_PATH" "$INSTALL_DIR/$APP_NAME.app"

# Clean up
rm -rf "$TMPDIR_BUILD"

echo ""
echo "  ✓ For You installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "  Launch it from your menu bar — look for the ✦ sparkle icon."
echo "  Open Settings (⌘,) to add your Gemini API key and research topics."
echo ""
