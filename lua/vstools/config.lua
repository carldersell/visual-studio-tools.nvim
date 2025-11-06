local M = {
  msbuild_path = "msbuild.exe",

  -- default build config
  build_config = "Release",

  -- terminal integration (your floating-terminal plugin)
  open_terminal = function(cmd)
    require("floating_terminal").run_in_bottom_terminal(cmd)
    vim.cmd("normal! G")
  end,
}

function M.apply(user_opts)
  M = vim.tbl_deep_extend("force", M, user_opts or {})
end

return M
