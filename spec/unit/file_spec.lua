local _ = require("plenary")
local file = require("neotest-golang.lib.file")

describe("File utilities", function()
  it("Writes and reads lines containing NUL bytes", function()
    local filepath = vim.fn.tempname()
    local input = { "before\0after", "next line" }

    file.write_lines(filepath, input)
    local got = file.read_lines(filepath)

    vim.fn.delete(filepath)
    assert.are_same(input, got)
  end)

  it("Preserves empty lines", function()
    local filepath = vim.fn.tempname()
    local input = { "before", "", "after" }

    file.write_lines(filepath, input)
    local got = file.read_lines(filepath)

    vim.fn.delete(filepath)
    assert.are_same(input, got)
  end)

  it("Reads CRLF line endings like vim.fn.readfile", function()
    local filepath = vim.fn.tempname()
    local fd = assert(vim.uv.fs_open(filepath, "w", 438))
    assert(vim.uv.fs_write(fd, "before\r\nafter\r\n", 0))
    assert(vim.uv.fs_close(fd))

    local got = file.read_lines(filepath)

    vim.fn.delete(filepath)
    assert.are_same({ "before", "after" }, got)
  end)
end)
