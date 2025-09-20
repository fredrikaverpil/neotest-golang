--- Shared type definitions for neotest-golang

--- @class RunspecContext
--- @field pos_id string Neotest tree position id.
--- @field golist_data table<string, string> The 'go list' JSON data (lua table).
--- @field errors? table<string> Non-gotest errors to show in the final output.
--- @field is_dap_active boolean? If true, parsing of test output will occur.
--- @field test_output_json_filepath? string Gotestsum JSON filepath.
--- @field stop_filestream fun() Stops the stream of test output.
--- @field process_test_results? boolean Used in test.lua specifically

--- @class GoListItem
--- @field ImportPath string The import path of the Go package
--- @field Dir string The directory containing the package source
--- @field Name string The package name
--- @field Module? table Module information if part of a Go module
--- @field Root? string The root directory of the module
--- @field GoMod? string Path to go.mod file
--- @field TestGoFiles? string[] List of test files in the package
--- @field XTestGoFiles? string[] List of external test files in the package

--- Internal test metadata, required for processing.
--- @class TestMetadata
--- @field position_id? string The neotest position ID for this test
--- @field output_parts string[] Raw output parts collected during streaming
--- @field output_path? string Path to the finalized output file
--- @field state? "streaming"|"streamed"|"finalized" State of the test entry's processing

--- The accumulated test data. This holds both the Neotest result for the test and also internal metadata.
--- @class TestEntry
--- @field result neotest.Result The neotest result data
--- @field metadata TestMetadata Custom metadata for processing

--- The `go test -json` event structure.
--- @class GoTestEvent
--- @field Time? string ISO 8601 timestamp when the event occurred
--- @field Action "start"|"run"|"output"|"build-output"|"skip"|"fail"|"pass" Test action
--- @field Package? string Package name being tested
--- @field Test? string Test name (present when Action relates to a specific test)
--- @field Elapsed? number Time elapsed in seconds
--- @field Output? string Output text (present when Action is "output")

local M = {}

return M
