const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ziggy_dep = b.dependency("ziggy", .{
        .target = target,
        .optimize = optimize,
    });

    const command_mod = b.addModule("command", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "ziggy", .module = ziggy_dep.module("ziggy") },
        },
    });

    const command_tests = b.addTest(.{
        .root_module = command_mod,
    });

    const run_command_tests = b.addRunArtifact(command_tests);

    const test_step = b.step("test", "Run libcommand tests");
    test_step.dependOn(&run_command_tests.step);
}

comptime {
    const minimum_zig_version: []const u8 = "0.17.0-dev.1282+c0f9b51d8";
    const minimum = std.SemanticVersion.parse(minimum_zig_version) catch unreachable;
    if (builtin.zig_version.order(minimum) != .eq) {
        @compileError(std.fmt.comptimePrint(
            \\Your version of Zig is too old.
            \\Minimum required version: {s}
        , .{minimum_zig_version}));
    }
}
