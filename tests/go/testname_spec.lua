local nio = require("nio")
local adapter = require("neotest-golang")
local convert = require("neotest-golang.convert")

describe("Subtest name conversion", function()
  -- Arrange
  local test_filepath = vim.loop.cwd() .. "/tests/go/testname_test.go"

  ---@type neotest.Tree
  local tree =
    nio.tests.with_async_context(adapter.discover_positions, test_filepath)

  it("Mixed case with space", function()
    local expected_subtest_name = '"Mixed case with space"'
    local expected_gotest_name = "TestNames/Mixed_case_with_space"

    -- Act
    local pos = tree:node(3):data()
    local actual_go_test_name = convert.to_gotest_test_name(pos.id)

    -- Assert
    local actual_name = pos.name
    assert.are.same(expected_subtest_name, actual_name)
    assert.are.same(
      vim.inspect(expected_gotest_name),
      vim.inspect(actual_go_test_name)
    )
  end)

  it("Special characters", function()
    local expected_subtest_name = '"Comma , and \' are ok to use"'
    local expected_gotest_name = "TestNames/Comma_,_and_'_are_ok_to_use"

    -- Act
    local pos = tree:node(4):data()
    local actual_go_test_name = convert.to_gotest_test_name(pos.id)

    -- Assert
    local actual_name = pos.name
    assert.are.same(expected_subtest_name, actual_name)
    assert.are.same(
      vim.inspect(expected_gotest_name),
      vim.inspect(actual_go_test_name)
    )
  end)
end)
