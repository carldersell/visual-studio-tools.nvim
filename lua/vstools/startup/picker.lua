local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local telescope_utils = require("telescope.utils")
local make_entry = require("telescope.make_entry")
local entry_display = require("telescope.pickers.entry_display")
local plenary_strings = require("plenary.strings")
local devicons = require("nvim-web-devicons")

-- Width for icon column
local icon_width = plenary_strings.strdisplaywidth(
  devicons.get_icon("fname", { default = true })
)

-- Extract tail + truncated parent path
local function get_path_and_tail(path)
  local tail = telescope_utils.path_tail(path)
  local parent = plenary_strings.truncate(path, #path - #tail, "")
  parent = telescope_utils.transform_path({
    path_display = { "truncate" },
  }, parent)
  return tail, parent
end

-- Compare displayed path vs current project
local function is_current_project(current, tail_with_space, display_path)
  if not current then
    return false
  end

  local cur_tail, cur_path = get_path_and_tail(current)
  cur_tail = cur_tail .. " "

  return (tail_with_space == cur_tail) and (cur_path == display_path)
end

-- Custom entry maker
local function entry_maker(current_project, opts)
  opts = opts or {}
  local original = make_entry.gen_from_file(opts)

  return function(line)
    local entry = original(line)

    local displayer = entry_display.create({
      separator = " ",
      items = {
        { width = icon_width },
        { width = nil },
        { remaining = true },
      },
    })

    entry.display = function(e)
      local tail, parent = get_path_and_tail(vim.fn.fnamemodify(e.value, ":r"))
      local tail_disp = tail .. " "

      local icon, icon_hl = telescope_utils.get_devicons(tail)
      icon = ""

      local highlighted_tail = tail_disp
      local highlighted_parent = { parent, "TelescopeResultsComment" }

      if is_current_project(current_project, tail_disp, parent) then
        highlighted_tail = { tail_disp, "TelescopeResultsComment" }
      end

      return displayer({
        { icon, icon_hl },
        highlighted_tail,
        highlighted_parent,
      })
    end

    return entry
  end
end

-- Public picker API
function M.select_project(projects, callback, current_project)
  if #projects == 0 then
    vim.notify("No .vcxproj projects found.", vim.log.levels.ERROR)
    return
  end

  local title = "Select Startup Project"
  if current_project then
    current_project = vim.fn.fnamemodify(current_project, ":r")
    title = title .. " (" .. telescope_utils.path_tail(current_project) .. ")"
  end

  pickers
    .new({}, {
      prompt_title = title,
      finder = finders.new_table({
        results = projects,
        entry_maker = entry_maker(current_project),
      }),
      sorter = require("telescope.sorters").get_fuzzy_file({}),
      attach_mappings = function(_, map)
        actions.select_default:replace(function(bufnr)
          local entry = action_state.get_selected_entry()
          actions.close(bufnr)
          if entry and callback then
            callback(entry[1])
          end
        end)
        return true
      end,
    })
    :find()
end

return M
