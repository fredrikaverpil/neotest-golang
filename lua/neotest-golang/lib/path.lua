--- Centralized path utilities for cross-platform file path operations.
--- Handles Windows drive letters, UNC paths, backslashes, and POSIX paths uniformly.

local M = {}

-- Platform-specific path separator
M.os_path_sep = package.config:sub(1, 1) -- "/" on Unix, "\" on Windows

-- Cache for go env results (populated on first call)
-- @type {gopath: string, goroot: string} | nil
local go_env_cache = nil

--- Populate the go env cache (sync version).
--- @return {gopath: string, goroot: string}
local function get_go_env()
  if go_env_cache == nil then
    local result = vim.fn.system({ "go", "env", "GOPATH", "GOROOT" })
    local lines = vim.split(vim.trim(result or ""), "\n")
    go_env_cache = {
      gopath = M.normalize_path(lines[1] or ""),
      goroot = M.normalize_path(lines[2] or ""),
    }
  end
  return go_env_cache
end

--- Populate the go env cache (async version).
--- @async
--- @return {gopath: string, goroot: string}
local function get_go_env_async()
  if go_env_cache == nil then
    local async = require("neotest.async")
    local result = async.fn.system({ "go", "env", "GOPATH", "GOROOT" })
    local lines = vim.split(vim.trim(result or ""), "\n")
    go_env_cache = {
      gopath = M.normalize_path(lines[1] or ""),
      goroot = M.normalize_path(lines[2] or ""),
    }
  end
  return go_env_cache
end

--- Clear the cached go env results (useful for testing).
function M.clear_go_env_cache()
  go_env_cache = nil
end

--- Check if a normalized path starts with a go env prefix (gopath or goroot).
--- @param normalized_path string Normalized path to check
--- @param env {gopath: string, goroot: string} Go environment
--- @return boolean True if path is inside GOPATH or GOROOT
local function is_in_go_env(normalized_path, env)
  if env.gopath ~= "" and normalized_path:find(env.gopath, 1, true) == 1 then
    return true
  end
  if env.goroot ~= "" and normalized_path:find(env.goroot, 1, true) == 1 then
    return true
  end
  return false
end

--- Check if a path should be skipped because it's in GOPATH/GOROOT but cwd is not.
--- This prevents the adapter from discovering tests in Go's stdlib or installed packages
--- when the user is working in a different project.
--- @param path string Path to check
--- @param cwd string|nil Current working directory
--- @return boolean True if the path should be skipped
function M.must_skip_path(path, cwd)
  if not cwd or not path then
    return false
  end
  local env = get_go_env()
  local norm_path = M.normalize_path(path)
  local norm_cwd = M.normalize_path(cwd)
  return not is_in_go_env(norm_cwd, env) and is_in_go_env(norm_path, env)
end

--- Check if a path should be skipped (async version).
--- @async
--- @param path string Path to check
--- @param cwd string|nil Current working directory
--- @return boolean True if the path should be skipped
function M.must_skip_path_async(path, cwd)
  if not cwd or not path then
    return false
  end
  local env = get_go_env_async()
  local norm_path = M.normalize_path(path)
  local norm_cwd = M.normalize_path(cwd)
  return not is_in_go_env(norm_cwd, env) and is_in_go_env(norm_path, env)
end

--- Get directory part of a path (Windows-safe replacement for vim.fn.fnamemodify(path, ":h")).
--- Preserves original path separators to avoid Windows path breakage.
--- @param path string File or directory path
--- @return string Directory part of the path
function M.get_directory(path)
  if not path or path == "" then
    return "." -- Return current directory for empty/nil paths (matches vim.fn.fnamemodify behavior)
  end

  -- Handle edge cases
  if path == "/" or path == "\\" then
    return path
  end

  -- Find the last separator (either / or \)
  local last_sep_pos = 0
  for i = #path, 1, -1 do
    local char = path:sub(i, i)
    if char == "/" or char == "\\" then
      last_sep_pos = i
      break
    end
  end

  if last_sep_pos == 0 then
    -- No separator found, it's just a filename - return current directory (matches vim.fn.fnamemodify behavior)
    return "."
  elseif last_sep_pos == 1 then
    -- Root directory
    return path:sub(1, 1)
  else
    -- Return everything before the last separator
    return path:sub(1, last_sep_pos - 1)
  end
end

--- Get filename part of a path (Windows-safe replacement for vim.fn.fnamemodify(path, ":t")).
--- Preserves original path separators to avoid Windows path breakage.
--- @param path string File or directory path
--- @return string Filename part of the path
function M.get_filename(path)
  if not path or path == "" then
    return ""
  end

  -- Find the last separator (either / or \)
  local last_sep_pos = 0
  for i = #path, 1, -1 do
    local char = path:sub(i, i)
    if char == "/" or char == "\\" then
      last_sep_pos = i
      break
    end
  end

  if last_sep_pos == 0 then
    -- No separator found, return the whole string
    return path
  else
    -- Return everything after the last separator
    return path:sub(last_sep_pos + 1)
  end
end

--- Platform-conditional filename extraction for optimal performance.
--- Uses fast vim.fs.basename for POSIX-style paths, safe get_filename for Windows-style paths.
--- @param path string File path to extract filename from
--- @return string|nil Filename or nil if path is invalid
function M.get_filename_fast(path)
  if not path or type(path) ~= "string" or path == "" then
    return nil
  end

  -- Detect Windows-style paths (drive letters, UNC paths, backslashes)
  local is_windows_path = path:match("^[A-Za-z]:") -- Drive letter
    or path:match("^\\\\") -- UNC path
    or path:match("\\") -- Contains backslashes

  if is_windows_path then
    -- Windows-style path: Use our Windows-safe implementation
    return M.get_filename(path)
  else
    -- POSIX-style path: Use fast built-in C function
    return vim.fs.basename(path)
  end
end

--- Extract file path from Neotest position ID (handles Windows drive letters correctly).
--- @param pos_id string Position ID like "/path/to/file_test.go::TestName" or "D:\\path\\file_test.go::TestName"
--- @return string|nil File path part before "::" or nil if not found
function M.extract_file_path_from_pos_id(pos_id)
  if not pos_id or type(pos_id) ~= "string" or pos_id == "" then
    return nil
  end

  -- Find the first occurrence of "::" (which separates file path from test path)
  local separator_pos = pos_id:find("::")
  if separator_pos then
    return pos_id:sub(1, separator_pos - 1)
  end

  -- If no "::" found, treat the entire string as the file path
  return pos_id
end

--- Normalize path separators for cross-platform compatibility.
--- Converts forward slashes to backslashes on Windows, leaves unchanged on POSIX.
--- @param path string Path to normalize
--- @return string Normalized path
function M.normalize_path(path)
  if not path or type(path) ~= "string" then
    return ""
  end

  if vim.fn.has("win32") == 1 then
    local normalized_path, _ = path:gsub("/", "\\")
    return normalized_path
  end
  return path
end

--- Detect if a path uses Windows-style formatting.
--- @param path string Path to analyze
--- @return boolean True if path appears to be Windows-style
function M.is_windows_path(path)
  if not path or type(path) ~= "string" then
    return false
  end

  return path:match("^[A-Za-z]:") -- Drive letter
    or path:match("^\\\\") -- UNC path
    or path:match("\\") -- Contains backslashes
end

--- Detect UNC (Universal Naming Convention) paths.
--- @param path string Path to analyze
--- @return boolean True if path is a UNC path
function M.is_unc_path(path)
  if not path or type(path) ~= "string" then
    return false
  end

  return path:match("^\\\\") ~= nil
end

--- Validate Windows drive letter format.
--- @param path string Path to validate
--- @return boolean True if path has valid Windows drive letter
function M.has_drive_letter(path)
  if not path or type(path) ~= "string" then
    return false
  end

  return path:match("^[A-Za-z]:") ~= nil
end

return M
