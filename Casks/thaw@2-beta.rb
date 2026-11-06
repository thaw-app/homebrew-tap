cask "thaw@2-beta" do
  version "2.2.0-beta.1"
  sha256 "db1d208d67f944b83b7a4e9ee9b1df50e628eefa91908a8ee0384c5c05a52797"

  url "https://github.com/thaw-app/Thaw/releases/download/#{version}/Thaw_#{version}.zip"
  name "Thaw"
  desc "Menu bar manager"
  homepage "https://github.com/thaw-app/Thaw/"

  # Thaw 2's beta channel: 2.x betas and release candidates, and stable 2.x when it is newer.
  livecheck do
    url :url
    regex(/^v?(2(?:\.\d+)+(?:-(?:beta|rc)[._-]?\d+(?:\.\d+)*)?)$/i)
  end

  auto_updates true
  conflicts_with cask: [
    "thaw",
    "thaw-app/tap/thaw@2",
    "thaw@beta",
  ]
  # No maximum: on macOS 27, Thaw 2 opens with a warning that offers Thaw 3 through beta updates.
  depends_on macos: :sequoia

  app "Thaw.app"

  uninstall quit: ["com.stonerl.Thaw", "com.stonerl.Thaw.MenuBarItemService"]

  zap trash: [
    "~/Library/Application Scripts/*.com.stonerl.Thaw",
    "~/Library/Application Scripts/com.stonerl.Thaw.ThawControls",
    "~/Library/Application Support/Thaw",
    "~/Library/Caches/com.stonerl.Thaw",
    "~/Library/Containers/com.stonerl.Thaw.ThawControls",
    "~/Library/Group Containers/*.com.stonerl.Thaw",
    "~/Library/HTTPStorages/com.stonerl.Thaw",
    "~/Library/Logs/Thaw",
    "~/Library/Preferences/com.stonerl.Thaw.plist",
    "~/Library/WebKit/com.stonerl.Thaw",
  ]
end
