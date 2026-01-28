const std = @import("std");
//const windows = std.os.windows;

pub fn main() !void {
    const environ = std.process.Environ.empty;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var thread = std.Io.Threaded.init(arena.allocator(), std.Io.Threaded.InitOptions{ .environ = environ });
    defer thread.deinit();

    const dir = try std.Io.Dir.cwd().openDir(thread.ioBasic(), "C:\\Users\\grand\\Desktop\\code\\zig\\kfind\\testshit", .{ .iterate = true });

    var walker = try dir.walk(arena.allocator());
    defer walker.deinit();
    //defer opened_dir.close();
    //const dir_info = try opened_dir
    while (try walker.next(thread.ioBasic())) |entry| {
        std.debug.print("{s}\n", .{entry.basename});
    }
}
