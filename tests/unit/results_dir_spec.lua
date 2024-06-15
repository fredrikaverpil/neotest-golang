local _ = require("plenary")

local results_dir = require("neotest-golang.utils")

describe("Common parts of Go package and folderpath", function()
  it("Root repo - ok", function()
    local line_package = "github.com/fredrikaverpil/my-service"
    local folderpath = "/Users/fredrik/code/work/private/my-service"

    local partial_path = results_dir.find_common_path(line_package, folderpath)
    assert.are_equal(partial_path, "my-service")
  end)

  it("Repo sub-folder - ok", function()
    local line_package = "github.com/fredrikaverpil/my-service/backend"
    local folderpath = "/Users/fredrik/code/work/private/my-service/backend"

    local partial_path = results_dir.find_common_path(line_package, folderpath)
    assert.are_equal(partial_path, "my-service/backend")
  end)

  it("Deep repo sub folder - ok", function()
    local line_package =
      "github.com/fredrikaverpil/my-service/backend/internal/outbound/spanner"
    local folderpath =
      "/Users/fredrik/code/work/private/my-service/backend/internal/outbound/spanner"

    local partial_path = results_dir.find_common_path(line_package, folderpath)
    assert.are_equal(
      partial_path,
      "my-service/backend/internal/outbound/spanner"
    )
  end)
end)
