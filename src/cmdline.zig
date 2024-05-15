const std = @import("std");
const h = @import("hive.zig");

pub fn cmdline(hive: h.Hive) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    _ = hive;

    while(true){
        try stdout.print("> ", .{});
        var msg_buf: [64]u8 = [1]u8{0} ** 64;
        _ = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');

        if(std.mem.eql(u8,msg_buf[0..1],"q"))
        {
            try stdout.print("Are you sure about that?(Y/anything else): ",.{});
            msg_buf = [1]u8{0} ** 64;
            _ = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');
            if(std.mem.eql(u8,msg_buf[0..1],"Y") or std.mem.eql(u8,msg_buf[0..1],"y")) break;

        }else {

        }
    }
}