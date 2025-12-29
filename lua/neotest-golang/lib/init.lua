local M = {}

M.colorize = require("neotest-golang.lib.colorize")
M.convert = require("neotest-golang.lib.convert")
M.cmd = require("neotest-golang.lib.cmd")
M.diagnostics = require("neotest-golang.lib.diagnostics")
M.discovery_cache = require("neotest-golang.lib.discovery_cache")
M.dupe = require("neotest-golang.lib.dupe")
M.extra_args = require("neotest-golang.lib.extra_args")
M.find = require("neotest-golang.lib.find")
M.goenv = require("neotest-golang.lib.goenv")
M.json = require("neotest-golang.lib.json")
M.logging = require("neotest-golang.lib.logging")
M.mapping = require("neotest-golang.lib.mapping")
M.path = require("neotest-golang.lib.path")
M.sanitize = require("neotest-golang.lib.sanitize")
M.stream = require("neotest-golang.lib.stream")

return M
