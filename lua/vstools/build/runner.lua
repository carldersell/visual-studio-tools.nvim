local M = {}

local config = require("vstools.config")
local state = require("vstools.startup.state")
local runargs = require("vstools.startup.runargs")
local msbuild = require("vstools.build.msbuild")

function M.build_startup_project(conf)
  local project = state.get_current_startup_project()
  if not project then
    vim.notify("No startup project set.", vim.log.levels.ERROR)
    return
  end

  local cmd, err = msbuild.build_project_cmd(project, conf)
  if not cmd and err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  config.open_terminal(cmd)
end

function M.build_solution(conf)
  local cmd, err = msbuild.build_solution_cmd(conf)
  if not cmd and err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  config.open_terminal(cmd)
end

function M.clean_startup_project(conf)
  local project = state.get_current_startup_project()
  if not project then
    vim.notify("No startup project set.", vim.log.levels.ERROR)
    return
  end

  local cmd, err = msbuild.clean_project_cmd(project, conf)
  if not cmd and err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  config.open_terminal(cmd)
end

function M.clean_solution(conf)
  local cmd, err = msbuild.clean_solution_cmd(conf)
  if not cmd and err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  config.open_terminal(cmd)
end

-- EXE runner ------------------------------------------------------

local function find_executable(project_path, config_name)
  local conf = config_name or "Debug"
  local project_dir = vim.fn.fnamemodify(project_path, ":h")
  local project_name = vim.fn.fnamemodify(project_path, ":t:r")
  local project_parent_dir = vim.fn.fnamemodify(project_path, ":h:h")

  -- very common MSVC output structure:
  local exe = project_parent_dir .. "\\x64" .. conf .. "\\" .. project_name .. ".exe"
  if vim.fn.filereadable(exe) == 1 then
    return exe
  end

  exe = project_parent_dir .. "\\" .. conf .. "\\" .. project_name .. ".exe"
  if vim.fn.filereadable(exe) == 1 then
    return exe
  end

  exe = project_dir .. "\\x64" .. conf .. "\\" .. project_name .. ".exe"
  if vim.fn.filereadable(exe) == 1 then
    return exe
  end

  exe = project_dir .. "\\" .. conf .. "\\" .. project_name .. ".exe"
  if vim.fn.filereadable(exe) == 1 then
    return exe
  end

  return nil
end

function M.run_startup_project(conf)
  if not conf or conf == "" then
    conf = state.get_build_config()
  end

  local project = state.get_current_startup_project()
  if not project then
    vim.notify("No startup project set.", vim.log.levels.ERROR)
    return
  end

  local exe = find_executable(project, conf)
  if not exe then
    vim.notify("Executable not found. Have you built the project?", vim.log.levels.ERROR)
    return
  end

  local args = runargs.get_run_args_str()
  -- Maybe add a check if we will run in nushell, if that is the case then we might have to add a '^' in front of the exe path
  -- local cmd = string.format([["%s" %s]], exe, args)
  local cmd = string.format([[%s'%s' %s]], config.prepend_exe_path, exe, args)

  config.open_terminal(cmd)
end

return M
