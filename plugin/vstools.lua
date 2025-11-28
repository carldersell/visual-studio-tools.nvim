-- Safe require to avoid breaking if plugin hasn't been loaded yet
local ok, vstools = pcall(require, "vstools")
if not ok then
  return
end

local function parse_args(argstr)
  local result = {}
  for token in string.gmatch(argstr, "%S+") do
    local key, val = token:match("^(%w+)%=(.+)$")
    if key then
      -- key=value form
      if val == "true" then
        result[key] = true
      elseif val == "false" then
        result[key] = false
      else
        result[key] = val
      end
    else
      result[token] = true
    end
  end
  return result
end

-- Commands delegate to vstools public API
vim.api.nvim_create_user_command("VSSelectStartupProject", function()
  vstools.select_startup_project()
end, {})

vim.api.nvim_create_user_command("VSShowStartupProject", function()
  vstools.show_startup_project()
end, {})

vim.api.nvim_create_user_command("VSGetProjectSettings", function()
  vstools.get_project_settings()
end, {})

-- Commands to change build configuration
vim.api.nvim_create_user_command("VSSetBuildConfig", function(opts)
  local new_conf = opts.args
  vstools.set_build_config(new_conf)
end, {
  nargs = 1,
  complete = function()
    return { "Debug", "Release" }
  end,
})

vim.api.nvim_create_user_command("VSBuildConfigToggle", function()
  vstools.toggle_build_config()
end, {})

vim.api.nvim_create_user_command("VSGetBuildConfig", function()
  vstools.get_build_config()
end, {})

vim.api.nvim_create_user_command("VSSetSolutionPath", function(opts)
    vstools.set_solution_file(opts.args)
end, {})

vim.api.nvim_create_user_command("VSGetSolutionPath", function()
    vstools.get_solution_file()
end, {})

vim.api.nvim_create_user_command("VSEditRunArgs", function()
  vstools.edit_run_args()
end, {})

vim.api.nvim_create_user_command("VSEditEnv", function()
  vstools.edit_environment()
end, {})

vim.api.nvim_create_user_command("VSProjectSetGuiFlag", function(opts)
  local flag = opts.args
  vstools.set_project_gui_flag(flag)
end, {
  nargs = 1,
  complete = function()
    return { "true", "false" }
  end,
})

vim.api.nvim_create_user_command("VSProjectGetGuiFlag", function()
  vstools.get_project_gui_flag()
end, {})

-- Commands for build and run
vim.api.nvim_create_user_command("VSBuildProject", function(opts)
      vstools.build_startup_project(parse_args(opts.args))
end, {nargs="*"})

vim.api.nvim_create_user_command("VSBuildSolution", function(opts)
      vstools.build_solution(parse_args(opts.args))
end, {nargs="*"})

vim.api.nvim_create_user_command("VSCleanProject", function(opts)
      vstools.clean_startup_project(parse_args(opts.args))
end, {nargs="*"})

vim.api.nvim_create_user_command("VSCleanSolution", function(opts)
      vstools.clean_solution(parse_args(opts.args))
end, {nargs="*"})

vim.api.nvim_create_user_command("VSRunProject", function(opts)
      vstools.run_startup_project(parse_args(opts.args))
end, {nargs="*"})

vim.api.nvim_create_user_command("VSBuildAndRun", function(opts)
      vstools.build_and_run(parse_args(opts.args))
end, {nargs="*"})

vim.api.nvim_create_user_command("VSToggleBuildTerminal", function(opts)
      local mode = nil
      if opts and opts.args ~= "" then
        mode = {mode = opts.args}
      end
      vstools.toggle_build_terminal(mode)
end, {
  nargs = '?',
  complete = function()
    return {"system", "terminal"}
  end,
})

vim.api.nvim_create_user_command("VSStopCommand", function()
      vstools.stop_command()
end, {})

vim.api.nvim_create_user_command("VSShowRunState", function()
      vim.notify(vim.inspect(vstools.get_run_state()), vim.log.levels.INFO)
end, {})
