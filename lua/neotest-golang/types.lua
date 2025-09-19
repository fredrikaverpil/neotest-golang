--- Shared type definitions for neotest-golang
--- This module defines common types used throughout the adapter

local M = {}

---@class GoListItem
---@field ImportPath string The import path of the Go package
---@field Dir string The directory containing the package source
---@field Name string The package name
---@field Module? table Module information if part of a Go module
---@field Root? string The root directory of the module
---@field GoMod? string Path to go.mod file

---@class DapConfig
---@field type string DAP adapter type (e.g., "go")
---@field request string DAP request type (e.g., "launch")
---@field mode string DAP mode (e.g., "test", "debug")
---@field program string Path to program to debug
---@field args? string[] Optional arguments to pass to the program
---@field env? table<string, string> Optional environment variables

---@class TestCommand
---@field cmd string[] The command to execute as an array of strings
---@field cwd string The working directory for the command
---@field env? table<string, string> Optional environment variables

---@class FileInfo
---@field path string Absolute file path
---@field exists boolean Whether the file exists
---@field readable boolean Whether the file is readable
---@field size? number File size in bytes if available

---@class PackageInfo
---@field import_path string The Go import path
---@field directory string The package directory
---@field name string The package name
---@field test_files string[] List of test files in the package

---@class TestPosition
---@field id string Neotest position ID
---@field name string Test name as it appears in Go
---@field path string File path containing the test
---@field package_path string Directory containing the package
---@field line_number number Line number where test is defined

---@alias TestStatus "passed" | "failed" | "skipped"
---@alias PositionType "dir" | "file" | "namespace" | "test"
---@alias RunnerType "go" | "gotestsum"

return M
