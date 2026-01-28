const std = @import("std");

pub fn main() !void {
    const environ = std.process.Environ.empty;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var thread = std.Io.Threaded.init(arena.allocator(), std.Io.Threaded.InitOptions{ .environ = environ });
    defer thread.deinit();

    const dir = try std.Io.Dir.cwd().openDir(thread.ioBasic(), "C:\\Users\\grand\\Desktop\\code\\zig\\kfind\\testshit", .{ .iterate = true });

    var walker = try dir.walk(arena.allocator());
    defer walker.deinit();

    while (try walker.next(thread.ioBasic())) |entry| {
        std.debug.print("{s} ({s})\n", .{ entry.basename, @tagName(entry.kind) });
    }
}
