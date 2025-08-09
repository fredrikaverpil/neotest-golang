--- Type definitions for neotest-golang
--- This file provides type annotations for better LSP support

---@meta

---@class neotest.Position
---@field id string The unique identifier for this position
---@field path string The file path
---@field name string The name of the test or namespace
---@field type string The type: "dir" | "file" | "namespace" | "test"
---@field range number[]|nil The range in the file

---@class neotest.Tree
---@field _children table|nil Internal children field
---@field _nodes table|nil Internal nodes table
---@field _parent neotest.Tree|nil Internal parent reference
---@field children fun(self: neotest.Tree): neotest.Tree[] Get children
---@field data fun(self: neotest.Tree): neotest.Position Get position data
---@field iter_nodes fun(self: neotest.Tree): fun(): neotest.Tree Iterator over all nodes

---@class neotest.RunSpec
---@field command string[] The command to run
---@field cwd string|nil The working directory
---@field env table<string, string>|nil Environment variables
---@field context RunspecContext|nil Context data
---@field strategy table|nil DAP strategy configuration
---@field stream fun(data: fun(): string[]): fun(): table<string, neotest.Result>|nil Stream function

---@class RunspecContext
---@field pos_id string Position ID
---@field golist_data table Go list data
---@field errors table|nil Any errors
---@field test_output_json_filepath string|nil JSON output file path
---@field is_dap_active boolean|nil Whether DAP is active
---@field is_streaming_active boolean|nil Whether streaming is active
---@field process_test_results boolean|nil Whether to process test results

---@class neotest.Result
---@field status string "passed" | "failed" | "skipped" | "running"
---@field short string|nil Short output
---@field errors neotest.Error[]|nil Errors if failed

---@class neotest.Error
---@field message string Error message
---@field line number|nil Line number (0-based)

return {}
