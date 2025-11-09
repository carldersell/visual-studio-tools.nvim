local M = {}

local config_dir  = vim.fn.stdpath("data") .. "/vstools"
local config_path = config_dir .. "/state.json"

-----------------------------------------------------------------------
-- Utilities
-----------------------------------------------------------------------
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

local function cwd()
  return vim.fn.getcwd()
end

-----------------------------------------------------------------------
-- Get or create workspace entry
-----------------------------------------------------------------------
local function ensure_workspace(tbl)
  local key = cwd()
  tbl[key] = tbl[key] or {
    build_config = "Debug",
    current_startup_project = nil,
    startup_projects = {},
  }
  return tbl[key]
end

local function ensure_startup_project(ws, project_path)
  ws.startup_projects[project_path] = ws.startup_projects[project_path] or {
  }
  return ws.startup_projects[project_path]
end

-----------------------------------------------------------------------
-- Workspace-level settings
-----------------------------------------------------------------------

function M.get_build_config()
  local cfg = load()
  local ws = ensure_workspace(cfg)
  return ws.build_config or "Debug"
end

function M.set_build_config(conf)
  local cfg = load()
  local ws = ensure_workspace(cfg)
  ws.build_config = conf
  save(cfg)
  vim.notify("Build configuration set to: " .. conf, vim.log.levels.INFO)
end

function M.toggle_build_config()
  local current = M.get_build_config()
  local next = (current == "Debug") and "Release" or "Debug"
  M.set_build_config(next)
end

function M.get_current_startup_project()
  local cfg = load()
  local ws = ensure_workspace(cfg)
  return ws.current_startup_project
end

function M.set_current_startup_project(project_path)
  local cfg = load()
  local ws = ensure_workspace(cfg)
  ws.current_startup_project = project_path
  ensure_startup_project(ws, project_path)
  save(cfg)
  vim.notify("Startup project set to: " .. project_path, vim.log.levels.INFO)
end

-----------------------------------------------------------------------
-- Per-startup-project settings
-----------------------------------------------------------------------

function M.get_project_settings(project_path)
  local cfg = load()
  local ws = ensure_workspace(cfg)
  if not project_path then
    project_path = ws.current_startup_project
  end
  if not project_path then
    return nil
  end
  return ensure_startup_project(ws, project_path)
end

return M
