local _ = require("plenary")
local options = require("neotest-golang.options")
local results_finalize = require("neotest-golang.results_finalize")

describe("results_finalize.test_results", function()
  -- A skipped runspec is produced for positions without tests (e.g. a file
  -- without Go test functions). Such a runspec carries no test output to parse,
  -- so result finalization must short-circuit regardless of the configured
  -- runner. Previously the "gotestsum" runner threw "Gotestsum JSON output file
  -- path not provided" in this case (issue #574).
  local runners = {
    { name = "go runner", runner = "go" },
    { name = "gotestsum runner", runner = "gotestsum" },
  }

  for _, case in ipairs(runners) do
    it("returns a skipped result for the " .. case.name, function()
      -- Arrange
      options.setup({ runner = case.runner })
      local pos_id = "/path/to/file_test.go"
      local spec = {
        context = {
          pos_id = pos_id,
          golist_data = {},
          skipped = true,
          stop_filestream = function() end,
        },
      }
      local result = { code = 0 }
      local tree = {
        data = function()
          return { id = pos_id }
        end,
      }

      -- Act
      local got = results_finalize.test_results(spec, result, tree)

      -- Assert
      assert.are_same({ [pos_id] = { status = "skipped" } }, got)
    end)
  end
end)
