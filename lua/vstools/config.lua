local DEFAULTS = {
  msbuild_path = "msbuild.exe",

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

return M
