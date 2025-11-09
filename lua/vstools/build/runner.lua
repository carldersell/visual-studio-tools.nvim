local M = {}

local config = require("vstools.config")
local state = require("vstools.startup.state")
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

return M
