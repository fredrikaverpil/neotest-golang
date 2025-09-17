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
    end)

    it(
      "does not add phantom prefix keys for non-existent parent tests",
      function()
        local result =
          lib.mapping.build_position_lookup(mock_tree, mock_golist_data)

        -- Deep node exact mapping remains
        assert.are.equal(
          deep_pos_id,
          result["example.com/repo/pkg::TestMain/Level1/Level2/Level3"]
        )

        -- Intermediate and top-level prefixes should NOT map when corresponding nodes do not exist
        assert.is_nil(result["example.com/repo/pkg::TestMain/Level1/Level2"])
        assert.is_nil(result["example.com/repo/pkg::TestMain/Level1"])
        assert.is_nil(result["example.com/repo/pkg::TestMain"])
      end
    )

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
end)
