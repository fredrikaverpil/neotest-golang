local options = require("neotest-golang.options")
local stream = require("neotest-golang.lib.stream")

local package_import = "example.com/repo/pkg"
local package_dir = "/tmp/neotest-stream/pkg"
local file_path = package_dir .. "/file_test.go"

local function make_event(action, test_name, output)
  return vim.json.encode({
    Action = action,
    Package = package_import,
    Test = test_name,
    Output = output,
  })
end

local function make_tree()
  local nodes = {
    {
      data = function()
        return {
          type = "file",
          id = file_path,
          path = file_path,
        }
      end,
    },
    {
      data = function()
        return {
          type = "test",
          id = file_path .. "::TestOne",
          path = file_path,
        }
      end,
    },
    {
      data = function()
        return {
          type = "test",
          id = file_path .. "::TestTwo",
          path = file_path,
        }
      end,
    },
  }

  return {
    iter_nodes = function()
      local index = 0
      return function()
        index = index + 1
        if nodes[index] then
          return index, nodes[index]
        end
      end
    end,
  }
end

describe("streaming results", function()
  before_each(function()
    options.setup({
      runner = "go",
      performance_monitoring = false,
    })
    stream.cached_results = {}
  end)

  after_each(function()
    for _, result in pairs(stream.cached_results) do
      if result.output and vim.uv.fs_stat(result.output) then
        vim.uv.fs_unlink(result.output)
      end
    end
    stream.cached_results = {}
  end)

  it(
    "reports each completed test before the full stream has finished",
    function()
      -- Arrange
      local next_lines = {}
      local stream_factory = stream.new(make_tree(), {
        {
          ImportPath = package_import,
          Dir = package_dir,
        },
      })
      local stream_results = stream_factory(function()
        return next_lines
      end)

      -- Act: only the first test has completed.
      next_lines = {
        make_event("run", "TestOne"),
        make_event("output", "TestOne", "=== RUN   TestOne\n"),
        make_event("pass", "TestOne"),
      }
      local first_results = stream_results()

      -- Assert: the first result is available immediately, without waiting for TestTwo.
      assert.are_same("passed", first_results[file_path .. "::TestOne"].status)
      assert.is_nil(first_results[file_path .. "::TestTwo"])

      -- Act: a later stream chunk completes the second test.
      next_lines = {
        make_event("run", "TestTwo"),
        make_event("fail", "TestTwo"),
      }
      local second_results = stream_results()

      -- Assert: later updates are still merged into the cache.
      assert.are_same("passed", second_results[file_path .. "::TestOne"].status)
      assert.are_same("failed", second_results[file_path .. "::TestTwo"].status)
    end
  )
end)
