-- Hammerspoon Configuration
-- Ctrl+SpaceでWezTermにフォーカス（なければ起動）

hs.hotkey.bind({"ctrl"}, "space", function()
    local app = hs.application.find("WezTerm")
    if app then
        app:activate()
    else
        hs.application.launchOrFocus("WezTerm")
    end
end)
