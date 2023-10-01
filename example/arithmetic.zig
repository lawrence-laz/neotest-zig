const std = @import("std");

test "two plus two" {
    const expected: u32 = 4;
    try std.testing.expectEqual(expected, 2 + 2);
}

test "eleven times eleven" {
    const expected: u32 = 121;
    try std.testing.expectEqual(expected, 11 * 11);
}
