local M = {}

function M.setup(opts)
  require("vstools.config").setup(opts)

  -- Load project upon startup
  local state = require("vstools.startup.state")
  local project = state.get_current_startup_project()
  if project then
    vim.notify("Loaded startup project: " .. project, vim.log.levels.INFO)
  end

  local build_config = state.get_build_config()
  if build_config then
    vim.notify("Build configuration: " .. build_config, vim.log.levels.INFO)
  end
end

-- Public API ----------------------------------------------------

-- State persitent parts
function M.select_startup_project()
  require("vstools.startup.selector").select()
end

function M.show_startup_project()
  local state = require("vstools.startup.state")
  local project = state.get_current_startup_project()

  if project then
    vim.notify("Startup project: " .. project, vim.log.levels.INFO)
  else
    vim.notify("No startup project set for this directory.", vim.log.levels.WARN)
  end
end

function M.set_build_config(conf)
  local state = require("vstools.startup.state")
  return state.set_build_config(conf)
end

function M.get_build_config()
  local state = require("vstools.startup.state")
  local build_config = state.get_build_config()
  if not build_config then return end
  vim.notify("Build configuration: ".. build_config)
end

function M.set_solution_file(solution_path)
  local state = require("vstools.startup.state")
  return state.set_solution_path(solution_path)
end

function M.get_solution_file()
  local state = require("vstools.startup.state")
  local solution_path = state.get_solution_path()
  if not solution_path then return end
  vim.notify("Solution path: ".. solution_path)
end

function M.toggle_build_config()
  local state = require("vstools.startup.state")
  return state.toggle_build_config()
end

function M.edit_run_args()
  return require("vstools.startup.runargs").open_runargs_editor({floating = true})
end

function M.get_project_settings()
  local state = require("vstools.startup.state")
  local settings = state.get_project_settings(state.get_current_startup_project())
  if not settings then return end
  vim.notify(state.get_current_startup_project() .. ": " .. vim.inspect(settings), vim.log.levels.INFO)
end

function M.get_project_gui_flag()
    local state = require("vstools.startup.state")
    local current_project = state.get_current_startup_project()
    if not current_project then
      vim.notify("No startup project set for this directory", vim.log.levels.WARN)
    end
    vim.notify(current_project .. ": gui = " .. tostring(state.get_gui_flag()), vim.log.levels.INFO)
end

function M.set_project_gui_flag(flag)
    require("vstools.startup.state").set_gui_flag(flag)
end

-- Build / Clean / Run API
local builder = require("vstools.build.runner")

function M.build_startup_project(opts)
      builder.build_startup_project(opts)
end

function M.build_solution(opts)
      builder.build_solution(opts)
end

function M.clean_startup_project(opts)
      builder.clean_startup_project(opts)
end

function M.clean_solution(opts)
      builder.clean_solution(opts)
end

function M.run_startup_project(opts)
      builder.run_startup_project(opts)
end

function M.build_and_run(opts)
      builder.build_and_run(opts)
end

function M.toggle_build_terminal()
    require("vstools.build.runner_system").toggle_window()
end

function M.stop_command()
    require("vstools.build.runner_system").stop()
end

return M
