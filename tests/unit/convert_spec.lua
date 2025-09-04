local _ = require("plenary")
local lib = require("neotest-golang.lib")

describe("Convert pos_id to go test name", function()
  it("handles simple test names", function()
    local input = "/path/to/file_test.go::TestName"
    assert.are_equal("TestName", lib.convert.pos_id_to_go_test_name(input))
  end)

  it("returns nil for missing ::", function()
    local input = "/path/to/file_test.go"
    assert.is_nil(lib.convert.pos_id_to_go_test_name(input))
  end)

  it("converts quoted subtests and spaces to underscores", function()
    local input = '/path/file.go::TestName::"Sub Test"::"Inner Sub"'
    assert.are_equal(
      "TestName/Sub_Test/Inner_Sub",
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
