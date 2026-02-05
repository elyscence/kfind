const std = @import("std");

pub fn main() !void {
    const environ = std.process.Environ.empty;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var size_map = std.AutoHashMap(u64, std.ArrayList([]const u8)).init(gpa.allocator());
    defer size_map.deinit();

    var thread = std.Io.Threaded.init(arena.allocator(), std.Io.Threaded.InitOptions{ .environ = environ });
    defer thread.deinit();

    var timer = try std.time.Timer.start();

    const dir = try std.Io.Dir.cwd().openDir(thread.ioBasic(), "C:\\Users\\grand\\Downloads", .{ .iterate = true });

    var walker = try dir.walk(arena.allocator());
    defer walker.deinit();

    while (try walker.next(thread.ioBasic())) |entry| {
        if (entry.kind != .file) continue;

        const file = try dir.openFile(thread.ioBasic(), entry.path, .{ .allow_directory = false, .mode = .read_write });
        defer file.close(thread.ioBasic());
        const file_stat = try file.stat(thread.ioBasic());

        if (file_stat.size == 0) continue;

        const full_path = try dir.realPathFileAlloc(thread.ioBasic(), entry.path, arena.allocator());

        const result = try size_map.getOrPut(file_stat.size);

        if (!result.found_existing) {
            result.value_ptr.* = .{ .items = &.{}, .capacity = 0 };
        }

        try result.value_ptr.append(arena.allocator(), full_path);
    }

    var hash_map = std.AutoHashMap([std.crypto.hash.Blake3.digest_length]u8, std.ArrayList([]const u8)).init(gpa.allocator());
    defer hash_map.deinit();

    var size_iter = size_map.iterator();
    while (size_iter.next()) |kv| {
        const paths = kv.value_ptr.items;

        if (paths.len < 2) continue;

        for (paths) |path| {
            const file = try dir.openFile(thread.ioBasic(), path, .{ .allow_directory = false, .mode = .read_write });
            defer file.close(thread.ioBasic());

            const file_hash = try get_file_hash(file, &thread);
            const result = try hash_map.getOrPut(file_hash.?);

            if (!result.found_existing) {
                result.value_ptr.* = .{ .items = &.{}, .capacity = 0 };
            }
            try result.value_ptr.append(arena.allocator(), path);
        }
    }

    var iter = hash_map.iterator();
    var found = false;

    while (iter.next()) |kv| {
        const paths = kv.value_ptr.items;

        if (paths.len > 1) {
            found = true;
            std.debug.print("\nFound {d} similar files:\n", .{paths.len});
            for (paths) |path| {
                std.debug.print("  - {s}\n", .{path});
            }
        }
    }

    if (!found) {
        std.debug.print("No duplicates!\n", .{});
    }

    const elapsed = timer.read();
    const elapsed_seconds = @as(f64, @floatFromInt(elapsed)) / std.time.ns_per_s;

    std.debug.print("Time elapsed: {d:.3} s\n", .{elapsed_seconds});

    // var iter = hash_map.iterator();
    // while (iter.next()) |entry| {
    //     const key = entry.key_ptr.*;
    //     const value = entry.value_ptr.*;

    //     //const key_readable = std.fmt.bytesToHex(key, std.fmt.Case.lower);
    //     const hex_readable = std.fmt.bytesToHex(value.?, std.fmt.Case.lower);

    //     std.debug.print("value: {s}, hash: {s}\n", .{ key, hex_readable });
    // }
}

fn get_file_hash(file: std.Io.File, thread: *std.Io.Threaded) !?[std.crypto.hash.Blake3.digest_length]u8 {
    const stat = try file.stat(thread.ioBasic());

    if (stat.size == 0) {
        return null;
    }

    var file_map = try file.createMemoryMap(thread.ioBasic(), .{ .len = try file.length(thread.ioBasic()) });
    defer file_map.destroy(thread.ioBasic());

    var src_hash: [std.crypto.hash.Blake3.digest_length]u8 = undefined;
    std.crypto.hash.Blake3.hash(file_map.memory, &src_hash, .{});

    return src_hash;
}
