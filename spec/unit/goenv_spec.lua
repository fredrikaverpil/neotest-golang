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

  describe("should_skip edge cases", function()
    before_each(function()
      goenv.clear_cache()
    end)

    it("returns false when cwd is nil", function()
      -- Can't test async functions directly without neotest context,
      -- but we can verify the nil handling
      local result = goenv.should_skip("/some/path", nil)
      assert.is_false(result)
    end)

    it("returns false when path is nil", function()
      local result = goenv.should_skip(nil, "/home/user")
      assert.is_false(result)
    end)
  end)
end)
