--- File system search operations for Go test discovery.

local lib_neotest = require("neotest.lib")
local scandir = require("plenary.scandir")

local logger = require("neotest-golang.lib.logging")
local path = require("neotest-golang.lib.path")

local M = {}

--- Cache for the primary root to prevent duplicate adapter trees.
--- When Neotest discovers a path under an already-known root, we reuse
--- the cached root instead of returning a nested module's root.
--- @type string|nil
local primary_root_cache = nil

--- Clear the primary root cache. Useful for testing or when changing projects.
function M.clear_root_cache()
  primary_root_cache = nil
  logger.debug("Cleared primary root cache")
end

--- Find a file upwards in the directory tree and return its path, if found.
--- @param filename string Name of file to search for
--- @param start_path string Starting directory or file path to search from
--- @return string|nil Full path to found file or nil if not found
function M.file_upwards(filename, start_path)
  -- Ensure start_path is a directory
  local start_dir = vim.fn.isdirectory(start_path) == 1 and start_path
    or path.get_directory(start_path)
  local home_dir = vim.fn.expand("$HOME")

  while start_dir ~= home_dir do
    logger.debug("Searching for " .. filename .. " in " .. start_dir)

    local try_path = start_dir .. path.os_path_sep .. filename
    if vim.fn.filereadable(try_path) == 1 then
      logger.info("Found " .. filename .. " at " .. try_path)
      return try_path
    end

    -- Go up one directory
    start_dir = path.get_directory(start_dir)
  end

  return nil
end

--- Find go.mod files downward to determine monorepo root.
--- @param folderpath string Directory path to search from
--- @return string|nil Root directory path or nil if no go.mod files found
function M.root_for_tests(folderpath)
  -- If we have a cached root and folderpath is under it, reuse the cached root.
  -- This prevents Neotest from creating duplicate adapter trees for nested
  -- Go modules (e.g., submodules with their own go.mod).
  if primary_root_cache then
    -- Normalize paths for comparison (ensure trailing slash for prefix match)
    local cached_prefix = primary_root_cache
    if not vim.endswith(cached_prefix, "/") then
      cached_prefix = cached_prefix .. "/"
    end
    if
      folderpath == primary_root_cache
      or vim.startswith(folderpath, cached_prefix)
    then
      logger.debug(
        "Reusing cached root: "
          .. primary_root_cache
          .. " for path: "
          .. folderpath
      )
      return primary_root_cache
    end
  end

  -- First, check for go.work or go.mod at cwd or above (stop at $HOME)
  local root =
    lib_neotest.files.match_root_pattern("go.work", "go.mod")(folderpath)
  if root then
    -- Cache the first discovered root
    if not primary_root_cache then
      primary_root_cache = root
      logger.debug("Cached primary root: " .. root)
    end
    return root
  end

  -- Second, find all go.mod files recursively (monorepo-style)
  local go_mod_files = scandir.scan_dir(
    folderpath,
    { search_pattern = "go%.mod$", respect_gitignore = true }
  )

  if #go_mod_files == 0 then
    -- No go.mod files found, no tests can run (disables adapter's test discovery)
    return nil
  elseif #go_mod_files == 1 then
    -- Single go.mod found, return its directory
    local found_root = path.get_directory(go_mod_files[1])
    if not primary_root_cache then
      primary_root_cache = found_root
      logger.debug("Cached primary root: " .. found_root)
    end
    return found_root
  else
    -- Multiple go.mod files (monorepo), return the search root
    if not primary_root_cache then
      primary_root_cache = folderpath
      logger.debug("Cached primary root: " .. folderpath)
    end
    return folderpath
  end
end

--- Get all *_test.go files in a directory recursively.
--- @param folderpath string Directory path to search in
--- @return string[] Array of full paths to test files
function M.go_test_filepaths(folderpath)
  local files = scandir.scan_dir(
    folderpath,
    { search_pattern = "_test%.go$", add_dirs = false }
  )
  return files
end

return M
