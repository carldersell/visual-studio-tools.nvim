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
    build_config = require("vstools.config").build_config,
    current_startup_project = nil,
    startup_projects = {},
  }
  return tbl[key]
end

local function ensure_startup_project(ws, project_path)
  ws.startup_projects[project_path] = ws.startup_projects[project_path] or {
    run_args = {},
    environment = {},
    gui = false,
  }
  return ws.startup_projects[project_path]
end

-----------------------------------------------------------------------
-- Workspace-level settings
-----------------------------------------------------------------------

function M.get_build_config()
  local cfg = load()
  local ws = ensure_workspace(cfg)
  return ws.build_config or require("vstools.comfig").build_config
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

-- Run args (grouped structure)
function M.get_run_args(project_path)
  local settings = M.get_project_settings(project_path)
  if not settings then return {} end
  return settings.run_args or {}
end

function M.set_run_args(groups, project_path)
  local cfg = load()
  local ws = ensure_workspace(cfg)

  project_path = project_path or ws.current_startup_project
  if not project_path then
    vim.notifyprint("No startup project selected.", vim.log.levels.ERROR)
    return
  end

  local ps = ensure_startup_project(ws, project_path)
  ps.run_args = groups or {}

  save(cfg)
  vim.notify("Run arguments saved for project: " .. project_path, vim.log.levels.INFO)
end

-- Environment variables
function M.get_environment(project_path)
  local settings = M.get_project_settings(project_path)
  if not settings then return {} end
  return settings.environment or {}
end

function M.set_environment(env_tbl, project_path)
  local cfg = load()
  local ws = ensure_workspace(cfg)

  project_path = project_path or ws.current_startup_project
  if not project_path then
    vim.notifyprint("No startup project selected.", vim.log.levels.ERROR)
    return
  end

  local ps = ensure_startup_project(ws, project_path)
  ps.environment = env_tbl or {}

  save(cfg)
  vim.notify("Environment saved for project: " .. project_path, vim.log.levels.INFO)
end

-- GUI flag
function M.get_gui_flag(project_path)
  local settings = M.get_project_settings(project_path)
  if not settings then return false end
  return settings.gui or false
end

function M.set_gui_flag(flag, project_path)
  local cfg = load()
  local ws = ensure_workspace(cfg)

  project_path = project_path or ws.current_startup_project
  if not project_path then
    vim.notifyprint("No startup project selected.", vim.log.levels.ERROR)
    return
  end

  local ps = ensure_startup_project(ws, project_path)
  if (type(flag) == "boolean") then
    ps.gui = flag
  elseif (type(flag) == "string") then
    ps.gui = string.lower(flag) == "true"
  else
    ps.gui = false
  end

  save(cfg)
  vim.notify("GUI flag saved for project: " .. project_path, vim.log.levels.INFO)
end

return M
