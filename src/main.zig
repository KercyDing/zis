const std = @import("std");

const curl = @import("curl");
const Cli = @import("zis_schema").Cli;
const Fetch = @FieldType(Cli.Result, "fetch");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);

    const result = try Cli.parse(allocator, args);

    switch (result) {
        .fetch => |fetch| try runFetch(init.io, allocator, fetch),
        .init => try runInit(),
    }
}

fn runFetch(
    io: std.Io,
    allocator: std.mem.Allocator,
    fetch: Fetch,
) !void {
    const url = try allocator.dupeSentinel(u8, fetch.url, 0);

    var ca_bundle = try curl.allocCABundle(allocator, io);
    defer ca_bundle.deinit(allocator);

    var easy = try curl.Easy.init(.{
        .ca_bundle = ca_bundle,
    });
    defer easy.deinit();

    try easy.setUrl(url);
    try curl.checkCode(
        curl.libcurl.curl_easy_setopt(
            easy.handle,
            curl.libcurl.CURLOPT_NOBODY,
            @as(c_long, 1),
        ),
        &easy.diagnostics,
    );

    const response = easy.perform() catch |err| {
        if (err == error.Curl) {
            if (easy.diagnostics.getMessage()) |message| {
                std.log.err("curl: {s}", .{message});
            }
        }
        return err;
    };

    std.debug.print("HTTP {d}\n", .{response.status_code});

    var headers = try response.iterateHeaders(.{});
    while (try headers.next()) |header| {
        std.debug.print("{s}: {s}\n", .{ header.name, header.get() });
    }
}

// TODO: implement init logic.
fn runInit() !void {
    std.debug.print("Have not done it yet.\n", .{});
}
