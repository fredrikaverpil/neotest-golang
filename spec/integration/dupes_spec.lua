local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: unkeyed table test bug #452", function()
  it("should not false-positive on unique unkeyed test names", function()
    -- ===== ARRANGE =====
    local test_options = options.get()
    test_options.runner = "gotestsum"
    test_options.warn_test_name_dupes = true
    options.set(test_options)

    local position_id = vim.uv.cwd() .. "/tests/go/internal/dupes/dupes_test.go"
    position_id = path.normalize_path(position_id)

    -- Capture warnings
    local captured_warnings = {}
    local logger = require("neotest-golang.lib.logging")
    local original_warn = logger.warn
    logger.warn = function(msg, notify)
      table.insert(captured_warnings, { msg = msg, notify = notify })
      original_warn(msg, notify)
    end

    -- ===== ACT =====
    print("\n[TEST] Running unkeyed table test bug #452...")
    local got = integration.execute_adapter_direct(position_id)

    -- Restore original logger
    logger.warn = original_warn

    -- ===== ASSERT =====
    -- Check that the tree was discovered
    assert.truthy(got.tree, "Should have discovered test tree")
    assert.truthy(got.tree.data, "Should have tree data")

    -- Collect all node IDs from the tree
    local all_node_ids = {}
    local subtest_names = {}

    for _, node in got.tree:iter_nodes() do
      local pos = node:data()
      local id = pos.id
      table.insert(all_node_ids, id)

      -- Collect subtest names (the last part after ::)
      if pos.type == "test" and id:match("::") then
        local name = id:match("::([^:]+)$")
        if name then
          table.insert(subtest_names, name)
        end
      end
    end

    print("\n[DEBUG] All discovered node IDs:")
    for _, id in ipairs(all_node_ids) do
      print("  - " .. id)
    end

    print("\n[DEBUG] Subtest names:")
    for _, name in ipairs(subtest_names) do
      print("  - " .. name)
    end

    print("\n[DEBUG] Captured warnings:")
    for _, warning in ipairs(captured_warnings) do
      print("  - " .. warning.msg)
    end

    -- The test has two DIFFERENT test names: "xx empty string" and "yy empty string"
    -- There should be NO duplicate warning
    local found_dupe_warning = false
    for _, warning in ipairs(captured_warnings) do
      if string.find(warning.msg, "duplicate subtest names") then
        found_dupe_warning = true
        print(
          "\n[FAIL] False positive: Found duplicate warning for unique test names!"
        )
      end
    end

    assert.falsy(
      found_dupe_warning,
      "Should NOT warn about duplicates when test names are unique (bug #452)"
    )

    print(
      "\n[SUCCESS] No false positive - unique test names not flagged as duplicates!"
    )
  end)
end)
