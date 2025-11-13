local M = {}

-- cross-platform process start time fetchers --------------------

local function get_process_start_time_unix(pid)
  local out = vim.fn.system({ "ps", "-o", "lstart=", "-p", tostring(pid) })
  if not out or out == "" then
    return nil
  end
  local t = vim.trim(out)
  local epoch = vim.fn.strptime("%c", t)
  return epoch > 0 and epoch or nil
end

local function get_process_start_time_windows(pid)
  local ps_cmd = string.format(
    "(Get-Process -Id %d).StartTime.ToUniversalTime().ToFileTimeUtc()",
    pid
  )
  local out = vim.fn.system({ "powershell", "-NoProfile", "-Command", ps_cmd })
  if not out or out == "" then
    return nil
  end
  -- Windows FILETIME is 100-nanosecond intervals since 1601-01-01
  local ft = tonumber((out:gsub("%s+", "")))
  if not ft then
    return nil
  end
  -- convert FILETIME to Unix epoch
  return math.floor(ft / 10000000 - 11644473600)
end

function M.get_process_start_time(pid)
  if vim.fn.has("win32") == 1 then
    return get_process_start_time_windows(pid)
  else
    return get_process_start_time_unix(pid)
  end
end

-- verification --------------------------------------------------

function M.is_same_process(pid, saved_start_time)
  if not (pid and saved_start_time) then
    return false
  end
  local actual = M.get_process_start_time(pid)
  if not actual then
    return false
  end
  -- allow small rounding difference
  return math.abs(actual - saved_start_time) < 10
end

return M
