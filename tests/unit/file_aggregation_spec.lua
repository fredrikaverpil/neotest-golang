local process = require("neotest-golang.process")

describe("file node aggregation", function()
  describe("populate_file_nodes", function()
    local mock_tree
    local test_results

    before_each(function()
      -- Mock tree with file and test nodes
      local nodes = {
        -- File node
        {
          data = function()
            return {
              type = "file",
              id = "/path/to/file_test.go",
              path = "/path/to/file_test.go",
            }
          end,
        },
        -- Test nodes belonging to the file
        {
          data = function()
            return {
              type = "test",
              id = "/path/to/file_test.go::TestPassed",
              path = "/path/to/file_test.go",
            }
          end,
        },
        {
          data = function()
            return {
              type = "test",
              id = "/path/to/file_test.go::TestFailed",
              path = "/path/to/file_test.go",
            }
          end,
        },
        -- Test node from different file (should not be included)
        {
          data = function()
            return {
              type = "test",
              id = "/path/to/other_test.go::TestOther",
              path = "/path/to/other_test.go",
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

      -- Mock test results with some passed/failed tests
      test_results = {
        ["/path/to/file_test.go::TestPassed"] = {
          status = "passed",
          output = "/tmp/test1_output",
          errors = {},
        },
        ["/path/to/file_test.go::TestFailed"] = {
          status = "failed",
          output = "/tmp/test2_output",
          errors = {
            { line = 10, message = "Test failed: assertion error" },
          },
        },
        ["/path/to/other_test.go::TestOther"] = {
          status = "passed",
          output = "/tmp/other_output",
          errors = {},
        },
      }

      -- Mock file reading
      local original_readfile = _G.vim.fn.readfile
      _G.vim.fn.readfile = function(path)
        if path == "/tmp/test1_output" then
          return { "PASS: TestPassed", "--- output from TestPassed ---" }
        elseif path == "/tmp/test2_output" then
          return { "FAIL: TestFailed", "--- error from TestFailed ---" }
        elseif path == "/tmp/other_output" then
          return { "PASS: TestOther" }
        else
          return {}
        end
      end

      -- Mock file writing
      _G.vim.fn.writefile = function(content, path)
        -- Just return success, we'll verify content structure in tests
        return 0
      end

      -- Mock tempname
      _G.vim.fs.normalize = function(path)
        return path
      end
      local tempname_counter = 0
      _G.vim.fn.tempname = function()
        tempname_counter = tempname_counter + 1
        return "/tmp/combined_output_" .. tempname_counter
      end
    end)

    it(
      "aggregates status from child tests - failed takes precedence",
      function()
        local result = process.populate_file_nodes(mock_tree, test_results)

        -- File should have failed status since one child failed
        assert.is_not_nil(result["/path/to/file_test.go"])
        assert.are.equal("failed", result["/path/to/file_test.go"].status)
      end
    )

    it("aggregates errors from child tests", function()
      local result = process.populate_file_nodes(mock_tree, test_results)

      local file_result = result["/path/to/file_test.go"]
      assert.is_not_nil(file_result)
      assert.are.equal(1, #file_result.errors)
      assert.are.equal(10, file_result.errors[1].line)
      assert.are.equal(
        "Test failed: assertion error",
        file_result.errors[1].message
      )
    end)

    it("creates combined output file", function()
      local result = process.populate_file_nodes(mock_tree, test_results)

      local file_result = result["/path/to/file_test.go"]
      assert.is_not_nil(file_result)
      assert.is_not_nil(file_result.output)
      assert.matches("/tmp/combined_output_", file_result.output)
    end)

    it("does not affect tests from other files", function()
      local result = process.populate_file_nodes(mock_tree, test_results)

      -- Test from other file should remain unchanged
      assert.are.equal(
        test_results["/path/to/other_test.go::TestOther"],
        result["/path/to/other_test.go::TestOther"]
      )
    end)

    it("handles file with only passed tests", function()
      -- Remove failed test
      test_results["/path/to/file_test.go::TestFailed"] = nil

      local result = process.populate_file_nodes(mock_tree, test_results)

      local file_result = result["/path/to/file_test.go"]
      assert.is_not_nil(file_result)
      assert.are.equal("passed", file_result.status)
      assert.are.equal(0, #file_result.errors)
    end)

    it("handles file with mixed passed/skipped tests", function()
      -- Change failed test to skipped
      test_results["/path/to/file_test.go::TestFailed"].status = "skipped"
      test_results["/path/to/file_test.go::TestFailed"].errors = {}

      local result = process.populate_file_nodes(mock_tree, test_results)

      local file_result = result["/path/to/file_test.go"]
      assert.is_not_nil(file_result)
      assert.are.equal("skipped", file_result.status)
    end)

    it("skips files that already have results", function()
      -- Pre-populate file result
      test_results["/path/to/file_test.go"] = {
        status = "passed",
        output = "/existing/output",
      }

      local result = process.populate_file_nodes(mock_tree, test_results)

      -- Should keep existing result, not overwrite
      assert.are.equal(
        "/existing/output",
        result["/path/to/file_test.go"].output
      )
    end)
  end)
end)
