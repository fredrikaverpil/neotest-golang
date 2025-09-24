local _ = require("plenary")
local adapter = require("neotest-golang")

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

  describe("Windows path handling", function()
    it("True - Windows path with backslashes", function()
      local file_path = "foo\\bar\\baz_test.go"
      assert.is_true(adapter.is_test_file(file_path))
    end)

    it("True - Windows path with drive letter", function()
      local file_path = "C:\\Users\\test\\project\\foo_test.go"
      assert.is_true(adapter.is_test_file(file_path))
    end)

    it("True - Windows UNC path", function()
      local file_path = "\\\\server\\share\\project\\foo_test.go"
      assert.is_true(adapter.is_test_file(file_path))
    end)

    it("True - Windows path with mixed separators", function()
      local file_path = "C:\\Users\\test/project\\foo_test.go"
      assert.is_true(adapter.is_test_file(file_path))
    end)

    it("False - Windows path but not a test file", function()
      local file_path = "C:\\Users\\test\\project\\foo_bar.go"
      assert.is_false(adapter.is_test_file(file_path))
    end)

    it("False - Windows path with different extension", function()
      local file_path = "C:\\Users\\test\\project\\foo_test.txt"
      assert.is_false(adapter.is_test_file(file_path))
    end)
  end)
end)
