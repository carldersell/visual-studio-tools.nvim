-- Safe require to avoid breaking if plugin hasn't been loaded yet
local ok, vstools = pcall(require, "vstools")
if not ok then
  return
end

-- User may configure later, but call setup with defaults now
vstools.setup()

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

vim.api.nvim_create_user_command("VSEditRunArgs", function()
  vstools.edit_run_args()
end, {})

-- Commands for build and run
vim.api.nvim_create_user_command("VSBuildProject", function(opts)
      vstools.build_startup_project(opts.args)
end, {})

vim.api.nvim_create_user_command("VSBuildSolution", function(opts)
      vstools.build_solution(opts.args)
end, {})

vim.api.nvim_create_user_command("VSCleanProject", function(opts)
      vstools.clean_startup_project(opts.args)
end, {})

vim.api.nvim_create_user_command("VSCleanSolution", function(opts)
      vstools.clean_solution(opts.args)
end, {})

