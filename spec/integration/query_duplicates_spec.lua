local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: query duplicates test", function()
  it("verifies no duplicate sub-tests in tree (bug fixed)", function()
    -- ===== ARRANGE =====
    local test_options = options.get()
    test_options.runner = "gotestsum"
    options.set(test_options)

    local position_id = vim.uv.cwd()
      .. "/tests/go/internal/query_duplicates/table_test.go"
    position_id = path.normalize_path(position_id)

    -- ===== ACT =====
    print("\n[TEST] Running query duplicates test...")
    local got = integration.execute_adapter_direct(position_id, false) -- SYNC EXECUTION

    -- ===== ASSERT =====
    -- Check that the tree was discovered
    assert.truthy(got.tree, "Should have discovered test tree")
    assert.truthy(got.tree.data, "Should have tree data")

    -- Collect all node IDs from the tree to analyze duplicates
    local all_node_ids = {}
    local duplicate_counts = {}

    for _, node in got.tree:iter_nodes() do
      local id = node:data().id
      table.insert(all_node_ids, id)

      -- Extract just the test name part (after ::) for comparison
      local test_name = id:match("::(.+)$")
      if test_name then
        duplicate_counts[test_name] = (duplicate_counts[test_name] or 0) + 1
      end
    end

    print("\n[DEBUG] All discovered node IDs:")
    for _, id in ipairs(all_node_ids) do
      print("  - " .. id)
    end

    print("\n[DEBUG] Test name occurrence counts:")
    for test_name, count in pairs(duplicate_counts) do
      print("  " .. test_name .. ": " .. count .. " times")
    end

    -- Verify all expected subtests appear exactly once (no duplicates)
    local expected_subtests = {
      'TestMilestonesSorted::"empty"',
      'TestMilestonesSorted::"single"',
      'TestMilestonesSorted::"chronological order"',
      'TestMilestonesSorted::"reverse chronological order"',
      'TestMilestonesSorted::"random"',
    }

    -- Verify no duplicates exist - each test should appear exactly once
    local found_duplicates = false
    local missing_tests = {}

    for _, subtest in ipairs(expected_subtests) do
      local count = duplicate_counts[subtest] or 0
      if count > 1 then
        found_duplicates = true
        print(
          "[FAIL] " .. subtest .. " appears " .. count .. " times (expected: 1)"
        )
      elseif count == 1 then
        print("[OK] " .. subtest .. " appears exactly once")
      else
        table.insert(missing_tests, subtest)
        print("[MISSING] " .. subtest .. " not found in tree")
      end
    end

    -- Assert that the fix worked
    assert.falsy(
      found_duplicates,
      "Found duplicate sub-tests! The query overlap fix failed."
    )
    assert.truthy(
      #missing_tests == 0,
      "Missing expected sub-tests: " .. vim.inspect(missing_tests)
    )

    print(
      "\n[SUCCESS] All sub-tests appear exactly once - duplicates eliminated!"
    )
  end)
end)
