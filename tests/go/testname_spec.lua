local nio = require("nio")
local adapter = require("neotest-golang")
local convert = require("neotest-golang.convert")
local _ = require("plenary")

describe("Neotest position to Go test name", function()
  -- Arrange
  local test_filepath = vim.loop.cwd() .. "/tests/go/testname_test.go"

  ---@type neotest.Tree
  local tree =
    nio.tests.with_async_context(adapter.discover_positions, test_filepath)

  it("supports mixed case with space", function()
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

  it("supports special characters", function()
    local expected_subtest_name =
      '"Period . comma , and apostrophy \' are ok to use"'
    local expected_gotest_name =
      "TestNames/Period_._comma_,_and_apostrophy_'_are_ok_to_use"

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

  it("supports brackets", function()
    local expected_subtest_name = '"Brackets [1] (2) {3} are ok"'
    local expected_gotest_name = "TestNames/Brackets_[1]_(2)_{3}_are_ok"

    -- Act
    local pos = tree:node(5):data()
    local actual_go_test_name = convert.to_gotest_test_name(pos.id)

    -- Assert
    local actual_name = pos.name
    assert.are.same(expected_subtest_name, actual_name)
    assert.are.same(
      vim.inspect(expected_gotest_name),
      vim.inspect(actual_go_test_name)
    )
  end)

  it("supports regexp characters", function()
    local expected_subtest_name =
      '"Regexp characters like ( ) [ ] { } - | ? + * ^ $ are ok"'
    local expected_gotest_name =
      "TestNames/Regexp_characters_like_(_)_[_]_{_}_-_|_?_+_*_^_$_are_ok"

    -- Act
    local pos = tree:node(8):data()
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

describe("Full Go test name conversion", function()
  -- Arrange
  local test_filepath = vim.loop.cwd() .. "/tests/go/testname_test.go"

  ---@type neotest.Tree
  local tree =
    nio.tests.with_async_context(adapter.discover_positions, test_filepath)

  it("escapes parenthesis", function()
    local expected_subtest_name = '"Test(success)"'
    local expected_gotest_name = "^TestNames/Test\\(success\\)$"

    -- Act
    local pos = tree:node(7):data()
    local test_name = convert.to_gotest_test_name(pos.id)
    test_name = convert.to_gotest_regex_pattern(test_name)

    -- Assert
    local actual_name = pos.name
    assert.are.same(expected_subtest_name, actual_name)
    assert.are.same(vim.inspect(expected_gotest_name), vim.inspect(test_name))
  end)
end)
