local state = require("vstools.startup.state")

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
  local lines = {}
  for _, grp in ipairs(groups) do
    table.insert(lines, table.concat(grp, " "))
  end
  return table.concat(lines, "\n")
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

  local buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch
  vim.api.nvim_buf_set_name(buf, "VSToolsRunArgs")

  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "vstools_runargs"

  local groups = state.get_run_args()
  local text = M.groups_to_text(groups)
  local lines = {}

  if text == "" then
    lines = { "" }
  else
    for ln in text:gmatch("([^\n]*)\n?") do
      table.insert(lines, ln)
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win
  if opts.floating ~= false then
    local width = math.max(60, math.floor(vim.o.columns * 0.8))
    local height = math.max(6, math.floor(vim.o.lines * 0.8))
    local row = math.floor((vim.o.lines - height) / 2 - 1)
    local col = math.floor((vim.o.columns - width) / 2)

    win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      border = "rounded",
      style = "minimal",
    })
  else
    vim.api.nvim_set_current_buf(buf)
    win = vim.api.nvim_get_current_win()
  end

  -- ✅ Save on :w
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local contents = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local raw = table.concat(contents, "\n")
      local parsed_groups = M.parse_run_args_text_to_groups(raw)

      state.set_run_args(parsed_groups)

      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end,
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
