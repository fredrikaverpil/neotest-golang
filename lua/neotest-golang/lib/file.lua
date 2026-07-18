local M = {}
local DEFAULT_FILE_MODE = 438
local FILE_READ_FLAGS = vim.uv.constants.O_RDONLY
local FILE_WRITE_FLAGS = bit.bor(
  vim.uv.constants.O_WRONLY,
  vim.uv.constants.O_CREAT,
  vim.uv.constants.O_TRUNC
)

local function close_file(fd, filepath)
  local ok, err = vim.uv.fs_close(fd)
  if not ok then
    error("Failed to close file " .. filepath .. ": " .. tostring(err))
  end
end

local function data_to_lines(data)
  local lines = vim.split(data, "\n", { plain = true })
  if data:sub(-1) == "\n" then
    table.remove(lines)
  end
  for index, line in ipairs(lines) do
    lines[index] = line:gsub("\r$", "")
  end
  return lines
end

local function lines_to_data(lines)
  local data = table.concat(lines, "\n")
  if #lines > 0 then
    data = data .. "\n"
  end
  return data
end

local function close_file_async(fd, filepath)
  local async = require("neotest.async")
  local err = async.uv.fs_close(fd)
  if err then
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

  local fd, open_err =
    vim.uv.fs_open(filepath, FILE_READ_FLAGS, DEFAULT_FILE_MODE)
  if not fd then
    error("Failed to open file " .. filepath .. ": " .. tostring(open_err))
  end

  local data, read_err = vim.uv.fs_read(fd, stat.size, 0)
  close_file(fd, filepath)

  if not data then
    error("Failed to read file " .. filepath .. ": " .. tostring(read_err))
  end

  return data_to_lines(data)
end

---Write lines to a file using Neovim's libuv bindings.
---This avoids the Lua-Vimscript bridge used by vim.fn.writefile.
---@param filepath string Path to write
---@param lines string[] Lines to write
function M.write_lines(filepath, lines)
  local fd, open_err =
    vim.uv.fs_open(filepath, FILE_WRITE_FLAGS, DEFAULT_FILE_MODE)
  if not fd then
    error("Failed to open file " .. filepath .. ": " .. tostring(open_err))
  end

  local data = lines_to_data(lines)

  local bytes, write_err = vim.uv.fs_write(fd, data, 0)
  close_file(fd, filepath)

  if not bytes then
    error("Failed to write file " .. filepath .. ": " .. tostring(write_err))
  end
  if bytes ~= #data then
    error("Failed to write complete file " .. filepath)
  end
end

---Read a file as lines using nvim-nio's coroutine-friendly libuv bindings.
---This avoids the Lua-Vimscript bridge used by vim.fn.readfile while preserving
---non-blocking behavior in async contexts.
---@async
---@param filepath string Path to read
---@return string[] lines File contents split into lines
function M.read_lines_async(filepath)
  local async = require("neotest.async")

  local stat_err, stat = async.uv.fs_stat(filepath)
  if stat_err then
    error("Failed to stat file " .. filepath .. ": " .. tostring(stat_err))
  end
  if not stat then
    error("Failed to stat file " .. filepath)
  end
  local stat_size = stat["size"]
  if stat_size == 0 then
    return {}
  end

  local open_err, fd =
    async.uv.fs_open(filepath, FILE_READ_FLAGS, DEFAULT_FILE_MODE)
  if open_err then
    error("Failed to open file " .. filepath .. ": " .. tostring(open_err))
  end
  if not fd then
    error("Failed to open file " .. filepath)
  end

  local read_err, data = async.uv.fs_read(fd, stat_size, 0)
  close_file_async(fd, filepath)

  if read_err then
    error("Failed to read file " .. filepath .. ": " .. tostring(read_err))
  end
  if not data then
    error("Failed to read file " .. filepath)
  end

  return data_to_lines(data)
end

---Write lines to a file using nvim-nio's coroutine-friendly libuv bindings.
---This avoids the Lua-Vimscript bridge used by vim.fn.writefile while preserving
---non-blocking behavior in async contexts.
---@async
---@param filepath string Path to write
---@param lines string[] Lines to write
function M.write_lines_async(filepath, lines)
  local async = require("neotest.async")

  local open_err, fd =
    async.uv.fs_open(filepath, FILE_WRITE_FLAGS, DEFAULT_FILE_MODE)
  if open_err then
    error("Failed to open file " .. filepath .. ": " .. tostring(open_err))
  end
  if not fd then
    error("Failed to open file " .. filepath)
  end

  local data = lines_to_data(lines)

  local write_err, bytes = async.uv.fs_write(fd, data, 0)
  close_file_async(fd, filepath)

  if write_err then
    error("Failed to write file " .. filepath .. ": " .. tostring(write_err))
  end
  if not bytes then
    error("Failed to write file " .. filepath)
  end
  if bytes ~= #data then
    error("Failed to write complete file " .. filepath)
  end
end

return M
