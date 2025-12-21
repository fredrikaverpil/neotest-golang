local _ = require("plenary")
local adapter_module = require("neotest-golang")

describe("Filter directories", function()
  describe("With default configuration", function()
    local adapter

    before_each(function()
      adapter = adapter_module()
    end)

    it("Filters .git directory", function()
      assert.is_false(adapter.filter_dir(".git", ".", "/project/root"))
    end)

    it("Filters node_modules directory", function()
      assert.is_false(adapter.filter_dir("node_modules", ".", "/project/root"))
    end)

    it("Filters .venv directory", function()
      assert.is_false(adapter.filter_dir(".venv", ".", "/project/root"))
    end)

    it("Filters venv directory", function()
      assert.is_false(adapter.filter_dir("venv", ".", "/project/root"))
    end)

    it("Allows regular directories", function()
      assert.is_true(adapter.filter_dir("src", ".", "/project/root"))
      assert.is_true(adapter.filter_dir("pkg", ".", "/project/root"))
      assert.is_true(adapter.filter_dir("cmd", ".", "/project/root"))
    end)
  end)

  describe("With custom filter_dirs configuration", function()
    it("Filters custom directories", function()
      local adapter = adapter_module({
        filter_dirs = { ".git", "vendor", "third_party" },
      })
      assert.is_false(adapter.filter_dir("vendor", ".", "/project/root"))
      assert.is_false(adapter.filter_dir("third_party", ".", "/project/root"))
      assert.is_false(adapter.filter_dir(".git", ".", "/project/root"))
    end)

    it("Allows directories not in filter list", function()
      local adapter = adapter_module({
        filter_dirs = { ".git", "vendor" },
      })
      assert.is_true(adapter.filter_dir("node_modules", ".", "/project/root"))
      assert.is_true(adapter.filter_dir("venv", ".", "/project/root"))
      assert.is_true(adapter.filter_dir("src", ".", "/project/root"))
    end)

    it("Works with empty filter_dirs list", function()
      local adapter = adapter_module({
        filter_dirs = {},
      })
      assert.is_true(adapter.filter_dir(".git", ".", "/project/root"))
      assert.is_true(adapter.filter_dir("node_modules", ".", "/project/root"))
      assert.is_true(adapter.filter_dir("vendor", ".", "/project/root"))
    end)
  end)

  describe("With filter_dirs as function", function()
    it("Filters directories returned by function", function()
      local adapter = adapter_module({
        filter_dirs = function()
          return { ".git", "build", "dist" }
        end,
      })
      assert.is_false(adapter.filter_dir("build", ".", "/project/root"))
      assert.is_false(adapter.filter_dir("dist", ".", "/project/root"))
      assert.is_false(adapter.filter_dir(".git", ".", "/project/root"))
    end)

    it("Allows directories not returned by function", function()
      local adapter = adapter_module({
        filter_dirs = function()
          return { ".git" }
        end,
      })
      assert.is_true(adapter.filter_dir("vendor", ".", "/project/root"))
      assert.is_true(adapter.filter_dir("src", ".", "/project/root"))
    end)
  end)

  describe("With filter_dir_patterns configuration", function()
    it("Filters directories matching double-star pattern", function()
      local adapter = adapter_module({
        filter_dirs = {},
        filter_dir_patterns = { "**/vendor" },
      })
      -- vendor at root level
      assert.is_false(adapter.filter_dir("vendor", ".", "/project/root"))
      -- vendor nested in src
      assert.is_false(adapter.filter_dir("vendor", "src", "/project/root"))
      -- vendor deeply nested
      assert.is_false(adapter.filter_dir("vendor", "a/b/c", "/project/root"))
      -- unrelated directory
      assert.is_true(adapter.filter_dir("src", ".", "/project/root"))
    end)

    it("Filters directories matching single-level pattern", function()
      local adapter = adapter_module({
        filter_dirs = {},
        filter_dir_patterns = { "foo/*" },
      })
      -- Matches foo/bar
      assert.is_false(adapter.filter_dir("bar", "foo", "/project/root"))
      -- Does not match baz/bar
      assert.is_true(adapter.filter_dir("bar", "baz", "/project/root"))
      -- Does not match foo itself at root
      assert.is_true(adapter.filter_dir("foo", ".", "/project/root"))
    end)

    it("Filters specific nested path without affecting others", function()
      local adapter = adapter_module({
        filter_dirs = {},
        filter_dir_patterns = { "foo/baz/**" },
      })
      -- Filters foo/baz/anything
      assert.is_false(
        adapter.filter_dir("anything", "foo/baz", "/project/root")
      )
      -- Does NOT filter bar/baz
      assert.is_true(adapter.filter_dir("anything", "bar/baz", "/project/root"))
    end)

    it("Filters directories matching absolute path pattern", function()
      local adapter = adapter_module({
        filter_dirs = {},
        filter_dir_patterns = { "/usr/local/go/**" },
      })
      -- Matches absolute path
      assert.is_false(adapter.filter_dir("src", ".", "/usr/local/go"))
      assert.is_false(adapter.filter_dir("runtime", "src", "/usr/local/go"))
      -- Does not match other roots
      assert.is_true(adapter.filter_dir("src", ".", "/project/root"))
    end)

    it("Works with filter_dir_patterns as function", function()
      local adapter = adapter_module({
        filter_dirs = {},
        filter_dir_patterns = function()
          return { "**/build" }
        end,
      })
      assert.is_false(adapter.filter_dir("build", ".", "/project/root"))
      assert.is_false(adapter.filter_dir("build", "src", "/project/root"))
      assert.is_true(adapter.filter_dir("src", ".", "/project/root"))
    end)

    it("Works alongside filter_dirs", function()
      local adapter = adapter_module({
        filter_dirs = { ".git" },
        filter_dir_patterns = { "**/vendor" },
      })
      -- filter_dirs still works
      assert.is_false(adapter.filter_dir(".git", ".", "/project/root"))
      -- filter_dir_patterns works
      assert.is_false(adapter.filter_dir("vendor", ".", "/project/root"))
      -- unrelated directory allowed
      assert.is_true(adapter.filter_dir("src", ".", "/project/root"))
    end)

    it("Handles empty filter_dir_patterns", function()
      local adapter = adapter_module({
        filter_dirs = {},
        filter_dir_patterns = {},
      })
      assert.is_true(adapter.filter_dir("vendor", ".", "/project/root"))
      assert.is_true(adapter.filter_dir("build", ".", "/project/root"))
    end)

    it("Handles multiple patterns", function()
      local adapter = adapter_module({
        filter_dirs = {},
        filter_dir_patterns = { "**/vendor", "**/node_modules", "build/*" },
      })
      assert.is_false(adapter.filter_dir("vendor", ".", "/project/root"))
      assert.is_false(adapter.filter_dir("node_modules", ".", "/project/root"))
      assert.is_false(adapter.filter_dir("output", "build", "/project/root"))
      assert.is_true(adapter.filter_dir("src", ".", "/project/root"))
    end)
  end)
end)
