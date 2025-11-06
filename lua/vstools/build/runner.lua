local M = {}

local config = require("vstools.config")
local state = require("vstools.startup.state")
local msbuild = require("vstools.build.msbuild")

function M.build_startup_project(conf)
  local project = state.get_project()
  if not project then
    print("No startup project set.")
    return
  end

  local cmd, err = msbuild.build_project_cmd(project, conf)
  if not cmd then
    print(err)
    return
  end

  config.open_terminal(cmd)
end

function M.build_solution(conf)
  local cmd, err = msbuild.build_solution_cmd(conf)
  if not cmd then
    print(err)
    return
  end

  config.open_terminal(cmd)
end

return M
