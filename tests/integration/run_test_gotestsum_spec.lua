local _ = require("plenary")
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

local function build_go_test_json_lines(pkg, test_name)
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
      Output = "--- PASS: " .. test_name .. " (0.00s)",
    }),
    encode({
      Time = "2025-01-01T00:00:03Z",
      Action = "pass",
      Package = pkg,
      Test = test_name,
      Elapsed = 0.001,
    }),
    encode({
      Time = "2025-01-01T00:00:04Z",
      Action = "pass",
      Package = pkg,
      Elapsed = 0.002,
    }),
  }
end

describe("Integration (gotestsum): stream + results", function()
  it("produces passed results from mocked JSON stream", function()
    -- Set gotestsum runner before requiring adapter
    options.set({
      runner = "gotestsum",
      warn_test_results_missing = false,
    })

    -- Mock the stream module to avoid file watching
    local stream_mod = require("neotest-golang.lib.stream")
    local original_new = stream_mod.new

    local import_path =
      "github.com/fredrikaverpil/neotest-golang/internal/positions"
    local test_name = "TestTopLevel"
    local lines = build_go_test_json_lines(import_path, test_name)

    -- Mock stream.new to return a non-file-watching stream
    stream_mod.new = function(tree, golist_data, json_filepath)
      -- Write the JSON data to the expected file for results() function
      if json_filepath then
        vim.fn.writefile(lines, json_filepath)
      end

      local function stream(data_provider)
        return function()
          -- Use the provided JSON lines directly instead of file watching
          local gotest_events =
            require("neotest-golang.lib.json").decode_from_table(lines, true)
          local accum = {}
          local lookup =
            require("neotest-golang.lib.mapping").build_position_lookup(
              tree,
              golist_data
            )

          for _, gotest_event in ipairs(gotest_events) do
            accum =
              stream_mod.process_event(golist_data, accum, gotest_event, lookup)
          end

          local results = stream_mod.make_stream_results(accum)

          -- Update cached results like the real implementation
          for pos_id, result in pairs(results) do
            stream_mod.cached_results[pos_id] = result
          end

          return results
        end
      end

      -- Return stream function and no-op stop function
      return stream, function() end
    end

    -- Now require adapter after mock is in place
    local adapter = require("neotest-golang")

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/positions/positions_test.go"
    test_filepath = normalize_windows_path(test_filepath)

    local tree =
      nio.tests.with_async_context(adapter.discover_positions, test_filepath)

    local run_spec = adapter.build_spec({ tree = tree })
    assert.is_truthy(run_spec)
    assert.is_truthy(run_spec.stream)
    assert.is_truthy(run_spec.context.test_output_json_filepath)

    -- Call the mocked stream function
    local emit = run_spec.stream(function()
      return {}
    end)
    local streamed = emit()
    assert.is_truthy(streamed)

    -- Create output path with actual JSON content (required by results())
    local output_path = vim.fs.normalize(vim.fn.tempname())
    vim.fn.writefile(lines, output_path)

    local strategy_result = { code = 0, output = output_path }
    local results = nio.tests.with_async_context(
      adapter.results,
      run_spec,
      strategy_result,
      tree
    )

    local test_pos_id = test_filepath .. "::" .. test_name
    assert.is_truthy(results[test_pos_id])
    assert.are.equal("passed", results[test_pos_id].status)

    local file_pos_id = test_filepath
    assert.is_truthy(results[file_pos_id])
    assert.are.equal("passed", results[file_pos_id].status)

    -- Restore original stream.new
    stream_mod.new = original_new
  end)
end)

