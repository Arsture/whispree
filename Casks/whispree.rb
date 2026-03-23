cask "whispree" do
  version :latest
  sha256 :no_check

  url "https://github.com/Arsture/whispree/releases/latest/download/Whispree.zip"
  name "Whispree"
  desc "macOS menu bar STT app with local WhisperKit transcription"
  homepage "https://github.com/Arsture/whispree"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true

  app "Whispree.app"

  zap trash: [
    "~/Library/Application Support/Whispree",
    "~/Library/Caches/com.whispree.app",
    "~/Library/Preferences/com.whispree.app.plist",
    "~/Library/Saved Application State/com.whispree.app.savedState",
  ]
end
