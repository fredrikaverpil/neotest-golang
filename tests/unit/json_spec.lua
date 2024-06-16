local json = require("neotest-golang.json")

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
      vim.inspect(json.process_golist_output(input))
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
      vim.inspect(json.process_golist_output(input))
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
      vim.inspect(json.process_golist_output(input))
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
           "GoVersion": "1.22.2"
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
          GoVersion = "1.22.2",
        },
      },
    }
    assert.are_same(
      vim.inspect(expected),
      vim.inspect(json.process_golist_output(input))
    )
  end)
end)
