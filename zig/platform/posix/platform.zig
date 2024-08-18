const std = @import("std");

pub fn redirectStdErrToFile(absolute_file_path: []const u8) !std.fs.File {
    const file = try std.fs.createFileAbsolute(absolute_file_path, .{});
    try std.posix.dup2(file.handle, std.posix.STDERR_FILENO);
    return file;
}

pub fn restoreStdErr() !void {
    try std.posix.dup2(std.posix.STDERR_FILENO, std.posix.STDERR_FILENO);
}
