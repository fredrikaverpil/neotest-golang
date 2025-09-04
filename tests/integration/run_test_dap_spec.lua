local _ = require("plenary")
local adapter = require("neotest-golang")
local nio = require("nio")
local options = require("neotest-golang.options")

local function normalize_windows_path(path)
  if vim.fn.has("win32") == 1 then
    return path:gsub("/", "\\")
  end
  return path
end

-- DAP path: when strategy="dap", adapter.results() skips processing and returns skipped for root pos
-- We do not require dap-go installed by using dap_mode="manual" which has no dependency

describe("Integration (DAP): results are skipped", function()
  it("returns skipped for DAP strategy without parsing output", function()
    options.set({ runner = "go", dap_mode = "manual" })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/position_discovery/positions_test.go"
    test_filepath = normalize_windows_path(test_filepath)

    -- Discover and pick a single test node
    local full_tree =
      nio.tests.with_async_context(adapter.discover_positions, test_filepath)
    local test_pos_id = test_filepath .. "::TestTopLevel"
    local test_node = full_tree:get_key(test_pos_id)
    assert.is_truthy(test_node)

    -- Build a DAP runspec for this test
    local run_spec = adapter.build_spec({ tree = test_node, strategy = "dap" })
    assert.is_truthy(run_spec)
    assert.is_truthy(run_spec.context.is_dap_active)

    -- results() should skip and mark the node skipped
    local results = nio.tests.with_async_context(
      adapter.results,
      run_spec,
      { code = 0, output = vim.fs.normalize(vim.fn.tempname()) },
      test_node
    )

    assert.is_truthy(results[test_pos_id])
    assert.are.equal("skipped", results[test_pos_id].status)
  end)
end)
