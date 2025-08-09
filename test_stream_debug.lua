-- Debug script to test if streaming is set up correctly
-- Run this in Neovim with :luafile test_stream_debug.lua

local function check_streaming()
  -- Check current configuration
  local opts = require("neotest-golang.options").get()
  print("Current configuration:")
  print("  runner: " .. tostring(opts.runner))
  print("  stream_enabled: " .. tostring(opts.stream_enabled))
  print("  log_level: " .. tostring(opts.log_level))

  -- Try to build a runspec for the streaming test file
  local adapter = require("neotest-golang")

  local test_file = vim.fn.expand("%:p")
  if not test_file:match("streaming_test%.go$") then
    test_file = vim.fn.getcwd()
      .. "/tests/go/internal/streaming/streaming_test.go"
  end

  print("\nTest file: " .. test_file)

  -- Create a mock tree
  local tree = {
    data = function()
      return {
        id = test_file,
        type = "file",
        path = test_file,
        name = "streaming_test.go",
      }
    end,
    children = function()
      return {}
    end,
    iter_nodes = function()
      return function() end
    end,
  }

  -- Build runspec
  local args = {
    tree = tree,
    strategy = "integrated",
  }

  local runspec = adapter.build_spec(args)

  if runspec then
    print("\nRunspec built successfully:")
    print("  Has stream function: " .. tostring(runspec.stream ~= nil))
    print("  Command: " .. vim.inspect(runspec.command))

    if runspec.stream then
      print("\n✅ Streaming is configured!")
    else
      print("\n❌ Streaming is NOT configured!")
    end
  else
    print("\n❌ Failed to build runspec")
  end

  print("\nTo check logs, run:")
  print(":exe 'edit' stdpath('log').'/neotest-golang.log'")
end

check_streaming()

