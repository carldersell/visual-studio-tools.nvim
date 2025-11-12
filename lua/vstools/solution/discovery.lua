local M = {}

--- Parse a Visual Studio solution file and return a table of projects with absolute paths.
-- @param sln_path string: Absolute path to the .sln file
-- @return table: A list of absolute paths to the projects
function M.find_vcxproj_projects(sln_path)
  local projects = {}
  if not sln_path then
    -- No solution file provided, search from cwd
    local files = vim.fn.systemlist("fd -e vcxproj")
    local dirs = {}

    for _, file in ipairs(files) do
      local dir = vim.fn.fnamemodify(file, ":p:h")
      if not vim.tbl_contains(dirs, dir) then
        table.insert(dirs, dir)
        table.insert(projects, vim.fn.fnamemodify(file, ":p"))
      end
    end
  else
    -- Get the directory of the solution file
    local sln_dir = vim.fn.fnamemodify(sln_path, ":h")

    -- Read the solution file
    local file = io.open(sln_path, "r")
    if not file then
        vim.notify("Failed to open solution file: " .. sln_path, vim.log.levels.ERROR)
        return projects
    end

    -- Pattern to match project lines in .sln file
    -- Example: Project("{GUID}") = "ProjectName", "RelativePath\ProjectName.vcxproj", "{GUID}"
    local pattern = [[Project%([^%)]+%)%s*=%s*"[^"]+"%s*,%s*"([^"]+)"]]

    for line in file:lines() do
        local rel_path = line:match(pattern)
        if rel_path and rel_path ~= "" then
            -- Normalize and make absolute path
            local abs_path = vim.fn.fnamemodify(sln_dir .. "/" .. rel_path, ":p")
            if vim.fn.filereadable(abs_path) then
              table.insert(projects, abs_path)
            end
        end
    end

    file:close()
  end

  return projects
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
