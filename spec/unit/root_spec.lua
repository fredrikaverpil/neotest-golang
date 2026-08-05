local _ = require("plenary")
local adapter = require("neotest-golang")
local find = require("neotest-golang.lib.find")

describe("Root", function()
  local project_root = vim.fn.getcwd()

  before_each(function()
    find.clear_root_cache()
  end)

  after_each(function()
    find.clear_root_cache()
  end)

  it("returns the root of the Go project", function()
    local root = adapter.root(project_root)
    assert.equals(project_root, root)
  end)

  it("returns nil when the go binary is not on PATH", function()
    local original_executable = vim.fn.executable
    vim.fn.executable = function(name)
      if name == "go" then
        return 0
      end
      return original_executable(name)
    end

    local root = adapter.root(project_root)

    vim.fn.executable = original_executable
    assert.is_nil(root)
  end)
end)
