-- エディタ補助プラグイン

return {
  -- インデント自動検出
  {
    "NMAC427/guess-indent.nvim",
    event = "BufReadPre",
    config = function()
      require("guess-indent").setup({})
    end,
  },
}
