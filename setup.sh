#!/bin/bash
set -e

# ──────────────────────────────────────────────────────────────
  For You — Setup Script
#  Installs dependencies and generates the Xcode project.
# ──────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "═══════════════════════════════════════════════════════════"
echo "  For You — macOS Menubar App Setup"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ── 1. Check for Homebrew ─────────────────────────────────────
if ! command -v brew &>/dev/null; then
    echo "→ Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "✓ Homebrew found."
fi

# ── 2. Install XcodeGen ──────────────────────────────────────
if ! command -v xcodegen &>/dev/null; then
    echo "→ Installing XcodeGen..."
    brew install xcodegen
else
    echo "✓ XcodeGen found."
fi

# ── 3. Verify Xcode command-line tools ────────────────────────
if ! xcode-select -p &>/dev/null; then
    echo "→ Installing Xcode command-line tools..."
    xcode-select --install
    echo "  Please complete the installation dialog, then re-run this script."
    exit 1
else
    echo "✓ Xcode command-line tools found."
fi

# ── 4. Generate Xcode project ────────────────────────────────
echo ""
echo "→ Generating Xcode project from project.yml..."
xcodegen generate

echo ""
echo "✓ Xcode project generated: ForYou.xcodeproj"

# ── 5. Resolve Swift Package Manager dependencies ────────────
echo ""
echo "→ Resolving Swift packages (Google Generative AI SDK)..."
xcodebuild -resolvePackageDependencies \
    -project ForYou.xcodeproj \
    -scheme ForYou \
    2>&1 | grep -E "(Resolved|Fetching|Computing|resolved|error)" || true

echo ""
echo "✓ Swift packages resolved."

# ── 6. Open in Xcode ────────────────────────────────────────
echo ""
echo "→ Opening in Xcode..."
open ForYou.xcodeproj

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✓  Setup complete!"
echo ""
echo "  NEXT STEPS:"
echo "  1. In Xcode, wait for package resolution to finish."
echo "  2. Set your Gemini API key in one of these ways:"
echo ""
echo "     • IN THE APP: Click ⚙ Settings → Gemini API Key"
echo ""
echo "     • IN CODE: Open Sources/Utilities/SettingsManager.swift"
echo "       and set a default value for geminiAPIKey."
echo ""
echo "  3. Press ⌘R to build and run."
echo "  4. The app will appear as a ✦ sparkle icon in your"
echo "     menu bar (no Dock icon)."
echo "═══════════════════════════════════════════════════════════"
