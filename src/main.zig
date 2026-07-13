const std = @import("std");
const command = @import("command");

const curl = @import("curl");

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
            std.log.err("Unknown command: {s}", .{args[1]});
            return;
        },
        error.ArgumentNotFound => {
            std.log.err("Unknown argument.", .{});
            return;
        },
        error.MissingOptionValue => {
            std.log.err("Option requires a value.", .{});
            return;
        },
        else => return err,
    };

    const result = maybe_result orelse {
        //TODO: show the help.
        std.debug.print(
            \\No command provided.
            \\Try to add "fetch"?
            \\
        , .{});
        return;
    };

    if (result.positional("url")) |raw_url| {
        const url = try allocator.dupeSentinel(u8, raw_url, 0);

        var ca_bundle = try curl.allocCABundle(allocator, init.io);
        defer ca_bundle.deinit(allocator);
        var easy = try curl.Easy.init(.{
            .ca_bundle = ca_bundle,
        });
        defer easy.deinit();

        try easy.setUrl(url);
        try curl.checkCode(
            curl.libcurl.curl_easy_setopt(easy.handle, curl.libcurl.CURLOPT_NOBODY, @as(c_long, 1)),
            &easy.diagnostics,
        );

        const resp = easy.perform() catch |err| {
            if (err == error.Curl) {
                if (easy.diagnostics.getMessage()) |message| {
                    std.log.err("curl: {s}\n", .{message});
                }
            }
            return err;
        };
        std.debug.print("HTTP {d}\n", .{resp.status_code});

        var headers = try resp.iterateHeaders(.{});
        while (try headers.next()) |header| {
            std.debug.print("{s}: {s}\n", .{ header.name, header.get() });
        }
    } else {
        std.log.err("Missing URL.\n", .{});
        return;
    }
}
