local M = {}
local DEFAULT_FILE_MODE = 438

local function close_file(fd, filepath)
  local ok, err = vim.uv.fs_close(fd)
  if not ok then
    error("Failed to close file " .. filepath .. ": " .. tostring(err))
  end
end

---Read a file as lines using Neovim's libuv bindings.
---This avoids the Lua-Vimscript bridge used by vim.fn.readfile.
---@param filepath string Path to read
---@return string[] lines File contents split into lines
function M.read_lines(filepath)
  local stat, stat_err = vim.uv.fs_stat(filepath)
  if not stat then
    error("Failed to stat file " .. filepath .. ": " .. tostring(stat_err))
  end
  if stat.size == 0 then
    return {}
  end

  local fd, open_err = vim.uv.fs_open(filepath, "r", DEFAULT_FILE_MODE)
  if not fd then
    error("Failed to open file " .. filepath .. ": " .. tostring(open_err))
  end

  local data, read_err = vim.uv.fs_read(fd, stat.size, 0)
  close_file(fd, filepath)

  if not data then
    error("Failed to read file " .. filepath .. ": " .. tostring(read_err))
  end

  local lines = vim.split(data, "\n", { plain = true })
  if data:sub(-1) == "\n" then
    table.remove(lines)
  end
  for index, line in ipairs(lines) do
    lines[index] = line:gsub("\r$", "")
  end
  return lines
end

---Write lines to a file using Neovim's libuv bindings.
---This avoids the Lua-Vimscript bridge used by vim.fn.writefile.
---@param filepath string Path to write
---@param lines string[] Lines to write
function M.write_lines(filepath, lines)
  local fd, open_err = vim.uv.fs_open(filepath, "w", DEFAULT_FILE_MODE)
  if not fd then
    error("Failed to open file " .. filepath .. ": " .. tostring(open_err))
  end

  local data = table.concat(lines, "\n")
  if #lines > 0 then
    data = data .. "\n"
  end

  local bytes, write_err = vim.uv.fs_write(fd, data, 0)
  close_file(fd, filepath)

  if not bytes then
    error("Failed to write file " .. filepath .. ": " .. tostring(write_err))
  end
  if bytes ~= #data then
    error("Failed to write complete file " .. filepath)
  end
end

return M
