--- Build the neotest.Runspec specification for a test execution.

local M = {}

M.dir = require("neotest-golang.runners.gotest.runspec.dir")
M.file = require("neotest-golang.runners.gotest.runspec.file")
M.namespace = require("neotest-golang.runners.gotest.runspec.namespace")
M.test = require("neotest-golang.runners.gotest.runspec.test")

return M
