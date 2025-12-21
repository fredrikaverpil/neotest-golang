local _ = require("plenary")
local path = require("neotest-golang.lib.path")

describe("Path utilities", function()
  describe("is_absolute_pattern", function()
    it("Returns true for Unix absolute paths", function()
      assert.is_true(path.is_absolute_pattern("/usr/local/go/**"))
      assert.is_true(path.is_absolute_pattern("/home/user/project"))
      assert.is_true(path.is_absolute_pattern("/"))
    end)

    it("Returns true for Windows drive letter paths", function()
      assert.is_true(path.is_absolute_pattern("C:/Users/**"))
      assert.is_true(path.is_absolute_pattern("D:\\Projects\\**"))
      assert.is_true(path.is_absolute_pattern("c:/lowercase"))
    end)

    it("Returns false for relative paths", function()
      assert.is_false(path.is_absolute_pattern("**/vendor"))
      assert.is_false(path.is_absolute_pattern("src/**"))
      assert.is_false(path.is_absolute_pattern("foo/bar"))
      assert.is_false(path.is_absolute_pattern("vendor"))
    end)

    it("Handles edge cases", function()
      assert.is_false(path.is_absolute_pattern(""))
      assert.is_false(path.is_absolute_pattern(nil))
    end)
  end)

  describe("matches_glob_pattern", function()
    it("Matches double-star patterns at any depth", function()
      assert.is_true(path.matches_glob_pattern("vendor", "**/vendor"))
      assert.is_true(path.matches_glob_pattern("src/vendor", "**/vendor"))
      assert.is_true(path.matches_glob_pattern("a/b/c/vendor", "**/vendor"))
    end)

    it("Matches single-star patterns within segment", function()
      assert.is_true(path.matches_glob_pattern("foo/bar", "foo/*"))
      assert.is_true(path.matches_glob_pattern("foo/baz", "foo/*"))
      assert.is_false(path.matches_glob_pattern("foo/bar/baz", "foo/*"))
    end)

    it("Matches exact paths", function()
      assert.is_true(path.matches_glob_pattern("foo/bar", "foo/bar"))
      assert.is_false(path.matches_glob_pattern("foo/baz", "foo/bar"))
    end)

    it("Matches paths with content after pattern", function()
      assert.is_true(path.matches_glob_pattern("vendor/foo", "**/vendor/**"))
      assert.is_true(
        path.matches_glob_pattern("src/vendor/bar", "**/vendor/**")
      )
      -- Does not match without trailing content
      assert.is_false(path.matches_glob_pattern("vendor", "**/vendor/**"))
    end)

    it("Handles Windows-style paths by normalizing", function()
      assert.is_true(path.matches_glob_pattern("vendor\\foo", "**/vendor/**"))
      assert.is_true(path.matches_glob_pattern("src\\vendor", "**/vendor"))
    end)

    it("Handles empty inputs", function()
      assert.is_false(path.matches_glob_pattern("", "**/vendor"))
      assert.is_false(path.matches_glob_pattern("vendor", ""))
      assert.is_false(path.matches_glob_pattern(nil, "**/vendor"))
      assert.is_false(path.matches_glob_pattern("vendor", nil))
    end)

    it("Handles absolute path patterns", function()
      assert.is_true(
        path.matches_glob_pattern("/usr/local/go/src", "/usr/local/go/**")
      )
      assert.is_true(
        path.matches_glob_pattern(
          "/usr/local/go/src/runtime",
          "/usr/local/go/**"
        )
      )
      assert.is_false(
        path.matches_glob_pattern("/home/user/project", "/usr/local/go/**")
      )
    end)
  end)
end)
