local M = {}

local config_dir = vim.fn.stdpath("data") .. "/vstools"
local config_path = config_dir .. "/state.json"

local function ensure_dir()
  if vim.fn.isdirectory(config_dir) == 0 then
    vim.fn.mkdir(config_dir, "p")
  end
end

local function load()
  local file = io.open(config_path, "r")
  if not file then return {} end
  local content = file:read("*a")
  file:close()
  return vim.fn.json_decode(content) or {}
end

local function save(tbl)
  ensure_dir()
  local file = assert(io.open(config_path, "w"))
  file:write(vim.fn.json_encode(tbl))
  file:close()
end

-- Helper to create consistent keys
local function key(cwd, name)
  return cwd .. "::" .. name
end

-- Startup project setters
function M.set_project(path)
  local cwd = vim.fn.getcwd()
  local cfg = load()
  cfg[key(cwd, "startup_project")] = path
  save(cfg)
  print("Startup project set to: " .. path)
end

function M.get_project()
  local cwd = vim.fn.getcwd()
  local cfg = load()
  return cfg[key(cwd, "startup_project")]
end

-- Build_config setters
function M.get_build_config()
  local cwd = vim.fn.getcwd()
  local cfg = load()
  return cfg[key(cwd, "build_config")] or "Debug"
end

function M.set_build_config(config_name)
  if config_name ~= "Debug" and config_name ~= "Release" then
    print("Invalid build configuration: " .. tostring(config_name))
    return
  end

  local cwd = vim.fn.getcwd()
  local cfg = load()

  cfg[key(cwd, "build_config")] = config_name
  save(cfg)

  print("Build configuration set to: " .. config_name)
end

function M.toggle_build_config()
  local current = M.get_build_config()
  local next = (current == "Debug") and "Release" or "Debug"
  M.set_build_config(next)
  return next
end

end

return M
