return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-neotest/nvim-nio',
      'nvim-treesitter/nvim-treesitter',
      'Issafalcon/neotest-dotnet',
    },
    keys = {
      {
        '<leader>tn',
        function() require('neotest').run.run() end,
        desc = '[T]est [N]earest',
      },
      {
        '<leader>tf',
        function() require('neotest').run.run(vim.fn.expand '%') end,
        desc = '[T]est [F]ile',
      },
      {
        '<leader>tl',
        function() require('neotest').run.run_last() end,
        desc = '[T]est [L]ast',
      },
      {
        '<leader>to',
        function() require('neotest').output.open { enter = true, auto_close = true } end,
        desc = '[T]est [O]utput',
      },
      {
        '<leader>tp',
        function() require('neotest').output_panel.toggle() end,
        desc = '[T]est Output [P]anel',
      },
      {
        '<leader>ts',
        function() require('neotest').summary.toggle() end,
        desc = '[T]est [S]ummary',
      },
      {
        '<leader>tS',
        function() require('neotest').run.stop() end,
        desc = '[T]est [S]top',
      },
    },
    config = function()
      require('neotest').setup {
        adapters = {
          require('neotest-dotnet'),
        },
        output_panel = {
          open = false,
        },
        quickfix = {
          enabled = false,
          open = false,
        },
      }
    end,
  },
}
