-- Run the plenary test suite in a fresh, isolated site directory.
-- Usage: nvim -l spec/run.lua <site-dir> [spec-path]

local usage = "usage: nvim -l spec/run.lua <site-dir> [spec-path]"
local site_dir = vim.fs.abspath(assert(arg[1], usage))
local spec_path = arg[2] or "spec/"

vim.fn.delete(site_dir, "rf")
vim.fn.mkdir(site_dir, "p")

local function write(stream)
  return function(_, data)
    if data then
      stream:write(data)
      stream:flush()
    end
  end
end

local plenary_cmd = string.format(
  "PlenaryBustedDirectory %s { minimal_init = 'spec/minimal_init.lua', timeout = 500000 }",
  spec_path
)

local result = vim
  .system({
    vim.v.progpath,
    "--headless",
    "--noplugin",
    "-i",
    "NONE",
    "-u",
    "spec/bootstrap.lua",
    "-c",
    plenary_cmd,
  }, {
    env = { NEOTEST_SITE_DIR = site_dir },
    stdout = write(io.stdout),
    stderr = write(io.stderr),
  })
  :wait()

os.exit(result.code)
