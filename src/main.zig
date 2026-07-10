const std = @import("std");
const command = @import("command");

const zis_source = @embedFile("zis_source");

pub fn main(init: std.process.Init) !void {
    const config = try command.parseConfig(
        init.arena.allocator(),
        zis_source,
    );

    std.debug.print(
        \\{s} {s}
        \\{s}
        \\
    ,
        .{
            config.name,
            config.version orelse "unknown",
            config.about,
        },
    );

    const fetch = command.findCommand(&config, "fetch") orelse {
        std.debug.print("fetch command not found\n", .{});
        return error.CommandNotFound;
    };

    std.debug.print(
        \\command: {s}
        \\about: {s}
        \\
    ,
        .{
            fetch.name,
            fetch.about,
        },
    );

    const url = command.findArg(fetch, "url") orelse {
        std.debug.print("url argument not found\n", .{});
        return error.ArgumentNotFound;
    };

    switch (url.*) {
        .positional => |arg| {
            std.debug.print(
                "positional: {s}, required={}\n",
                .{ arg.id, arg.required },
            );
        },
        else => return error.UnexpectedArgumentType,
    }

    const force = command.findArg(fetch, "force") orelse {
        std.debug.print("force argument not found\n", .{});
        return error.ArgumentNotFound;
    };

    switch (force.*) {
        .flag => |flag| {
            std.debug.print(
                "flag: --{s}",
                .{flag.long orelse flag.id},
            );

            if (flag.short) |short| {
                std.debug.print(" (-{s})", .{short});
            }

            std.debug.print("\n", .{});
        },
        else => return error.UnexpectedArgumentType,
    }
}
