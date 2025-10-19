local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load nearest helpers
local nearest_path = vim.uv.cwd() .. "/spec/helpers/nearest.lua"
local nearest = dofile(nearest_path)

describe("Integration: testify suites nearest test", function()
  before_each(function()
    -- Configure adapter for testify
    local test_options = options.get()
    test_options.runner = "gotestsum"
    test_options.testify_enabled = true
    test_options.log_level = vim.log.levels.DEBUG
    options.set(test_options)
  end)

  -- Test file with mixed testify and regular tests
  local test_file = vim.uv.cwd()
    .. "/tests/features/internal/testifysuites/positions_test.go"
  test_file = path.normalize_path(test_file)

  describe("cursor on testify method", function()
    it(
      "selects testify test when cursor is on TestExample (line 54)",
      function()
        -- Line 54 in editor = index 53 for Neotest (0-indexed)
        local position = nearest.get_nearest_position(test_file, 53)

        assert.is_not_nil(position, "Should find a nearest position")
        assert.equals(
          test_file .. "::TestExampleTestSuite2/TestExample",
          position.id,
          "Should select the testify test at cursor"
        )
        assert.equals("test", position.type)
        -- Note: position.name is just the method name, not the suite-prefixed version
        assert.equals("TestExample", position.name)
      end
    )

    it(
      "selects testify test when cursor is on TestExample3 (line 75)",
      function()
        -- Line 75 in editor = index 74 for Neotest (0-indexed)
        local position = nearest.get_nearest_position(test_file, 74)

        assert.is_not_nil(position)
        assert.equals(
          test_file .. "::TestExampleTestSuite2/TestExample3",
          position.id
        )
        assert.equals("test", position.type)
      end
    )

    it(
      "selects testify test with subtest when cursor is on TestSubTestOperand1 (line 89)",
      function()
        -- Line 89 in editor = index 88 for Neotest (0-indexed)
        local position = nearest.get_nearest_position(test_file, 88)

        assert.is_not_nil(position)
        assert.equals(
          test_file .. "::TestExampleTestSuite/TestSubTestOperand1",
          position.id
        )
        assert.equals("test", position.type)
      end
    )
  end)

  describe("cursor on regular test", function()
    it(
      "selects regular test when cursor is on TestTrivial (line 69)",
      function()
        -- Line 69 in editor = index 68 for Neotest (0-indexed)
        -- With sorted tree, cursor at line 68 correctly selects TestTrivial
        local position = nearest.get_nearest_position(test_file, 68)

        assert.is_not_nil(position)
        assert.equals(test_file .. "::TestTrivial", position.id)
        assert.equals("test", position.type)
        assert.equals("TestTrivial", position.name)
      end
    )
  end)

  describe("cursor on suite function (not in tree)", function()
    it(
      "selects nearest test upward when cursor is on TestExampleTestSuite2 suite function (line 62)",
      function()
        -- Line 62 in editor = index 61 for Neotest (0-indexed)
        -- Suite function is NOT in tree, so should find nearest test upward
        -- The nearest test upward is TestExample2 at line 58
        local position = nearest.get_nearest_position(test_file, 61)

        assert.is_not_nil(position)
        assert.equals(
          test_file .. "::TestExampleTestSuite2/TestExample2",
          position.id,
          "Should select nearest test upward from suite function"
        )
        assert.equals("test", position.type)
      end
    )

    it(
      "selects nearest test upward when cursor is on TestExampleTestSuite suite function (line 37)",
      function()
        -- Line 37 in editor = index 36 for Neotest (0-indexed)
        -- The nearest test upward is TestExample2 at line 31
        local position = nearest.get_nearest_position(test_file, 36)

        assert.is_not_nil(position)
        assert.equals(
          test_file .. "::TestExampleTestSuite/TestExample2",
          position.id
        )
        assert.equals("test", position.type)
      end
    )
  end)

  describe("cursor on cross-file method", function()
    it(
      "selects cross-file test when cursor is on TestOther (line 82)",
      function()
        -- Line 82 in editor = index 81 for Neotest (0-indexed)
        -- DISCOVERY: TestOther IS in the tree (cross-file support still works)
        local position = nearest.get_nearest_position(test_file, 81)

        assert.is_not_nil(position)
        assert.equals(
          test_file .. "::TestOtherTestSuite/TestOther",
          position.id,
          "Cross-file methods are still shown in the tree"
        )
        assert.equals("test", position.type)
      end
    )
  end)

  describe("cursor between tests", function()
    it(
      "selects previous test when cursor is between TestTrivial and TestExample3 (line 71)",
      function()
        -- Line 71 in editor = index 70 for Neotest (0-indexed)
        -- Between TestTrivial (line 69) and TestExample3 (line 75)
        -- With sorted tree, correctly selects TestTrivial as nearest test
        local position = nearest.get_nearest_position(test_file, 70)

        assert.is_not_nil(position)
        assert.equals(
          test_file .. "::TestTrivial",
          position.id,
          "Sorted tree ensures file line order"
        )
        assert.equals("test", position.type)
      end
    )

    it(
      "selects previous test when cursor is in comment block (line 41)",
      function()
        -- Line 41 in editor = index 40 for Neotest (0-indexed)
        -- In comment block between suite function (line 37) and next suite def (line 45)
        -- Should select TestExample2 (line 31) as nearest test
        local position = nearest.get_nearest_position(test_file, 40)

        assert.is_not_nil(position)
        assert.equals(
          test_file .. "::TestExampleTestSuite/TestExample2",
          position.id
        )
        assert.equals("test", position.type)
      end
    )
  end)

  describe("cursor at file boundaries", function()
    it(
      "selects file position when cursor is before any test (line 1)",
      function()
        -- Line 1 in editor = index 0 for Neotest (0-indexed)
        local position = nearest.get_nearest_position(test_file, 0)

        assert.is_not_nil(position)
        assert.equals(test_file, position.id, "Should select file position")
        assert.equals("file", position.type)
      end
    )

    it(
      "selects last subtest when cursor is after all tests (line 103)",
      function()
        -- Line 103 in editor = index 102 for Neotest (0-indexed)
        -- After the last test TestSubTestOperand2 (line 97) which contains a subtest
        -- Nearest algorithm selects the subtest since it's the deepest node that contains this line
        local position = nearest.get_nearest_position(test_file, 102)

        assert.is_not_nil(position)
        assert.equals(
          test_file .. '::TestExampleTestSuite/TestSubTestOperand2::"subtest"',
          position.id,
          "Subtest is selected as nearest (deepest matching node)"
        )
        assert.equals("test", position.type)
      end
    )
  end)

  describe("flat structure with sorted tree", function()
    it(
      "correctly handles mixed testify and regular tests in file line order",
      function()
        -- This test validates that the flat structure with sorted children
        -- allows nearest test to work correctly based on actual file line order

        -- Get positions at various points in the file
        local pos_at_27 = nearest.get_nearest_id(test_file, 26) -- Line 27: TestExample (Suite1)
        local pos_at_54 = nearest.get_nearest_id(test_file, 53) -- Line 54: TestExample (Suite2)
        local pos_at_69 = nearest.get_nearest_id(test_file, 68) -- Line 69: TestTrivial
        local pos_at_75 = nearest.get_nearest_id(test_file, 74) -- Line 75: TestExample3 (Suite2)

        -- Verify positions at cursor locations match file line order
        assert.equals(
          test_file .. "::TestExampleTestSuite/TestExample",
          pos_at_27
        )
        assert.equals(
          test_file .. "::TestExampleTestSuite2/TestExample",
          pos_at_54
        )
        -- With sorted tree, line 69 correctly gets TestTrivial
        assert.equals(
          test_file .. "::TestTrivial",
          pos_at_69,
          "Sorted tree makes TestTrivial nearest at line 69"
        )
        assert.equals(
          test_file .. "::TestExampleTestSuite2/TestExample3",
          pos_at_75
        )

        -- Verify positions work correctly with mixed test types
        local pos_between_suite_and_regular =
          nearest.get_nearest_id(test_file, 65)
        assert.equals(
          test_file .. "::TestExampleTestSuite2/TestExample2",
          pos_between_suite_and_regular,
          "Sorted tree ensures file line order"
        )
      end
    )
  end)

  describe("assert_nearest helper", function()
    it("provides concise assertion syntax", function()
      -- Demonstrate the helper function for cleaner test syntax
      -- At line 68, sorted tree makes TestTrivial the nearest (line 69 = index 68)
      nearest.assert_nearest(
        test_file,
        68,
        test_file .. "::TestTrivial",
        "Custom error message"
      )
    end)

    it("throws error when assertion fails", function()
      local success, err = pcall(function()
        nearest.assert_nearest(
          test_file,
          68,
          test_file .. "::WrongTest",
          "Should fail"
        )
      end)

      assert.is_false(success, "Should throw error on assertion failure")
      assert.is_not_nil(
        err:match("Should fail"),
        "Should include custom message"
      )
    end)
  end)
end)
