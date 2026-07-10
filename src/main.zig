const std = @import("std");
const command = @import("command");

pub fn main() !void {
    _ = command;

    std.debug.print("Hello, zis!\n", .{});
}
