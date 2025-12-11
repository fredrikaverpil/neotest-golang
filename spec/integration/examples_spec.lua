local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: Example functions", function()
  it(
    "file reports test discovery and execution for Example functions",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      options.set(test_options)

      local position_id = vim.uv.cwd()
        .. "/tests/go/internal/examples/examples_test.go"
      position_id = path.normalize_path(position_id)

      -- Expected complete adapter execution result
      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Package-level result (from streaming) - should fail due to failing examples
          [path.get_directory(position_id)] = {
            status = "failed",
            errors = {},
          },
          -- File-level result - should fail due to failing examples
          [position_id] = {
            status = "failed",
            errors = {},
          },
          -- Regular test result
          [position_id .. "::TestAdd"] = {
            status = "passed",
            errors = {},
          },
          -- Package-level Example (should pass)
          [position_id .. "::Example"] = {
            status = "passed",
            errors = {},
          },
          -- Example function that passes
          [position_id .. "::ExampleAdd"] = {
            status = "passed",
            errors = {},
          },
          -- Example function that fails (incorrect output comment)
          [position_id .. "::ExampleAdd_failing"] = {
            status = "failed",
            errors = {},
          },
          -- Example for Multiply (should pass)
          [position_id .. "::ExampleMultiply"] = {
            status = "passed",
            errors = {},
          },
          -- Second example for Multiply (should pass)
          [position_id .. "::ExampleMultiply_second"] = {
            status = "passed",
            errors = {},
          },
          -- Example with method-style naming (should fail)
          [position_id .. "::ExampleCalculator_Add"] = {
            status = "failed",
            errors = {},
          },
        },
        run_spec = {
          command = {}, -- this will be replaced in the assertion
          context = {
            pos_id = position_id,
          },
        },
        strategy_result = {
          code = 1, -- Exit code 1 because some examples fail
        },
        tree = {
          -- this will be replaced in the assertion
          _children = {},
          _nodes = {},
          _key = function()
            return ""
          end,
        },
      }

      -- ===== ACT =====
      ---@type AdapterExecutionResult
      local got = integration.execute_adapter_direct(position_id)

      -- ===== ASSERT =====
      -- Copy dynamic run_spec fields
      want.run_spec.command = got.run_spec.command
      want.run_spec.cwd = got.run_spec.cwd
      want.run_spec.env = got.run_spec.env
      want.run_spec.stream = got.run_spec.stream
      want.run_spec.strategy = got.run_spec.strategy
      want.run_spec.context.golist_data = got.run_spec.context.golist_data
      want.run_spec.context.stop_filestream =
        got.run_spec.context.stop_filestream
      want.run_spec.context.test_output_json_filepath =
        got.run_spec.context.test_output_json_filepath

      -- Copy dynamic strategy_result fields
      want.strategy_result.output = got.strategy_result.output

      -- Copy tree field if present
      want.tree = got.tree

      -- Copy dynamic output paths for all results
      for pos_id, result in pairs(got.results) do
        if want.results[pos_id] then
          -- Copy output path if it exists
          if result.output then
            want.results[pos_id].output = result.output
          end
          -- Copy short field if it exists
          if result.short then
            want.results[pos_id].short = result.short
          end
        end
      end

      -- Helper function to sort errors for order-agnostic comparison
      local function sort_errors(errors)
        if not errors or #errors == 0 then
          return errors or {}
        end
        local sorted = vim.deepcopy(errors)
        table.sort(sorted, function(a, b)
          if a.line ~= b.line then
            return a.line < b.line
          end
          return a.message < b.message
        end)
        return sorted
      end

      -- Sort errors in both expected and actual results for order-agnostic comparison
      for pos_id, result in pairs(want.results) do
        if result.errors then
          result.errors = sort_errors(result.errors)
        end
      end
      for pos_id, result in pairs(got.results) do
        if result.errors then
          result.errors = sort_errors(result.errors)
        end
      end

      assert.are.same(
        vim.inspect(want),
        vim.inspect(got),
        "Complete adapter execution result should match"
      )
    end
  )

  it("failing Example function executes correctly", function()
    -- ===== ARRANGE =====
    local test_options = options.get()
    test_options.runner = "gotestsum"
    options.set(test_options)

    local position_id = vim.uv.cwd()
      .. "/tests/go/internal/examples/examples_test.go::ExampleAdd_failing"
    position_id = path.normalize_path(position_id)
    local file_id = vim.uv.cwd()
      .. "/tests/go/internal/examples/examples_test.go"
    file_id = path.normalize_path(file_id)

    -- Expected complete adapter execution result
    ---@type AdapterExecutionResult
    local want = {
      results = {
        -- Package-level result (from streaming)
        [path.get_directory(position_id)] = {
          status = "failed",
          errors = {},
        },
        -- File-level result
        [file_id] = {
          status = "failed",
          errors = {},
        },
        -- Individual failing example
        [position_id] = {
          status = "failed",
          errors = {},
        },
      },
      run_spec = {
        command = {},
        context = {
          pos_id = position_id,
        },
      },
      strategy_result = {
        code = 1, -- Exit code 1 for failing test
      },
      tree = {
        _children = {},
        _nodes = {},
        _key = function()
          return ""
        end,
      },
    }

    -- ===== ACT =====
    ---@type AdapterExecutionResult
    local got = integration.execute_adapter_direct(position_id)

    -- ===== ASSERT =====
    -- Copy dynamic fields
    want.run_spec.command = got.run_spec.command
    want.run_spec.cwd = got.run_spec.cwd
    want.run_spec.env = got.run_spec.env
    want.run_spec.stream = got.run_spec.stream
    want.run_spec.strategy = got.run_spec.strategy
    want.run_spec.context.golist_data = got.run_spec.context.golist_data
    want.run_spec.context.stop_filestream = got.run_spec.context.stop_filestream
    want.run_spec.context.test_output_json_filepath =
      got.run_spec.context.test_output_json_filepath
    want.run_spec.context.process_test_results =
      got.run_spec.context.process_test_results
    want.strategy_result.output = got.strategy_result.output
    want.tree = got.tree

    -- Copy dynamic output paths
    for pos_id, result in pairs(got.results) do
      if want.results[pos_id] then
        if result.output then
          want.results[pos_id].output = result.output
        end
        if result.short then
          want.results[pos_id].short = result.short
        end
      end
    end

    assert.are.same(
      vim.inspect(want),
      vim.inspect(got),
      "Failing Example function should be detected correctly"
    )
  end)

  it("passing Example function executes correctly", function()
    -- ===== ARRANGE =====
    local test_options = options.get()
    test_options.runner = "gotestsum"
    options.set(test_options)

    local position_id = vim.uv.cwd()
      .. "/tests/go/internal/examples/examples_test.go::ExampleAdd"
    position_id = path.normalize_path(position_id)
    local file_id = vim.uv.cwd()
      .. "/tests/go/internal/examples/examples_test.go"
    file_id = path.normalize_path(file_id)

    -- Expected complete adapter execution result
    ---@type AdapterExecutionResult
    local want = {
      results = {
        -- Package-level result (from streaming)
        [path.get_directory(position_id)] = {
          status = "passed",
          errors = {},
        },
        -- File-level result
        [file_id] = {
          status = "passed",
          errors = {},
        },
        -- Individual passing example
        [position_id] = {
          status = "passed",
          errors = {},
        },
      },
      run_spec = {
        command = {},
        context = {
          pos_id = position_id,
        },
      },
      strategy_result = {
        code = 0, -- Exit code 0 for passing test
      },
      tree = {
        _children = {},
        _nodes = {},
        _key = function()
          return ""
        end,
      },
    }

    -- ===== ACT =====
    ---@type AdapterExecutionResult
    local got = integration.execute_adapter_direct(position_id)

    -- ===== ASSERT =====
    -- Copy dynamic fields
    want.run_spec.command = got.run_spec.command
    want.run_spec.cwd = got.run_spec.cwd
    want.run_spec.env = got.run_spec.env
    want.run_spec.stream = got.run_spec.stream
    want.run_spec.strategy = got.run_spec.strategy
    want.run_spec.context.golist_data = got.run_spec.context.golist_data
    want.run_spec.context.stop_filestream = got.run_spec.context.stop_filestream
    want.run_spec.context.test_output_json_filepath =
      got.run_spec.context.test_output_json_filepath
    want.run_spec.context.process_test_results =
      got.run_spec.context.process_test_results
    want.strategy_result.output = got.strategy_result.output
    want.tree = got.tree

    -- Copy dynamic output paths
    for pos_id, result in pairs(got.results) do
      if want.results[pos_id] then
        if result.output then
          want.results[pos_id].output = result.output
        end
        if result.short then
          want.results[pos_id].short = result.short
        end
      end
    end

    assert.are.same(
      vim.inspect(want),
      vim.inspect(got),
      "Passing Example function should be detected correctly"
    )
  end)
end)
