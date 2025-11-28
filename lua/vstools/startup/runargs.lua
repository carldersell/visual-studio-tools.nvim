local state = require("vstools.startup.state")
local config = require("vstools.config")
local utils = require("vstools.startup.utils")

local M = {}

-----------------------------------------------------------------------
-- Quote-aware tokenizer (supports "..." and '...')
-- Produces a list of tokens: {"-flag", "value with spaces", ...}
-----------------------------------------------------------------------
local function shell_tokenize(line)
  local tokens = {}
  local cur = {}
  local i, len = 1, #line
  local in_single, in_double = false, false

  while i <= len do
    local c = line:sub(i, i)

    if c == "\\" then
      -- escape next character
      local nxt = line:sub(i + 1, i + 1)
      if nxt ~= "" then
        table.insert(cur, nxt)
        i = i + 2
      else
        table.insert(cur, c)
        i = i + 1
      end

    elseif c == '"' and not in_single then
      in_double = not in_double
      i = i + 1

    elseif c == "'" and not in_double then
      in_single = not in_single
      i = i + 1

    elseif (not in_single and not in_double) and c:match("%s") then
      if #cur > 0 then
        table.insert(tokens, table.concat(cur))
        cur = {}
      end
      i = i + 1

    else
      table.insert(cur, c)
      i = i + 1
    end
  end

  if #cur > 0 then
    table.insert(tokens, table.concat(cur))
  end

  return tokens
end

-----------------------------------------------------------------------
-- Parse raw text into grouped arguments:
-- {
--   { "-flag", "a", "b" },
--   { "-s", "out" },
-- }
-----------------------------------------------------------------------
function M.parse_run_args_text_to_groups(text)
  if not text or text == "" then
    return {}
  end

  text = text:gsub("\r\n", "\n")

  -- Correctly parse windows paths
  text = utils.windows_paths(text)

  -- split into lines
  local lines = {}
  for ln in text:gmatch("([^\n]*)\n?") do
    table.insert(lines, ln)
  end

  -- count non-empty
  local non_empty = 0
  for _, ln in ipairs(lines) do
    if ln:match("%S") then non_empty = non_empty + 1 end
  end

  local result = {}

  -- ✅ SINGLE-LINE MODE → auto-split into groups
  if non_empty <= 1 then
    local single = ""
    for _, ln in ipairs(lines) do
      if ln:match("%S") then
        single = ln
        break
      end
    end
    if single == "" then
      return {}
    end

    local toks = shell_tokenize(single)
    local group = {}
    for _, t in ipairs(toks) do
      if t:match("^%-%-?[%w%-_]+") then
        -- new flag = new group
        if #group > 0 then
          table.insert(result, group)
        end
        group = { t }
      else
        table.insert(group, t)
      end
    end
    if #group > 0 then
      table.insert(result, group)
    end

    return result
  end

  --------------------------------------------------------------------
  -- ✅ MULTI-LINE MODE: each line = one group
  --------------------------------------------------------------------
  for _, ln in ipairs(lines) do
    if ln:match("%S") then
      local toks = shell_tokenize(ln)
      if #toks > 0 then
        table.insert(result, toks)
      end
    end
  end

  return result
end

------------------------------------------------------------------------
-- GROUPS → TEXT
------------------------------------------------------------------------
function M.groups_to_text(groups)
  if groups == {} then return "" end
  local lines = {}
  for _, grp in ipairs(groups) do
    table.insert(lines, table.concat(grp, " "))
  end
  local tmp = table.concat(lines, "\n")
  return tmp:gsub("\n$", "")
end

------------------------------------------------------------------------
-- GROUPS → FINAL ARGUMENT STRING FOR RUNNER
------------------------------------------------------------------------
function M.groups_to_arg_string(groups)
  local flat = {}
  for _, grp in ipairs(groups) do
    for _, v in ipairs(grp) do
      -- quote if necessary
      if v:match("%s") then
        table.insert(flat, vim.fn.shellescape(v))
      else
        table.insert(flat, v)
      end
    end
  end
  return table.concat(flat, " ")
end

------------------------------------------------------------------------
-- lines → Same format as entered
------------------------------------------------------------------------
local function line_to_provided_format(lines, mode)
  if mode == "line" then
    return {table.concat(lines, " ")}
  end
  return lines
end

-----------------------------------------------------------------------
-- Editor: open scratch buffer, save on :w, and close buffer
-----------------------------------------------------------------------
function M.open_runargs_editor(opts)
  -- Sanity check
  if not state.get_current_startup_project() then
    vim.notify("No startup project selected.", vim.log.levels.ERROR)
    return
  end

  opts = opts or {}

  local groups = state.get_run_args()
  local text = M.groups_to_text(groups)
  local lines = {}

  if text == "" then
    lines = { "" }
  else
    for ln in text:gmatch("([^\n]+)\n?") do
      table.insert(lines, ln)
    end
  end

  -- Check how keys should be presented
  local mode
  if opts and opts.presentation_mode then
    mode = opts.presentation_mode
    if opts.presentation_mode == "automatic" then
      mode = state.get_run_args_mode()
    end
  else
    mode = config.setting_presentation or state.get_run_args_mode()
    if mode == "automatic" then
      mode = state.get_run_args_mode()
    end
  end
  lines = line_to_provided_format(lines, mode)

  local buf = utils.open_editor({
    name = "VSToolsRunArgs",
    title = " Command arguments ",
    filetype = "vstools_runargs",
    lines = lines,
    on_save = function(raw)
      local parsed_groups = M.parse_run_args_text_to_groups(raw)
      local inferred_mode = utils.count_non_empty_lines(raw) > 1 and "row" or "line"
      state.set_run_args(parsed_groups, nil, inferred_mode)
    end,
    floating = (opts.floating ~= false),
  })

  return buf
end

-----------------------------------------------------------------------
-- Convenience: parsed args for runner
-----------------------------------------------------------------------
function M.get_run_args_groups()
  return state.get_run_args()
end

function M.get_run_args_str()
  return M.groups_to_arg_string(state.get_run_args())
end

return M
