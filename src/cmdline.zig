const std = @import("std");
const h = @import("hive.zig");

pub fn cmdline(hive: *h.Hive) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var path = std.ArrayList(u8).init(std.heap.page_allocator);
    var rWeAtRoot: bool = true;
    var currkey: *h.Key = undefined;

    while(true){
        try stdout.print("{s} >> ", .{path.items});
        var msg_buf: [64]u8 = [1]u8{0} ** 64;
        _ = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');

        if(std.mem.eql(u8,msg_buf[0..1],"q"))
        {
            try stdout.print("Are you sure about that?(Y/anything else): ",.{});
            msg_buf = [1]u8{0} ** 64;
            _ = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');
            if(std.mem.eql(u8,msg_buf[0..1],"Y") or std.mem.eql(u8,msg_buf[0..1],"y")) break;

        }else if(std.mem.eql(u8,msg_buf[0..2],"ls")){
            if(rWeAtRoot) {
                for(hive.keys.items) |key|
                {
                    try stdout.print("  {s}\n",.{key.name});
                }
            }else{
                for(currkey.subkeys.items) |key|
                {
                    try stdout.print("  {s}\n",.{key.name});
                }
            }
        }else if(std.mem.eql(u8,msg_buf[0..2],"cd")){
            try stdout.print("Waht key? ",.{});
            msg_buf = [1]u8{0} ** 64;
            _ = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');
            var toSet : *h.Key = undefined;
            if(rWeAtRoot) {
                toSet = hive.iterateKeys(&msg_buf) catch {
                    try stdout.print("key not found\n", .{});
                    continue;
                };
            }else{
                toSet = currkey.iterateSubkeys(&msg_buf) catch {
                    try stdout.print("key not found\n", .{});
                    continue;
                };
            }
            //append the name of the key to the path
            for(toSet.name) |c|{
                if(c == '\n') break;
                try path.append(c);
            }
            currkey = toSet;
            rWeAtRoot = false;
        }else if(std.mem.eql(u8,msg_buf[0..4],"nkey")){
            try stdout.print("key name: ",.{});
            msg_buf = [1]u8{0} ** 64;
            _ = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');
            if(rWeAtRoot) {
                currkey = hive.addKey(&msg_buf) catch {
                    try stdout.print("failed to add key\n", .{});
                    continue;
                };
            }else{
                currkey = currkey.addSubkey(&msg_buf) catch {
                    try stdout.print("failed to add key\n", .{});
                    continue;
                };
            }
        }else{
            try stdout.print("unknown command \"{s}\"\n", .{msg_buf});
        }
    }
}