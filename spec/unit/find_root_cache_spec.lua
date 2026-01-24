local _ = require("plenary")
local find = require("neotest-golang.lib.find")

describe("Find root caching", function()
  -- Get the actual project root for testing
  local project_root = vim.fn.getcwd()
  local submodule_path = project_root .. "/tests/features/submodule"

  before_each(function()
    -- Clear cache before each test to ensure clean state
    find.clear_root_cache()
  end)

  after_each(function()
    -- Clean up after tests
    find.clear_root_cache()
  end)

  describe("root_for_tests", function()
    it("returns the project root for the main directory", function()
      local root = find.root_for_tests(project_root)
      assert.is_not_nil(root)
      assert.equals(project_root, root)
    end)

    it("caches the first discovered root", function()
      -- First call should discover and cache the root
      local first_root = find.root_for_tests(project_root)
      assert.is_not_nil(first_root)

      -- Second call with the same path should return the same root
      local second_root = find.root_for_tests(project_root)
      assert.equals(first_root, second_root)
    end)

    it("returns cached root for nested paths under the cached root", function()
      -- First, discover and cache the project root
      local first_root = find.root_for_tests(project_root)
      assert.is_not_nil(first_root)
      assert.equals(project_root, first_root)

      -- Now ask for the root of the nested submodule path
      -- Even though it has its own go.mod, we should get the cached project root
      local nested_root = find.root_for_tests(submodule_path)
      assert.equals(project_root, nested_root)
    end)

    it("discovers submodule root when cache is empty", function()
      -- When cache is empty and we start from submodule, it should find
      -- the submodule's own go.mod as the root
      local root = find.root_for_tests(submodule_path)
      assert.is_not_nil(root)
      assert.equals(submodule_path, root)
    end)
  end)
end)
