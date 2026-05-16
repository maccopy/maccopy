cask "clipboard-manager" do
  version "1.1.1"
  sha256 "154a21008f95485a50ce3da1ece1a21eb9a11d77ceb3a2b21472d7fe1bc13296"

  url "https://github.com/FernandoHaeser/macos-clipboard-manager/releases/download/v#{version}/ClipboardManager.zip"
  name "Clipboard Manager"
  desc "macOS menu bar clipboard history manager"
  homepage "https://github.com/FernandoHaeser/macos-clipboard-manager"

  depends_on macos: ">= :sonoma"

  app "ClipboardManager.app"

  zap trash: [
    "~/Library/Application Support/ClipboardManager",
    "~/Library/Preferences/com.fernandohaeser.clipboardmanager.plist",
    "~/Library/LaunchAgents/com.fernandohaeser.clipboardmanager.plist",
    "~/Library/Logs/ClipboardManager.log",
  ]
end
