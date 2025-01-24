local nio = require("nio")
local _ = require("plenary")

local adapter = require("neotest-golang")
local options = require("neotest-golang.options")
local lib = require("neotest-golang.lib")
local testify = require("neotest-golang.features.testify")

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

local function normalize_windows_path(path)
  return path:gsub("/", "\\")
end

describe("With testify_enabled=false", function()
  it("Discover test functions", function()
    -- Arrange
    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/testify/positions_test.go"
    if vim.fn.has("win32") == 1 then
      test_filepath = normalize_windows_path(test_filepath)
    end
    local expected = {
      {
        id = test_filepath,
        name = "positions_test.go",
        path = test_filepath,
        type = "file",
      },
      {
        {
          id = test_filepath .. "::TestExampleTestSuite",
          name = "TestExampleTestSuite",
          path = test_filepath,
          type = "test",
        },
      },
      {
        {
          id = test_filepath .. "::TestExampleTestSuite2",
          name = "TestExampleTestSuite2",
          path = test_filepath,
          type = "test",
        },
      },
      {
        {
          id = test_filepath .. "::TestTrivial",
          name = "TestTrivial",
          path = test_filepath,
          type = "test",
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

describe("With testify_enabled=true", function()
  it("Discover namespaces, test methods and test function", function()
    -- Arrange
    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/testify/positions_test.go"
    if vim.fn.has("win32") == 1 then
      test_filepath = normalize_windows_path(test_filepath)
    end
    options.set({ testify_enabled = true }) -- enable testify
    local filepaths = lib.find.go_test_filepaths(test_filepath)
    testify.lookup.initialize_lookup(filepaths) -- generate lookup
    local expected = {
      {
        id = test_filepath,
        name = "positions_test.go",
        path = test_filepath,
        type = "file",
      },
      {
        {
          id = test_filepath .. "::TestExampleTestSuite",
          name = "TestExampleTestSuite",
          path = test_filepath,
          type = "namespace",
        },
        {
          {
            id = test_filepath .. "::TestExampleTestSuite::TestExample",
            name = "TestExample",
            path = test_filepath,
            type = "test",
          },
        },
        {
          {
            id = test_filepath .. "::TestExampleTestSuite::TestExample2",
            name = "TestExample2",
            path = test_filepath,
            type = "test",
          },
        },
        {
          {
            id = test_filepath .. "::TestExampleTestSuite::TestSubTestOperand1",
            name = "TestSubTestOperand1",
            path = test_filepath,
            type = "test",
          },
          {
            {
              id = test_filepath
                .. '::TestExampleTestSuite::TestSubTestOperand1::"subtest"',
              name = '"subtest"',
              path = test_filepath,
              type = "test",
            },
          },
        },
        {
          {
            id = test_filepath .. "::TestExampleTestSuite::TestSubTestOperand2",
            name = "TestSubTestOperand2",
            path = test_filepath,
            type = "test",
          },
          {
            {
              id = test_filepath
                .. '::TestExampleTestSuite::TestSubTestOperand2::"subtest"',
              name = '"subtest"',
              path = test_filepath,
              type = "test",
            },
          },
        },
      },
      {
        {
          id = test_filepath .. "::TestExampleTestSuite2",
          name = "TestExampleTestSuite2",
          path = test_filepath,
          type = "namespace",
        },
        {
          {
            id = test_filepath .. "::TestExampleTestSuite2::TestExample",
            name = "TestExample",
            path = test_filepath,
            type = "test",
          },
        },
        {
          {
            id = test_filepath .. "::TestExampleTestSuite2::TestExample2",
            name = "TestExample2",
            path = test_filepath,
            type = "test",
          },
        },
      },
      {
        {
          id = test_filepath .. "::TestTrivial",
          name = "TestTrivial",
          path = test_filepath,
          type = "test",
        },
      },
      {
        {
          id = test_filepath .. "::TestOtherTestSuite",
          name = "TestOtherTestSuite",
          path = test_filepath,
          type = "namespace",
        },
        {
          {
            id = test_filepath .. "::TestOtherTestSuite::TestOther",
            name = "TestOther",
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
