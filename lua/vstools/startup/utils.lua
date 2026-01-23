-- lua/vstools/util.lua
local U = {}

local editors = {}

function U.is_windows()
  return vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
  -- return package.config:sub(1,1) == "\\"
end

function U.path_sep()
  return U.is_windows() and ";" or ":"
end

function U.trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Count lines that contain any non-whitespace char
function U.count_non_empty_lines(text)
  local count = 0
  for line in (text or ""):gmatch("[^\n]*") do
    if line:match("%S") then count = count + 1 end
  end
  return count
end

-- Double single backslashes in Windows-like paths (avoid touching existing \\)
function U.windows_paths(text)
  if not text or text == "" then return text end
  -- Match a single backslash that is NOT followed by another backslash
  local result = text:gsub("([^\\])\\([^\\])", "%1\\\\%2")
  -- Handle start of string
  result = result:gsub("^\\([^\\])", "\\\\%1")
  -- Handle end of string
  result = result:gsub("([^\\])\\$", "%1\\\\")

  return result
end

-- Tokenizer that splits on "sep" while respecting quotes and \-escapes.
-- Example: split_values([[C:\A; "C:\Program Files\B"; /usr/bin]], ';')
function U.split_values(values, sep_char)
  local out, cur = {}, {}
  local i, len = 1, #values
  local in_single, in_double = false, false

  while i <= len do
    local c = values:sub(i, i)
    if c == "\\" then
      -- escape next character
      local nxt = values:sub(i + 1, i + 1)
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
    elseif c == sep_char and not in_single and not in_double then
      local token = table.concat(cur)
      token = U.trim(token)
      if token ~= "" then table.insert(out, token) end
      cur = {}
      i = i + 1
    else
      table.insert(cur, c)
      i = i + 1
    end
  end

  local tail = U.trim(table.concat(cur))
  if tail ~= "" then table.insert(out, tail) end
  return out
end

-- General-purpose floating editor creator; calls on_save(raw_text) on :w
function U.open_editor(opts)
  opts = opts or {}

  local win_id = opts.id or opts.name
  assert(win_id, "open_editor requires opts.name or opts.id")
  local title = opts.title or " Editor "
  local lines = opts.lines or { "" }
  local floating = (opts.floating ~= false)
  local on_save = assert(opts.on_save, "open_editor requires opts.on_save")

  -- Check if window is already open, then refocus
  editors[win_id] = editors[win_id] or {}
  local state = editors[win_id]
  if state.win and vim.api.nvim_win_is_valid(state.win) and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_set_current_win(state.win)
    return state.buf
  end

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch
  vim.api.nvim_buf_set_name(buf, opts.name or title:gsub("%s", ""))
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = opts.filetype or "vstools_editor"

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win
  if floating then
    local width = math.max(60, math.floor(vim.o.columns * 0.8))
    local height = math.max(6,  math.floor(vim.o.lines   * 0.8))
    local row = math.floor((vim.o.lines - height) / 2 - 1)
    local col = math.floor((vim.o.columns - width) / 2)

    win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width, height = height, row = row, col = col,
      border = "rounded", style = "minimal", title = title, title_pos = "center",
    })
    vim.wo[win].winhl = "FloatTitle:TelescopeBorder,NormalFloat:TelescopeNormal"
  else
    vim.api.nvim_set_current_buf(buf)
    win = vim.api.nvim_get_current_win()
  end

  -- Save instance
  state.buf = buf
  state.win = win

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local contents = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local raw = table.concat(contents, "\n")
      local ok, err = pcall(on_save, raw)
      if not ok then
        vim.notify("Save failed: " .. tostring(err), vim.log.levels.ERROR)
        return
      end

      -- Cleanup
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
      if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
      editors[win_id] = nil
    end,
  })

  -- Cleanup if user closes window manually
  vim.api.nvim_create_autocmd("WinClosed", {
    callback = function(args)
      if tonumber(args.match) == win then
        editors[win_id] = nil
      end
    end,
    once = true,
  })

  return buf
end

return U
