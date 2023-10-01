const std = @import("std");

test "appending" {
    const input = "Hello, ";
    const expected = "Hello, world!";
    try std.testing.expectEqualStrings(expected, input ++ "world!");
}
