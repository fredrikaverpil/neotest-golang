local async = require("nio").tests
local neotest = require("neotest")

describe("neotest-golang integration", function()
  async.it("runs Go tests and verifies results", function()
    -- Initialize neotest and set up neotest-golang
    neotest.setup({
      adapters = {
        require("neotest-golang"),
      },
    })

    -- Run Go tests in the tests/go directory
    local results = neotest.run.run({ vim.fn.expand("tests/go") })

    -- Verify the results of the Go tests executed through neotest and neotest-golang
    for _, result in pairs(results) do
      assert.are.equal(result.status, "passed")
    end

    -- Ensure the exit code is 0 and all tests passed
    assert.are.equal(vim.v.shell_error, 0)
  end)
end)
