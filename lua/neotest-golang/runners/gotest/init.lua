local M = {}

M.build_runspec = require("neotest-golang.runners.gotest.build_runspec")
M.runspec = require("neotest-golang.runners.gotest.runspec")
M.cmd_data = require("neotest-golang.runners.gotest.cmd_data")
M.processing = require("neotest-golang.runners.gotest.processing")

return M
