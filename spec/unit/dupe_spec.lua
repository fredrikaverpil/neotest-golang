local _ = require("plenary")
local Tree = require("neotest.types").Tree
local dupe = require("neotest-golang.lib.dupe")

describe("Duplicate subtest detection", function()
  local function create_test_position(id, type)
    return {
      id = id,
      type = type or "test",
      name = id:match("::([^:]+)$") or id,
      path = id:match("^([^:]+)") or id,
    }
  end

  local function create_tree_from_positions(positions)
    local tree_data = {}
    for _, pos in ipairs(positions) do
      table.insert(tree_data, pos)
    end
    return Tree.from_list(tree_data, function(pos)
      return pos.id
    end)
  end

  describe("warn_duplicate_tests", function()
    local original_warn
    local captured_warnings = {}

    before_each(function()
      captured_warnings = {}
      local logger = require("neotest-golang.logging")
      original_warn = logger.warn
      logger.warn = function(msg, notify)
        table.insert(captured_warnings, { msg = msg, notify = notify })
      end
    end)

    after_each(function()
      if original_warn then
        require("neotest-golang.logging").warn = original_warn
      end
    end)

    it("detects no duplicates when all subtest names are unique", function()
      local positions = {
        create_test_position('/path/file_test.go::TestNoDupe::"foo"::"bar"'),
        create_test_position('/path/file_test.go::TestNoDupe::"foo"::"baz"'),
      }
      local tree = create_tree_from_positions(positions)

      dupe.warn_duplicate_tests(tree)

      assert.are.equal(0, #captured_warnings)
    end)

    it("detects duplicates in same parent test", function()
      local positions = {
        create_test_position('/path/file_test.go::TestDupe::"foo"::"bar"'),
        create_test_position('/path/file_test.go::TestDupe::"foo"::"bar"'),
      }
      local tree = create_tree_from_positions(positions)

      dupe.warn_duplicate_tests(tree)

      assert.are.equal(1, #captured_warnings)
      local warning = captured_warnings[1]
      assert.is_true(warning.notify)
      assert.is_true(
        string.find(warning.msg, "Found duplicate subtest names:") ~= nil
      )
      assert.is_true(string.find(warning.msg, "TestDupe/foo::bar") ~= nil)
    end)

    it("detects multiple different duplicates", function()
      local positions = {
        create_test_position('/path/file_test.go::TestDupe::"foo"::"bar"'),
        create_test_position('/path/file_test.go::TestDupe::"foo"::"bar"'),
        create_test_position('/path/file_test.go::TestDupe::"baz"::"qux"'),
        create_test_position('/path/file_test.go::TestDupe::"baz"::"qux"'),
      }
      local tree = create_tree_from_positions(positions)

      dupe.warn_duplicate_tests(tree)

      assert.are.equal(1, #captured_warnings)
      local warning = captured_warnings[1]
      assert.is_true(string.find(warning.msg, "TestDupe/foo::bar") ~= nil)
      assert.is_true(string.find(warning.msg, "TestDupe/baz::qux") ~= nil)
    end)

    it("ignores duplicates across different parent tests", function()
      local positions = {
        create_test_position('/path/file_test.go::TestOne::"foo"::"bar"'),
        create_test_position('/path/file_test.go::TestTwo::"foo"::"bar"'),
      }
      local tree = create_tree_from_positions(positions)

      dupe.warn_duplicate_tests(tree)

      assert.are.equal(0, #captured_warnings)
    end)

    it("handles single-level subtests", function()
      local positions = {
        create_test_position('/path/file_test.go::TestDupe::"foo"'),
        create_test_position('/path/file_test.go::TestDupe::"foo"'),
      }
      local tree = create_tree_from_positions(positions)

      dupe.warn_duplicate_tests(tree)

      assert.are.equal(1, #captured_warnings)
      local warning = captured_warnings[1]
      assert.is_true(string.find(warning.msg, "TestDupe::foo") ~= nil)
    end)

    it("handles deeply nested subtests", function()
      local positions = {
        create_test_position(
          '/path/file_test.go::TestDeep::"level1"::"level2"::"level3"::"final"'
        ),
        create_test_position(
          '/path/file_test.go::TestDeep::"level1"::"level2"::"level3"::"final"'
        ),
      }
      local tree = create_tree_from_positions(positions)

      dupe.warn_duplicate_tests(tree)

      assert.are.equal(1, #captured_warnings)
      local warning = captured_warnings[1]
      assert.is_true(
        string.find(warning.msg, "TestDeep/level1/level2/level3::final") ~= nil
      )
    end)

    it("handles mixed duplicate and non-duplicate subtests", function()
      local positions = {
        create_test_position('/path/file_test.go::TestMixed::"unique1"'),
        create_test_position('/path/file_test.go::TestMixed::"duplicate"'),
        create_test_position('/path/file_test.go::TestMixed::"duplicate"'),
        create_test_position('/path/file_test.go::TestMixed::"unique2"'),
      }
      local tree = create_tree_from_positions(positions)

      dupe.warn_duplicate_tests(tree)

      assert.are.equal(1, #captured_warnings)
      local warning = captured_warnings[1]
      assert.is_true(string.find(warning.msg, "TestMixed::duplicate") ~= nil)
      assert.is_true(string.find(warning.msg, "unique1") == nil)
      assert.is_true(string.find(warning.msg, "unique2") == nil)
    end)

    it("handles non-test positions gracefully", function()
      local positions = {
        create_test_position("/path/file_test.go", "file"),
        create_test_position("/path", "dir"),
        create_test_position("/path/file_test.go::TestFunction"),
      }
      local tree = create_tree_from_positions(positions)

      dupe.warn_duplicate_tests(tree)

      assert.are.equal(0, #captured_warnings)
    end)

    it("handles empty tree gracefully", function()
      -- Create a dummy tree with a single dummy position to avoid nil issues
      local dummy_pos = { id = "dummy", type = "dummy" }
      local tree = Tree.from_list({ dummy_pos }, function(pos)
        return pos.id
      end)

      dupe.warn_duplicate_tests(tree)

      assert.are.equal(0, #captured_warnings)
    end)

    it("includes helpful context in warning message", function()
      local positions = {
        create_test_position('/path/file_test.go::TestHelp::"same"'),
        create_test_position('/path/file_test.go::TestHelp::"same"'),
      }
      local tree = create_tree_from_positions(positions)

      dupe.warn_duplicate_tests(tree)

      assert.are.equal(1, #captured_warnings)
      local warning = captured_warnings[1]
      assert.is_true(
        string.find(warning.msg, "Go will append suffixes like '#01'") ~= nil
      )
      assert.is_true(
        string.find(warning.msg, "Consider using unique subtest names") ~= nil
      )
      assert.is_true(
        string.find(warning.msg, "warn_test_name_dupes = false") ~= nil
      )
    end)

    it("sorts duplicate entries consistently", function()
      local positions = {
        create_test_position('/path/file_test.go::TestZ::"dup"'),
        create_test_position('/path/file_test.go::TestZ::"dup"'),
        create_test_position('/path/file_test.go::TestA::"dup"'),
        create_test_position('/path/file_test.go::TestA::"dup"'),
      }
      local tree = create_tree_from_positions(positions)

      dupe.warn_duplicate_tests(tree)

      assert.are.equal(1, #captured_warnings)
      local warning = captured_warnings[1]
      local lines = vim.split(warning.msg, "\n")

      local testA_line, testZ_line
      for i, line in ipairs(lines) do
        if string.find(line, "TestA::dup") then
          testA_line = i
        elseif string.find(line, "TestZ::dup") then
          testZ_line = i
        end
      end

      assert.is_not_nil(testA_line)
      assert.is_not_nil(testZ_line)
      assert.is_true(
        testA_line < testZ_line,
        "TestA should appear before TestZ"
      )
    end)
  end)
end)
