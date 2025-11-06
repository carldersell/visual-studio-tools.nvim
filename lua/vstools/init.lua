local M = {}

function M.setup()
  local state = require("vstools.startup.state")
  local selector = require("vstools.startup.selector")

  -- Auto-load current startup project
  local project = state.get_project()
  if project then
    print("Loaded startup project: " .. project)
  end

  -- Commands
  vim.api.nvim_create_user_command("VSSelectStartupProject", function()
    selector.select()
  end, {})

  vim.api.nvim_create_user_command("VSShowStartupProject", function()
    local project = state.get_project()
    if project then
      print("Startup project: " .. project)
    else
      print("No startup project set for this directory.")
    end
  end, {})
end

return M
