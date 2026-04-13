-- Hammerspoon Configuration
-- Ctrl+SpaceでGhosttyにフォーカス（なければ起動）

hs.hotkey.bind({"ctrl"}, "space", function()
    local app = hs.application.find("Ghostty")
    if app then
        app:activate()
    else
        hs.application.launchOrFocus("Ghostty")
    end
end)
