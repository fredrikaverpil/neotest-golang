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
end)
