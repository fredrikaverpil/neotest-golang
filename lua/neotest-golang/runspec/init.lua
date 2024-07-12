--- Build the neotest.Runspec specification for a test execution.

local M = {}

M.dir = require("neotest-golang.runspec.dir")
M.file = require("neotest-golang.runspec.file")
M.namespace = require("neotest-golang.runspec.namespace")
M.test = require("neotest-golang.runspec.test")

return M
