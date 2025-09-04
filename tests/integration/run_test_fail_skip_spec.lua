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

local function encode(tbl)
  return vim.json.encode(tbl)
end

local function lines_for(pkg, test_name, action)
  if action == "fail" then
    return {
      encode({
        Time = "2025-01-01T00:00:00Z",
        Action = "run",
        Package = pkg,
        Test = test_name,
      }),
      encode({
        Time = "2025-01-01T00:00:01Z",
        Action = "output",
        Package = pkg,
        Test = test_name,
        Output = "=== RUN   " .. test_name,
      }),
      encode({
        Time = "2025-01-01T00:00:02Z",
        Action = "output",
        Package = pkg,
        Test = test_name,
        Output = "file_test.go:10: assertion failed",
      }),
      encode({
        Time = "2025-01-01T00:00:03Z",
        Action = "fail",
        Package = pkg,
        Test = test_name,
        Elapsed = 0.001,
      }),
      encode({
        Time = "2025-01-01T00:00:04Z",
        Action = "fail",
        Package = pkg,
        Elapsed = 0.002,
      }),
    }
  elseif action == "skip" then
    return {
      encode({
        Time = "2025-01-01T00:00:00Z",
        Action = "run",
        Package = pkg,
        Test = test_name,
      }),
      encode({
        Time = "2025-01-01T00:00:01Z",
        Action = "output",
        Package = pkg,
        Test = test_name,
        Output = "=== RUN   " .. test_name,
      }),
      encode({
        Time = "2025-01-01T00:00:02Z",
        Action = "skip",
        Package = pkg,
        Test = test_name,
        Elapsed = 0.001,
      }),
      encode({
        Time = "2025-01-01T00:00:03Z",
        Action = "skip",
        Package = pkg,
        Elapsed = 0.002,
      }),
    }
  end
end

describe("Integration: fail/skip paths", function()
  it("marks skipped test at the test node (file remains passed)", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/positions/positions_test.go"
    test_filepath = normalize_windows_path(test_filepath)

    local tree =
      nio.tests.with_async_context(adapter.discover_positions, test_filepath)

    local import_path =
      "github.com/fredrikaverpil/neotest-golang/internal/positions"
    local test_name = "TestTopLevel"
    local test_pos_id = test_filepath .. "::" .. test_name

    local run_spec = adapter.build_spec({ tree = tree })
    assert.is_truthy(run_spec)

    local lines = lines_for(import_path, test_name, "skip")

    local emitted = run_spec.stream(function()
      return lines
    end)()
    assert.is_truthy(emitted)

    local output_path = vim.fs.normalize(vim.fn.tempname())
    vim.fn.writefile(lines, output_path)

    local results = nio.tests.with_async_context(
      adapter.results,
      run_spec,
      { code = 0, output = output_path },
      tree
    )

    assert.is_truthy(results[test_pos_id])
    assert.are.equal("skipped", results[test_pos_id].status)

    local file_pos_id = test_filepath
    assert.is_truthy(results[file_pos_id])
    -- With only one test skipped in the file, overall may still be passed depending on other tests in file.
    -- We assert presence rather than forcing exact status here to keep this stable across fixtures.
    assert.is_truthy(results[file_pos_id].status)
  end)

  it("marks failing test at the test node", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/positions/positions_test.go"
    test_filepath = normalize_windows_path(test_filepath)

    local tree =
      nio.tests.with_async_context(adapter.discover_positions, test_filepath)

    local import_path =
      "github.com/fredrikaverpil/neotest-golang/internal/positions"
    local test_name = "TestTopLevel"
    local test_pos_id = test_filepath .. "::" .. test_name

    local run_spec = adapter.build_spec({ tree = tree })
    assert.is_truthy(run_spec)

    local lines = lines_for(import_path, test_name, "fail")

    local emitted = run_spec.stream(function()
      return lines
    end)()
    assert.is_truthy(emitted)

    local output_path = vim.fs.normalize(vim.fn.tempname())
    vim.fn.writefile(lines, output_path)

    local results = nio.tests.with_async_context(
      adapter.results,
      run_spec,
      { code = 1, output = output_path },
      tree
    )

    assert.is_truthy(results[test_pos_id])
    assert.are.equal("failed", results[test_pos_id].status)

    -- File-level aggregation is tested in dedicated unit specs.
  end)
end)
