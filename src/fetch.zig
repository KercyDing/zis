const std = @import("std");
const builtin = @import("builtin");
const curl = @import("curl");

const Cli = @import("zis_schema").Cli;
const Fetch = @FieldType(Cli.Result, "fetch");

const ArchiveFormat = enum {
    tar,
    tar_gz,
    tar_xz,
    tar_zst,
    zip,

    fn checkFormat(path: []const u8) ?ArchiveFormat {
        if (std.ascii.endsWithIgnoreCase(path, ".tar")) {
            return .tar;
        }
        if (std.ascii.endsWithIgnoreCase(path, ".tar.gz") or std.ascii.endsWithIgnoreCase(path, ".tgz")) {
            return .tar_gz;
        }
        if (std.ascii.endsWithIgnoreCase(path, ".tar.xz") or std.ascii.endsWithIgnoreCase(path, ".txz")) {
            return .tar_xz;
        }
        if (std.ascii.endsWithIgnoreCase(path, ".tar.zst") or std.ascii.endsWithIgnoreCase(path, ".tzst")) {
            return .tar_zst;
        }
        if (std.ascii.endsWithIgnoreCase(path, ".zip") or std.ascii.endsWithIgnoreCase(path, ".jar")) {
            return .zip;
        }

        return null;
    }
};

const TempTaskDir = struct {
    dir: std.Io.Dir,
    name: [32]u8,

    fn create(
        io: std.Io,
        parent: std.Io.Dir,
    ) !TempTaskDir {
        while (true) {
            var random_id: u128 = undefined;
            io.random(std.mem.asBytes(&random_id));

            const name = std.fmt.hex(random_id);

            parent.createDir(
                io,
                &name,
                .default_dir,
            ) catch |err| switch (err) {
                error.PathAlreadyExists => continue,
                else => return err,
            };

            const dir = parent.openDir(io, &name, .{}) catch |err| {
                parent.deleteDir(io, &name) catch {};
                return err;
            };

            return .{
                .dir = dir,
                .name = name,
            };
        }
    }

    fn cleanup(
        self: *TempTaskDir,
        io: std.Io,
        parent: std.Io.Dir,
    ) void {
        self.dir.close(io);
        parent.deleteTree(io, &self.name) catch {};
        self.* = undefined;
    }
};

/// The fetch command entry.
pub fn runFetch(
    io: std.Io,
    allocator: std.mem.Allocator,
    environ: *const std.process.Environ.Map,
    fetch: Fetch,
) !void {
    const url: [:0]u8 = try allocator.dupeSentinel(u8, fetch.url, 0);
    defer allocator.free(url);

    const download_name = fileNameFromUrl(url);
    const archive_format = ArchiveFormat.checkFormat(download_name) orelse {
        std.log.err("Unsupported format: {s}", .{download_name});
        return error.UnsupportedArchiveFormat;
    };

    _ = archive_format;

    const part_name = try std.fmt.allocPrint(allocator, "{s}.part", .{download_name});
    defer allocator.free(part_name);

    var ca_bundle = try curl.allocCABundle(allocator, io);
    defer ca_bundle.deinit(allocator);

    var temp_root = try openSystemTempDir(io, environ);
    defer temp_root.close(io);

    var download_path = try std.Io.Dir.createDirPathOpen(temp_root, io, "zis", .{});
    defer download_path.close(io);

    var task = try TempTaskDir.create(io, download_path);
    defer task.cleanup(io, download_path);

    const task_dir = task.dir;

    const archive_path = try std.fmt.allocPrint(
        allocator,
        "./{s}",
        .{download_name},
    );
    defer allocator.free(archive_path);

    var committed = false;
    defer {
        if (!committed) {
            task_dir.deleteFile(io, part_name) catch {};
        }
    }

    var easy = try curl.Easy.init(.{
        .ca_bundle = ca_bundle,
    });
    defer easy.deinit();

    try easy.setFollowLocation(true);
    try easy.setMaxRedirects(10);

    std.debug.print("Fetching...\n", .{});

    const response = blk: {
        var file = try task_dir.createFile(io, part_name, .{});
        defer file.close(io);

        var writer_buffer: [64 * 1024]u8 = undefined;
        var file_writer = file.writer(io, &writer_buffer);

        const response = try easy.fetch(url, .{
            .writer = &file_writer.interface,
        });

        try file_writer.interface.flush();

        break :blk response;
    };

    if (response.status_code < 200 or response.status_code >= 300) {
        return error.UnexpectedHttpStatus;
    }

    try task_dir.rename(part_name, task_dir, download_name, io);
    committed = true;

    // Let Zig to take it over.
    var child = try std.process.spawn(
        io,
        .{
            .argv = &.{ "zig", "fetch", archive_path },
            .cwd = .{ .dir = task_dir },
        },
    );

    const term = try child.wait(io);

    if (!term.success()) {
        std.log.err("zig fetch failed: {f}", .{term});
        return error.ZigFetchFailed;
    }
}

/// Open the temporary directory of the system.
fn openSystemTempDir(io: std.Io, environ: *const std.process.Environ.Map) !std.Io.Dir {
    const temp_path = switch (builtin.os.tag) {
        .windows => environ.get("TMP") orelse environ.get("TEMP") orelse return error.TempDirUnavailble,
        .wasi, .freestanding => return error.TempDirUnavailble,
        else => environ.get("TMPDIR") orelse "/tmp",
    };

    if (!std.fs.path.isAbsolute(temp_path)) {
        return error.InvalidTempDir;
    }

    return std.Io.Dir.openDirAbsolute(io, temp_path, .{}) catch return error.OpenTempDirFailed;
}

/// Get file name from the given URL.
inline fn fileNameFromUrl(url: []const u8) []const u8 {
    var end = url.len;

    if (std.mem.findScalar(u8, url, '?')) |index| {
        end = @min(end, index);
    }

    if (std.mem.findScalar(u8, url, '#')) |index| {
        end = @min(end, index);
    }

    while (end > 0 and url[end - 1] == '/') {
        end -= 1;
    }

    if (end == 0) return "download";

    const clean_url = url[0..end];

    const slash_index = std.mem.findScalarLast(u8, clean_url, '/') orelse return clean_url;

    const name = clean_url[slash_index + 1 ..];

    return if (name.len == 0) "download" else name;
}

test "fileNameFromUrl : success" {
    const url: []const u8 = "https://github.com/opencv/opencv/archive/refs/tags/5.0.0.tar.gz/";
    const expected: []const u8 = "5.0.0.tar.gz";

    try std.testing.expectEqualStrings(expected, fileNameFromUrl(url));
}
