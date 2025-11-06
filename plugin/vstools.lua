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
