local _ = require("plenary")
local goenv = require("neotest-golang.lib.goenv")

describe("Go environment utilities", function()
  describe("is_path_inside", function()
    it("returns false for empty prefix", function()
      assert.is_false(goenv.is_path_inside("/home/user/project", ""))
    end)

    it("returns true for exact match", function()
      assert.is_true(goenv.is_path_inside("/home/go", "/home/go"))
    end)

    it("returns true when path is subdirectory of prefix", function()
      assert.is_true(goenv.is_path_inside("/home/go/pkg/mod", "/home/go"))
    end)

    it(
      "returns false when path shares prefix but is different directory",
      function()
        -- This is the key bug fix: /home/golang should NOT match /home/go
        assert.is_false(
          goenv.is_path_inside("/home/golang/project", "/home/go")
        )
      end
    )

    it("returns false when prefix is not at start", function()
      assert.is_false(goenv.is_path_inside("/other/home/go", "/home/go"))
    end)

    it("returns false when path is shorter than prefix", function()
      assert.is_false(goenv.is_path_inside("/home", "/home/go"))
    end)

    it("handles Windows paths with backslashes", function()
      assert.is_true(
        goenv.is_path_inside("C:\\Users\\go\\pkg", "C:\\Users\\go")
      )
    end)

    it("rejects Windows paths that share prefix but are different", function()
      assert.is_false(
        goenv.is_path_inside("C:\\Users\\golang\\project", "C:\\Users\\go")
      )
    end)

    it("handles GOROOT edge case with similar prefix", function()
      -- Common case: GOROOT=/usr/local/go, user project at /usr/local/golang-tools
      assert.is_false(
        goenv.is_path_inside(
          "/usr/local/golang-tools/myproject",
          "/usr/local/go"
        )
      )
    end)

    it("handles nested subdirectories", function()
      assert.is_true(
        goenv.is_path_inside("/home/go/pkg/mod/github.com/foo/bar", "/home/go")
      )
    end)

    it("handles path with trailing separator in prefix", function()
      -- Edge case: prefix might have trailing slash
      assert.is_true(goenv.is_path_inside("/home/go/pkg", "/home/go/"))
    end)
  end)

  describe("should_skip", function()
    before_each(function()
      goenv.clear_cache()
      -- Set up mock GOPATH and GOROOT for testing
      goenv.set_cache_for_testing({
        gopath = "/home/user/go",
        goroot = "/usr/local/go",
      })
    end)

    after_each(function()
      goenv.clear_cache()
    end)

    it("returns false when cwd is nil", function()
      local result = goenv.should_skip("/some/path", nil)
      assert.is_false(result)
    end)

    it("returns false when path is nil", function()
      local result = goenv.should_skip(nil, "/home/user")
      assert.is_false(result)
    end)

    it("returns true when path is in GOPATH but cwd is not", function()
      local result = goenv.should_skip(
        "/home/user/go/pkg/mod/github.com/foo/bar",
        "/home/user/myproject"
      )
      assert.is_true(result)
    end)

    it("returns true when path is in GOROOT but cwd is not", function()
      local result = goenv.should_skip(
        "/usr/local/go/src/fmt/print.go",
        "/home/user/myproject"
      )
      assert.is_true(result)
    end)

    it("returns false when both path and cwd are in GOPATH", function()
      local result = goenv.should_skip(
        "/home/user/go/src/myproject/main_test.go",
        "/home/user/go/src/myproject"
      )
      assert.is_false(result)
    end)

    it("returns false when neither path nor cwd is in GOPATH/GOROOT", function()
      local result = goenv.should_skip(
        "/home/user/myproject/main_test.go",
        "/home/user/myproject"
      )
      assert.is_false(result)
    end)

    it("returns false when path is outside but cwd is in GOPATH", function()
      -- Edge case: user is working inside GOPATH
      local result =
        goenv.should_skip("/tmp/some/test.go", "/home/user/go/src/myproject")
      assert.is_false(result)
    end)

    it("does not match paths with similar prefix (the bug fix)", function()
      -- GOPATH is /home/user/go, but /home/user/golang should NOT match
      local result = goenv.should_skip(
        "/home/user/golang/myproject/main_test.go",
        "/home/user/myproject"
      )
      assert.is_false(result)
    end)
  end)
end)
