local lib = require("neotest-golang.lib")

describe("mapping module", function()
  describe("pos_id_to_go_test_name", function()
    it("converts simple test names", function()
      local pos_id = "/path/to/pkg/file_test.go::TestName"
      local expected = "TestName"
      local result = lib.convert.pos_id_to_go_test_name(pos_id)
      assert.are.equal(expected, result)
    end)

    it("converts test with single subtest", function()
      local pos_id = '/path/to/pkg/file_test.go::TestName::"SubTest"'
      local expected = "TestName/SubTest"
      local result = lib.convert.pos_id_to_go_test_name(pos_id)
      assert.are.equal(expected, result)
    end)

    it("converts test with nested subtests", function()
      local pos_id =
        '/path/to/pkg/file_test.go::TestName::"SubTest1"::"NestedSubTest"'
      local expected = "TestName/SubTest1/NestedSubTest"
      local result = lib.convert.pos_id_to_go_test_name(pos_id)
      assert.are.equal(expected, result)
    end)

    it("converts test with spaces in subtest names", function()
      local pos_id =
        '/path/to/pkg/file_test.go::TestName::"Sub Test With Spaces"'
      local expected = "TestName/Sub_Test_With_Spaces"
      local result = lib.convert.pos_id_to_go_test_name(pos_id)
      assert.are.equal(expected, result)
    end)

    it("converts deeply nested subtests", function()
      local pos_id =
        '/path/to/pkg/file_test.go::TestMain::"Level1"::"Level2"::"Level3"::"Level4"'
      local expected = "TestMain/Level1/Level2/Level3/Level4"
      local result = lib.convert.pos_id_to_go_test_name(pos_id)
      assert.are.equal(expected, result)
    end)

    it("handles subtests with special characters", function()
      local pos_id =
        '/path/to/pkg/file_test.go::TestName::"SubTest with & symbols!"'
      local expected = "TestName/SubTest_with_&_symbols!"
      local result = lib.convert.pos_id_to_go_test_name(pos_id)
      assert.are.equal(expected, result)
    end)

    it("returns nil for invalid position IDs", function()
      local pos_id = "/path/to/pkg/file_test.go" -- No :: separator
      local result = lib.convert.pos_id_to_go_test_name(pos_id)
      assert.is_nil(result)
    end)
  end)

  describe("go_test_name_to_pos_format", function()
    it("converts simple test names", function()
      local go_test_name = "TestName"
      local expected = "TestName"
      local result = lib.convert.go_test_name_to_pos_id(go_test_name)
      assert.are.equal(expected, result)
    end)

    it("converts test with single subtest", function()
      local go_test_name = "TestName/SubTest"
      local expected = 'TestName::"SubTest"'
      local result = lib.convert.go_test_name_to_pos_id(go_test_name)
      assert.are.equal(expected, result)
    end)

    it("converts test with nested subtests", function()
      local go_test_name = "TestName/SubTest1/NestedSubTest"
      local expected = 'TestName::"SubTest1"::"NestedSubTest"'
      local result = lib.convert.go_test_name_to_pos_id(go_test_name)
      assert.are.equal(expected, result)
    end)

    it("converts underscores back to spaces in subtests", function()
      local go_test_name = "TestName/Sub_Test_With_Spaces"
      local expected = 'TestName::"Sub Test With Spaces"'
      local result = lib.convert.go_test_name_to_pos_id(go_test_name)
      assert.are.equal(expected, result)
    end)
  end)

  describe("file_path_to_import_path", function()
    it("finds matching import path", function()
      local file_path = "/path/to/pkg/subdir/file_test.go"
      local import_to_dir = {
        ["example.com/repo/pkg"] = "/path/to/pkg",
        ["example.com/repo/pkg/subdir"] = "/path/to/pkg/subdir",
        ["example.com/repo/other"] = "/path/to/other",
      }

      local expected = "example.com/repo/pkg/subdir"
      local result =
        lib.convert.file_path_to_import_path(file_path, import_to_dir)
      assert.are.equal(expected, result)
    end)

    it("returns nil when no match found", function()
      local file_path = "/path/to/unknown/file_test.go"
      local import_to_dir = {
        ["example.com/repo/pkg"] = "/path/to/pkg",
      }

      local result =
        lib.convert.file_path_to_import_path(file_path, import_to_dir)
      assert.is_nil(result)
    end)

    it("returns nil for invalid file path", function()
      local file_path = "invalid_path" -- No directory separator
      local import_to_dir = {}

      local result =
        lib.convert.file_path_to_import_path(file_path, import_to_dir)
      assert.is_nil(result)
    end)
  end)

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

    it("adds prefix keys for subtests mapping to deepest node", function()
      local result =
        lib.mapping.build_position_lookup(mock_tree, mock_golist_data)

      -- Deep node exact mapping
      assert.are.equal(
        deep_pos_id,
        result["example.com/repo/pkg::TestMain/Level1/Level2/Level3"]
      )

      -- Intermediate prefixes should map as well
      assert.are.equal(
        deep_pos_id,
        result["example.com/repo/pkg::TestMain/Level1/Level2"]
      )
      assert.are.equal(
        deep_pos_id,
        result["example.com/repo/pkg::TestMain/Level1"]
      )

      -- Top-level prefix should already exist; must not overwrite an existing top-level test if present
      -- but ensure it has some mapping. Here, TestMain top-level isn't separately present, so it should map to deep_pos_id
      assert.are.equal(deep_pos_id, result["example.com/repo/pkg::TestMain"])
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

  describe("bidirectional conversion", function()
    it(
      "maintains consistency between pos_id and go_test_name conversions",
      function()
        local test_cases = {
          { pos = "TestName", go = "TestName" },
          { pos = 'TestName::"SubTest"', go = "TestName/SubTest" },
          { pos = 'TestName::"Sub1"::"Sub2"', go = "TestName/Sub1/Sub2" },
          {
            pos = 'TestName::"Sub Test With Spaces"',
            go = "TestName/Sub_Test_With_Spaces",
          },
        }

        for _, test_case in ipairs(test_cases) do
          -- Test pos -> go -> pos
          local go_result =
            lib.convert.pos_id_to_go_test_name("file.go::" .. test_case.pos)
          assert.are.equal(
            test_case.go,
            go_result,
            "pos->go conversion failed for " .. test_case.pos
          )

          local pos_result = lib.convert.go_test_name_to_pos_id(go_result)
          assert.are.equal(
            test_case.pos,
            pos_result,
            "go->pos conversion failed for " .. test_case.go
          )

          -- Test go -> pos -> go
          local pos_result2 = lib.convert.go_test_name_to_pos_id(test_case.go)
          assert.are.equal(
            test_case.pos,
            pos_result2,
            "go->pos conversion failed for " .. test_case.go
          )

          local go_result2 =
            lib.convert.pos_id_to_go_test_name("file.go::" .. pos_result2)
          assert.are.equal(
            test_case.go,
            go_result2,
            "pos->go conversion failed for " .. test_case.pos
          )
        end
      end
    )
  end)
end)
