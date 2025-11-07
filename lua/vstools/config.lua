local DEFAULTS = {
  msbuild_path = "msbuild.exe",
  build_config = "Release",

  open_terminal = function(cmd)
    require("floating_terminal").run_in_bottom_terminal(cmd)
    vim.cmd("normal! G")
  end,
}

-- Current live config (merged defaults + user overrides)
local M = vim.deepcopy(DEFAULTS)

-- Merge user opts at startup
function M.apply(user_opts)
  user_opts = user_opts or {}

  local merged = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), user_opts)

  for k, v in pairs(merged) do
    M[k] = v
  end

  return M
end

-- Runtime setter for build_config (or other runtime options)
function M.set_build_config(new_config)
  M.build_config = new_config
end

function M.get_build_config()
  return M.build_config
end

function M.toggle_build_config()
  if M.build_config == "Debug" then
    M.build_config = "Release"
  else
    M.build_config = "Debug"
  end
end

return M
