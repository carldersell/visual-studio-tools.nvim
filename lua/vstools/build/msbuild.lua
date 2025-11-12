local M = {}

local config = require("vstools.config")
local state = require("vstools.startup.state")

local function get_config_name(config_name)
  if config_name == nil or config_name == "" then
    return state.get_build_config()
  end
  return config_name
end

-- msbuild <solution> -t:<project> -p:Configuration=Debug
function M.build_project_cmd_list(project_path, config_name)
  local sln = state.get_solution_path()
  if not sln then
    return nil, "No solution file found."
  end

  local msbuild = config.msbuild_path
  local conf = get_config_name(config_name)

  local target = vim.fn.fnamemodify(project_path, ":t:r") -- project name w/o extension

  local cmdlist = {
        msbuild,
        string.format("%s", sln),
        string.format('-t:"%s"', target),
        string.format("-p:Configuration=%s", conf)
    }

  return cmdlist
end

function M.build_project_cmd_str(project_path, config_name)
  local cmdlist = M.build_project_cmd_list(project_path, config_name)
  if not cmdlist then return nil end
  local cmd = string.format(
    [[%s'%s' "%s" %s %s]],
    config.prepend_exe_path,
    cmdlist[1],
    cmdlist[2],
    cmdlist[3],
    cmdlist[4]
  )
  return cmd
end

-- builds entire solution
function M.build_solution_cmd_list(config_name)
  local sln = state.get_solution_path()
  if not sln then
    return nil, "No solution file found."
  end

  local msbuild = config.msbuild_path
  local conf = get_config_name(config_name)

  local cmdlist = {
        msbuild,
        string.format("%s", sln),
        string.format("-p:Configuration=%s", conf)
    }

  return cmdlist
end

function M.build_solution_cmd_str(config_name)
  local cmdlist = M.build_solution_cmd_list(config_name)
  if not cmdlist then return nil end

  local cmd = string.format(
    [[%s'%s' "%s" %s]],
    config.prepend_exe_path,
    cmdlist[1],
    cmdlist[2],
    cmdlist[3]
  )

  return cmd
end

-- clean current project
function M.clean_project_cmd_list(project_path, config_name)
  local sln = state.get_solution_path()
  if not sln then
    return nil, "No solution file found."
  end

  local msbuild = config.msbuild_path
  local conf = get_config_name(config_name)

  local target = vim.fn.fnamemodify(project_path, ":t:r") -- project name w/o extension

  local cmdlist = {
        msbuild,
        string.format("%s", sln),
        string.format('-t:"%s:clean"', target),
        string.format("-p:Configuration=%s", conf)
    }

  return cmdlist
end

function M.clean_project_cmd_str(project_path, config_name)
  local cmdlist = M.clean_project_cmd_list(project_path, config_name)
  if not cmdlist then return nil end

  local cmd = string.format(
    [[%s'%s' "%s" %s %s]],
    config.prepend_exe_path,
    cmdlist[1],
    cmdlist[2],
    cmdlist[3],
    cmdlist[4]
  )

  return cmd
end

-- cleans entire solution
function M.clean_solution_cmd_list(config_name)
  local sln = state.get_solution_path()
  if not sln then
    return nil, "No solution file found."
  end

  local msbuild = config.msbuild_path
  local conf = get_config_name(config_name)

  local cmdlist = {
        msbuild,
        string.format("%s", sln),
        "-t:clean",
        string.format("-p:Configuration=%s", conf)
    }

  return cmdlist
end

function M.clean_solution_cmd_str(config_name)
  local cmdlist = M.clean_solution_cmd_list(config_name)
  if not cmdlist then return nil end

  local cmd = string.format(
    [[%s'%s' "%s" %s %s]],
    config.prepend_exe_path,
    cmdlist[1],
    cmdlist[2],
    cmdlist[3],
    cmdlist[4]
  )

  return cmd
end

return M
