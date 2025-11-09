local M = {}

local config = require("vstools.config")
local state = require("vstools.startup.state")
local solution = require("vstools.solution.discovery")

local function get_config_name(config_name)
  if config_name == nil or config_name == "" then
    return state.get_build_config()
  end
  return config_name
end

-- msbuild <solution> -t:<project> -p:Configuration=Debug
function M.build_project_cmd(project_path, config_name)
  local sln = solution.find_solution()
  if not sln then
    return nil, "No solution file found."
  end

  local msbuild = config.msbuild_path
  local conf = get_config_name(config_name)

  local target = vim.fn.fnamemodify(project_path, ":t:r") -- project name w/o extension

  local cmd = string.format(
    [[%s'%s' "%s" -t:"%s" -p:Configuration=%s]],
    config.prepend_exe_path,
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
  local conf = get_config_name(config_name)

  local cmd = string.format(
    [[%s'%s' "%s" -p:Configuration=%s]],
    config.prepend_exe_path,
    msbuild,
    sln,
    conf
  )

  return cmd
end

-- clean current project
function M.clean_project_cmd(project_path, config_name)
  local sln = solution.find_solution()
  if not sln then
    return nil, "No solution file found."
  end

  local msbuild = config.msbuild_path
  local conf = get_config_name(config_name)

  local target = vim.fn.fnamemodify(project_path, ":t:r") -- project name w/o extension

  local cmd = string.format(
    [[%s'%s' "%s" -t:"%s:clean" -p:Configuration=%s]],
    config.prepend_exe_path,
    msbuild,
    sln,
    target,
    conf
  )

  return cmd
end

-- cleans entire solution
function M.clean_solution_cmd(config_name)
  local sln = solution.find_solution()
  if not sln then
    return nil, "No solution file found."
  end

  local msbuild = config.msbuild_path
  local conf = get_config_name(config_name)

  local cmd = string.format(
    [[%s'%s' "%s" -t:clean -p:Configuration=%s]],
    config.prepend_exe_path,
    msbuild,
    sln,
    conf
  )

  return cmd
end
return M
