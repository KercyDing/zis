const std = @import("std");
const ziggy = @import("ziggy");

const constants = @import("constants.zig");
const cli = @import("cli.zig");

const CliConfig = cli.CliConfig;
const CommandConfig = cli.CommandConfig;
const ArgConfig = cli.ArgConfig;

pub const ParseError = error{
    OutOfMemory,
    CommandNotFound,
    ArgumentNotFound,
    MissingOptionValue,
    TooManyArguments,
};

pub const ParseResult = struct {
    command_config: *const CommandConfig,
    arguments: []const ParsedArg = &.{},

    pub fn positional(
        self: *const ParseResult,
        id: []const u8,
    ) ?[]const u8 {
        for (self.arguments) |arg| {
            switch (arg) {
                .positional => |pos| {
                    if (std.mem.eql(u8, pos.id, id)) {
                        return pos.value;
                    }
                },
                else => {},
            }
        }

        return null;
    }

    pub fn flag(
        self: *const ParseResult,
        id: []const u8,
    ) bool {
        for (self.arguments) |arg| {
            switch (arg) {
                .flag => |flag_arg| {
                    if (std.mem.eql(u8, flag_arg.id, id)) {
                        return true;
                    }
                },
                else => {},
            }
        }

        return false;
    }

    pub fn option(
        self: *const ParseResult,
        id: []const u8,
    ) ?[]const u8 {
        for (self.arguments) |arg| {
            switch (arg) {
                .option => |option_arg| {
                    if (std.mem.eql(u8, option_arg.id, id)) {
                        return option_arg.value;
                    }
                },
                else => {},
            }
        }

        return null;
    }
};

pub const ParsedArg = union(enum) {
    positional: Positional,
    flag: Flag,
    option: Option,

    pub const Positional = struct {
        id: []const u8,
        value: []const u8,
    };

    pub const Flag = struct {
        id: []const u8,
    };

    pub const Option = struct {
        id: []const u8,
        value: []const u8,
    };
};

/// Parse the `.ziggy` source.
pub fn parseSource(
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

/// Parse the command line arguments.
///
/// Get args from `init.minimal.args.toSlice()`.
///
/// Return null if no command, handle that.
pub fn parseArgs(
    allocator: std.mem.Allocator,
    cli_config: *const CliConfig,
    args: []const [:0]const u8,
) ParseError!?ParseResult {
    if (args.len <= 1) return null;

    const cmd_name: []const u8 = args[1];
    const cmd_config = try findCommand(cli_config, cmd_name);

    if (args.len == 2) return .{
        .command_config = cmd_config,
    };

    const arg_lists = try parseCommandArgs(allocator, cmd_config, args);

    return .{
        .command_config = cmd_config,
        .arguments = arg_lists,
    };
}

fn findCommand(
    cli_config: *const CliConfig,
    cmd_name: []const u8,
) ParseError!*const CommandConfig {
    for (cli_config.commands) |*cmd| {
        if (std.mem.eql(u8, cmd.name, cmd_name)) {
            return cmd;
        }
    }

    return ParseError.CommandNotFound;
}

pub fn parseCommandArgs(
    allocator: std.mem.Allocator,
    command: *const CommandConfig,
    args: []const [:0]const u8,
) ParseError![]const ParsedArg {
    var result: std.ArrayList(ParsedArg) = .empty;
    errdefer result.deinit(allocator);

    var i: usize = 2;
    var positional_index: usize = 0;

    while (i < args.len) {
        const raw: []const u8 = args[i];

        const found_ptr = if (isNamedArg(raw))
            findNamedArg(command, raw) orelse return ParseError.ArgumentNotFound
        else
            try findPositionalArg(command, positional_index);
        const found = found_ptr.*;
        switch (found) {
            .positional => {
                positional_index += 1;
                appendParsedArg(allocator, &result, .{
                    .positional = .{
                        .id = found.positional.id,
                        .value = raw,
                    },
                }) catch return ParseError.OutOfMemory;
                i += 1;
            },
            .flag => {
                try appendParsedArg(allocator, &result, .{
                    .flag = .{
                        .id = found.flag.id,
                    },
                });
                i += 1;
            },
            .option => {
                if (i == args.len - 1) {
                    return ParseError.MissingOptionValue;
                }

                const next: []const u8 = args[i + 1];
                if (isNamedArg(next) and findNamedArg(command, next) != null) {
                    return ParseError.MissingOptionValue;
                }

                try appendParsedArg(allocator, &result, .{
                    .option = .{
                        .id = found.option.id,
                        .value = next,
                    },
                });
                i += 2;
            },
        }
    }

    const result_slice: []const ParsedArg = try result.toOwnedSlice(allocator);
    return result_slice;
}

// ========== Inline helpers ==========
/// Find the named argument of the command.
///
/// Return error if not found.
inline fn findNamedArg(
    command: *const CommandConfig,
    name: []const u8,
) ?*const ArgConfig {
    const stripped = stripHyphen(name);

    for (command.args) |*arg| {
        if (checkNamedArg(arg, stripped)) {
            return arg;
        }
    }

    return null;
}

/// Append ParsedArg into ArrayList.
///
/// Return TooManyArguments when too long.
fn appendParsedArg(
    allocator: std.mem.Allocator,
    result: *std.ArrayList(ParsedArg),
    arg: ParsedArg,
) ParseError!void {
    if (result.items.len >= constants.ARG_COUNT_MAX) {
        return ParseError.TooManyArguments;
    }

    result.append(allocator, arg) catch
        return ParseError.OutOfMemory;
}

/// Find the next positional argument of the command.
///
/// Return error if no positional argument is available for this value.
inline fn findPositionalArg(
    command: *const CommandConfig,
    positional_index: usize,
) ParseError!*const ArgConfig {
    var found_count: usize = 0;

    for (command.args) |*arg| {
        switch (arg.*) {
            .positional => {
                if (found_count == positional_index) {
                    return arg;
                }
                found_count += 1;
            },
            else => {},
        }
    }

    return ParseError.ArgumentNotFound;
}

/// Check whether a stripped name matches a named argument.
inline fn checkNamedArg(arg: *const ArgConfig, name: []const u8) bool {
    switch (arg.*) {
        .positional => return false,
        .flag => |value| {
            if (value.short != null and std.mem.eql(u8, value.short.?, name)) {
                return true;
            } else if (std.mem.eql(u8, value.id, name)) {
                return true;
            } else return false;
        },
        .option => |value| {
            if (value.short != null and std.mem.eql(u8, value.short.?, name)) {
                return true;
            } else if (std.mem.eql(u8, value.id, name)) {
                return true;
            } else return false;
        },
    }
}

inline fn isNamedArg(name: []const u8) bool {
    return name.len > 1 and name[0] == '-';
}

/// Strip the hyphen of the raw arguments.
///
/// Return the stripped slice of arguments.
/// Like: "--force" -> "force", "-f" -> "f".
inline fn stripHyphen(name: []const u8) []const u8 {
    if (std.mem.startsWith(u8, name, "--")) {
        return name[2..];
    } else if (std.mem.startsWith(u8, name, "-")) {
        return name[1..];
    }

    return name;
}

// ========== Tests ==========
test "findCommand : error : unknown command" {
    const cmd_a: CommandConfig = .{
        .name = "init",
        .about = "for init",
    };
    const cmd_b: CommandConfig = .{
        .name = "help",
        .about = "show help",
    };
    const cli_config: CliConfig = .{
        .name = "test",
        .about = "for test",
        .commands = &.{ cmd_a, cmd_b },
    };

    try std.testing.expectError(
        ParseError.CommandNotFound,
        findCommand(&cli_config, "find"),
    );
}

test "parseCommandArgs : success : long/short flags" {
    const url_arg: ArgConfig = .{
        .positional = .{
            .id = "url",
            .required = true,
        },
    };
    const force_arg: ArgConfig = .{
        .flag = .{
            .id = "force",
            .short = "f",
        },
    };
    const command: CommandConfig = .{
        .name = "fetch",
        .args = &.{ url_arg, force_arg },
    };
    const long_args = [_][:0]const u8{
        "zis",
        "fetch",
        "https://example.com/repo.git",
        "--force",
    };
    const short_args = [_][:0]const u8{
        "zis",
        "fetch",
        "https://example.com/repo.git",
        "-f",
    };

    const long_parsed = try parseCommandArgs(std.testing.allocator, &command, long_args[0..]);
    defer std.testing.allocator.free(long_parsed);
    const short_parsed = try parseCommandArgs(std.testing.allocator, &command, short_args[0..]);
    defer std.testing.allocator.free(short_parsed);

    try std.testing.expectEqual(@as(usize, 2), long_parsed.len);
    try std.testing.expectEqualStrings("force", long_parsed[1].flag.id);
    try std.testing.expectEqual(@as(usize, 2), short_parsed.len);
    try std.testing.expectEqualStrings("force", short_parsed[1].flag.id);
}

test "parseCommandArgs : error : missing option value" {
    const path_arg: ArgConfig = .{
        .option = .{
            .id = "path",
            .short = "p",
        },
    };
    const force_arg: ArgConfig = .{
        .flag = .{
            .id = "force",
            .short = "f",
        },
    };
    const command: CommandConfig = .{
        .name = "init",
        .args = &.{ path_arg, force_arg },
    };
    const args = [_][:0]const u8{
        "zis",
        "init",
        "--path",
        "--force",
    };

    try std.testing.expectError(
        ParseError.MissingOptionValue,
        parseCommandArgs(std.testing.allocator, &command, args[0..]),
    );
}

test "parseCommandArgs : error : unknown named argument" {
    const url_arg: ArgConfig = .{
        .positional = .{
            .id = "url",
            .required = true,
        },
    };
    const command: CommandConfig = .{
        .name = "fetch",
        .args = &.{url_arg},
    };
    const args = [_][:0]const u8{
        "zis",
        "fetch",
        "--force",
    };

    try std.testing.expectError(
        ParseError.ArgumentNotFound,
        parseCommandArgs(std.testing.allocator, &command, args[0..]),
    );
}
