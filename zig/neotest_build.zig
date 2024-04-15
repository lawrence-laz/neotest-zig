const std = @import("std");
const original_build_file = @import("build.zig");

pub fn build(b: *std.Build) void {
    original_build_file.build(b);
    replaceTestRunner(b);
}

fn replaceTestRunner(b: *std.Build) void {
    if (b.top_level_steps.get("test")) |test_step| {
        const test_runner = b.option([]const u8, "neotest-runner", "Use a custom test runner");
        for (test_step.step.dependencies.items) |step| {
            const run_step = step.cast(std.Build.Step.Run) orelse continue;

            // Pass down build arguments into test run
            // (ex. --neotest-results-path)
            if (b.args) |args| {
                run_step.addArgs(args);
            }

            for (step.dependencies.items) |maybe_compile_step| {
                if (maybe_compile_step.cast(std.Build.Step.Compile)) |compile_step| {
                    compile_step.test_runner = if (test_runner) |x| .{ .cwd_relative = x } else null;
                }
            }
        }
    } else {
        @panic("Neotest runner needs a 'test' step to be defined in `build.zig`.");
    }
}
