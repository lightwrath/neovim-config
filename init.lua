vim.g.mapleader = ' ' -- Must be done first, before plugins used so wrong leader isn't used
vim.g.maplocalleader = ' '

-- [[ SETTINGS ]] --
vim.g.have_nerd_font = true --Nerdfonts needing to be installed on the system!
vim.o.number = true -- Line numbers
vim.o.relativenumber = true
vim.o.mouse = 'a' -- Enable mouse mode (split resizing)
vim.o.showmode = false -- Already in status bar
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end) -- Sync clipboard with OS
vim.o.breakindent = true -- Indentation
vim.o.undofile = true --undo/redo after closing and reopening file
vim.o.ignorecase = true -- For searching
vim.o.smartcase = true
vim.o.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.list = true -- For whitespace character displays
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.inccommand = 'split' -- Preview substitutions live, as you type!
vim.o.cursorline = true -- Show which line your cursor is on
vim.o.scrolloff = 10 -- Minimal number of screen lines to keep above and below the cursor.
vim.o.confirm = true -- Show dialog one failed operation (:q with unsaved changes = dialog prompt)
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>') -- Clear highlights on search when pressing <Esc> in normal mode

local dotnet = require 'utils.dotnet'

-- [[ Keymaps ]] --
vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = { min = vim.diagnostic.severity.WARN } },
  virtual_text = false, -- Text shows up at the end of the line
  virtual_lines = true, -- Text shows up underneath the line, with virtual lines
  jump = { float = true }, -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
}
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
-- vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' }) -- Terminal close keybind
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
vim.keymap.set('n', '<leader>ps', dotnet.open_user_secrets, { desc = 'Open project [S]ecrets' })

vim.api.nvim_create_user_command('DotnetUserSecrets', dotnet.open_user_secrets, { desc = 'Open .NET user secrets' })

vim.api.nvim_create_autocmd('TextYankPost', { -- Highlight when yanking (copying) text
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- [[ Install `lazy.nvim` plugin manager ]]
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then error('Error cloning lazy.nvim:\n' .. out) end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
require('lazy').setup({
  { import = 'plugins.editor' },
  { import = 'plugins.oil' },
  { import = 'plugins.git' },
  { import = 'plugins.telescope' },
  { import = 'plugins.test' },
  { import = 'plugins.lsp' },
  { import = 'plugins.completion' },
  { import = 'plugins.ui' },
}, { ---@diagnostic disable-line: missing-fields
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})
