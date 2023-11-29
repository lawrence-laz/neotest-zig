const std = @import("std");
const io = std.io;
const fs = std.fs;
const builtin = @import("builtin");

pub const io_mode: io.Mode = builtin.test_io_mode;

const STATUS_FAILED = "failed";
const STATUS_PASSED = "passed";
const STATUS_SKIPPED = "skipped";

const TestResult = struct {
    absolute_file_path: []const u8,
    test_name: []const u8,
    status: []const u8,
    error_message: []const u8,
    line: u64,
};

pub fn main() !void {
    // Get test output path.
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const args_allocator = general_purpose_allocator.allocator();
    const args = try std.process.argsAlloc(args_allocator);
    defer std.process.argsFree(args_allocator, args);
    const test_output_path = args[1];

    // Prepare results.
    var results = std.ArrayList(TestResult).init(std.testing.allocator);
    var passed_count: usize = 0;
    var skip_count: usize = 0;
    var fail_count: usize = 0;

    // Load debug info.
    const debug_info = std.debug.getSelfDebugInfo() catch |debug_info_err| {
        std.debug.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(debug_info_err)});
        return;
    };
    defer debug_info.deinit();

    // Run test functions and store results.
    const test_functions = builtin.test_functions;
    for (test_functions) |test_function| {
        const is_success = if (test_function.async_frame_size) |_| switch (io_mode) {
            .evented => {
                skip_count += 1;
            },
            .blocking => {
                skip_count += 1;
                continue;
            },
        } else test_function.func();
        if (is_success) |_| {
            passed_count += 1;
            try results.append(.{
                .absolute_file_path = "TODO",
                .test_name = test_function.name,
                .status = STATUS_PASSED,
                .error_message = "",
                .line = 0,
            });
        } else |err| switch (err) {
            error.SkipZigTest => {
                skip_count += 1;
                try results.append(.{
                    .absolute_file_path = "TODO",
                    .test_name = test_function.name,
                    .status = STATUS_SKIPPED,
                    .error_message = "",
                    .line = 0,
                });
            },
            else => {
                fail_count += 1;
                if (@errorReturnTrace()) |stack_trace| {
                    const last_frame_index = @min(stack_trace.index, stack_trace.instruction_addresses.len) - 1;
                    const return_address = stack_trace.instruction_addresses[last_frame_index];
                    const address = return_address - 1;
                    const module = try debug_info.getModuleForAddress(address);
                    const symbol_info = try module.getSymbolAtAddress(debug_info.allocator, address);
                    const line_info = symbol_info.line_info orelse {
                        std.debug.print("Unable to retrieve line info\n", .{});
                        return;
                    };
                    try results.append(.{
                        .absolute_file_path = line_info.file_name,
                        .test_name = test_function.name,
                        .status = STATUS_FAILED,
                        .error_message = @errorName(err),
                        .line = line_info.line,
                    });
                }
            },
        }
    }

    // Save test results as a json file.
    std.fs.cwd().deleteFile(test_output_path) catch {};
    const file = try std.fs.createFileAbsolute(test_output_path, .{});
    try std.json.stringify(results.items, .{ .whitespace = .indent_1 }, file.writer());

    // Output results.
    if (passed_count == test_functions.len) {
        std.debug.print("All {d} tests passed.\n", .{passed_count});
    } else {
        std.debug.print("{d} passed; {d} skipped; {d} failed.\n", .{ passed_count, skip_count, fail_count });
    }
    if (passed_count != 1 or skip_count != 1 or fail_count != 1) {
        std.process.exit(1);
    }
}
