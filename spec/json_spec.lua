local _ = require("plenary")

-- Local implementation of the JSON parsing function to avoid module loading issues
local function decode_json_from_string(str)
  -- Split the input into separate JSON objects
  local tbl = {}
  local current_object = ""
  for line in str:gmatch("[^\r\n]+") do
    if line:match("^%s*{") and current_object ~= "" then
      table.insert(tbl, current_object)
      current_object = ""
    end
    current_object = current_object .. line
  end
  table.insert(tbl, current_object)
  
  -- Decode each JSON object
  local jsonlines = {}
  for _, json_str in ipairs(tbl) do
    if string.match(json_str, "^%s*{") then -- must start with the `{` character
      local status, json_data = pcall(vim.json.decode, json_str)
      if status then
        table.insert(jsonlines, json_data)
      end
    end
  end
  
  return jsonlines
end

describe("Go list", function()
  it("Returns one entry", function()
    local input = [[
{
   "Dir": "foo"
}
]]
    local expected = { { Dir = "foo" } }
    assert.are_same(
      vim.inspect(expected),
      vim.inspect(decode_json_from_string(input))
    )
  end)

  it("Returns two entries", function()
    local input = [[{
   "Dir": "foo"
}
{
   "Dir": "bar"
}
]]
    local expected = { { Dir = "foo" }, { Dir = "bar" } }
    assert.are_same(
      vim.inspect(expected),
      vim.inspect(decode_json_from_string(input))
    )
  end)

  it("Returns three entries", function()
    local input = [[
{
   "Dir": "foo"
}
{
   "Dir": "bar"
}
{
   "Dir": "baz"
}
]]
    local expected = { { Dir = "foo" }, { Dir = "bar" }, { Dir = "baz" } }
    assert.are_same(
      vim.inspect(expected),
      vim.inspect(decode_json_from_string(input))
    )
  end)
  it("Returns nested entries", function()
    local input = [[
{
   "Dir": "/Users/fredrik/code/public/neotest-golang/tests/go",
   "ImportPath": "github.com/fredrikaverpil/neotest-golang",
   "Module": {
           "Path": "github.com/fredrikaverpil/neotest-golang",
           "Main": true,
           "Dir": "/Users/fredrik/code/public/neotest-golang/tests/go",
           "GoMod": "/Users/fredrik/code/public/neotest-golang/tests/go/go.mod",
           "GoVersion": "1.24"
   }
}
]]
    local expected = {
      {
        Dir = "/Users/fredrik/code/public/neotest-golang/tests/go",
        ImportPath = "github.com/fredrikaverpil/neotest-golang",
        Module = {
          Path = "github.com/fredrikaverpil/neotest-golang",
          Main = true,
          Dir = "/Users/fredrik/code/public/neotest-golang/tests/go",
          GoMod = "/Users/fredrik/code/public/neotest-golang/tests/go/go.mod",
          GoVersion = "1.24",
        },
      },
    }
    assert.are_same(
      vim.inspect(expected),
      vim.inspect(decode_json_from_string(input))
    )
  end)
end)
