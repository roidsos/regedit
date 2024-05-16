const std = @import("std");
const hive = @import("hive.zig");
const cmdline = @import("cmdline.zig");

pub fn main() !void {
    // stdout stuffs
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var args = std.process.args();
    _ = args.skip(); // skip the exe name
    const fileName = args.next() orelse {
        try stdout.print("Error:please specify a hive name to create or open\n", .{});
        return;
    };

    // look for the file
    var isThere: bool = true;
    _ = std.fs.cwd().openFile(fileName,.{}) catch {
        isThere = false;
    };

    var opened: hive.Hive = undefined;
    if(isThere){
        opened = try hive.Hive.read(fileName); 
    }else{
        try stdout.print("creatig file \"{s}\"\n", .{fileName});
        try stdout.print("Hive name: ",.{});
        var msg_buf: [64]u8 = [1]u8{0} ** 64;
        _ = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');
        opened = try hive.Hive.create(fileName, &msg_buf);
    }

    try cmdline.cmdline(&opened,fileName);
}
