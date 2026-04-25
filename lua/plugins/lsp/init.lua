return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      {
        'mason-org/mason.nvim',
        ---@module 'mason.settings'
        ---@type MasonSettings
        ---@diagnostic disable-next-line: missing-fields
        opts = {},
      },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim', opts = {} },
    },
    config = function()
      local blink = require 'blink.cmp'
      local lspMethods = vim.lsp.protocol.Methods

      local pendingDiagnosticRefreshes = {}
      local pendingBufferRefreshes = {}

      local refresh_buffer_diagnostics = function(bufnr)
        if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then return end

        pendingBufferRefreshes[bufnr] = nil

        for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
          if client:supports_method(lspMethods.textDocument_diagnostic, bufnr) then
            vim.lsp.util._refresh(lspMethods.textDocument_diagnostic, {
              bufnr = bufnr,
              client_id = client.id,
            })
          elseif client:supports_method(lspMethods.textDocument_didOpen, bufnr) then
            vim.lsp.buf_detach_client(bufnr, client.id)

            if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
              vim.lsp.buf_attach_client(bufnr, client.id)
            end
          end
        end
      end

      local refresh_client_diagnostics = function(clientId)
        local client = vim.lsp.get_client_by_id(clientId)
        if not client or not client:supports_method(lspMethods.textDocument_diagnostic) then return end

        pendingDiagnosticRefreshes[clientId] = nil

        for bufnr in pairs(client.attached_buffers) do
          if vim.api.nvim_buf_is_loaded(bufnr) then
            vim.lsp.util._refresh(lspMethods.textDocument_diagnostic, {
              bufnr = bufnr,
              client_id = clientId,
            })
          end
        end
      end

      vim.api.nvim_create_autocmd('LspNotify', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-refresh-all-tabs', { clear = true }),
        callback = function(event)
          if
            event.data.method ~= lspMethods.textDocument_didChange
            and event.data.method ~= lspMethods.textDocument_didOpen
          then
            return
          end

          local clientId = event.data.client_id
          if not clientId or pendingDiagnosticRefreshes[clientId] then return end

          pendingDiagnosticRefreshes[clientId] = true
          vim.defer_fn(function() refresh_client_diagnostics(clientId) end, 75)
        end,
      })

      vim.api.nvim_create_autocmd({ 'BufEnter', 'TabEnter' }, {
        group = vim.api.nvim_create_augroup('kickstart-lsp-refresh-current-buffer', { clear = true }),
        callback = function(event)
          local bufnr = event.buf
          if pendingBufferRefreshes[bufnr] or vim.tbl_isempty(vim.lsp.get_clients { bufnr = bufnr }) then return end

          pendingBufferRefreshes[bufnr] = true
          vim.defer_fn(function() refresh_buffer_diagnostics(bufnr) end, 50)
        end,
      })

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method('textDocument/documentHighlight', event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          if client and client:supports_method('textDocument/inlayHint', event.buf) then
            map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      ---@type table<string, vim.lsp.Config>
      local servers = {
        stylua = {},
        lua_ls = {
          on_init = function(client)
            if client.workspace_folders then
              local path = client.workspace_folders[1].name
              if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
            end

            client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
              runtime = {
                version = 'LuaJIT',
                path = { 'lua/?.lua', 'lua/?/init.lua' },
              },
              workspace = {
                checkThirdParty = false,
                library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
                  '${3rd}/luv/library',
                  '${3rd}/busted/library',
                }),
              },
            })
          end,
          settings = {
            Lua = {},
          },
        },
        omnisharp = {
          cmd = {
            'omnisharp',
            '-z',
            '--hostPID',
            tostring(vim.fn.getpid()),
            'DotNet:enablePackageRestore=false',
            '--encoding',
            'utf-8',
            '--languageserver',
          },
          settings = {
            FormattingOptions = {
              EnableEditorConfigSupport = true,
            },
            RoslynExtensionsOptions = {
              EnableAnalyzersSupport = true,
              EnableDecompilationSupport = true,
              EnableImportCompletion = true,
            },
            Sdk = {
              IncludePrereleases = true,
            },
          },
        },
        ts_ls = {},
        jsonls = {},
        html = {},
        cssls = {},
      }

      local ensure_installed = vim.tbl_keys(servers or {})
      local capabilities = blink.get_lsp_capabilities()

      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      for name, server in pairs(servers) do
        server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
        vim.lsp.config(name, server)
        vim.lsp.enable(name)
      end
    end,
  },
}
