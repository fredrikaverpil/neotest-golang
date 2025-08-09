--- Tests for gotestsum streaming functionality

local options = require("neotest-golang.options")
local streaming = require("neotest-golang.lib.streaming")

describe("Gotestsum streaming", function()
  local original_options

  before_each(function()
    -- Save original options
    original_options = vim.deepcopy(options.get())
  end)

  after_each(function()
    -- Restore original options
    options.setup(original_options)
  end)

  describe("is_streaming_supported", function()
    it("supports gotestsum runner", function()
      local supported = streaming.is_streaming_supported(nil, "gotestsum")
      assert.is_true(supported)
    end)

    it("supports go runner", function()
      local supported = streaming.is_streaming_supported(nil, "go")
      assert.is_true(supported)
    end)

    it("does not support dap strategy", function()
      local supported = streaming.is_streaming_supported("dap", "gotestsum")
      assert.is_false(supported)
    end)
  end)

  describe("setup_gotestsum_file_streaming", function()
    local mock_tree = {
      iter_nodes = function()
        return function() end
      end,
      data = function()
        return { id = "test_pos" }
      end,
    }

    local mock_golist_data = { { ImportPath = "example.com/test" } }
    local mock_context = {}
    local json_filepath = "/tmp/test.json"

    it("returns runspec unchanged when streaming disabled", function()
      options.setup({ stream_enabled = false })
      local run_spec = { command = { "test" } }

      local result = streaming.setup_gotestsum_file_streaming(
        run_spec,
        json_filepath,
        mock_tree,
        mock_golist_data,
        mock_context
      )

      assert.are.same(run_spec, result)
      assert.is_nil(result.stream)
    end)

    it("returns runspec unchanged when no tree provided", function()
      options.setup({ stream_enabled = true })
      local run_spec = { command = { "test" } }

      local result = streaming.setup_gotestsum_file_streaming(
        run_spec,
        json_filepath,
        nil,
        mock_golist_data,
        mock_context
      )

      assert.are.same(run_spec, result)
      assert.is_nil(result.stream)
    end)

    it("returns runspec unchanged when no json_filepath provided", function()
      options.setup({ stream_enabled = true })
      local run_spec = { command = { "test" } }

      local result = streaming.setup_gotestsum_file_streaming(
        run_spec,
        nil,
        mock_tree,
        mock_golist_data,
        mock_context
      )

      assert.are.same(run_spec, result)
      assert.is_nil(result.stream)
    end)

    it("returns runspec unchanged when dap strategy", function()
      options.setup({ stream_enabled = true })
      local run_spec = { command = { "test" } }

      local result = streaming.setup_gotestsum_file_streaming(
        run_spec,
        json_filepath,
        mock_tree,
        mock_golist_data,
        mock_context,
        "dap"
      )

      assert.are.same(run_spec, result)
      assert.is_nil(result.stream)
    end)

    it(
      "sets up streaming when neotest.lib.files is available",
      function()
        options.setup({ stream_enabled = true, runner = "gotestsum" })
        local run_spec = { command = { "test" } }

        local result = streaming.setup_gotestsum_file_streaming(
          run_spec,
          json_filepath,
          mock_tree,
          mock_golist_data,
          mock_context
        )

        -- In test environment, neotest.lib.files is available, so streaming should be set up
        assert.are.same(run_spec, result)
        assert.is_function(result.stream)
      end
    )
  end)

  describe("setup_gotestsum_file_streaming_for_single_test", function()
    local mock_pos = { id = "test_pos", name = "TestExample" }
    local mock_golist_data = { { ImportPath = "example.com/test" } }
    local mock_context = {}
    local json_filepath = "/tmp/test.json"

    it(
      "sets up streaming when neotest.lib.files is available",
      function()
        options.setup({ stream_enabled = true, runner = "gotestsum" })
        local run_spec = { command = { "test" } }

        local result = streaming.setup_gotestsum_file_streaming_for_single_test(
          run_spec,
          json_filepath,
          nil, -- no tree provided, will create minimal tree
          mock_golist_data,
          mock_context,
          mock_pos
        )

        -- Should set up streaming with minimal tree
        assert.are.same(run_spec, result)
        assert.is_function(result.stream)
      end
    )

    it("handles provided tree correctly", function()
      options.setup({ stream_enabled = true, runner = "gotestsum" })
      local run_spec = { command = { "test" } }

      local result = streaming.setup_gotestsum_file_streaming_for_single_test(
        run_spec,
        json_filepath,
        mock_tree, -- tree provided
        mock_golist_data,
        mock_context,
        mock_pos
      )

      -- Should use provided tree and set up streaming
      assert.are.same(run_spec, result)
      assert.is_function(result.stream)
    end)
  end)

  describe("error handling and fallback behavior", function()
    local mock_tree = {
      iter_nodes = function()
        return function() end
      end,
      data = function()
        return { id = "test_pos" }
      end,
    }
    local mock_golist_data = { { ImportPath = "example.com/test" } }
    local mock_context = {}
    local json_filepath = "/tmp/test.json"

    it("sets up streaming when neotest.lib.files is available", function()
      options.setup({ stream_enabled = true, runner = "gotestsum" })
      local run_spec = { command = { "test" } }

      -- In test environment, neotest.lib.files is available
      local result = streaming.setup_gotestsum_file_streaming(
        run_spec,
        json_filepath,
        mock_tree,
        mock_golist_data,
        mock_context
      )

      -- Should set up streaming successfully
      assert.are.same(run_spec, result)
      assert.is_function(result.stream)
    end)

    it("handles empty json_filepath", function()
      options.setup({ stream_enabled = true, runner = "gotestsum" })
      local run_spec = { command = { "test" } }

      local result = streaming.setup_gotestsum_file_streaming(
        run_spec,
        "", -- empty json_filepath
        mock_tree,
        mock_golist_data,
        mock_context
      )

      -- Should return unchanged runspec without streaming
      assert.are.same(run_spec, result)
      assert.is_nil(result.stream)
    end)

    it("handles nil json_filepath", function()
      options.setup({ stream_enabled = true, runner = "gotestsum" })
      local run_spec = { command = { "test" } }

      local result = streaming.setup_gotestsum_file_streaming(
        run_spec,
        nil,
        mock_tree,
        mock_golist_data,
        mock_context
      )

      assert.are.same(run_spec, result)
      assert.is_nil(result.stream)
    end)
  end)
end)
