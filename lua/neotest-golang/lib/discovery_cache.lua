--- Discovery cache to prevent redundant test discovery when buffers are opened rapidly.
--- This addresses issues like DAP-UI triggering multiple discoveries.

local M = {}

--- Cache structure: { [file_path] = { tree = neotest.Tree, mtime = number } }
--- @type table<string, {tree: neotest.Tree|nil, mtime: number}>
local cache = {}

--- Get the modification time of a file.
--- @param file_path string Absolute file path
--- @return number|nil Modification time in seconds, or nil if file doesn't exist
local function get_mtime(file_path)
  local stat = vim.uv.fs_stat(file_path)
  if stat then
    return stat.mtime.sec
  end
  return nil
end

--- Get cached discovery result if valid.
--- Returns cached tree if file hasn't been modified since last discovery.
--- @param file_path string Absolute file path
--- @return neotest.Tree|nil Cached tree if valid, nil if cache miss or stale
function M.get(file_path)
  local entry = cache[file_path]
  if not entry then
    return nil
  end

  local current_mtime = get_mtime(file_path)
  if not current_mtime then
    cache[file_path] = nil
    return nil
  end

  if current_mtime == entry.mtime then
    return entry.tree
  end

  cache[file_path] = nil
  return nil
end

--- Store discovery result in cache.
--- @param file_path string Absolute file path
--- @param tree neotest.Tree|nil Discovered test tree
function M.set(file_path, tree)
  local mtime = get_mtime(file_path)
  if mtime then
    cache[file_path] = { tree = tree, mtime = mtime }
  end
end

--- Invalidate cache for a specific file.
--- @param file_path string Absolute file path
function M.invalidate(file_path)
  cache[file_path] = nil
end

--- Clear the entire cache.
function M.clear()
  cache = {}
end

--- Get cache statistics (for debugging).
--- @return {size: number, files: string[]}
function M.stats()
  local files = {}
  for file_path, _ in pairs(cache) do
    table.insert(files, file_path)
  end
  return { size = #files, files = files }
end

return M
