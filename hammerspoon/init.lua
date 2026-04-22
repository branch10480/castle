-- Hammerspoon Configuration
-- Ctrl+Spaceでcmuxにフォーカス（なければ起動）

local cmuxBundleID = "com.cmuxterm.app.nightly"

hs.hotkey.bind({"ctrl"}, "space", function()
    local app = hs.application.get(cmuxBundleID)
    if app then
        app:activate()
    else
        hs.application.launchOrFocusByBundleID(cmuxBundleID)
    end
end)
