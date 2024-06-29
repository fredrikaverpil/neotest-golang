local nio = require("nio")
local adapter = require("neotest-golang")

describe("Discovery of test positions", function()
  it("Discover OK", function()
    -- Arrange
    local test_filepath = vim.loop.cwd() .. "/tests/go/positions_test.go"
    local expected = {
      {
        id = test_filepath,
        name = vim.fn.fnamemodify(test_filepath, ":t"),
        path = test_filepath,
        range = { 0, 0, 59, 0 }, -- NOTE: this always gets changed when tests are added or removed
        type = "file",
      },
      {
        {
          id = test_filepath .. "::TestTopLevel",
          name = "TestTopLevel",
          path = test_filepath,
          range = { 4, 0, 8, 1 },
          type = "test",
        },
      },
      {
        {
          id = test_filepath .. "::TestTopLevelWithSubTest",
          name = "TestTopLevelWithSubTest",
          path = test_filepath,
          range = { 10, 0, 16, 1 },
          type = "test",
        },
        {
          {
            id = test_filepath .. '::TestTopLevelWithSubTest::"SubTest"',
            name = '"SubTest"',
            path = test_filepath,
            range = { 11, 1, 15, 3 },
            type = "test",
          },
        },
      },
      {
        {
          id = test_filepath .. "::TestTopLevelWithTableTests",
          name = "TestTopLevelWithTableTests",
          path = test_filepath,
          range = { 18, 0, 36, 1 },
          type = "test",
        },
        {
          {
            id = test_filepath .. '::TestTopLevelWithTableTests::"TableTest1"',
            name = '"TableTest1"',
            path = test_filepath,
            range = { 25, 2, 25, 47 },
            type = "test",
          },
        },
        {
          {
            id = test_filepath .. '::TestTopLevelWithTableTests::"TableTest2"',
            name = '"TableTest2"',
            path = test_filepath,
            range = { 26, 2, 26, 47 },
            type = "test",
          },
        },
      },
      {
        {
          id = test_filepath .. "::TestTopLevelWithSubTestWithTableTests",
          name = "TestTopLevelWithSubTestWithTableTests",
          path = test_filepath,
          range = { 38, 0, 58, 1 },
          type = "test",
        },
        {
          {
            id = test_filepath
              .. '::TestTopLevelWithSubTestWithTableTests::"SubTest"',
            name = '"SubTest"',
            path = test_filepath,
            range = { 39, 1, 57, 3 },
            type = "test",
          },
          {
            {
              id = test_filepath
                .. '::TestTopLevelWithSubTestWithTableTests::"SubTest"::"TableTest1"',
              name = '"TableTest1"',
              path = test_filepath,
              range = { 46, 3, 46, 48 },
              type = "test",
            },
          },
          {
            {
              id = test_filepath
                .. '::TestTopLevelWithSubTestWithTableTests::"SubTest"::"TableTest2"',
              name = '"TableTest2"',
              path = test_filepath,
              range = { 47, 3, 47, 48 },
              type = "test",
            },
          },
        },
      },
    }

    -- Act
    ---@type neotest.Tree
    local tree =
      nio.tests.with_async_context(adapter.discover_positions, test_filepath)

    -- Assert
    local result = tree:to_list()
    assert.are.same(vim.inspect(expected), vim.inspect(result))
  end)
end)
