local function formatCsharpBuffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= 'cs' then return end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == '' then return end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, '\n') .. '\n'
  local configPath = vim.fn.stdpath 'config' .. '/.csharpierrc'
  local result = vim.system({ 'csharpier', 'format', '--config-path', configPath, '--stdin-path', filename }, { stdin = text, text = true }):wait()

  if result.code ~= 0 then
    vim.notify(result.stderr ~= '' and result.stderr or 'CSharpier formatting failed', vim.log.levels.ERROR)
    return
  end

  local formatted = vim.split(result.stdout, '\n', { plain = true })
  if formatted[#formatted] == '' then table.remove(formatted) end

  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted)
  vim.fn.winrestview(view)
end

vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.cs',
  callback = function(event) formatCsharpBuffer(event.buf) end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'cs',
  callback = function(event)
    vim.keymap.set('x', '=', function()
      vim.api.nvim_feedkeys(vim.keycode '<Esc>', 'n', false)
      vim.schedule(function() formatCsharpBuffer(event.buf) end)
    end, { buffer = event.buf, desc = 'Format C# buffer' })
  end,
})

return {

  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    ---@module 'todo-comments'
    ---@type TodoOptions
    ---@diagnostic disable-next-line: missing-fields
    opts = { signs = false },
  },

  {
    'nvim-mini/mini.nvim',
    config = function()
      require('mini.ai').setup { n_lines = 500 }
      local bufremove = require 'mini.bufremove'
      bufremove.setup()
      require('mini.pairs').setup()
      require('mini.surround').setup()

      local function findBufferWindow(bufnr)
        for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
            if vim.api.nvim_win_get_buf(win) == bufnr then return tabpage, win end
          end
        end

        return nil, nil
      end

      local function bufferIsVisible(bufnr)
        local tabpage = findBufferWindow(bufnr)
        return tabpage ~= nil
      end

      local function getBufferTabs()
        local bufferTabs = {}

        for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
          local win = vim.api.nvim_tabpage_get_win(tabpage)
          local bufnr = vim.api.nvim_win_get_buf(win)

          if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted then table.insert(bufferTabs, { bufnr = bufnr, tabpage = tabpage, win = win }) end
        end

        return bufferTabs
      end

      local function goToSiblingBuffer(direction)
        local bufferTabs = getBufferTabs()
        if #bufferTabs <= 1 then return end

        local currentBuffer = vim.api.nvim_get_current_buf()
        local currentTabpage = vim.api.nvim_get_current_tabpage()
        local currentIndex

        for index, bufferTab in ipairs(bufferTabs) do
          if bufferTab.bufnr == currentBuffer and bufferTab.tabpage == currentTabpage then
            currentIndex = index
            break
          end
        end

        local targetIndex
        if currentIndex then
          targetIndex = ((currentIndex - 1 + direction) % #bufferTabs) + 1
        elseif direction > 0 then
          targetIndex = 1
        else
          targetIndex = #bufferTabs
        end

        local target = bufferTabs[targetIndex]
        vim.api.nvim_set_current_tabpage(target.tabpage)
        vim.api.nvim_set_current_win(target.win)
      end

      local function closeTabAndDeleteBuffer()
        local bufnr = vim.api.nvim_get_current_buf()
        local tabCount = #vim.api.nvim_list_tabpages()

        if tabCount > 1 then
          local closed = pcall(vim.cmd.tabclose)
          if not closed or not vim.api.nvim_buf_is_valid(bufnr) or bufferIsVisible(bufnr) then return end
        end

        if not vim.api.nvim_buf_is_valid(bufnr) then return end

        bufremove.delete(bufnr, false)
      end

      vim.api.nvim_create_user_command('TabCloseBuffer', closeTabAndDeleteBuffer, { desc = 'Close tab and delete buffer' })
      vim.keymap.set('n', '<leader>bd', closeTabAndDeleteBuffer, { desc = '[B]uffer [D]elete tab' })
      vim.keymap.set('n', ']b', function() goToSiblingBuffer(1) end, { desc = 'Next buffer tab' })
      vim.keymap.set('n', '[b', function() goToSiblingBuffer(-1) end, { desc = 'Previous buffer tab' })

      local statusline = require 'mini.statusline'
      statusline.setup { use_icons = vim.g.have_nerd_font }
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function() return '%2l:%-2v' end
    end,
  },

  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    branch = 'main',
    config = function()
      local parsers = { 'bash', 'c', 'c_sharp', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }
      require('nvim-treesitter').install(parsers)

      ---@param buf integer
      ---@param language string
      local function treesitter_try_attach(buf, language)
        if not vim.treesitter.language.add(language) then return end

        vim.treesitter.start(buf, language)

        local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil
        if has_indent_query then vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
      end

      local available_parsers = require('nvim-treesitter').get_available()
      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          local buf, filetype = args.buf, args.match
          local language = vim.treesitter.language.get_lang(filetype)
          if not language then return end

          local installed_parsers = require('nvim-treesitter').get_installed 'parsers'

          if vim.tbl_contains(installed_parsers, language) then
            treesitter_try_attach(buf, language)
          elseif vim.tbl_contains(available_parsers, language) then
            require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
          else
            treesitter_try_attach(buf, language)
          end
        end,
      })
    end,
  },
}
