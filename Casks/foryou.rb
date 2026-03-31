# Homebrew Cask for "For You" — AI Research Aggregator
#
# To set up your own tap:
#
# 1. Create a GitHub repo: github.com/<username>/homebrew-foryou
# 2. Put this file at: Casks/foryou.rb
# 3. Build a release zip: ./scripts/build-release.sh
# 4. Upload ForYou.zip to a GitHub Release
# 5. Update the `url` and `sha256` below
# 6. Users install with: brew tap <username>/foryou && brew install --cask foryou
#
cask "foryou" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_FROM_BUILD_SCRIPT"

  # Update this URL to point to your GitHub Release asset
  url "https://github.com/rudraksh/ForYou/releases/download/v#{version}/ForYou.zip"
  name "For You"
  desc "AI-powered research aggregator — arXiv, blogs, YouTube in your menu bar"
  homepage "https://github.com/rudraksh/ForYou"

  depends_on macos: ">= :sonoma"

  app "ForYou.app"

  zap trash: [
    "~/Library/Application Support/ForYou",
    "~/Library/Preferences/com.foryou.app.plist",
    "~/Library/Caches/com.foryou.app",
  ]
end
