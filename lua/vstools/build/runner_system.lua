local state_module = require("vstools.startup.state")

local M = {}
local api = vim.api

-- Load user config (with safe defaults)
local function resolve_size(value, max)
  if type(value) == "number" then
    if value <= 1 then
      return math.floor(max * value)
    else
      return math.floor(value)
    end
  end
  return max
end

local function get_term_cfg()
  local ok, cfg = pcall(require, "vstools.config")
  cfg = ok and cfg or {}
  cfg.log_settings = cfg.log_settings or {}
  return {
    width  = resolve_size(cfg.log_settings.width or 0.8, vim.o.columns),
    height = resolve_size(cfg.log_settings.height or 0.8, vim.o.lines),
    border = cfg.log_settings.border or "single",
  }
end

-- State for buffer/window/job
local state = {
  buf = nil,
  win = nil,
  job = nil,
  pid = nil,
  partial = "",
  name = "VSTools Build",
}

-- format a command (string or list) for display
local function format_cmd_line(arg)
  if type(arg) == "string" then
    return arg
  end
  -- arg is a list: quote only when needed
  local parts = {}
  for _, s in ipairs(arg) do
    if s:find("[%s\"'\\$]") then
      -- minimal, portable-ish quoting
      s = "'" .. s:gsub("'", "'\\''") .. "'"
    end
    table.insert(parts, s)
  end
  return table.concat(parts, " ")
end

-- ---------- buffer helpers ----------

local function ensure_buf()
  if state.buf and api.nvim_buf_is_valid(state.buf) then
    return state.buf
  end
  local buf = api.nvim_create_buf(false, true) -- [listed=false, scratch=true]
  state.buf = buf

  vim.bo[buf].buftype   = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile  = false
  vim.bo[buf].filetype  = "vstoolslog"
  api.nvim_buf_set_name(buf, state.name)

  -- Start empty
  api.nvim_buf_set_lines(buf, 0, -1, false, {})

  return buf
end

local function find_window_for_buf(buf)
  for _, w in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_is_valid(w) and api.nvim_win_get_buf(w) == buf then
      return w
    end
  end
end

local function clear_buffer()
  local buf = ensure_buf()
  api.nvim_buf_set_lines(buf, 0, -1, false, {})
  state.partial = ""
end

-- Append text in chunks, handling partial lines between chunks.
local function _append_chunk(chunk)
  local buf = ensure_buf()
  if not api.nvim_buf_is_valid(buf) then return end

  local data = state.partial .. chunk
  local parts = vim.split(data, "\n", { plain = true })
  state.partial = table.remove(parts) or ""

  if #parts > 0 then
    local last = api.nvim_buf_line_count(buf)
    api.nvim_buf_set_lines(buf, last, last, false, parts)
  end

  -- Auto-scroll if visible
  local win = find_window_for_buf(buf)
  if win and api.nvim_win_is_valid(win) then
    local lastline = api.nvim_buf_line_count(buf)
    api.nvim_win_set_cursor(win, { lastline, 0 })
  end
end

-- Schedule buffer mutations to avoid E5560 (fast event context)
local append_chunk = vim.schedule_wrap(_append_chunk)

local function is_open()
  local buf = state.buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return false, nil
  end
  local win = nil
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == buf then
      win = w
      break
    end
  end
  return win ~= nil, win
end
-- ---------- window / toggle ----------

-- Create (or jump to) a floating window showing the build buffer,
-- honoring width/height/border from config.

function M.toggle_window(opts)
  opts = opts or {}
  local buf = ensure_buf()

  if not opts.keep_open then
    -- If it's open anywhere, close it (true toggle)
    local open, win = is_open()
    if open and win and vim.api.nvim_win_is_valid(win) then
      -- Close the floating window; keep buffer around for reuse
      pcall(vim.api.nvim_win_close, win, true)
      -- If we tracked a stale win id, clear it
      if state.win == win then
        state.win = nil
      end
      return
    end
  end

  -- Otherwise open (or focus) it using current config
  local cfg = get_term_cfg()
  local columns = vim.o.columns
  local lines = vim.o.lines

  local width  = math.min(cfg.width, columns - 2)
  local height = math.min(cfg.height, lines - 2)

  local row = math.max(1, math.floor((lines - height) / 2))
  local col = math.max(1, math.floor((columns - width) / 2))

  state.win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = cfg.border,
    noautocmd = true,
  })
  vim.cmd("normal! G")

  -- Window-local options
  local w = state.win
  if w and vim.api.nvim_win_is_valid(w) then
    vim.wo[w].number = false
    vim.wo[w].relativenumber = false
    vim.wo[w].wrap = false
  end
end

-- ---------- job control ----------

function M.delete_buffer()
  if state.buf then
    vim.cmd("bd! ".. state.buf)
  end
end

function M.clean_stale_processes()
  local proc = state_module.get_running_process()
  if proc and proc.pid and proc.start_time then
    local same = require("vstools.build.utils.process_checker").is_same_process(proc.pid, proc.start_time)
    if same then
      vim.notify(("Killing stale process PID %d"):format(proc.pid))
      pcall(vim.uv.kill, proc.pid, 15)
    end
      state_module.clear_running_process()
    end
end

function M.stop()
  if state.job and state.job.kill then
    pcall(function() state.job:kill("sigterm") end)
  end
  state.job = nil
  state.pid = nil
  state_module.clear_running_process()
end

--- Run a command and stream output to the reusable buffer.
--- @param cmd string|string[] command or {cmd, args...}
--- @param opts table|nil { cwd=string }
function M.start(cmd, opts)
  opts = opts or {}
  local args = type(cmd) == "table" and cmd or { cmd }

  -- Show buffer (reuse) & clear content before new run
  ensure_buf()
  M.toggle_window({keep_open=true})
  if (type(opts.clear_buffer) == "boolean" and opts.clear_buffer) or opts.clear_buffer == nil then clear_buffer() end

  -- Print the command being executed at the top of the log
  local cmdline = format_cmd_line(args)
  append_chunk(("$ %s\n\n"):format(cmdline))
  if opts.cwd and opts.cwd ~= "" then
    append_chunk(("[cwd] %s\n"):format(opts.cwd))
  end

  -- Stop previous job if any
  M.stop()

  -- Start new job; schedule all buffer writes to avoid E5560
  local job = vim.system(args, {
    cwd = opts.cwd,
    text = false,  -- stream raw bytes
    stdout = function(_, data)
      if data then append_chunk(data) end
    end,
    stderr = function(_, data)
      if data then append_chunk(data) end
    end,
  }, vim.schedule_wrap(function(obj)
    append_chunk(("\n[process exited %d]\n"):format(obj.code))
    state.job = nil
    state.pid = nil
    state_module.clear_running_process()
    if opts.on_exit then
      opts.on_exit(obj.code)
    end
  end))

  state.job = job
  state.pid = job.pid
  state_module.save_running_process(job.pid, args, os.time())
end

return M
