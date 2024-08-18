const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;

extern "kernel32" fn SetStdHandle(nStdHandle: windows.DWORD, hHandle: windows.HANDLE) callconv(windows.WINAPI) windows.BOOL;

fn setStdHandle(stdHandle: windows.DWORD, handle: windows.HANDLE) !void {
    const result = SetStdHandle(stdHandle, handle);
    if (result == 0) {
        switch (windows.kernel32.GetLastError()) {
            else => |err| return windows.unexpectedError(err),
        }
    }
}

var original_std_err_handle: windows.HANDLE = windows.INVALID_HANDLE_VALUE;

pub fn redirectStdErrToFile(absolute_file_path: []const u8) !std.fs.File {
    const file = try std.fs.createFileAbsolute(absolute_file_path, .{});
    const handle: std.os.windows.HANDLE = file.handle;

    if (original_std_err_handle == windows.INVALID_HANDLE_VALUE) {
        original_std_err_handle = try windows.GetStdHandle(windows.STD_ERROR_HANDLE);
    }

    try setStdHandle(std.os.windows.STD_ERROR_HANDLE, handle);

    return file;
}

pub fn restoreStdErr() !void {
    try setStdHandle(std.os.windows.STD_ERROR_HANDLE, original_std_err_handle);
}
