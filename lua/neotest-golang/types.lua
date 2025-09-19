--- Shared type definitions for neotest-golang
--- This module defines common types used throughout the adapter

local M = {}

---@alias TestStatus "passed" | "failed" | "skipped"
---@alias PositionType "dir" | "file" | "namespace" | "test"
---@alias RunnerType "go" | "gotestsum"

return M
