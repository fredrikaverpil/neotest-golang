local lib = require("neotest-golang.lib")

describe("mapping module", function()
  describe("get_position_id", function()
    local lookup_table

    before_each(function()
      lookup_table = {
        ["example.com/repo/pkg::TestName"] = "/path/to/pkg/file_test.go::TestName",
        ["example.com/repo/pkg::TestName/SubTest"] = '/path/to/pkg/file_test.go::TestName::"SubTest"',
        ["example.com/repo/pkg::TestMain/Level1/Level2"] = '/path/to/pkg/file_test.go::TestMain::"Level1"::"Level2"',
      }
    end)

    it("finds position ID for simple test", function()
      local package_name = "example.com/repo/pkg"
      local test_name = "TestName"
      local expected = "/path/to/pkg/file_test.go::TestName"

      local result =
        lib.mapping.get_pos_id(lookup_table, package_name, test_name)
      assert.are.equal(expected, result)
    end)

    it("finds position ID for nested subtest", function()
      local package_name = "example.com/repo/pkg"
      local test_name = "TestMain/Level1/Level2"
      local expected = '/path/to/pkg/file_test.go::TestMain::"Level1"::"Level2"'

      local result =
        lib.mapping.get_pos_id(lookup_table, package_name, test_name)
      assert.are.equal(expected, result)
    end)

    it("returns nil for unknown test", function()
      local package_name = "example.com/repo/pkg"
      local test_name = "UnknownTest"

      local result =
        lib.mapping.get_pos_id(lookup_table, package_name, test_name)
      assert.is_nil(result)
    end)
  end)

  describe("build_position_lookup", function()
    local mock_tree, mock_golist_data, deep_pos_id

    before_each(function()
      deep_pos_id =
        '/path/to/pkg/file_test.go::TestMain::"Level1"::"Level2"::"Level3"'
      -- Mock tree structure with test nodes
      local nodes = {
        {
          data = function()
            return {
              type = "test",
              id = "/path/to/pkg/file_test.go::TestName",
              path = "/path/to/pkg/file_test.go",
            }
          end,
        },
        {
          data = function()
            return {
              type = "test",
              id = '/path/to/pkg/file_test.go::TestName::"SubTest"',
              path = "/path/to/pkg/file_test.go",
            }
          end,
        },
        {
          data = function()
            return {
              type = "test",
              id = deep_pos_id,
              path = "/path/to/pkg/file_test.go",
            }
          end,
        },
        {
          data = function()
            return {
              type = "file", -- Non-test node, should be ignored
              id = "/path/to/pkg/file_test.go",
              path = "/path/to/pkg/file_test.go",
            }
          end,
        },
      }

      mock_tree = {
        iter_nodes = function()
          local i = 0
          return function()
            i = i + 1
            return nodes[i], nodes[i]
          end
        end,
      }

      mock_golist_data = {
        {
          ImportPath = "example.com/repo/pkg",
          Dir = "/path/to/pkg",
        },
      }
    end)

    it("builds lookup table from tree and golist data", function()
      local result =
        lib.mapping.build_position_lookup(mock_tree, mock_golist_data)

      -- Should have entries for test nodes only
      assert.are.equal(
        "/path/to/pkg/file_test.go::TestName",
        result["example.com/repo/pkg::TestName"]
      )
      assert.are.equal(
        '/path/to/pkg/file_test.go::TestName::"SubTest"',
        result["example.com/repo/pkg::TestName/SubTest"]
      )

      -- Should not have entry for file node
      assert.is_nil(result["example.com/repo/pkg::"])

      -- Should have package-only entry
      assert.are.equal(
        "/path/to/pkg/file_test.go::TestName",
        result["example.com/repo/pkg"]
      )
    end)

    it("generates parent test lookup entries for nested tests", function()
      local result =
        lib.mapping.build_position_lookup(mock_tree, mock_golist_data)

      -- Deep node exact mapping remains
      assert.are.equal(
        deep_pos_id,
        result["example.com/repo/pkg::TestMain/Level1/Level2/Level3"]
      )

      -- Parent test entries should now be generated
      assert.are.equal(
        "/path/to/pkg/file_test.go::TestMain",
        result["example.com/repo/pkg::TestMain"]
      )
      assert.are.equal(
        "/path/to/pkg/file_test.go::TestMain",
        result["example.com/repo/pkg::TestMain/Level1"]
      )
      assert.are.equal(
        "/path/to/pkg/file_test.go::TestMain",
        result["example.com/repo/pkg::TestMain/Level1/Level2"]
      )
    end)

    it("handles empty tree", function()
      local empty_tree = {
        iter_nodes = function()
          return function()
            return nil
          end
        end,
      }

      local result =
        lib.mapping.build_position_lookup(empty_tree, mock_golist_data)
      assert.are.same({}, result)
    end)
  end)

  describe("Windows path handling", function()
    describe("build_position_lookup with Windows paths", function()
      local mock_tree_windows, mock_golist_data_windows

      before_each(function()
        -- Mock tree structure with Windows test nodes (using normalized paths for cross-platform testing)
        local nodes = {
          {
            data = function()
              return {
                type = "test",
                id = "D:/a/neotest-golang/tests/go/internal/multifile/first_file_test.go::TestOne",
                path = "D:/a/neotest-golang/tests/go/internal/multifile/first_file_test.go",
              }
            end,
          },
          {
            data = function()
              return {
                type = "test",
                id = "D:/a/neotest-golang/tests/go/internal/multifile/second_file_test.go::TestTwo",
                path = "D:/a/neotest-golang/tests/go/internal/multifile/second_file_test.go",
              }
            end,
          },
        }

        mock_tree_windows = {
          iter_nodes = function()
            local i = 0
            return function()
              i = i + 1
              return nodes[i], nodes[i]
            end
          end,
        }

        mock_golist_data_windows = {
          {
            ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/multifile",
            Dir = "D:/a/neotest-golang/tests/go/internal/multifile",
          },
        }
      end)

      it("builds lookup table for Windows paths correctly", function()
        local result = lib.mapping.build_position_lookup(
          mock_tree_windows,
          mock_golist_data_windows
        )

        -- Should correctly map Windows paths with drive letters
        assert.are.equal(
          "D:/a/neotest-golang/tests/go/internal/multifile/first_file_test.go::TestOne",
          result["github.com/fredrikaverpil/neotest-golang/internal/multifile::TestOne"]
        )
        assert.are.equal(
          "D:/a/neotest-golang/tests/go/internal/multifile/second_file_test.go::TestTwo",
          result["github.com/fredrikaverpil/neotest-golang/internal/multifile::TestTwo"]
        )
      end)

      it("does not break on Windows drive letter colons", function()
        -- This is a regression test for the specific issue where Windows drive letter colons
        -- were causing path extraction to fail
        local result = lib.mapping.build_position_lookup(
          mock_tree_windows,
          mock_golist_data_windows
        )

        -- Make sure we don't have broken entries due to colon confusion
        local keys = vim.tbl_keys(result)
        for _, key in ipairs(keys) do
          -- No entry should contain just "D" or other single drive letters
          assert.is_not.equal("D", key)
          assert.is_not.equal("C", key)
        end

        -- Verify the correct full paths are in the keys
        local has_correct_key = false
        for _, key in ipairs(keys) do
          if
            key:find(
              "github.com/fredrikaverpil/neotest%-golang/internal/multifile::TestOne"
            )
          then
            has_correct_key = true
            break
          end
        end
        assert.is_true(
          has_correct_key,
          "Should have correct lookup key for TestOne"
        )
      end)
    end)

    describe("get_pos_id with Windows paths", function()
      local lookup_table_windows

      before_each(function()
        lookup_table_windows = {
          ["github.com/repo/pkg::TestName"] = "D:\\\\path\\\\to\\\\pkg\\\\file_test.go::TestName",
          ["github.com/repo/pkg::TestName/SubTest"] = 'D:\\\\path\\\\to\\\\pkg\\\\file_test.go::TestName::"SubTest"',
        }
      end)

      it("finds Windows position ID for simple test", function()
        local package_name = "github.com/repo/pkg"
        local test_name = "TestName"
        local expected = "D:\\\\path\\\\to\\\\pkg\\\\file_test.go::TestName"

        local result =
          lib.mapping.get_pos_id(lookup_table_windows, package_name, test_name)
        assert.are.equal(expected, result)
      end)

      it("finds Windows position ID for nested subtest", function()
        local package_name = "github.com/repo/pkg"
        local test_name = "TestName/SubTest"
        local expected =
          'D:\\\\path\\\\to\\\\pkg\\\\file_test.go::TestName::"SubTest"'

        local result =
          lib.mapping.get_pos_id(lookup_table_windows, package_name, test_name)
        assert.are.equal(expected, result)
      end)
    end)
  end)
end)
