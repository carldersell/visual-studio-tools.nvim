local M = {}

local discovery = require("vstools.solution.discovery")
local state = require("vstools.startup.state")

function M.select()
  local projects = discovery.find_vcxproj_projects()

  require("vstools.startup.picker").select_project(projects, function(choice)
    if choice then
      state.set_project(choice)
    end
  end, state.get_project())
end

return M
