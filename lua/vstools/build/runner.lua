local M = {}

local config = require("vstools.config")
local state = require("vstools.startup.state")
local runargs = require("vstools.startup.runargs")
local msbuild = require("vstools.build.msbuild")
local runner_process = require("vstools.build.runner_process")

------------------------------------------------------------
-- Helpers
------------------------------------------------------------

local function start_job(cmd, opts)
  opts = opts or {}
  runner_process.start(cmd, opts)
end

------------------------------------------------------------
-- Build Commands
------------------------------------------------------------

function M.build_startup_project(opts)
  opts = opts or {}
  local project = state.get_current_startup_project()
  if not project then
    vim.notify("No startup project set.", vim.log.levels.ERROR)
    return
  end

  local cmd, err
  if opts.interactive then
    cmd, err = msbuild.build_project_cmd_str(project, opts.conf)
  else
    cmd, err = msbuild.build_project_cmd_list(project, opts.conf)
  end
  if not cmd and err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  start_job(cmd, opts)
end

function M.build_solution(opts)
  opts = opts or {}
  local cmd, err
  if opts.interactive then
    cmd, err = msbuild.build_solution_cmd_str(opts.conf)
  else
    cmd, err = msbuild.build_solution_cmd_list(opts.conf)
  end
  if not cmd and err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  start_job(cmd, opts)
end

function M.clean_startup_project(opts)
  opts = opts or {}
  local project = state.get_current_startup_project()
  if not project then
    vim.notify("No startup project set.", vim.log.levels.ERROR)
    return
  end

  local cmd, err
  if opts.interactive then
    cmd, err = msbuild.clean_project_cmd_str(project, opts.conf)
  else
    cmd, err = msbuild.clean_project_cmd_list(project, opts.conf)
  end
  if not cmd and err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  start_job(cmd, opts)
end

function M.clean_solution(opts)
  opts = opts or {}
  local cmd, err
  if opts.interactive then
    cmd, err = msbuild.clean_solution_cmd_str(opts.conf)
  else
    cmd, err = msbuild.clean_solution_cmd_list(opts.conf)
  end
  if not cmd and err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  start_job(cmd, opts)
end

------------------------------------------------------------
-- EXE Runner -------------------------------------------------
------------------------------------------------------------

local function find_built(project_path, config_name, extension)
  local conf = config_name or config.build_config
  local project_dir = vim.fn.fnamemodify(project_path, ":h")
  local project_name = vim.fn.fnamemodify(project_path, ":t:r")
  local project_parent_dir = vim.fn.fnamemodify(project_path, ":h:h")

  local paths = {
    project_parent_dir .. "\\x64" .. conf .. "\\" .. project_name .. extension,
    project_parent_dir .. "\\" .. conf .. "\\" .. project_name .. extension,
    project_dir .. "\\x64" .. conf .. "\\" .. project_name .. extension,
    project_dir .. "\\" .. conf .. "\\" .. project_name .. extension,
  }

  for _, p in ipairs(paths) do
    if vim.fn.filereadable(p) == 1 then return p end
  end

  return nil
end

function M.run_startup_project(opts)
  opts = opts or {}
  local conf = opts.conf or state.get_build_config()

  local project = opts.project or state.get_current_startup_project()
  if not project then
    vim.notify("No startup project set.", vim.log.levels.ERROR)
    return
  end

  local exe = find_built(project, conf, ".exe")
  if not exe then
    local dll = find_built(project, conf, ".dll")
    if not dll then
      vim.notify("Executable not found. Have you built the project?", vim.log.levels.ERROR)
    end
    return
  end

  -- If gui flag is set, run interactively
  if state.get_gui_flag(project) then
    opts.run_in_terminal = true
  end

  local args = runargs.get_run_args_str()
  local cmd
  if opts.interactive then
    cmd = string.format("%s'%s' %s", config.prepend_exe_path, exe, args)
  else
    cmd = { exe }
    for word in string.gmatch(args, "%S+") do table.insert(cmd, word) end
  end

  start_job(cmd, opts)
end

------------------------------------------------------------
-- Build + Run ------------------------------------------------
------------------------------------------------------------

function M.build_and_run(opts)
  opts = opts or {}

  local project = state.get_current_startup_project()
  if not project then
    vim.notify("No startup project set.", vim.log.levels.ERROR)
    return
  end

  local conf = opts.conf or state.get_build_config()

  local cmd, err = msbuild.build_project_cmd_list(project, conf)
  if not cmd and err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  start_job(cmd, {
    on_exit = function(code)
      if code == 0 then
        M.run_startup_project(opts)
      else
        vim.notify("Build failed, not running executable.", vim.log.levels.ERROR)
      end
    end,
    run_in_terminal = true,
  })
end

return M
