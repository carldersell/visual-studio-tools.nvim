local M = {}

local config_dir = vim.fn.stdpath("data") .. "/vstools"
local config_path = config_dir .. "/startup_projects.json"

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

function M.set_project(path)
  local cwd = vim.fn.getcwd()
  local cfg = load()
  cfg[cwd] = path
  save(cfg)
  print("Startup project set to: " .. path)
end

function M.get_project()
  local cwd = vim.fn.getcwd()
  local cfg = load()
  return cfg[cwd]
end

return M
