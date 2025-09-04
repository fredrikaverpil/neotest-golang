local _ = require("plenary")
local adapter = require("neotest-golang")
local nio = require("nio")
local options = require("neotest-golang.options")

local function normalize_windows_path(path)
  if vim.fn.has("win32") == 1 then
    return path:gsub("/", "\\")
  end
  return path
end

--- Build minimal go test -json event lines for a passing test
local function build_go_test_json_lines(pkg, test_name)
  local function ev(tbl)
    return vim.json.encode(tbl)
  end
  return {
    ev({
      Time = "2025-01-01T00:00:00Z",
      Action = "run",
      Package = pkg,
      Test = test_name,
    }),
    ev({
      Time = "2025-01-01T00:00:01Z",
      Action = "output",
      Package = pkg,
      Test = test_name,
      Output = "=== RUN   " .. test_name,
    }),
    ev({
      Time = "2025-01-01T00:00:02Z",
      Action = "output",
      Package = pkg,
      Test = test_name,
      Output = "--- PASS: " .. test_name .. " (0.00s)",
    }),
    ev({
      Time = "2025-01-01T00:00:03Z",
      Action = "pass",
      Package = pkg,
      Test = test_name,
      Elapsed = 0.001,
    }),
    -- Package-level pass (optional but realistic)
    ev({
      Time = "2025-01-01T00:00:04Z",
      Action = "pass",
      Package = pkg,
      Elapsed = 0.002,
    }),
  }
end

describe("Integration: stream + results", function()
  it("produces passed results for a single test", function()
    -- Arrange
    options.set({
      runner = "go", -- ensure go-runner path for streaming via data() function
      colorize_test_output = true,
      sanitize_output = false,
      warn_test_results_missing = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/positions/positions_test.go"
    test_filepath = normalize_windows_path(test_filepath)

    -- Discover positions (neotest tree for this file)
    ---@type neotest.Tree
    local tree =
      nio.tests.with_async_context(adapter.discover_positions, test_filepath)

    -- Build a runspec for the file (so mapping includes all tests in file)
    local run_spec = adapter.build_spec({ tree = tree })
    assert.is_truthy(run_spec)
    assert.is_truthy(run_spec.stream)

    -- Prepare mocked go test -json lines for TestTopLevel
    local import_path =
      "github.com/fredrikaverpil/neotest-golang/internal/positions"
    local test_name = "TestTopLevel"
    local lines = build_go_test_json_lines(import_path, test_name)

    -- Stream once to populate cached results
    local first_call = true
    local function data_provider()
      if first_call then
        first_call = false
        return lines
      end
      return {}
    end

    local emit = run_spec.stream(data_provider)
    local streamed = emit()
    assert.is_truthy(streamed)

    -- Create the result.output file that process.test_results will read
    local output_path = vim.fs.normalize(vim.fn.tempname())
    vim.fn.writefile(lines, output_path)

    -- Act: process final results
    local strategy_result = { code = 0, output = output_path }
    local results = nio.tests.with_async_context(
      adapter.results,
      run_spec,
      strategy_result,
      tree
    )

    -- Assert: test-level result exists and passed
    local test_pos_id = test_filepath .. "::" .. test_name
    assert.is_truthy(results[test_pos_id])
    assert.are.equal("passed", results[test_pos_id].status)
    assert.is_truthy(results[test_pos_id].output)

    -- The output file should contain RUN/PASS markers (colorized or plain)
    local out_lines = vim.fn.readfile(results[test_pos_id].output)
    local found_run, found_pass = false, false
    for _, l in ipairs(out_lines) do
      if l:find("RUN", 1, true) then
        found_run = true
      end
      if l:find("PASS", 1, true) then
        found_pass = true
      end
    end
    assert.is_true(found_run)
    assert.is_true(found_pass)

    -- File-level node should have a result (root pos)
    local file_pos_id = test_filepath
    assert.is_truthy(results[file_pos_id])
    assert.are.equal("passed", results[file_pos_id].status)
  end)
end)
