--- Go environment utilities for detecting GOPATH/GOROOT paths.
--- Used to prevent discovering tests in Go's stdlib or installed packages.

local path = require("neotest-golang.lib.path")

local M = {}

-- Cache for go env results (populated on first call)
-- @type {gopath: string, goroot: string} | nil
local go_env_cache = nil

--- Populate the go env cache (async version).
--- @async
--- @return {gopath: string, goroot: string}
local function get_go_env_async()
  if go_env_cache == nil then
    local async = require("neotest.async")
    local result = async.fn.system({ "go", "env", "GOPATH", "GOROOT" })
    local lines = vim.split(vim.trim(result or ""), "\n")
    go_env_cache = {
      gopath = path.normalize_path(lines[1] or ""),
      goroot = path.normalize_path(lines[2] or ""),
    }
  end
  return go_env_cache
end

--- Clear the cached go env results (useful for testing).
function M.clear_cache()
  go_env_cache = nil
end

--- Check if a path starts with a prefix and respects path boundaries.
--- Ensures the prefix match ends at a path separator or at the end of the path.
--- @param path_str string Path to check
--- @param prefix string Prefix to match against
--- @return boolean True if path is inside or equal to prefix with proper boundary
function M.is_path_inside(path_str, prefix)
  if prefix == "" then
    return false
  end
  -- Check if path starts with prefix
  if path_str:find(prefix, 1, true) ~= 1 then
    return false
  end
  -- Path must either equal prefix or have a separator after prefix
  local prefix_len = #prefix
  if #path_str == prefix_len then
    return true -- exact match
  end
  -- If prefix ends with separator, we already have a boundary
  local last_prefix_char = prefix:sub(-1)
  if last_prefix_char == "/" or last_prefix_char == "\\" then
    return true
  end
  -- Check if character after prefix is a path separator
  local next_char = path_str:sub(prefix_len + 1, prefix_len + 1)
  return next_char == "/" or next_char == "\\"
end

--- Check if a normalized path is inside GOPATH or GOROOT.
--- @param normalized_path string Normalized path to check
--- @param env {gopath: string, goroot: string} Go environment
--- @return boolean True if path is inside GOPATH or GOROOT
local function is_in_go_env(normalized_path, env)
  return M.is_path_inside(normalized_path, env.gopath)
    or M.is_path_inside(normalized_path, env.goroot)
end

--- Check if a path should be skipped because it's in GOPATH/GOROOT but cwd is not.
--- This prevents the adapter from discovering tests in Go's stdlib or installed packages
--- when the user is working in a different project.
--- @async
--- @param file_path string Path to check
--- @param cwd string|nil Current working directory
--- @return boolean True if the path should be skipped
function M.should_skip(file_path, cwd)
  if not cwd or not file_path then
    return false
  end
  local env = get_go_env_async()
  local norm_path = path.normalize_path(file_path)
  local norm_cwd = path.normalize_path(cwd)
  return not is_in_go_env(norm_cwd, env) and is_in_go_env(norm_path, env)
end

return M
