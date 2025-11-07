local M = {}

local config = require("vstools.config")
local solution = require("vstools.solution.discovery")

-- msbuild <solution> -t:<project> -p:Configuration=Debug
function M.build_project_cmd(project_path, config_name)
  local sln = solution.find_solution()
  if not sln then
    return nil, "No solution file found."
  end

  local msbuild = config.msbuild_path
  local conf = config_name or config.build_config

  local target = vim.fn.fnamemodify(project_path, ":t:r") -- project name w/o extension

  local cmd = string.format(
    [[%s "%s" -t:%s -p:Configuration=%s]],
    msbuild,
    sln,
    target,
    conf
  )

  return cmd
end

-- builds entire solution
function M.build_solution_cmd(config_name)
  local sln = solution.find_solution()
  if not sln then
    return nil, "No solution file found."
  end

  local msbuild = config.msbuild_path
  local conf = config_name or config.build_config

  local cmd = string.format(
    [[%s "%s" -p:Configuration=%s]],
    msbuild,
    sln,
    conf
  )

  return cmd
end

return M
