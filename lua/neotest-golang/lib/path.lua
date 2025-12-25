--- Centralized path utilities for cross-platform file path operations.
--- Handles Windows drive letters, UNC paths, backslashes, and POSIX paths uniformly.

local M = {}

-- Platform-specific path separator
M.os_path_sep = package.config:sub(1, 1) -- "/" on Unix, "\" on Windows

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

--- Check if a glob pattern is an absolute path pattern.
--- @param pattern string The glob pattern to check
--- @return boolean True if the pattern is absolute (starts with / or drive letter)
function M.is_absolute_pattern(pattern)
  if not pattern or type(pattern) ~= "string" or pattern == "" then
    return false
  end

  -- Unix absolute path or Windows drive letter
  return pattern:match("^/") ~= nil or pattern:match("^[A-Za-z]:[/\\]") ~= nil
end

--- Match a path against a glob pattern using vim.glob.to_lpeg.
--- Patterns follow the LSP 3.17 glob specification:
--- - `*` matches zero or more characters in a path segment
--- - `?` matches a single character in a path segment
--- - `**` matches any number of path segments, including none
--- - `{}` for grouping conditions (e.g., `**/*.{ts,js}`)
--- - `[]` for character ranges (e.g., `example.[0-9]`)
--- @param path string The path to match against
--- @param pattern string The glob pattern
--- @return boolean True if the path matches the pattern
function M.matches_glob_pattern(path, pattern)
  if not path or path == "" or not pattern or pattern == "" then
    return false
  end

  -- Normalize path to use forward slashes for matching (glob patterns use /)
  local normalized_path = path:gsub("\\", "/")

  -- Compile glob pattern to lpeg
  local ok, lpeg_pattern = pcall(vim.glob.to_lpeg, pattern)
  if not ok or not lpeg_pattern then
    -- Invalid pattern, return false
    return false
  end

  -- Match returns position (number) on success, nil on failure
  return lpeg_pattern:match(normalized_path) ~= nil
end

return M
