-- Hammerspoon Configuration
-- Ctrl+Spaceでcmuxにフォーカス（なければ起動）

hs.hotkey.bind({"ctrl"}, "space", function()
    local app = hs.application.find("cmux")
    if app then
        app:activate()
    else
        hs.application.launchOrFocus("cmux")
    end
end)
