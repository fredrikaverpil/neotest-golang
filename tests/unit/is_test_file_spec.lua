local adapter = require("neotest-golang")
local _ = require("plenary")

describe("Is test file", function()
  it("True - Path to file", function()
    local file_path = "foo/bar/baz_test.go"
    assert.is_true(adapter.is_test_file(file_path))
  end)

  it("True - Just filename", function()
    local file_path = "foo_test.go"
    assert.is_true(adapter.is_test_file(file_path))
  end)

  it("False - Not a test file", function()
    local file_path = "foo_bar.go"
    assert.is_false(adapter.is_test_file(file_path))
  end)
end)
