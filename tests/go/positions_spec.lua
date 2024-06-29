local nio = require("nio")
local adapter = require("neotest-golang")
local _ = require("plenary")

local function compareIgnoringKeys(t1, t2, ignoreKeys)
  local function copyTable(t, ignoreKeys)
    local copy = {}
    for k, v in pairs(t) do
      if not ignoreKeys[k] then
        if type(v) == "table" then
          copy[k] = copyTable(v, ignoreKeys)
        else
          copy[k] = v
        end
      end
    end
    return copy
  end
  return copyTable(t1, ignoreKeys), copyTable(t2, ignoreKeys)
end

describe("Discovery of test positions", function()
  it("Discover OK", function()
    -- Arrange
    local test_filepath = vim.loop.cwd() .. "/tests/go/positions_test.go"
    local expected = {
      {
        id = test_filepath,
        name = "positions_test.go",
        path = test_filepath,
        type = "file",
      },
      {
        {
          id = test_filepath .. "::TestTopLevel",
          name = "TestTopLevel",
          path = test_filepath,
          type = "test",
        },
      },
      {
        {
          id = test_filepath .. "::TestTopLevelWithSubTest",
          name = "TestTopLevelWithSubTest",
          path = test_filepath,
          type = "test",
        },
        {
          {
            id = test_filepath .. '::TestTopLevelWithSubTest::"SubTest"',
            name = '"SubTest"',
            path = test_filepath,
            type = "test",
          },
        },
      },
      {
        {
          id = test_filepath .. "::TestTableTestStruct",
          name = "TestTableTestStruct",
          path = test_filepath,
          type = "test",
        },
        {
          {
            id = test_filepath .. '::TestTableTestStruct::"TableTest1"',
            name = '"TableTest1"',
            path = test_filepath,
            type = "test",
          },
        },
        {
          {
            id = test_filepath .. '::TestTableTestStruct::"TableTest2"',
            name = '"TableTest2"',
            path = test_filepath,
            type = "test",
          },
        },
      },
      {
        {
          id = test_filepath .. "::TestSubTestTableTestStruct",
          name = "TestSubTestTableTestStruct",
          path = test_filepath,
          type = "test",
        },
        {
          {
            id = test_filepath .. '::TestSubTestTableTestStruct::"SubTest"',
            name = '"SubTest"',
            path = test_filepath,
            type = "test",
          },
          {
            {
              id = test_filepath
                .. '::TestSubTestTableTestStruct::"SubTest"::"TableTest1"',
              name = '"TableTest1"',
              path = test_filepath,
              type = "test",
            },
          },
          {
            {
              id = test_filepath
                .. '::TestSubTestTableTestStruct::"SubTest"::"TableTest2"',
              name = '"TableTest2"',
              path = test_filepath,
              type = "test",
            },
          },
        },
      },
      {
        {
          id = test_filepath .. "::TestTableTestInlineStruct",
          name = "TestTableTestInlineStruct",
          path = test_filepath,
          type = "test",
        },
        {
          {
            id = test_filepath .. '::TestTableTestInlineStruct::"TableTest1"',
            name = '"TableTest1"',
            path = test_filepath,
            type = "test",
          },
        },
        {
          {
            id = test_filepath .. '::TestTableTestInlineStruct::"TableTest2"',
            name = '"TableTest2"',
            path = test_filepath,
            type = "test",
          },
        },
      },
      {
        {
          id = test_filepath .. "::TestSubTestTableTestInlineStruct",
          name = "TestSubTestTableTestInlineStruct",
          path = test_filepath,
          type = "test",
        },
        {
          {
            id = test_filepath
              .. '::TestSubTestTableTestInlineStruct::"SubTest"',
            name = '"SubTest"',
            path = test_filepath,
            type = "test",
          },
          {
            {
              id = test_filepath
                .. '::TestSubTestTableTestInlineStruct::"SubTest"::"TableTest1"',
              name = '"TableTest1"',
              path = test_filepath,
              type = "test",
            },
          },
          {
            {
              id = test_filepath
                .. '::TestSubTestTableTestInlineStruct::"SubTest"::"TableTest2"',
              name = '"TableTest2"',
              path = test_filepath,
              type = "test",
            },
          },
        },
      },
      {
        {
          id = test_filepath .. "::TestTableTestInlineStructLoop",
          name = "TestTableTestInlineStructLoop",
          path = test_filepath,
          type = "test",
        },
        {
          {
            id = test_filepath
              .. '::TestTableTestInlineStructLoop::"TableTest1"',
            name = '"TableTest1"',
            path = test_filepath,
            type = "test",
          },
        },
        {
          {
            id = test_filepath
              .. '::TestTableTestInlineStructLoop::"TableTest2"',
            name = '"TableTest2"',
            path = test_filepath,
            type = "test",
          },
        },
      },
      {
        {
          id = test_filepath .. "::TestSubTestTableTestInlineStructLoop",
          name = "TestSubTestTableTestInlineStructLoop",
          path = test_filepath,
          type = "test",
        },
        {
          {
            id = test_filepath
              .. '::TestSubTestTableTestInlineStructLoop::"SubTest"',
            name = '"SubTest"',
            path = test_filepath,
            type = "test",
          },
          {
            {
              id = test_filepath
                .. '::TestSubTestTableTestInlineStructLoop::"SubTest"::"TableTest1"',
              name = '"TableTest1"',
              path = test_filepath,
              type = "test",
            },
          },
          {
            {
              id = test_filepath
                .. '::TestSubTestTableTestInlineStructLoop::"SubTest"::"TableTest2"',
              name = '"TableTest2"',
              path = test_filepath,
              type = "test",
            },
          },
        },
      },
      {
        {
          id = test_filepath .. "::TestTableTestMap",
          name = "TestTableTestMap",
          path = test_filepath,
          type = "test",
        },
        {
          {
            id = test_filepath .. '::TestTableTestMap::"TableTest1"',
            name = '"TableTest1"',
            path = test_filepath,
            type = "test",
          },
        },
        {
          {
            id = test_filepath .. '::TestTableTestMap::"TableTest2"',
            name = '"TableTest2"',
            path = test_filepath,
            type = "test",
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

    local ignoreKeys = { range = true }
    local expectedCopy, resultCopy =
      compareIgnoringKeys(expected, result, ignoreKeys)
    assert.are.same(vim.inspect(expectedCopy), vim.inspect(resultCopy))
    assert.are.same(expectedCopy, resultCopy)
  end)
end)
