return {
  {
    'stevearc/oil.nvim',
    lazy = false,
    dependencies = {
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    init = function()
      vim.keymap.set('n', '<leader>e', function()
        vim.cmd.tabnew()
        require('oil').open()
      end, { desc = 'Open file explorer' })
    end,
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
      default_file_explorer = true,
      columns = {
        'icon',
      },
      view_options = {
        show_hidden = true,
      },
      float = {
        padding = 2,
        max_width = 0,
        max_height = 0,
        border = 'rounded',
      },
    },
  },
}
