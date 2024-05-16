const std = @import("std");
const h = @import("hive.zig");

pub fn cmdline(hive: *h.Hive, fname: []const u8) !void {
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

        }else if(std.mem.eql(u8,msg_buf[0..3],"lsk")){
            if(rWeAtRoot) {
                for(hive.keys.items) |key|
                {
                    try stdout.print(" -{s}\n",.{key.name});
                }
            }else{
                for(currkey.subkeys.items) |key|
                {
                    try stdout.print(" -{s}\n",.{key.name});
                }
            }
        }else if(std.mem.eql(u8,msg_buf[0..2],"ck")){
            try stdout.print("What key? ",.{});
            msg_buf = [1]u8{0} ** 64;
            const name = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');
            var toSet : *h.Key = undefined;
            if(rWeAtRoot) {
                toSet = hive.iterateKeys(name.?) catch {
                    try stdout.print("key not found \"{s}\"\n", .{name.?});
                    continue;
                };
            }else{
                toSet = currkey.iterateSubkeys(name.?) catch {
                    try stdout.print("subkey not found \"{s}\"\n", .{name.?});
                    continue;
                };
            }
            //append the name of the key to the path
            if(!rWeAtRoot) try path.append('/');
            for(toSet.name) |c|{
                if(c == '\n') break;
                try path.append(c);
            }
            currkey = toSet;
            rWeAtRoot = false;
        }else if(std.mem.eql(u8,msg_buf[0..4],"nkey")){
            try stdout.print("key name: ",.{});
            msg_buf = [_]u8{0} ** 64;
            const name = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');
            if(rWeAtRoot) {
                _ = hive.addKey(name.?) catch {
                    try stdout.print("failed to add key \"{s}\"\n", .{name.?});
                    continue;
                };
            }else{
                _ = currkey.addSubkey(name.?) catch {
                    try stdout.print("failed to add key \"{s}\"\n", .{name.?});
                    continue;
                };
            }
        }else if(std.mem.eql(u8,msg_buf[0..4],"rkey")){
            try stdout.print("What key? ",.{});
            msg_buf = [_]u8{0} ** 64;
            const name = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');
            if(rWeAtRoot) {
                hive.removeKey(name.?) catch {
                    try stdout.print("key not found \"{s}\"\n", .{ name.? });
                    continue;
                };
            }else{
                currkey.removeSubkey(name.?) catch {
                    try stdout.print("key not found \"{s}\"\n", .{ name.? });
                    continue;
                };
            }
        }else if(std.mem.eql(u8,msg_buf[0..4],"nent")){
            if (rWeAtRoot){
                stdout.print("Root of the hive cannot contain entries!\n", .{}) catch {};
                continue;
            }

            msg_buf = [1]u8{0} ** 64;
            try stdout.print("entry type(decimal number index 0-12): ",.{});
            const entryType = try std.fmt.parseInt(u8,(try stdin.readUntilDelimiterOrEof(&msg_buf, '\n')).?,10);
            msg_buf = [1]u8{0} ** 64;
            try stdout.print("entry name: ",.{});
            const name = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');
            if (entryType < 0 or entryType > 12) {
                try stdout.print("invalid type\n", .{});
                continue;
            }
            _ = currkey.addEntry(name.?,@enumFromInt(entryType)) catch {
                try stdout.print("failed to add entry\n", .{});
                continue;
            };
        }else if(std.mem.eql(u8,msg_buf[0..4],"rent")){
            if (rWeAtRoot){
                stdout.print("Root of the hive cannot contain entries!\n", .{}) catch {};
                continue;
            }
            try stdout.print("What entry? ",.{});
            msg_buf = [1]u8{0} ** 64;
            const name = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');
            {
                currkey.removeEntry(name.?) catch {
                    try stdout.print("entry not found \"{s}\"\n", .{name.?});
                    continue;
                };
            }
        }else if(std.mem.eql(u8,msg_buf[0..3],"lse")){
            if (rWeAtRoot){
                stdout.print("Root of the hive cannot contain entries!\n", .{}) catch {};
                continue;
            }
            for(currkey.entries.items) |entry| {
                try stdout.print(" -{s}\n", .{entry.name});
            }
        }else if(std.mem.eql(u8,msg_buf[0..5],"chval")){
            if (rWeAtRoot){
                stdout.print("Root of the hive cannot contain entries!\n", .{}) catch {};
                continue;
            }
            try stdout.print("What entry? ",.{});
            msg_buf = [1]u8{0} ** 64;
            const name = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');

            var entry = currkey.iterateEntries(name.?) catch {
                try stdout.print("entry not found \"{s}\"\n", .{name.?});
                continue;
            };
            if(entry.type != @intFromEnum(h.EntryType.SZ)) {
                //TODO: implement non-string entries
                try stdout.print("Error: non-string entry, not implemented\n", .{});
                continue;
            }

            try stdout.print("new value: ",.{});
            var val_buf = [1]u8{0} ** 1024;
            const val = try stdin.readUntilDelimiterOrEof(&val_buf, '\n');
            entry.length = @intCast(val.?.len);
            entry.data.clearAndFree();
            try entry.data.appendSlice(val.?);

        }else if(std.mem.eql(u8,msg_buf[0..6],"getval")){
            if (rWeAtRoot){
                stdout.print("Root of the hive cannot contain entries!\n", .{}) catch {};
                continue;
            }
            try stdout.print("What entry? ",.{});
            msg_buf = [1]u8{0} ** 64;
            const name = try stdin.readUntilDelimiterOrEof(&msg_buf, '\n');
            const entry = currkey.iterateEntries(name.?) catch {
                try stdout.print("entry not found \"{s}\"\n", .{name.?});
                continue;
            };
            if(entry.type != @intFromEnum(h.EntryType.SZ)) {
                //TODO: implement non-string entries
                try stdout.print("Error: non-string entry, not implemented\n", .{});
                continue;
            }
            try stdout.print("value: {s}\n", .{entry.data.items});
        }else if(std.mem.eql(u8,msg_buf[0..1],"w")){
            hive.write(fname) catch |err| {
                try stdout.print("failed to write hive: {}\n", .{err});
                continue;
            };
        }else{
            try stdout.print("unknown command \"{s}\"\n", .{msg_buf});
        }
    }
}