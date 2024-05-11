local nio = require("nio")
local adapter = require("neotest-golang")

describe("Discovery of test positions", function()
  it("Discover OK", function()
    -- Arrange
    local test_filepath = vim.loop.cwd() .. "/test/unit/main_test.go"
    local expected = {
      {
        id = test_filepath,
        name = vim.fn.fnamemodify(test_filepath, ":t"),
        path = test_filepath,
        range = { 0, 0, 10, 0 },
        type = "file",
      },
      {
        {
          id = test_filepath .. "::TestAdd",
          name = "TestAdd",
          path = test_filepath,
          range = { 5, 0, 9, 1 },
          type = "test",
        },
      },
    }

    -- Act
    local tree =
      nio.tests.with_async_context(adapter.discover_positions, test_filepath)

    -- Assert
    local result = tree:to_list()
    assert.are.same(expected, result)
  end)
end)
