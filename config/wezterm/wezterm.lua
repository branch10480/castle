-- WezTerm Configuration
-- =====================
--
-- リーダーキー: Ctrl+a (タイムアウト: 1秒)
--
-- ## キーバインド一覧
--
-- ### ペイン操作
--   Leader + %     : 横分割
--   Leader + "     : 縦分割
--   Leader + h/j/k/l : ペイン移動 (vim風)
--   Leader + x     : ペインを閉じる
--   Leader + z     : ペインのズーム切り替え
--   Leader + r     : リサイズモード (h/j/k/l で調整、Esc/Enter で終了)
--
-- ### Workspace操作
--   Leader + s     : ワークスペース一覧を表示・選択
--   Leader + n     : 新規ワークスペース作成（名前入力）
--   Leader + $     : 現在のワークスペースをリネーム
--   Leader + (     : 前のワークスペースに切り替え
--   Leader + )     : 次のワークスペースに切り替え
--
-- ### Workspaceの使い方
--   1. Leader + n で新規ワークスペース作成（例: project-a）
--   2. 同様に別のワークスペースを作成（例: project-b）
--   3. Leader + s で一覧から選択、または ( / ) で前後移動
--   各ワークスペースは独立したタブ・ペイン構成を保持
--

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- 設定変更時自動リロード
config.automatically_reload_config = true

-- フォント設定
config.font = wezterm.font "BitstromWera Nerd Font Mono"
config.font_size = 14

-- 初期ウィンドウサイズ
config.initial_cols = 150
config.initial_rows = 50

-- カラースキーム（神奈川）
config.color_scheme = "Kanagawa (Gogh)"

-- 背景の透明度とぼかし
config.window_background_opacity = 0.85
config.macos_window_background_blur = 25

-- タブバーを非表示
config.enable_tab_bar = false

-- タイトルバーを非表示（リサイズのみ可能）
config.window_decorations = "RESIZE"

-- リーダーキーの設定
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

-- 終了時の確認
config.window_close_confirmation='NeverPrompt'

-- 非アクティブペインの色を変えない
config.inactive_pane_hsb = {
    saturation = 1.0,
    brightness = 1.0,
}

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

    -- リサイズモードに入る
    {
        key = 'r',
        mods = 'LEADER',
        action = wezterm.action.ActivateKeyTable {
            name = 'resize_pane',
            one_shot = false,
        },
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

    -- Workspace操作
    -- ワークスペース一覧を表示して選択
    {
        key = 's',
        mods = 'LEADER',
        action = wezterm.action.ShowLauncherArgs { flags = 'WORKSPACES' },
    },
    -- 新規ワークスペース作成（名前を入力）
    {
        key = 'n',
        mods = 'LEADER',
        action = wezterm.action.PromptInputLine {
            description = 'Enter new workspace name:',
            action = wezterm.action_callback(function(window, pane, line)
                if line then
                    window:perform_action(
                        wezterm.action.SwitchToWorkspace { name = line },
                        pane
                    )
                end
            end),
        },
    },
    -- 現在のワークスペースをリネーム
    {
        key = '$',
        mods = 'LEADER|SHIFT',
        action = wezterm.action.PromptInputLine {
            description = 'Rename workspace:',
            action = wezterm.action_callback(function(window, pane, line)
                if line then
                    wezterm.mux.rename_workspace(
                        wezterm.mux.get_active_workspace(),
                        line
                    )
                end
            end),
        },
    },
    -- 前のワークスペースに切り替え
    {
        key = '(',
        mods = 'LEADER|SHIFT',
        action = wezterm.action.SwitchWorkspaceRelative(-1),
    },
    -- 次のワークスペースに切り替え
    {
        key = ')',
        mods = 'LEADER|SHIFT',
        action = wezterm.action.SwitchWorkspaceRelative(1),
    },
}

-- リサイズモード用キーテーブル
config.key_tables = {
    resize_pane = {
        { key = 'h', action = wezterm.action.AdjustPaneSize { 'Left', 3 } },
        { key = 'j', action = wezterm.action.AdjustPaneSize { 'Down', 3 } },
        { key = 'k', action = wezterm.action.AdjustPaneSize { 'Up', 3 } },
        { key = 'l', action = wezterm.action.AdjustPaneSize { 'Right', 3 } },
        { key = 'Escape', action = 'PopKeyTable' },
        { key = 'Enter', action = 'PopKeyTable' },
    },
}

return config
