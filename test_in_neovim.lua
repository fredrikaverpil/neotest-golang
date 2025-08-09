-- Test gotestsum streaming within actual neovim environment
-- This should be run from within neovim, not headless

print("=== Testing Gotestsum Streaming in Neovim ===")

-- Check if neotest.lib.files is available
local ok, neotest_files = pcall(require, "neotest.lib.files")
print("neotest.lib.files available:", ok)

if ok then
  print("Available functions:", vim.inspect(vim.tbl_keys(neotest_files)))
  
  -- Test file streaming on a test file
  local test_file = "/tmp/test_streaming.json"
  
  -- Write some test data
  vim.fn.writefile({
    '{"Time":"2025-01-01T00:00:00Z","Action":"start","Package":"test"}',
    '{"Time":"2025-01-01T00:00:01Z","Action":"run","Package":"test","Test":"TestExample"}',
  }, test_file)
  
  -- Try to set up streaming
  local stream_lines, stop_stream = neotest_files.stream_lines(test_file)
  print("File streaming set up successfully")
  
  -- Try to read some lines
  local lines = stream_lines()
  print("Lines read:", vim.inspect(lines))
  
  -- Clean up
  stop_stream()
  vim.fn.delete(test_file)
else
  print("Error:", neotest_files)
end

print("=== Test Complete ===")