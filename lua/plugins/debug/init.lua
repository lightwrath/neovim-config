local function get_netcoredbg_path()
  local extension = vim.uv.os_uname().sysname == 'Windows_NT' and '.exe' or ''
  return vim.fs.joinpath(vim.fn.stdpath 'data', 'mason', 'packages', 'netcoredbg', 'netcoredbg' .. extension)
end

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.ERROR, { title = '.NET Debug' })
end

local function warn_if_netcoredbg_missing(path)
  if vim.fn.executable(path) == 1 then return end

  notify('netcoredbg was not found at ' .. path .. '. Mason should install it through mason-tool-installer.', vim.log.levels.WARN)
end

return {
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'rcarriga/nvim-dap-ui',
    },
    keys = {
      {
        '<leader>dr',
        function()
          local dap = require 'dap'
          dap.run(dap.configurations.cs[1])
        end,
        desc = '[D]ebug [R]un .NET project',
      },
      {
        '<leader>da',
        function()
          local dap = require 'dap'
          dap.run(dap.configurations.cs[2])
        end,
        desc = '[D]ebug [A]ttach process',
      },
      {
        '<leader>dc',
        function() require('dap').continue() end,
        desc = '[D]ebug [C]ontinue',
      },
      {
        '<leader>dt',
        function() require('dap').terminate() end,
        desc = '[D]ebug [T]erminate',
      },
      {
        '<leader>do',
        function() require('dap').step_over() end,
        desc = '[D]ebug Step [O]ver',
      },
      {
        '<leader>di',
        function() require('dap').step_into() end,
        desc = '[D]ebug Step [I]nto',
      },
      {
        '<leader>dO',
        function() require('dap').step_out() end,
        desc = '[D]ebug Step [O]ut',
      },
      {
        '<leader>db',
        function() require('dap').toggle_breakpoint() end,
        desc = '[D]ebug Toggle [B]reakpoint',
      },
      {
        '<leader>dB',
        function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end,
        desc = '[D]ebug Conditional [B]reakpoint',
      },
      {
        '<leader>dL',
        function() require('dap').set_breakpoint(nil, nil, vim.fn.input 'Log point message: ') end,
        desc = '[D]ebug [L]og point',
      },
      {
        '<leader>du',
        function() require('dapui').toggle() end,
        desc = '[D]ebug Toggle [U]I',
      },
      {
        '<leader>dR',
        function() require('dap').repl.toggle() end,
        desc = '[D]ebug Toggle [R]EPL',
      },
      {
        '<leader>dn',
        function() require('neotest').run.run { strategy = 'dap' } end,
        desc = '[D]ebug [N]earest test',
      },
      {
        '<leader>df',
        function() require('neotest').run.run { vim.fn.expand '%', strategy = 'dap' } end,
        desc = '[D]ebug [F]ile tests',
      },
      {
        '<leader>dl',
        function() require('neotest').run.run_last { strategy = 'dap' } end,
        desc = '[D]ebug [L]ast test',
      },
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'
      local dotnet = require 'utils.dotnet'

      dapui.setup()

      dap.listeners.before.attach.dapui_config = function() dapui.open() end
      dap.listeners.before.launch.dapui_config = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
      dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

      local netcoredbgPath = get_netcoredbg_path()
      warn_if_netcoredbg_missing(netcoredbgPath)

      dap.adapters.netcoredbg = {
        type = 'executable',
        command = netcoredbgPath,
        args = { '--interpreter=vscode' },
      }

      dap.configurations.cs = {
        {
          type = 'netcoredbg',
          request = 'launch',
          name = 'Launch .NET project',
          stopAtEntry = false,
          program = function()
            local target, errorMessage = dotnet.resolve_debug_target()
            if not target then
              notify(errorMessage)
              return dap.ABORT
            end

            return target.program
          end,
          cwd = function()
            local project = dotnet.resolve_project()
            if project then return vim.fs.dirname(project) end

            return vim.fn.getcwd()
          end,
        },
        {
          type = 'netcoredbg',
          request = 'attach',
          name = 'Attach to .NET process',
          processId = require('dap.utils').pick_process,
        },
      }
    end,
  },
}
