const std = @import("std");
const ziggy = @import("ziggy");

const constants = @import("constants.zig");
const cli = @import("cli.zig");

pub const CliConfig = cli.CliConfig;
pub const CommandConfig = cli.CommandConfig;
pub const ArgConfig = cli.ArgConfig;

pub fn parseConfig(
    allocator: std.mem.Allocator,
    source: [:0]const u8,
) !CliConfig {
    var meta: ziggy.Deserializer.Meta = .init;

    return ziggy.deserializeLeaky(
        CliConfig,
        allocator,
        source,
        &meta,
        .{},
    );
}

pub fn argId(arg: *const ArgConfig) []const u8 {
    return switch (arg.*) {
        .positional => |value| value.id,
        .flag => |value| value.id,
        .option => |value| value.id,
    };
}

pub fn findCommand(
    config: *const CliConfig,
    name: []const u8,
) ?*const CommandConfig {
    for (config.commands) |*cmd| {
        if (std.mem.eql(u8, cmd.name, name)) {
            return cmd;
        }
    }

    return null;
}

pub fn findArg(
    cmd: *const CommandConfig,
    id: []const u8,
) ?*const ArgConfig {
    for (cmd.args) |*arg| {
        if (std.mem.eql(u8, argId(arg), id)) {
            return arg;
        }
    }

    return null;
}

// =============== Tests ===============
test {
    _ = constants;
    _ = cli;
}
