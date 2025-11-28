-- lua/vstools/env.lua
local utils  = require("vstools.startup.utils")
local state  = require("vstools.startup.state")

local M = {}

local function valid_name(name)
  -- Accept typical env var names (POSIX + common Windows)
  return name and name:match("^[A-Za-z_][A-Za-z0-9_]*$")
end

-- Parse text like:
--   PATH = /usr/local/bin : /opt/bin
--   FOO = DEBUG
--   LD_LIBRARY_PATH = "/lib:/usr/lib" : ./build/lib
-- Comments with # or //, blank lines ignored.
function M.parse_env_text(text)
  local env = {}
  local sep = utils.path_sep()
  local sep_char = sep -- single char by design

  text = (text or ""):gsub("\r\n", "\n")

  for line in text:gmatch("[^\n]*") do
    local raw = utils.trim(line or "")
    if raw ~= "" and not raw:match("^%s*[#/]") and not raw:match("^%s*//") then
      local name, rhs = raw:match("^%s*([%w_]+)%s*=%s*(.+)$")
      if name and rhs and valid_name(name) then
        -- Split RHS by sep with quoting/escapes
        local parts = utils.split_values(rhs, sep_char)
        -- Optionally fix Windows backslashes in each part
        if utils.is_windows() then
          for i = 1, #parts do parts[i] = utils.windows_paths(parts[i]) end
        end
        -- Recompose normalized value string
        env[name] = table.concat(parts, sep)
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

-- Format env table back to text lines: NAME = v1 sep v2 …
function M.env_to_text(env)
  local sep = utils.path_sep()
  local lines = {}
  for k, v in pairs(env or {}) do
    -- Split existing composite value to show normalized entries
    local parts = utils.split_values(v, sep)
    table.insert(lines, string.format("%s = %s", k, table.concat(parts, " " .. sep .. " ")))
  end
  table.sort(lines) -- deterministic order
  return table.concat(lines, "\n")
end

-- Merge PATH with extra entries; deduplicate while keeping order
local function merge_path(cur, extras)
  local sep = utils.path_sep()
  local seen, out = {}, {}
  local function push_list(list)
    for _, p in ipairs(list) do
      local n = utils.trim(p)
      if n ~= "" and not seen[n] then
        seen[n] = true
        table.insert(out, n)
      end
    end
  end
  push_list(utils.split_values(cur or "", sep))
  push_list(extras)
  return table.concat(out, sep)
end

-- Build env to pass to job, optionally extending PATH
function M.build_effective_env(user_env, opts)
  opts = opts or {}
  local clear_env = opts.clear_env or false
  local base_env = clear_env and {} or vim.fn.environ()
  local result = vim.tbl_extend("force", base_env, user_env or {})

  -- If user provided PATH as composite string, keep as-is.
  -- If user provided PATH parts list via opts.path_add, merge.
  if opts.path_add and #opts.path_add > 0 then
    result.PATH = merge_path(result.PATH or vim.fn.getenv("PATH") or "", opts.path_add)
  end
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
