--- Build the neotest.Runspec specification for a test execution.

require("neotest-golang.lib.types")

local M = {}

M.dir = require("neotest-golang.runspec.dir")
M.file = require("neotest-golang.runspec.file")
M.test = require("neotest-golang.runspec.test")

return M
