const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip = b.option(bool, "strip", "Strip debug symbols") orelse false;

    const command_dep = b.dependency("libcommand", .{
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .imports = &.{
            .{ .name = "command", .module = command_dep.module("command") },
        },
    });

    exe_mod.addAnonymousImport("zis_source", .{
        .root_source_file = b.path("zis.ziggy"),
    });

    const exe = b.addExecutable(.{
        .name = "zis",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run zis");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    run_cmd.addPassthruArgs();

    run_step.dependOn(&run_cmd.step);
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
