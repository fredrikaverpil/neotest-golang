local _ = require("plenary")
local discovery_cache = require("neotest-golang.lib.discovery_cache")

describe("Discovery cache", function()
  local test_file = vim.fn.tempname() .. "_test.go"
  local mock_tree = { type = "file", name = "test_file" }

  before_each(function()
    discovery_cache.clear()
    local file = io.open(test_file, "w")
    if file then
      file:write("package main\n")
      file:close()
    end
  end)

  after_each(function()
    discovery_cache.clear()
    os.remove(test_file)
  end)

  describe("get", function()
    it("returns nil for uncached file", function()
      local result = discovery_cache.get(test_file)
      assert.is_nil(result)
    end)

    it("returns nil for non-existent file", function()
      local result = discovery_cache.get("/nonexistent/path/test.go")
      assert.is_nil(result)
    end)
  end)

  describe("set and get", function()
    it("caches and retrieves tree", function()
      discovery_cache.set(test_file, mock_tree)
      local result = discovery_cache.get(test_file)
      assert.are.same(mock_tree, result)
    end)

    it("returns nil after file modification", function()
      discovery_cache.set(test_file, mock_tree)

      vim.uv.sleep(1100)

      local file = io.open(test_file, "w")
      if file then
        file:write("package main\n\n// modified\n")
        file:close()
      end

      local result = discovery_cache.get(test_file)
      assert.is_nil(result)
    end)
  end)

  describe("invalidate", function()
    it("removes specific file from cache", function()
      discovery_cache.set(test_file, mock_tree)
      discovery_cache.invalidate(test_file)
      local result = discovery_cache.get(test_file)
      assert.is_nil(result)
    end)
  end)

  describe("clear", function()
    it("removes all entries from cache", function()
      discovery_cache.set(test_file, mock_tree)
      local stats_before = discovery_cache.stats()
      assert.are.equal(1, stats_before.size)

      discovery_cache.clear()

      local stats_after = discovery_cache.stats()
      assert.are.equal(0, stats_after.size)
    end)
  end)

  describe("stats", function()
    it("returns correct size and files", function()
      discovery_cache.set(test_file, mock_tree)
      local stats = discovery_cache.stats()
      assert.are.equal(1, stats.size)
      assert.are.same({ test_file }, stats.files)
    end)

    it("returns empty stats for empty cache", function()
      local stats = discovery_cache.stats()
      assert.are.equal(0, stats.size)
      assert.are.same({}, stats.files)
    end)
  end)
end)
