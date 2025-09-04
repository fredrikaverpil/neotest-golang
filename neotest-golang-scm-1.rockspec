rockspec_format = "3.0"
package = "neotest-golang"
version = "scm-1"
source = {
   url = "git+https://github.com/fredrikaverpil/neotest-golang.git"
}
description = {
   summary = "Neotest adapter for Go",
   homepage = "https://github.com/fredrikaverpil/neotest-golang",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "busted >= 2.0.0",
   "nlua"
}
test_dependencies = {
   "busted >= 2.0.0",
   "nlua"
}
test = {
   type = "command",
   command = "./tests/run_tests.sh"
}
build = {
   type = "builtin",
   modules = {}
}