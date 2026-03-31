# Homebrew Cask for "For You" — AI Research Aggregator
# Install: brew install --cask rudraksh/foryou/foryou
cask "foryou" do
  version "1.0.0"
  sha256 "REPLACE_AFTER_FIRST_RELEASE"

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
