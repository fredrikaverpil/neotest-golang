const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello, World!\n", .{});
}

pub fn getGreeting() []const u8 {
    return "Hello, World!";
}

test "verify greeting" {
    const expected = "Hello, World!";
    const actual = getGreeting();
    try std.testing.expectEqualStrings(expected, actual);
}
