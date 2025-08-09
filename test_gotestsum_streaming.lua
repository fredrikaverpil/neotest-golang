-- Test script to debug gotestsum streaming
-- Run with: nvim --headless -c "luafile test_gotestsum_streaming.lua" -c "qa"

-- Set up neotest with gotestsum and streaming
require("neotest").setup({
  adapters = {
    require("neotest-golang")({
      runner = "gotestsum",
      stream_enabled = true,
    }),
  },
  log_level = vim.log.levels.WARN, -- Show our debug messages
})

print("=== Testing Gotestsum Streaming ===")
print("Running slow tests to observe streaming behavior...")

-- Run the streaming test directory
require("neotest").run.run("./tests/go/streaming_test")

-- Wait a bit to see the streaming in action
vim.wait(8000) -- Wait 8 seconds

print("=== Test Complete ===")
print("Check the neotest log for debug messages:")