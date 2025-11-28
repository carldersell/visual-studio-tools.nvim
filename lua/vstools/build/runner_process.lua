local state_module = require("vstools.startup.state")

local M = {}
local api = vim.api

-- ---------- Config helpers ----------
local function resolve_size(value, max)
  if type(value) == "number" then
    return value <= 1 and math.floor(max * value) or math.floor(value)
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

-- ---------- State ----------
local state = {
  buf_system   = nil,
  buf_terminal = nil,
  win          = nil,
  mode         = "system",
  job          = nil,
  pid          = nil,
  partial      = "",
  name_system  = "VSTools Build",
  name_terminal= "VSTools Terminal",
}

function M.get_state()
  return state
end

-- ---------- Buffer helpers ----------
local function ensure_system_buf()
  if state.buf_system and api.nvim_buf_is_valid(state.buf_system) then
    return state.buf_system
  end

  local buf = api.nvim_create_buf(false, true)
  state.buf_system = buf

  vim.bo[buf].buftype   = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile  = false
  vim.bo[buf].filetype  = "vstoolslog"
  api.nvim_buf_set_name(buf, state.name_system)

  -- Start empty
  api.nvim_buf_set_lines(buf, 0, -1, false, {})
  return buf
end

local function ensure_terminal_buf()
  if state.buf_terminal and api.nvim_buf_is_valid(state.buf_terminal) then
    return state.buf_terminal
  end

  local buf = api.nvim_create_buf(false, false)  -- NOT scratch since terminal requires a normal buffer
  state.buf_terminal = buf

  vim.bo[buf].buftype   = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile  = false
  vim.bo[buf].filetype  = "vstoolsterm"
  api.nvim_buf_set_name(buf, state.name_terminal)

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

local function close_window_for_buf(buf)
  local win = find_window_for_buf(buf)
  if win then
    pcall(api.nvim_win_close, win, true)
    return true
  end
  return false
end

local function clear_buffer(buf)
  if not (buf and api.nvim_buf_is_valid(buf)) then return end
  api.nvim_buf_set_lines(buf, 0, -1, false, {})
  state.partial = ""
end

-- Append text in chunks, handling partial lines between chunks.
local function _append_chunk(chunk)
  local buf = (state.mode == "system") and ensure_system_buf() or ensure_terminal_buf()
  local data = state.partial .. chunk
  local parts = vim.split(data, "\n", { plain = true })
  state.partial = table.remove(parts) or ""

  if #parts > 0 then
    local last = api.nvim_buf_line_count(buf)
    api.nvim_buf_set_lines(buf, last, last, false, parts)
  end

  -- Auto-scroll if visible
  local win = find_window_for_buf(buf)
  if win then
    local lastline = api.nvim_buf_line_count(buf)
    api.nvim_win_set_cursor(win, { lastline, 0 })
  end
end

-- Schedule buffer mutations to avoid E5560 (fast event context)
local append_chunk = vim.schedule_wrap(_append_chunk)

-- Remove ANSI escape sequences + normalize CRLF/CR
local function normalize_output(data)
  if not data or data == "" then return data end

  -- Remove OSC sequences: ESC ] ... BEL
  data = data:gsub("\27%].-\7", "")

  -- Remove cursor movement / screen control: ESC [ … H, A, B, C, D, J, K, etc.
  data = data:gsub("\27%[[0-9;]*[HfABCDJKsu]", "")

  -- Remove DEC private modes: ESC [ ? … h / l   (cursor show/hide, mouse modes, etc.)
  data = data:gsub("\27%[%?%d+[hl]", "")

  -- Remove CSI sequences: ESC [ ... command
  data = data:gsub("\27%[[0-9;]*[A-Za-z]", "")

  -- Remove single ESC commands: ESC + any byte in @-~
  data = data:gsub("\27[@-~]", "")

  -- Normalize Windows CRLF and lone CR
  data = data:gsub("\r\n", "\n")
  data = data:gsub("\r", "\n")

  return data
end

-- ---------- Window / toggle ----------

-- Create (or jump to) a floating window showing the build buffer,
-- honoring width/height/border from config.

function M.toggle_window(opts)
  opts = opts or {}
  local mode = opts.mode or state.mode
  local buf = opts.buf
  if buf == nil or buf < 0 then
    buf = (mode == "system")
      and ensure_system_buf()
      or ensure_terminal_buf()
  end

  -- Case 1: explicit close request
  if opts.keep_open == false then
    close_window_for_buf(buf)
    return
  end

  local existing = find_window_for_buf(buf)

  -- Case 2: window already open AND user used toggle_window()
  if existing and not opts.keep_open then
    close_window_for_buf(buf)
    return
  end

  -- Case 3: window is already open → DO NOT steal focus
  if existing then
    -- If cursor is inside window, scroll to bottom
    local curwin = api.nvim_get_current_win()
    if curwin == existing then
      vim.cmd("normal! G")
    end
    return
  end

  -- Otherwise open (or focus) it using current config
  local cfg = get_term_cfg()
  local width  = math.min(cfg.width, vim.o.columns - 2)
  local height = math.min(cfg.height, vim.o.lines - 2)
  local row = math.max(1, math.floor((vim.o.lines - height) / 2))
  local col = math.max(1, math.floor((vim.o.columns - width) / 2))
  local focus = opts.focus ~= false

  state.win = api.nvim_open_win(buf, focus, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = cfg.border,
    title = (mode == "system") and " Build Log " or " Terminal Output ",
    title_pos = "center",
    noautocmd = true,
  })

  vim.wo[state.win].winhl = "FloatTitle:TelescopeBorder,NormalFloat:TelescopeNormal"
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].wrap = false
  if focus then vim.cmd("normal! G") end

end

-- ---------- Job control ----------
function M.delete_buffer()
  if state.buf_system then vim.cmd("bd! " .. state.buf_system) end
  if state.buf_terminal then vim.cmd("bd! " .. state.buf_terminal) end
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
  if state.pid then
    pcall(vim.uv.kill, state.pid)
  end
  state.job = nil
  state.pid = nil
  state_module.clear_running_process()
end

--- Run a command (System or PTY) and stream output to reusable buffer
--- @param cmd string|string[] command or {cmd, args...}
--- @param opts table|nil { cwd=string, run_in_terminal=boolean, keep_open=boolean, focus=boolean, clear_buffer=boolean, on_exit=function }
function M.start(cmd, opts)
  opts = opts or {}
  local args = (type(cmd) == "table") and cmd or { cmd }

  -- Check working directory
  if opts.cwd == nil then
    opts.cwd = vim.uv.cwd()
  end

  -- detect mode
  local new_mode = opts.run_in_terminal and "terminal" or "system"

  local was_focused = true
  if opts.focus == false then
    -- Check if old window is focused
    local buf
    if state.mode == "system" then
      buf = state.buf_system
    else
      buf = state.buf_terminal
    end
    local buf_win = buf and find_window_for_buf(buf) or nil
    local cur_win = api.nvim_get_current_win()
    was_focused = buf_win ~= nil and cur_win == buf_win
  end
  -- Check window state and toggle off if we change mode
  local was_open = state.win ~= nil and api.nvim_win_is_valid(state.win)
  local is_open = was_open
  if new_mode ~= state.mode then
    -- Close current window
    M.toggle_window({ keep_open = false })
    is_open = false
  end
  state.mode = new_mode

  local open_window = opts.keep_open ~= false
  if state.win == nil or open_window or is_open ~= was_open then
    M.toggle_window({ keep_open = true, focus = was_focused })
  end

  if opts.clear_buffer ~= false then
    if state.mode == "system" then
      clear_buffer(state.buf_system)
    else
      clear_buffer(state.buf_terminal)
    end
  end

  -- Stop previous job
  M.stop()

  -- Print command
  local formatted = table.concat(args, " ")
  append_chunk("$ " .. formatted .. "\n")

  --------------------------------------------------------
  -- TERMINAL (PTY) MODE
  --------------------------------------------------------
  if state.mode == "terminal" then
    local job_id = vim.fn.jobstart(args, {
      cwd = opts.cwd,
      pty = true,          -- ← PTY mode (safe!)
      on_stdout = function(_, data)
        for _, line in ipairs(data) do
          append_chunk(normalize_output(line) .. "")
        end
      end,
      clear_env = true,
      env = opts.env,
      on_exit = function(_, code)
        append_chunk("\n[Process exited " .. code .. "]\n")
        state.job = nil
        state.pid = nil
        state_module.clear_running_process()
        if code == 0 then
          if opts.on_exit then opts.on_exit(code) end
        else
          M.toggle_window({ keep_open = true })
        end
      end,
    })

    if job_id > 0 then
      state.job = job_id
      state.pid = vim.fn.jobpid(job_id)
      state_module.save_running_process(state.pid, args, os.time())
    else
      vim.notify("Failed to start terminal job", vim.log.levels.ERROR)
    end

    return
  end

  --------------------------------------------------------
  -- SYSTEM MODE
  --------------------------------------------------------

  local job = vim.system(args, {
    cwd = opts.cwd,
    clear_env = true,
    env = opts.env,
    text = false,
    stdout = function(_, d) if d then append_chunk(normalize_output(d)) end end,
    stderr = function(_, d) if d then append_chunk(normalize_output(d)) end end,
  }, vim.schedule_wrap(function(obj)
    append_chunk("\n[process exited " .. obj.code .. "]\n")
    state.job = nil
    state.pid = nil
    state_module.clear_running_process()
    if obj.code == 0 then
      if opts.on_exit then opts.on_exit(obj.code) end
    else
      M.toggle_window({ keep_open = true })
    end
  end))

  state.job = job
  state.pid = job.pid
  state_module.save_running_process(job.pid, args, os.time())
end

return M
