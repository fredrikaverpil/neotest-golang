local M = {}

M.namespace = require("neotest-golang.features.testify.namespace")
M.lookup = require("neotest-golang.features.testify.lookup")
M.query = require("neotest-golang.features.testify.query")
M.tree_modification =
  require("neotest-golang.features.testify.tree_modification")

return M
