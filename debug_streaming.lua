-- Direct debug test for gotestsum streaming
print("=== Direct Gotestsum Streaming Debug ===")

-- Add current directory to package path
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

-- Set up options
local options = require("neotest-golang.options")
options.setup({
  runner = "gotestsum",
  stream_enabled = true,
})

print("Runner:", options.get().runner)
print("Stream enabled:", options.get().stream_enabled)

-- Test streaming support
local streaming = require("neotest-golang.lib.streaming")
local supported = streaming.is_streaming_supported(nil, "gotestsum")
print("Streaming supported for gotestsum:", supported)

-- Test command generation
local cmd = require("neotest-golang.lib.cmd")
local test_args = { "./tests/go/streaming_test" }
local test_cmd, json_filepath = cmd.test_command(test_args, false)
print("Generated command:", table.concat(test_cmd, " "))
print("JSON filepath:", json_filepath)

-- Test if we can access neotest.lib.files
local ok, neotest_files = pcall(require, "neotest.lib.files")
print("neotest.lib.files available:", ok)
if not ok then
  print("Error:", neotest_files)
end

print("=== Debug Complete ===")