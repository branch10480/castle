local logo = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝
]]

return {
  'nvimdev/dashboard-nvim',
  event = 'VimEnter',
  config = function()
    require('dashboard').setup({
      theme = 'hyper',
      config = {
        header = vim.split(logo, '\n'),
        shortcut = {
        { desc = '󰊳 Update', group = '@property', action = 'Lazy update', key = 'u' },
        {
          icon = ' ',
          icon_hl = '@variable',
          desc = 'Files',
          group = 'Label',
          action = 'lua require("lazy").load({ plugins = { "snacks.nvim" } }); require("snacks").picker.files()',
          key = 'f',
        },
--         {
--           desc = ' Apps',
--           group = 'DiagnosticHint',
--           action = 'Telescope app',
--           key = 'a',
--         },
--         {
--           desc = ' dotfiles',
--           group = 'Number',
--           action = 'Telescope dotfiles',
--           key = 'd',
--         },
      },
      },
    })
  end,
  dependencies = {{'nvim-tree/nvim-web-devicons'}}
}
