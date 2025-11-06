local M = {}

function M.find_vcxproj_projects()
  local files = vim.fn.systemlist("fd -e vcxproj")
  local dirs = {}

  for _, file in ipairs(files) do
    local dir = vim.fn.fnamemodify(file, ":p:h")
    if not vim.tbl_contains(dirs, dir) then
      table.insert(dirs, dir)
    end
  end

  return dirs
end

return M
