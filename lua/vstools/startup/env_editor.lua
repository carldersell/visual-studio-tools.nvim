-- lua/vstools/env.lua
local utils  = require("vstools.startup.utils")
local state  = require("vstools.startup.state")

local M = {}

local valid_variable_characters = "[A-Za-z_][A-Za-z0-9_]"
local function valid_name(name)
  return name and name:match(string.format("^%s*$", valid_variable_characters))
end

-- Parse text like:
--   PATH = /usr/local/bin : /opt/bin
--   FOO = DEBUG
--   LD_LIBRARY_PATH = "/lib:/usr/lib" : ./build/lib
-- Comments with # or //, blank lines ignored.
function M.parse_env_text(text)
  local env = {}

  text = (text or ""):gsub("\r\n", "\n")

  for line in text:gmatch("[^\n]*") do
    local raw = utils.trim(line or "")
    if raw ~= "" and not raw:match("^%s*[#/]") and not raw:match("^%s*//") then
      local name, rhs = raw:match("^%s*([%w_]+)%s*=%s*(.+)$")
      if name and rhs and valid_name(name) then
        table.insert(env, {name, rhs})
      else
        -- Silently ignore invalid lines or report:
        vim.schedule(function()
          vim.notify("Invalid env line (ignored): " .. raw, vim.log.levels.WARN)
        end)
      end
    end
  end

  return env
end

-- Format env table back to text lines: NAME = v1sepv2 …
function M.env_to_text(env)
  local lines = {}

  for _, pair in ipairs(env or {}) do
    local name, rhs = pair[1], pair[2]
    -- Show RHS exactly as stored (no recomputing, no splitting)
    table.insert(lines, string.format("%s = %s", name, rhs))
  end

  return table.concat(lines, "\n")
end

local function capture_script_env(script, env, cwd)
  local is_windows = utils.is_windows()
  local cmd

  if is_windows then
    local cmd_exe = vim.fn.exepath("cmd.exe")
    if cmd_exe == "" then
      cmd_exe = "cmd.exe"
    end

    cmd = {
      cmd_exe,
      "/d",
      "/s",
      "/c",
      -- 'call "' .. script .. '" >nul && set',
      "call " .. script .. " >nul && set",
    }
  else
    local bash = vim.fn.exepath("bash")
    if bash == "" then
      bash = "/bin/bash"
    end

    cmd = {
      bash,
      "-c",
      'source "$1" >/dev/null && /usr/bin/env -0',
      "bash",
      script,
    }
  end

  local result = vim.system(cmd, {
    cwd = cwd,
    env = env,
    clear_env = true,
    text = true,
  }):wait()

  if result.code ~= 0 then
    error(string.format(
      "Failed to load environment script '%s': %s",
      script,
      result.stderr or "Unknown error"
    ))
  end

  local captured = {}

  if is_windows then
    for line in result.stdout:gmatch("[^\r\n]+") do
      local key, value = line:match("^([^=]+)=(.*)$")

      if key and not key:match("^=") then
        captured[key:upper()] = value
      end
    end
  else
    for entry in result.stdout:gmatch("[^\0]+") do
      local key, value = entry:match("^([^=]+)=(.*)$")

      if key then
        captured[key] = value
      end
    end
  end

  return captured
end

local function apply_user_env(result, user_env, old_environment)
  local sep = utils.path_sep()

  for _, pair in pairs(user_env or {}) do
    local name, rhs = pair[1], pair[2]

    -- Windows: environment variable names are case-insensitive
    -- and Neovim/Win32 uppercases all variable names.
    if utils.is_windows() then
      name = name:upper()
    end

    -- 1. Expand $VAR placeholders using the current environment.
    local expanded = rhs:gsub(
      string.format("%%$(%s+)", valid_variable_characters),
      function(var)
        if utils.is_windows() then
          var = var:upper()
        end

        return result[var] or old_environment[var] or ""
      end
    )

    -- 2. Windows path normalization
    if utils.is_windows() then
      expanded = utils.windows_paths(expanded)
    end

    -- 3. split composite value into parts respecting quotes
    local parts = utils.split_values(expanded, sep)

    -- 4. normalize list
    result[name] = table.concat(parts, sep)
  end

  return result
end

-- Build env to pass to job
function M.build_effective_env(user_env, opts)
  opts = opts or {}

  local old_environment = vim.fn.environ()
  local base_env = opts.clear_env and {} or old_environment

  local result = vim.tbl_extend("force", {}, base_env)

  -- Extract MOD_ENV_SCRIPT without treating it as an actual env variable.
  local env_script
  local regular_env = {}

  for _, pair in ipairs(user_env or {}) do
    local name = pair[1]

    if utils.is_windows() then
      name = name:upper()
    end

    if name == "MOD_ENV_SCRIPT" then
      env_script = pair[2]
    else
      table.insert(regular_env, pair)
    end
  end

  -- Load the environment script first.
  if env_script then
    result = capture_script_env(
      env_script,
      result,
      opts.cwd or vim.uv.cwd()
    )
  end

  -- Explicit user variables override script values.
  apply_user_env(result, regular_env, old_environment)

  return result
end

-- Editor for environment variables
function M.open_env_editor(opts)
  opts = opts or {}
  local existing = state.get_environment and state.get_environment() or {}
  local start_text = M.env_to_text(existing)
  if start_text == "" then start_text = "" end

  return utils.open_editor({
    name = "VSToolsEnv",
    title = " Environment variables ",
    filetype = "vstools_env",
    lines = (#start_text > 0) and vim.split(start_text, "\n") or { "" },
    on_save = function(raw)
      local parsed = M.parse_env_text(raw)
      state.set_environment(parsed)
    end,
    floating = (opts.floating ~= false),
  })
end

return M
