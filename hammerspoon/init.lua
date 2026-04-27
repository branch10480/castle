-- Hammerspoon Configuration
-- Ctrl+SpaceでGhosttyにフォーカス（なければ起動）

local ghosttyBundleID = "com.mitchellh.ghostty"

hs.hotkey.bind({"ctrl"}, "space", function()
    local app = hs.application.get(ghosttyBundleID)
    if app then
        app:activate()
    else
        hs.application.launchOrFocusByBundleID(ghosttyBundleID)
    end
end)
