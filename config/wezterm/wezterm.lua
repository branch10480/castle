local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- フォント設定
config.font = wezterm.font "BitstromWera Nerd Font Mono"
config.font_size = 14

-- 初期ウィンドウサイズ
config.initial_cols = 150
config.initial_rows = 40

-- 背景の透明度とぼかし
config.window_background_opacity = 0.85
config.macos_window_background_blur = 20

-- タブバーを非表示
config.enable_tab_bar = false

-- タイトルバーを非表示（リサイズのみ可能）
config.window_decorations = "RESIZE"

-- リーダーキーの設定 (tmuxのプレフィックスキーに相当)
config.leader = { key = 't', mods = 'CTRL', timeout_milliseconds = 1000 }

-- 終了時の確認
config.window_close_confirmation='NeverPrompt'

-- キーバインドの設定
config.keys = {
    -- ペイン分割
    {
        key = '%',
        mods = 'LEADER|SHIFT',
        action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
    },
    {
        key = '"',
        mods = 'LEADER|SHIFT',
        action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
    },

    -- ペイン移動 (vim風)
    {
        key = 'h',
        mods = 'LEADER',
        action = wezterm.action.ActivatePaneDirection 'Left',
    },
    {
        key = 'j',
        mods = 'LEADER',
        action = wezterm.action.ActivatePaneDirection 'Down',
    },
    {
        key = 'k',
        mods = 'LEADER',
        action = wezterm.action.ActivatePaneDirection 'Up',
    },
    {
        key = 'l',
        mods = 'LEADER',
        action = wezterm.action.ActivatePaneDirection 'Right',
    },

    -- ペインを閉じる
    {
        key = 'x',
        mods = 'LEADER',
        action = wezterm.action.CloseCurrentPane { confirm = true },
    },

    -- ペインのズーム切り替え
    {
        key = 'z',
        mods = 'LEADER',
        action = wezterm.action.TogglePaneZoomState,
    },
    {
        key = '¥',
        action = wezterm.action.SendKey({ key = "\\" })
    },
    {
        key = '¥',
        mods = 'ALT',
        action = wezterm.action.SendKey({ key = "¥" })
    },
}

return config
