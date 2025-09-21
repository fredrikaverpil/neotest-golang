---Performance metrics collection for streaming operations
local logger = require("neotest-golang.lib.logging")
local options = require("neotest-golang.options")

local M = {}

---@class StreamingMetrics
---@field start_time number High-resolution start timestamp
---@field events_processed number Total events processed
---@field events_by_type table<string, number> Count by event action type
---@field peak_accum_size number Peak accumulator table size
---@field peak_cache_size number Peak cache table size
---@field files_written number Number of output files written
---@field total_output_size number Total bytes written to output files
---@field position_lookups number Total position lookups attempted
---@field position_failures number Failed position lookups

---Current streaming session metrics
---@type StreamingMetrics|nil
M._current_session = nil

---Start a new metrics collection session
function M.start_session()
  if not options.get().performance_monitoring then
    return
  end

  M._current_session = {
    start_time = vim.uv.hrtime(),
    events_processed = 0,
    events_by_type = {},
    peak_accum_size = 0,
    peak_cache_size = 0,
    files_written = 0,
    total_output_size = 0,
    position_lookups = 0,
    position_failures = 0,
  }

  logger.debug("Started performance monitoring session")
end

---Record an event being processed
---@param event_action string The Go test event action (run, pass, fail, output, etc.)
function M.record_event(event_action)
  if not M._current_session then
    return
  end

  M._current_session.events_processed = M._current_session.events_processed + 1

  local count = M._current_session.events_by_type[event_action] or 0
  M._current_session.events_by_type[event_action] = count + 1
end

---Record accumulator table size
---@param size number Current accumulator table size
function M.record_accum_size(size)
  if not M._current_session then
    return
  end

  if size > M._current_session.peak_accum_size then
    M._current_session.peak_accum_size = size
  end
end

---Record cache table size
---@param size number Current cache table size
function M.record_cache_size(size)
  if not M._current_session then
    return
  end

  if size > M._current_session.peak_cache_size then
    M._current_session.peak_cache_size = size
  end
end

---Record a file being written
---@param file_size number Size of the written file in bytes
function M.record_file_write(file_size)
  if not M._current_session then
    return
  end

  M._current_session.files_written = M._current_session.files_written + 1
  M._current_session.total_output_size = M._current_session.total_output_size
    + file_size
end

---Record a position lookup attempt
---@param success boolean Whether the lookup succeeded
function M.record_position_lookup(success)
  if not M._current_session then
    return
  end

  M._current_session.position_lookups = M._current_session.position_lookups + 1
  if not success then
    M._current_session.position_failures = M._current_session.position_failures
      + 1
  end
end

---Format file size in human-readable format
---@param bytes number Size in bytes
---@return string Formatted size (e.g., "1.2MB", "456KB")
local function format_size(bytes)
  if bytes >= 1024 * 1024 then
    return string.format("%.1fMB", bytes / (1024 * 1024))
  elseif bytes >= 1024 then
    return string.format("%.1fKB", bytes / 1024)
  else
    return string.format("%dB", bytes)
  end
end

---Calculate hit rate percentage
---@param hits number Successful attempts
---@param total number Total attempts
---@return string Formatted percentage
local function hit_rate(hits, total)
  if total == 0 then
    return "N/A"
  end
  return string.format("%.1f%%", (hits / total) * 100)
end

---End the current session and log performance summary
function M.end_session()
  if not M._current_session then
    return
  end

  local session = M._current_session
  local duration_ns = vim.uv.hrtime() - session.start_time
  local duration_s = duration_ns / 1e9
  local events_per_sec = session.events_processed / duration_s

  -- Calculate position lookup hit rate
  local lookup_hits = session.position_lookups - session.position_failures
  local lookup_hit_rate = hit_rate(lookup_hits, session.position_lookups)

  -- Build summary message
  local summary_lines = {
    "Streaming Performance Summary:",
    string.format(
      "  Events processed: %d (%.1f events/sec)",
      session.events_processed,
      events_per_sec
    ),
    string.format(
      "  Peak memory usage: %s accumulator, %s cache",
      format_size(session.peak_accum_size * 50), -- rough estimate: 50 bytes per table entry
      format_size(session.peak_cache_size * 100)
    ), -- rough estimate: 100 bytes per result
    string.format(
      "  File I/O: %d files written (total %s)",
      session.files_written,
      format_size(session.total_output_size)
    ),
    string.format(
      "  Position lookup: %s hit rate (%d failed mappings)",
      lookup_hit_rate,
      session.position_failures
    ),
    string.format("  Total streaming time: %.1fs", duration_s),
  }

  -- Add event breakdown if there are multiple types
  if vim.tbl_count(session.events_by_type) > 1 then
    table.insert(summary_lines, "  Event breakdown:")
    local sorted_types = vim.tbl_keys(session.events_by_type)
    table.sort(sorted_types)
    for _, event_type in ipairs(sorted_types) do
      local count = session.events_by_type[event_type]
      table.insert(
        summary_lines,
        string.format("    %s: %d", event_type, count)
      )
    end
  end

  logger.info(table.concat(summary_lines, "\n"))

  -- Clear the session
  M._current_session = nil
end

return M
