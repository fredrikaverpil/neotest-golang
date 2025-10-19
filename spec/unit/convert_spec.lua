local _ = require("plenary")
local lib = require("neotest-golang.lib")

describe("Convert pos_id to go test name", function()
  it("handles simple test names", function()
    local input = "/path/to/file_test.go::TestName"
    assert.are_equal("TestName", lib.convert.pos_id_to_go_test_name(input))
  end)

  it("returns nil for invalid position IDs", function()
    local input = "/path/to/pkg/file_test.go" -- No :: separator
    assert.is_nil(lib.convert.pos_id_to_go_test_name(input))
  end)

  it("converts test with single subtest", function()
    local input = '/path/to/pkg/file_test.go::TestName::"SubTest"'
    assert.are_equal(
      "TestName/SubTest",
      lib.convert.pos_id_to_go_test_name(input)
    )
  end)

  it("converts test with nested subtests", function()
    local input =
      '/path/to/pkg/file_test.go::TestName::"SubTest1"::"NestedSubTest"'
    assert.are_equal(
      "TestName/SubTest1/NestedSubTest",
      lib.convert.pos_id_to_go_test_name(input)
    )
  end)

  it("converts test with spaces in subtest names", function()
    local input = '/path/to/pkg/file_test.go::TestName::"Sub Test With Spaces"'
    assert.are_equal(
      "TestName/Sub_Test_With_Spaces",
      lib.convert.pos_id_to_go_test_name(input)
    )
  end)

  it("converts deeply nested subtests", function()
    local input =
      '/path/to/pkg/file_test.go::TestMain::"Level1"::"Level2"::"Level3"::"Level4"'
    assert.are_equal(
      "TestMain/Level1/Level2/Level3/Level4",
      lib.convert.pos_id_to_go_test_name(input)
    )
  end)

  it("handles subtests with special characters", function()
    local input =
      '/path/to/pkg/file_test.go::TestName::"SubTest with & symbols!"'
    assert.are_equal(
      "TestName/SubTest_with_&_symbols!",
      lib.convert.pos_id_to_go_test_name(input)
    )
  end)

  it("preserves main test name (no normalization)", function()
    -- Neotest provides the main test name as-is.
    local input = '/path/file.go::Test Name::"Sub Test"'
    assert.are_equal(
      "Test Name/Sub_Test",
      lib.convert.pos_id_to_go_test_name(input)
    )
  end)

  it("supports mixed case with space", function()
    local input = '/path/file.go::TestNames::"Mixed case with space"'
    assert.are_equal(
      "TestNames/Mixed_case_with_space",
      lib.convert.pos_id_to_go_test_name(input)
    )
  end)

  it("supports special characters", function()
    local input =
      '/path/file.go::TestNames::"Period . comma , and apostrophy \' are ok to use"'
    assert.are_equal(
      "TestNames/Period_._comma_,_and_apostrophy_'_are_ok_to_use",
      lib.convert.pos_id_to_go_test_name(input)
    )
  end)

  it("supports brackets", function()
    local input = '/path/file.go::TestNames::"Brackets [1] (2) {3} are ok"'
    assert.are_equal(
      "TestNames/Brackets_[1]_(2)_{3}_are_ok",
      lib.convert.pos_id_to_go_test_name(input)
    )
  end)

  it("supports regexp characters", function()
    local input =
      '/path/file.go::TestNames::"Regexp characters like ( ) [ ] { } - | ? + * ^ $ are ok"'
    assert.are_equal(
      "TestNames/Regexp_characters_like_(_)_[_]_{_}_-_|_?_+_*_^_$_are_ok",
      lib.convert.pos_id_to_go_test_name(input)
    )
  end)

  -- Testify suite tests (flat structure with suite prefix)
  it("handles testify suite test (flat structure)", function()
    local input = "/path/file.go::TestSuite/TestMethod"
    assert.are_equal(
      "TestSuite/TestMethod",
      lib.convert.pos_id_to_go_test_name(input)
    )
  end)

  it("handles testify suite test with subtest", function()
    local input = '/path/file.go::TestSuite/TestMethod::"subtest"'
    assert.are_equal(
      "TestSuite/TestMethod/subtest",
      lib.convert.pos_id_to_go_test_name(input)
    )
  end)

  it("handles testify suite test with nested subtests", function()
    local input = '/path/file.go::TestSuite/TestMethod::"level1"::"level2"'
    assert.are_equal(
      "TestSuite/TestMethod/level1/level2",
      lib.convert.pos_id_to_go_test_name(input)
    )
  end)
end)

describe("Convert go test name to pos_id", function()
  it("handles simple test names", function()
    local input = "TestName"
    assert.are_equal("TestName", lib.convert.go_test_name_to_pos_id(input))
  end)

  it("converts test with single subtest", function()
    local input = "TestName/SubTest"
    assert.are_equal(
      'TestName::"SubTest"',
      lib.convert.go_test_name_to_pos_id(input)
    )
  end)

  it("converts test with nested subtests", function()
    local input = "TestName/SubTest1/NestedSubTest"
    assert.are_equal(
      'TestName::"SubTest1"::"NestedSubTest"',
      lib.convert.go_test_name_to_pos_id(input)
    )
  end)

  it("converts underscores back to spaces in subtests", function()
    local input = "TestName/Sub_Test_With_Spaces"
    assert.are_equal(
      'TestName::"Sub Test With Spaces"',
      lib.convert.go_test_name_to_pos_id(input)
    )
  end)

  it("preserves main test name exactly (no normalization)", function()
    -- Even if the main part has spaces/underscores, keep it literal
    local input = "Test Name/Sub_Test"
    assert.are_equal(
      'Test Name::"Sub Test"',
      lib.convert.go_test_name_to_pos_id(input)
    )
  end)

  it("ignores empty path segments", function()
    local input = "TestName//SubTest///Inner"
    assert.are_equal(
      'TestName::"SubTest"::"Inner"',
      lib.convert.go_test_name_to_pos_id(input)
    )
  end)

  it("does not convert underscores in main test", function()
    local input = "Test_Name/Sub_Test"
    assert.are_equal(
      'Test_Name::"Sub Test"',
      lib.convert.go_test_name_to_pos_id(input)
    )
  end)
end)

describe("Convert go test name to pos_id (special cases)", function()
  it("handles brackets and special characters in subtests", function()
    local input = "TestNames/Brackets_[1]_(2)_{3}_are_ok"
    assert.are_equal(
      'TestNames::"Brackets [1] (2) {3} are ok"',
      lib.convert.go_test_name_to_pos_id(input)
    )
  end)

  it("handles regex-like characters in subtests without escaping", function()
    local input =
      "TestNames/Regexp_characters_like_(_)_[_]_{_}_-_|_?_+_*_^_$_are_ok"
    assert.are_equal(
      'TestNames::"Regexp characters like ( ) [ ] { } - | ? + * ^ $ are ok"',
      lib.convert.go_test_name_to_pos_id(input)
    )
  end)

  it("keeps parentheses as-is in subtests (no escaping)", function()
    local input = "TestNames/Test(success)"
    assert.are_equal(
      'TestNames::"Test(success)"',
      lib.convert.go_test_name_to_pos_id(input)
    )
  end)
end)

describe("Convert go test name to regex pattern", function()
  it("wrap single test in exact regex", function()
    local input = "TestNames"
    assert.are_equal("^TestNames$", lib.convert.to_gotest_regex_pattern(input))
  end)

  it("escapes parenthesis and anchors segments", function()
    local input = "TestNames/Test(success)"
    assert.are_equal(
      "^TestNames$/^Test\\(success\\)$",
      lib.convert.to_gotest_regex_pattern(input)
    )
  end)

  it("wrap doubly nested test in exact regex", function()
    local input = "TestNames/nested1/nested2"
    assert.are_equal(
      "^TestNames$/^nested1$/^nested2$",
      lib.convert.to_gotest_regex_pattern(input)
    )
  end)
end)

describe("file_path_to_import_path", function()
  it("finds matching import path", function()
    local file_path = "/path/to/pkg/subdir/file_test.go"
    local import_to_dir = {
      ["example.com/repo/pkg"] = "/path/to/pkg",
      ["example.com/repo/pkg/subdir"] = "/path/to/pkg/subdir",
      ["example.com/repo/other"] = "/path/to/other",
    }

    local expected = "example.com/repo/pkg/subdir"
    local result =
      lib.convert.file_path_to_import_path(file_path, import_to_dir)
    assert.are.equal(expected, result)
  end)

  it("returns nil when no match found", function()
    local file_path = "/path/to/unknown/file_test.go"
    local import_to_dir = {
      ["example.com/repo/pkg"] = "/path/to/pkg",
    }

    local result =
      lib.convert.file_path_to_import_path(file_path, import_to_dir)
    assert.is_nil(result)
  end)

  it("returns nil for invalid file path", function()
    local file_path = "invalid_path" -- No directory separator
    local import_to_dir = {}

    local result =
      lib.convert.file_path_to_import_path(file_path, import_to_dir)
    assert.is_nil(result)
  end)
end)

describe("to_dir_position_id", function()
  it("finds matching package directory", function()
    local golist_data = {
      {
        ImportPath = "example.com/repo/pkg",
        Dir = "/path/to/pkg",
      },
      {
        ImportPath = "example.com/repo/other",
        Dir = "/path/to/other",
      },
    }
    local package_name = "example.com/repo/pkg"
    local expected = "/path/to/pkg"

    local result = lib.convert.to_dir_position_id(golist_data, package_name)
    assert.are.equal(expected, result)
  end)

  it("errors for unknown package", function()
    local golist_data = {
      {
        ImportPath = "example.com/repo/pkg",
        Dir = "/path/to/pkg",
      },
    }
    local package_name = "example.com/unknown/pkg"

    assert.has_error(function()
      lib.convert.to_dir_position_id(golist_data, package_name)
    end, "Could not find position id for package: example.com/unknown/pkg")
  end)

  it("errors for empty golist data", function()
    local golist_data = {}
    local package_name = "example.com/repo/pkg"

    assert.has_error(function()
      lib.convert.to_dir_position_id(golist_data, package_name)
    end, "Could not find position id for package: example.com/repo/pkg")
  end)
end)

describe("extract_file_path_from_pos_id", function()
  it("extracts Unix-style file paths correctly", function()
    local pos_id = "/home/user/project/file_test.go::TestName"
    local expected = "/home/user/project/file_test.go"

    local result = lib.convert.extract_file_path_from_pos_id(pos_id)
    assert.are.equal(expected, result)
  end)

  it("extracts Windows-style file paths correctly with drive letter", function()
    local pos_id =
      "D:\\\\a\\\\neotest-golang\\\\tests\\\\go\\\\internal\\\\multifile\\\\first_file_test.go::TestOne"
    local expected =
      "D:\\\\a\\\\neotest-golang\\\\tests\\\\go\\\\internal\\\\multifile\\\\first_file_test.go"

    local result = lib.convert.extract_file_path_from_pos_id(pos_id)
    assert.are.equal(expected, result)
  end)

  it("extracts Windows-style file paths with forward slashes", function()
    local pos_id =
      "D:/a/neotest-golang/tests/go/internal/multifile/first_file_test.go::TestOne"
    local expected =
      "D:/a/neotest-golang/tests/go/internal/multifile/first_file_test.go"

    local result = lib.convert.extract_file_path_from_pos_id(pos_id)
    assert.are.equal(expected, result)
  end)

  it("handles complex test names with subtests", function()
    local pos_id =
      'D:\\\\path\\\\file_test.go::TestName::"SubTest"::"NestedTest"'
    local expected = "D:\\\\path\\\\file_test.go"

    local result = lib.convert.extract_file_path_from_pos_id(pos_id)
    assert.are.equal(expected, result)
  end)

  it("handles position IDs without test separators", function()
    local pos_id = "D:\\\\path\\\\file_test.go"
    local expected = "D:\\\\path\\\\file_test.go"

    local result = lib.convert.extract_file_path_from_pos_id(pos_id)
    assert.are.equal(expected, result)
  end)

  it("returns nil for invalid input", function()
    assert.is_nil(lib.convert.extract_file_path_from_pos_id(nil))
    assert.is_nil(lib.convert.extract_file_path_from_pos_id(123))
    assert.is_nil(lib.convert.extract_file_path_from_pos_id(""))
  end)

  it(
    "should not be confused by Windows drive letter colons (regression test)",
    function()
      -- This tests the specific issue where "D:" was extracted instead of the full path
      local pos_id =
        "D:\\\\a\\\\neotest-golang\\\\neotest-golang\\\\tests\\\\go\\\\internal\\\\multifile\\\\first_file_test.go::TestOne"
      local result = lib.convert.extract_file_path_from_pos_id(pos_id)

      -- The old regex would return "D" instead of the full path
      assert.is_not.equal("D", result)
      assert.are.equal(
        "D:\\\\a\\\\neotest-golang\\\\neotest-golang\\\\tests\\\\go\\\\internal\\\\multifile\\\\first_file_test.go",
        result
      )
    end
  )
end)

describe("pos_id_to_filename", function()
  it("extracts filename from file path position ID", function()
    local pos_id = "/path/to/pkg/file_test.go::TestName"
    local expected = "file_test.go"

    local result = lib.convert.pos_id_to_filename(pos_id)
    assert.are.equal(expected, result)
  end)

  it("extracts filename from Windows path with drive letter", function()
    local pos_id =
      "D:\\\\a\\\\neotest-golang\\\\tests\\\\go\\\\internal\\\\multifile\\\\first_file_test.go::TestOne"
    local expected = "first_file_test.go"

    local result = lib.convert.pos_id_to_filename(pos_id)
    assert.are.equal(expected, result)
  end)

  it("returns nil for synthetic position ID", function()
    local pos_id = "github.com/pkg::TestName"

    local result = lib.convert.pos_id_to_filename(pos_id)
    assert.is_nil(result)
  end)

  it("returns nil for nil input", function()
    local result = lib.convert.pos_id_to_filename(nil)
    assert.is_nil(result)
  end)

  it("returns nil for non-go file path", function()
    local pos_id = "/path/to/pkg/file.txt::TestName"

    local result = lib.convert.pos_id_to_filename(pos_id)
    assert.is_nil(result)
  end)

  it("returns nil for path without directory separator", function()
    local pos_id = "file_test.go::TestName"

    local result = lib.convert.pos_id_to_filename(pos_id)
    assert.is_nil(result)
  end)
end)

describe("Platform-conditional path utilities", function()
  describe("get_filename_fast", function()
    it("uses vim.fs.basename on POSIX systems for performance", function()
      -- Mock vim.fn.has to return 0 (POSIX)
      local original_has = vim.fn.has
      vim.fn.has = function(feature)
        if feature == "win32" then
          return 0
        end
        return original_has(feature)
      end

      -- Mock vim.fs.basename to track calls
      local original_basename = vim.fs.basename
      local basename_called = false
      vim.fs.basename = function(path)
        basename_called = true
        return original_basename(path)
      end

      local result = lib.path.get_filename_fast("/path/to/file_test.go")

      -- Verify the fast path was used
      assert.is_true(basename_called)
      assert.equals("file_test.go", result)

      -- Restore original functions
      vim.fn.has = original_has
      vim.fs.basename = original_basename
    end)

    it("uses find.get_filename on Windows systems for compatibility", function()
      -- Mock vim.fn.has to return 1 (Windows)
      local original_has = vim.fn.has
      vim.fn.has = function(feature)
        if feature == "win32" then
          return 1
        end
        return original_has(feature)
      end

      -- Test with Windows path
      local result = lib.path.get_filename_fast("D:\\\\project\\\\file_test.go")

      -- Should work correctly with Windows paths
      assert.equals("file_test.go", result)

      -- Restore original function
      vim.fn.has = original_has
    end)

    it("handles Windows UNC paths correctly on Windows", function()
      -- Mock vim.fn.has to return 1 (Windows)
      local original_has = vim.fn.has
      vim.fn.has = function(feature)
        if feature == "win32" then
          return 1
        end
        return original_has(feature)
      end

      local result =
        lib.path.get_filename_fast("\\\\\\\\server\\\\share\\\\file_test.go")

      assert.equals("file_test.go", result)

      -- Restore original function
      vim.fn.has = original_has
    end)

    it(
      "maintains performance benefit on POSIX while preserving Windows compatibility",
      function()
        -- This test documents the performance intention
        -- POSIX: fast vim.fs.basename (C built-in)
        -- Windows: safe find.get_filename (Lua implementation)

        -- Test that function works correctly with POSIX-style paths
        local posix_result =
          lib.path.get_filename_fast("/unix/path/file_test.go")
        assert.equals("file_test.go", posix_result)

        -- Test that function exists and is callable (Windows path testing done in Windows-specific test)
        assert.is_function(lib.path.get_filename_fast)
      end
    )
  end)
end)

describe("bidirectional conversion", function()
  it(
    "maintains consistency between pos_id and go_test_name conversions",
    function()
      local test_cases = {
        { pos = "TestName", go = "TestName" },
        { pos = 'TestName::"SubTest"', go = "TestName/SubTest" },
        { pos = 'TestName::"Sub1"::"Sub2"', go = "TestName/Sub1/Sub2" },
        {
          pos = 'TestName::"Sub Test With Spaces"',
          go = "TestName/Sub_Test_With_Spaces",
        },
      }

      for _, test_case in ipairs(test_cases) do
        -- Test pos -> go -> pos
        local go_result =
          lib.convert.pos_id_to_go_test_name("file.go::" .. test_case.pos)
        assert.are.equal(
          test_case.go,
          go_result,
          "pos->go conversion failed for " .. test_case.pos
        )

        local pos_result = lib.convert.go_test_name_to_pos_id(go_result)
        assert.are.equal(
          test_case.pos,
          pos_result,
          "go->pos conversion failed for " .. test_case.go
        )

        -- Test go -> pos -> go
        local pos_result2 = lib.convert.go_test_name_to_pos_id(test_case.go)
        assert.are.equal(
          test_case.pos,
          pos_result2,
          "go->pos conversion failed for " .. test_case.go
        )

        local go_result2 =
          lib.convert.pos_id_to_go_test_name("file.go::" .. pos_result2)
        assert.are.equal(
          test_case.go,
          go_result2,
          "pos->go conversion failed for " .. test_case.pos
        )
      end
    end
  )
end)
