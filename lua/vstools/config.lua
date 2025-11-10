local DEFAULTS = {
  msbuild_path = "msbuild.exe",

  -- To run executables in nushell
  prepend_exe_path = "",

  -- Set default build_config
  build_config = "Debug",

  open_terminal = function(cmd)
    require("floating_terminal").run_in_bottom_terminal(cmd)
    vim.cmd("normal! G")
  end,
  log_settings = {
    width = nil,
    height = nil,
    border = "rounded"
  }
}

----------------------------------------------------------------------
-- Validation helpers
----------------------------------------------------------------------

-- Normalize and validate build_config
local function normalize_build_config(value)
  if value == nil then return nil end
  if type(value) ~= "string" then
    error("vstools.config: build_config must be a string (got " .. type(value) .. ")")
  end
  local lower = value:lower()
  if lower == "debug" then return "Debug" end
  if lower == "release" then return "Release" end
  error("vstools.config: build_config must be 'Debug' or 'Release' (got '" .. value .. "')")
end

-- Return path without surrounding quotes (user might paste quoted Windows path)
local function unquote(s)
  if type(s) ~= "string" then return s end
  -- remove surrounding "..." or '...'
  local a, b = s:match('^"(.*)"$'), s:match("^'(.*)'$")
  return a or b or s
end

-- Check if a path points to an existing file
local function file_exists(path)
  local stat = path and vim.uv.fs_stat(path) or nil
  return stat and stat.type == "file" or false
end

-- Determine if the given command/path is runnable:
-- 1) If absolute/relative path to a file -> exists AND (on Windows: .exe/.cmd/.bat)
-- 2) Otherwise, resolvable via PATH (vim.fn.executable == 1 or vim.fn.exepath has value)
local function is_runnable(cmd)
  if type(cmd) ~= "string" or cmd == "" then return false end
  local cleaned = unquote(cmd)

  -- If it looks like a path (contains a slash or a drive colon), prefer direct file check
  local looks_like_path = cleaned:find("[/\\]") or cleaned:match("^%a:[/\\]")
  if looks_like_path then
    if not file_exists(cleaned) then
      return false
    end
    -- On Windows, ensure it is an executable type (best-effort)
    if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
      local ext = cleaned:match("%.([%w]+)$")
      ext = ext and ext:lower() or ""
      if ext == "exe" or ext == "cmd" or ext == "bat" then
        return true
      end
      -- Some MSBuild installations may be MSBuild.exe only; others could be via dotnet msbuild
      -- If it's a path but not a common executable extension, still try executable()
      return vim.fn.executable(cleaned) == 1
    else
      -- On Unix, just having a file doesn't guarantee exec bit; try executable()
      return vim.fn.executable(cleaned) == 1
    end
  end

  -- Otherwise treat it as a command name to be resolved via PATH
  if vim.fn.executable(cleaned) == 1 then
    return true
  end
  local exepath = vim.fn.exepath(cleaned)
  return type(exepath) == "string" and exepath ~= ""
end

-- Validate and canonicalize msbuild_path
local function normalize_msbuild_path(value)
  if value == nil then
    -- Permit nil to signal "resolve from PATH" (user can set msbuild_path = "msbuild")
    return nil
  end
  if type(value) ~= "string" then
    error("vstools.config: msbuild_path must be a string (got " .. type(value) .. ")")
  end
  local cleaned = unquote(vim.fn.expand(value))
  if not is_runnable(cleaned) then
    error(
      ("vstools.config: msbuild_path is not runnable or not found: %s\n")
      :format(value)
      .. "Tips:\n"
      .. "  • Use a full path to MSBuild.exe, or\n"
      .. "  • Put MSBuild on PATH and set msbuild_path = 'msbuild', or\n"
      .. "  • Use 'dotnet msbuild' via your runner if you prefer the .NET SDK."
    )
  end
  return cleaned
end

-- Shallow validation of log_settings (numbers or nil; known border string)
local VALID_BORDERS = {
  none = true, single = true, double = true, rounded = true, solid = true, shadow = true,
}
local function validate_log_settings(ls)
  if ls == nil then return end
  if type(ls) ~= "table" then
    error("vstools.config: log_settings must be a table")
  end
  if ls.width ~= nil and type(ls.width) ~= "number" then
    error("vstools.config: log_settings.width must be a number or nil")
  end
  if ls.height ~= nil and type(ls.height) ~= "number" then
    error("vstools.config: log_settings.height must be a number or nil")
  end
  if ls.border ~= nil then
    if type(ls.border) ~= "string" then
      error("vstools.config: log_settings.border must be a string")
    end
    if not VALID_BORDERS[(ls.border or ""):lower()] then
      error("vstools.config: log_settings.border must be one of: none|single|double|rounded|solid|shadow")
    end
  end
end

-- Current live config (merged defaults + user overrides)
local M = vim.deepcopy(DEFAULTS)

-- Merge user opts at startup
function M.setup(user_opts)
  user_opts = user_opts or {}

-- 1) Merge user opts into a fresh copy (so defaults remain immutable)
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), user_opts)

  -- 2) Validate & normalize specific fields
  --    (Run before copying into M, so we fail fast without mutating live config)
  validate_log_settings(merged.log_settings)

  if merged.build_config ~= nil then
    merged.build_config = normalize_build_config(merged.build_config)
  end

  if merged.msbuild_path ~= nil then
    merged.msbuild_path = normalize_msbuild_path(merged.msbuild_path)
  else
    -- If user provided nil, try to validate the default/path form as well
    merged.msbuild_path = normalize_msbuild_path(DEFAULTS.msbuild_path)
  end

  -- 3) Commit into the live table M (preserve identity)
  -- We update the keys so other modules will get the new values in case they create a local copy (e.g. local config = require("vstools.config"))
  for k in pairs(M) do M[k] = nil end
  for k, v in pairs(merged) do
    M[k] = v
  end

  return M
end

return M
