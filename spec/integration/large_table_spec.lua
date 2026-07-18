local _ = require("plenary")
local nio = require("nio")
local path = require("neotest-golang.lib.path")

-- Regression test for https://github.com/fredrikaverpil/neotest-golang/issues/581
--
-- Table-driven tests with many cases used to have their *leading* cases dropped
-- during discovery: the combined tree-sitter query bound every struct element to
-- the trailing `for ... t.Run(...)` loop, so tree-sitter kept one in-progress
-- match per element until the loop and evicted the oldest matches once its match
-- limit was exceeded. The fixture below has more cases than that old limit; all
-- of them must now be discovered.
describe("Integration: large table-driven test discovery", function()
  local adapter = require("neotest-golang")

  local test_file = vim.uv.cwd()
    .. "/tests/go/internal/issue581/issue581_test.go"
  test_file = path.normalize_path(test_file)

  local expected_case_count = 50

  it("discovers every case in a large table-driven test", function()
    -- ===== ARRANGE / ACT =====
    local tree =
      nio.tests.with_async_context(adapter.discover_positions, test_file)
    assert.is_not_nil(tree, "discovery returned no tree")

    -- Collect discovered subtest names (positions nested under the function).
    local discovered = {}
    for _, pos in tree:iter() do
      if pos.type == "test" and pos.name ~= "TestManyTableCases" then
        -- Names come back quoted (e.g. `"case - 01"`); strip the quotes.
        local name = pos.name:gsub('^"(.*)"$', "%1")
        discovered[name] = true
      end
    end

    -- ===== ASSERT =====
    -- Every case from "case - 01" through "case - 50" must be present. The old
    -- behaviour dropped the first ~7+ cases (the exact count depended on the
    -- tree-sitter match limit), so any missing leading case is a regression.
    local missing = {}
    local found_count = 0
    for i = 1, expected_case_count do
      local name = string.format("case - %02d", i)
      if discovered[name] then
        found_count = found_count + 1
      else
        missing[#missing + 1] = name
      end
    end

    assert.equals(
      expected_case_count,
      found_count,
      "missing table-test cases (leading cases dropped): "
        .. vim.inspect(missing)
    )
  end)
end)
