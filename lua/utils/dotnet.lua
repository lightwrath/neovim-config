local M = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.ERROR, { title = '.NET User Secrets' })
end

local function normalize(path)
  return vim.fs.normalize(path)
end

local function dirname(path)
  return vim.fs.dirname(normalize(path))
end

local function get_buffer_dir()
  local path = vim.api.nvim_buf_get_name(0)
  if path == '' then return nil end

  local stat = vim.uv.fs_stat(path)
  if not stat then return nil end
  if stat.type == 'directory' then return normalize(path) end

  return dirname(path)
end

local function find_upward(match, start)
  local results = vim.fs.find(match, {
    path = start,
    upward = true,
    limit = 1,
    type = 'file',
  })

  return results[1]
end

local function find_nearest_csproj(start)
  return find_upward(function(name)
    return name:match '%.csproj$' ~= nil
  end, start)
end

local function find_solution_root(start)
  local solution = find_upward(function(name)
    return name:match '%.sln$' ~= nil
  end, start)

  if not solution then return nil end

  return dirname(solution)
end

local function find_csproj_in_solution(solution_root)
  local matches = vim.fn.globpath(solution_root, '**/*.csproj', false, true)
  if #matches == 0 then return nil end

  table.sort(matches)
  return normalize(matches[1])
end

function M.resolve_project()
  local cwd = normalize(vim.fn.getcwd())
  local search_roots = {}
  local buffer_dir = get_buffer_dir()

  if buffer_dir then table.insert(search_roots, buffer_dir) end
  if not vim.tbl_contains(search_roots, cwd) then table.insert(search_roots, cwd) end

  for _, start in ipairs(search_roots) do
    local project = find_nearest_csproj(start)
    if project then return normalize(project) end
  end

  for _, start in ipairs(search_roots) do
    local solution_root = find_solution_root(start)
    if solution_root then
      local project = find_csproj_in_solution(solution_root)
      if project then return project end
    end
  end

  return nil, 'No .csproj found for the current buffer or working directory'
end

function M.resolve_user_secrets_id(project)
  if vim.fn.executable 'dotnet' ~= 1 then return nil, '`dotnet` is not available in PATH' end

  local result = vim.system({
    'dotnet',
    'msbuild',
    project,
    '--getProperty:UserSecretsId',
    '-nologo',
    '-p:Configuration=Debug',
  }, { text = true }):wait()

  if result.code ~= 0 then
    local stderr = vim.trim(result.stderr or '')
    if stderr == '' then stderr = 'dotnet msbuild failed while resolving UserSecretsId' end
    return nil, stderr
  end

  local userSecretsId = vim.trim(result.stdout or '')
  if userSecretsId == '' then return nil, 'The current project does not define a UserSecretsId' end

  return userSecretsId
end

function M.get_secrets_path(userSecretsId)
  local sysname = vim.uv.os_uname().sysname
  local base = sysname == 'Windows_NT' and os.getenv 'APPDATA' or vim.fn.expand '$HOME/.microsoft/usersecrets'

  if not base or base == '' then return nil, 'Could not resolve the user secrets directory' end

  return normalize(vim.fs.joinpath(base, userSecretsId, 'secrets.json'))
end

function M.resolve_secrets_path()
  local project, projectError = M.resolve_project()
  if not project then return nil, projectError end

  local userSecretsId, secretsError = M.resolve_user_secrets_id(project)
  if not userSecretsId then return nil, secretsError end

  local path, pathError = M.get_secrets_path(userSecretsId)
  if not path then return nil, pathError end

  return {
    project = project,
    userSecretsId = userSecretsId,
    path = path,
  }
end

function M.open_user_secrets()
  local resolved, error_message = M.resolve_secrets_path()
  if not resolved then
    notify(error_message)
    return
  end

  local parent = dirname(resolved.path)
  if vim.fn.mkdir(parent, 'p') == 0 and vim.fn.isdirectory(parent) == 0 then
    notify('Could not create secrets directory: ' .. parent)
    return
  end

  if vim.fn.filereadable(resolved.path) == 0 then vim.fn.writefile({ '{', '}' }, resolved.path) end

  vim.cmd('tabedit ' .. vim.fn.fnameescape(resolved.path))
end

return M
