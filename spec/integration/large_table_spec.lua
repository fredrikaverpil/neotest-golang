local _ = require("plenary")
local nio = require("nio")
local path = require("neotest-golang.lib.path")

-- Regression test for https://github.com/fredrikaverpil/neotest-golang/issues/581
--
-- Table-driven tests with many cases used to have their leading cases dropped
-- during discovery: the combined tree-sitter query bound every struct element
-- to the trailing `for ... t.Run(...)` loop, so tree-sitter kept one in-progress
-- match alive per element until the loop and evicted the earliest-starting
-- matches once its match limit (256 by default) was exceeded. With that query
-- the keyed table below dropped its first 29 of 50 cases (only 21 detected).
--
-- The fixture exercises all four rewritten discovery shapes; every case of each
-- must now be discovered.
describe("Integration: large table-driven test discovery", function()
  local adapter = require("neotest-golang")

  local test_file = vim.uv.cwd()
    .. "/tests/go/internal/issue581/issue581_test.go"
  test_file = path.normalize_path(test_file)

  local case_count = 50
  local functions = {
    "TestManyKeyedCases",
    "TestManyUnkeyedCases",
    "TestManyMapCases",
    "TestManyInlineCases",
  }

  for _, func in ipairs(functions) do
    it("discovers every case in " .. func, function()
      -- Discovery is cached per file, so re-discovering per test is cheap.
      local tree =
        nio.tests.with_async_context(adapter.discover_positions, test_file)
      assert.is_not_nil(tree, "discovery returned no tree")

      -- Collect the subtest case names discovered under this function.
      local discovered = {}
      for _, pos in tree:iter() do
        local prefix = test_file .. "::" .. func .. '::"'
        if pos.type == "test" and vim.startswith(pos.id, prefix) then
          discovered[pos.name:gsub('^"(.*)"$', "%1")] = true
        end
      end

      -- Every case from "case - 01" through "case - 50" must be present. The
      -- old behaviour dropped a run of leading cases, so any missing leading
      -- case is a regression.
      local missing = {}
      for i = 1, case_count do
        local name = string.format("case - %02d", i)
        if not discovered[name] then
          missing[#missing + 1] = name
        end
      end

      assert.equals(
        0,
        #missing,
        "missing table-test cases in " .. func .. ": " .. vim.inspect(missing)
      )
    end)
  end
end)
