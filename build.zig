const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip = b.option(bool, "strip", "Strip debug symbols") orelse false;
    const static = b.option(bool, "static", "Link libcurl statically") orelse false;

    const command_dep = b.dependency("libcommand", .{
        .target = target,
        .optimize = optimize,
    });

    const curl_dep = b.dependency("curl", .{
        .target = target,
        .optimize = optimize,
        // Static linking would make the size of bin too big!(500 KB -> 7 MB)
        // Dynamic linking would affect performance.(700 us -> 3 ms)
        // So the default setting is dynamic.
        .link_vendor = static,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .imports = &.{
            .{ .name = "command", .module = command_dep.module("command") },
            .{ .name = "curl", .module = curl_dep.module("curl") },
        },
    });

    if (static) {
        exe_mod.linkSystemLibrary("curl", .{});
    }

    exe_mod.addAnonymousImport("zis_source", .{
        .root_source_file = b.path("zis.ziggy"),
        .link_libc = true,
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
    const minimum_zig_version = "0.17.0-dev.1387+01b60634c";
    const minimum = std.SemanticVersion.parse(minimum_zig_version) catch unreachable;

    if (builtin.zig_version.order(minimum) == .lt) {
        @compileError(std.fmt.comptimePrint(
            \\Your version of Zig is too old.
            \\Minimum required version: {s}
        , .{minimum_zig_version}));
    }
}
