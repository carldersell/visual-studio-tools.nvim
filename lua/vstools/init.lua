local M = {}

function M.setup(opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    auto_load_startup_project = true,
  })

  -- Load project upon startup
  if opts.auto_load_startup_project then
    local state = require("vstools.startup.state")
    local project = state.get_project()
    if project then
      print("Loaded startup project: " .. project)
    end

    local build_config = state.get_build_config()
    if build_config then
      print("Build configuration: " .. build_config)
    end
  end
end

-- Public API ----------------------------------------------------

-- State persitent parts
function M.select_startup_project()
  require("vstools.startup.selector").select()
end

function M.show_startup_project()
  local state = require("vstools.startup.state")
  local project = state.get_project()

  if project then
    print("Startup project: " .. project)
  else
    print("No startup project set for this directory.")
  end
end

function M.set_build_config(conf)
  local state = require("vstools.startup.state")
  return state.set_build_config(conf)
end

function M.toggle_build_config()
  local state = require("vstools.startup.state")
  return state.toggle_build_config()
end

-- Build / Clean / Run API
local builder = require("vstools.build.runner")

function M.build_startup_project(conf)
      builder.build_startup_project(conf)
end

function M.build_solution(conf)
      builder.build_solution(conf)
end

function M.clean_startup_project(conf)
      builder.clean_startup_project(conf)
end

function M.clean_solution(conf)
      builder.clean_solution(conf)
end

function M.run_startup_project(conf)
      builder.run_startup_project(conf)
end

function M.build_and_run(conf)
      builder.build_and_run(conf)
end

return M
