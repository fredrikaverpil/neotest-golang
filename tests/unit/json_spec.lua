local _ = require("plenary")
local lib = require("neotest-golang.lib")

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
      vim.inspect(lib.json.decode_from_string(input))
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
      vim.inspect(lib.json.decode_from_string(input))
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
      vim.inspect(lib.json.decode_from_string(input))
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
      vim.inspect(lib.json.decode_from_string(input))
    )
  end)
end)

describe("Go test JSON decoding", function()
  it("Handles complete JSON lines", function()
    local input = {
      '{"Action":"run","Package":"example.com/test","Test":"TestFoo"}',
      '{"Action":"output","Package":"example.com/test","Test":"TestFoo","Output":"=== RUN   TestFoo\\n"}',
      '{"Action":"pass","Package":"example.com/test","Test":"TestFoo","Elapsed":0.001}',
    }
    local result = lib.json.decode_from_table(input, false)
    assert.equals(3, #result)
    assert.equals("run", result[1].Action)
    assert.equals("output", result[2].Action)
    assert.equals("pass", result[3].Action)
    assert.equals("TestFoo", result[1].Test)
  end)

  it("Handles JSON lines split across multiple array elements", function()
    local input = {
      '{"Action":"run","Package":"example.com/test",',
      '"Test":"TestFoo"}',
      '{"Action":"output","Package":"example.com/test","Test":"TestFoo",',
      '"Output":"=== RUN   TestFoo\\n"}',
      '{"Action":"pass","Package":"example.com/test",',
      '"Test":"TestFoo","Elapsed":0.001}',
    }
    local result = lib.json.decode_from_table(input, false)
    assert.equals(3, #result)
    assert.equals("run", result[1].Action)
    assert.equals("output", result[2].Action)
    assert.equals("pass", result[3].Action)
    assert.equals("TestFoo", result[1].Test)
  end)

  it("Handles test names with { } characters", function()
    local input = {
      '{"Action":"run","Test":"TestNames/Regexp_characters_{_}_[_]_are_ok"}',
      '{"Action":"output","Test":"TestNames/Regexp_characters_{_}_[_]_are_ok","Output":"PASS\\n"}',
    }
    local result = lib.json.decode_from_table(input, false)
    assert.equals(2, #result)
    assert.equals("TestNames/Regexp_characters_{_}_[_]_are_ok", result[1].Test)
    assert.equals("TestNames/Regexp_characters_{_}_[_]_are_ok", result[2].Test)
  end)

  it("Handles split JSON with test names containing { } characters", function()
    local input = {
      '{"Action":"run",',
      '"Test":"TestNames/Regexp_characters_{_}_[_]_are_ok"}',
      '{"Action":"output",',
      '"Test":"TestNames/Regexp_characters_{_}_[_]_are_ok",',
      '"Output":"PASS\\n"}',
    }
    local result = lib.json.decode_from_table(input, false)
    assert.equals(2, #result)
    assert.equals("TestNames/Regexp_characters_{_}_[_]_are_ok", result[1].Test)
    assert.equals("TestNames/Regexp_characters_{_}_[_]_are_ok", result[2].Test)
  end)

  it("Handles test output containing JSON-like text", function()
    local input = {
      '{"Action":"output","Test":"TestJSON","Output":"Expected: {\\"foo\\": \\"bar\\"}\\n"}',
      '{"Action":"output","Test":"TestJSON","Output":"Got: {\\"foo\\": \\"baz\\"}\\n"}',
    }
    local result = lib.json.decode_from_table(input, false)
    assert.equals(2, #result)
    assert.equals('Expected: {"foo": "bar"}\n', result[1].Output)
    assert.equals('Got: {"foo": "baz"}\n', result[2].Output)
  end)

  it("Handles mixed JSON and non-JSON lines with wrap_non_json", function()
    local input = {
      "Some error output",
      '{"Action":"run","Test":"TestBar"}',
      '{"Action":"output",',
      '"Test":"TestBar","Output":"test output\\n"}',
      "Another non-JSON line",
      '{"Action":"pass","Test":"TestBar","Elapsed":0.002}',
    }
    local result = lib.json.decode_from_table(input, true)
    assert.equals(5, #result)
    -- First item should be the non-JSON line converted to output
    assert.equals("output", result[1].Action)
    assert.equals("Some error output", result[1].Output)
    -- Second should be the run action
    assert.equals("run", result[2].Action)
    -- Third should be the output action
    assert.equals("output", result[3].Action)
    assert.equals("test output\n", result[3].Output)
    -- Fourth should be the non-JSON line
    assert.equals("output", result[4].Action)
    assert.equals("Another non-JSON line", result[4].Output)
    -- Fifth should be the pass action
    assert.equals("pass", result[5].Action)
  end)

  it("Handles multi-line JSON objects", function()
    local input = [[
{
  "Action": "run",
  "Package": "example.com/test",
  "Test": "TestMultiline"
}
{
  "Action": "pass",
  "Package": "example.com/test",
  "Test": "TestMultiline",
  "Elapsed": 0.003
}
]]
    local result = lib.json.decode_from_string(input)
    assert.equals(2, #result)
    assert.equals("run", result[1].Action)
    assert.equals("pass", result[2].Action)
    assert.equals("TestMultiline", result[1].Test)
    assert.equals("TestMultiline", result[2].Test)
  end)
end)
