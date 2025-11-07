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

-- search parent directories for .sln
function M.find_solution(start_dir)
  local dir = start_dir or vim.fn.getcwd()
  while dir ~= "" and dir ~= "/" do
    local files = vim.fn.globpath(dir, "*.sln", false, true)
    if #files > 0 then
      return files[1]:gsub('\\', '/')
    end
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  return nil
end

return M
