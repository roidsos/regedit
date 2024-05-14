const std = @import("std");
const hive = @import("hive.zig");

pub fn main() !void {
    // stdout stuffs
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    defer bw.flush() catch unreachable; // don't forget to flush!

    try stdout.print("Hello World!\n", .{});

    const ass= try hive.Hive.create("test.reg","SYSTEM");

    try ass.write("test.reg");

}
