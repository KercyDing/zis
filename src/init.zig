const std = @import("std");
const curl = @import("curl");

const Cli = @import("zis_schema").Cli;
const Init = @FieldType(Cli.Result, "init");

// TODO: implement init logic.
pub fn runInit(
    io: std.Io,
    allocator: std.mem.Allocator,
    init: Init,
) !void {
    _ = io;
    _ = allocator;
    _ = init;

    std.debug.print("Have not done it yet.\n", .{});
}
