const std = @import("std");
const hive = @import("hive.zig");

pub fn main() !void {
    // stdout stuffs
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    defer bw.flush() catch unreachable; // don't forget to flush!

    try stdout.print("Hello World!\n", .{});

    var ass= try hive.Hive.create("test.reg","SYSTEM");

    var key = try ass.addKey("test");
    
    var ent = try key.addEntry("test",hive.EntryType.SZ);

    try ent.setData("Suck my cock");

    try ass.write("test.reg");

}
