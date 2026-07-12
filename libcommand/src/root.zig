// =============== Mods ===============
const std = @import("std");

const constants = @import("constants.zig");
const cli = @import("cli.zig");
const parse = @import("parse.zig");

// =============== Types ===============
const CliConfig = cli.CliConfig;
const CommandConfig = cli.CommandConfig;
const ArgConfig = cli.ArgConfig;

const ParseResult = parse.ParseResult;

// =============== Functions ===============
pub const parseSource = parse.parseSource;
pub const parseArgs = parse.parseArgs;

pub const findCommand = parse.findCommand;
pub const findArg = parse.findArg;

// =============== Tests ===============
test {
    _ = constants;
    _ = cli;
    _ = parse;
}
