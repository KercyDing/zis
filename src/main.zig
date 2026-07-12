const std = @import("std");
const command = @import("command");

const zis_source = @embedFile("zis_source");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    const cli_config = try command.parseSource(
        allocator,
        zis_source,
    );

    const args = try init.minimal.args.toSlice(allocator);

    const maybe_result = command.parseArgs(
        allocator,
        &cli_config,
        args,
    ) catch |err| switch (err) {
        error.CommandNotFound => {
            std.debug.print("Unknown command: {s}\n", .{args[1]});
            return;
        },
        error.ArgumentNotFound => {
            std.debug.print("Unknown argument.\n", .{});
            return;
        },
        error.MissingOptionValue => {
            std.debug.print("Option requires a value.\n", .{});
            return;
        },
        else => return err,
    };

    const result = maybe_result orelse {
        std.debug.print("No command provided.\n", .{});
        return;
    };

    const url = result.positional("url") orelse return error.MissingUrl;

    const force = result.flag("force");

    std.debug.print("url={s}, force={}\n", .{ url, force });
}
