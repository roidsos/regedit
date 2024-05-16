const std = @import("std");

pub const EntryType = enum(u8) {
    I8 = 0x0,
    I16 = 0x1,
    I32 = 0x2,
    I64 = 0x3,
    U8 = 0x4,
    U16 = 0x5,
    U32 = 0x6,
    U64 = 0x7,
    BOOL = 0x8,
    CHAR = 0x9,
    SZ = 0xA,
    FLOAT = 0xB,
    DOUBLE = 0xC,
};

pub const HiveErrors = error{
    NotFound
};

pub const Entry = struct {
    name: [64]u8,
    type: u8,
    length: u8,
    data: std.ArrayList(u8),

    pub fn read(in_stream: anytype) !Entry {
        var newEntry = Entry{
            .name = std.mem.zeroes([64]u8),
            .type = 0,
            .length = 0,
            .data = std.ArrayList(u8).init(std.heap.page_allocator)
        };
        try in_stream.readNoEof(&newEntry.name);
        newEntry.type = try in_stream.readByte();
        newEntry.length = try in_stream.readByte();
        var i: u8 = 0;
        while(i < newEntry.length) : (i += 1) {
            try newEntry.data.append(try in_stream.readByte());
        }
        return newEntry;
    }

    pub fn write(out_stream: anytype,newEntry: Entry) !void {
        try out_stream.writeAll(&newEntry.name);
        try out_stream.writeByte(newEntry.type);
        try out_stream.writeByte(newEntry.length);
        var i: u8 = 0;
        while(i < newEntry.length) : (i += 1) {
            try out_stream.writeByte(newEntry.data.items[i]);
        }
        return;
    }
    pub fn setData(self: *Entry,data: []const u8) !void {
        self.length = @intCast(data.len);
        self.data.clearAndFree();
        self.data = std.ArrayList(u8).init(std.heap.page_allocator);
        try self.data.appendSlice(data);
    }
};
pub const Key = struct {
    name: [64]u8,
    num_entries: u32,
    num_subkeys: u32,
    entries: std.ArrayList(Entry),
    subkeys: std.ArrayList(Key),

    pub fn addEntry(self: *Key,name: []const u8,Type: EntryType) !*Entry {
        self.num_entries += 1;
        try self.entries.append(Entry{
            .name = std.mem.zeroes([64]u8),
            .type = @intFromEnum(Type),
            .length = 0,
            .data =std.ArrayList(u8).init(std.heap.page_allocator)
        });
        if(name.len > 64) unreachable;
        @memcpy(self.entries.items[self.num_entries - 1].name[0..name.len], name);

        return &self.entries.items[self.num_entries - 1];
    }

    pub fn addSubkey(self: *Key,name: []const u8) !*Key {
        self.num_subkeys += 1;
        try self.subkeys.append(Key{
            .name = std.mem.zeroes([64]u8),
            .num_entries = 0,
            .num_subkeys = 0,
            .entries = std.ArrayList(Entry).init(std.heap.page_allocator),
            .subkeys = std.ArrayList(Key).init(std.heap.page_allocator),
        });
        if(name.len > 64) unreachable;
        @memcpy(self.subkeys.items[self.num_subkeys - 1].name[0..name.len], name);

        return &self.subkeys.items[self.num_subkeys - 1];
    }

    pub fn iterateSubkeys(self: Key,name: []const u8) HiveErrors!*Key {
        for (self.subkeys.items) |*key| {
            if(std.mem.eql(u8,name,key.name[0..name.len])) return key;
        }
        return HiveErrors.NotFound;
    }

    pub fn removeSubkey(self: *Key,name: []const u8) HiveErrors!void {
        for (self.subkeys.items, 0..) |*key, i| {
            if(std.mem.eql(u8,name,key.name[0..name.len])) {
                _ = self.subkeys.orderedRemove(i);
                self.num_subkeys -= 1;
                return;
            }
        }
        return HiveErrors.NotFound;
    }

    pub fn iterateEntries(self: Key,name: []const u8) HiveErrors!*Entry {
        for (self.entries.items) |*entry| {
            if(std.mem.eql(u8,name,entry.name[0..name.len])) return entry;
        }
        return HiveErrors.NotFound;
    }

    pub fn removeEntry(self: *Key,name: []const u8) HiveErrors!void {
        for (self.entries.items, 0..) |*entry, i| {
            if(std.mem.eql(u8,name,entry.name[0..name.len])) {
                _ = self.entries.orderedRemove(i);
                self.num_entries -= 1;
                return;
            }
        }
        return HiveErrors.NotFound;
    }

    pub fn read(in_stream: anytype) !Key {
        var newKey = Key{
            .name = std.mem.zeroes([64]u8),
            .num_entries = 0,
            .num_subkeys = 0,
            .entries = std.ArrayList(Entry).init(std.heap.page_allocator),
            .subkeys = std.ArrayList(Key).init(std.heap.page_allocator),
        };
        const magic = try in_stream.readInt(u32, .big);
        if(magic != 0x69420666) unreachable;
        newKey.num_entries = try in_stream.readInt(u32, .big);
        newKey.num_subkeys = try in_stream.readInt(u32, .big);
        try in_stream.readNoEof(&newKey.name);
        var i: u32 = 0;
        while(i < newKey.num_entries) : (i += 1) {
            try newKey.entries.append(try Entry.read(in_stream));
        }
        i = 0;
        while(i < newKey.num_subkeys) : (i += 1) {
            try newKey.subkeys.append(try Key.read(in_stream));
        }
        return newKey;
    }

    pub fn write(out_stream: anytype,newKey: Key) !void {
        try out_stream.writeInt(u32, 0x69420666, .big);
        try out_stream.writeInt(u32, newKey.num_entries, .big);
        try out_stream.writeInt(u32, newKey.num_subkeys, .big);
        try out_stream.writeAll(&newKey.name);
        var i: u32 = 0;
        while(i < newKey.num_entries) : (i += 1) {
            try Entry.write(out_stream,newKey.entries.items[i]);
        }
        i = 0;
        while(i < newKey.num_subkeys) : (i += 1) {
            try Key.write(out_stream,newKey.subkeys.items[i]);
        }
    }
};
pub const Hive = struct {
    magic: u32,
    num_keys: u32,
    checksum: u8,
    name: [64]u8,
    keys: std.ArrayList(Key),

    pub fn iterateKeys(self: Hive,name: []const u8) HiveErrors!*Key {
        for (self.keys.items) |*key| {
            if(std.mem.eql(u8,name,key.name[0..name.len])) return key;
        }
        return HiveErrors.NotFound;
    }

    pub fn removeKey(self: *Hive,name: []const u8) HiveErrors!void {
        for (self.keys.items, 0..) |*key, i| {
            if(std.mem.eql(u8,name,key.name[0..name.len])) {
                _ = self.keys.orderedRemove(i);
                self.num_keys -= 1;
                return;
            }
        }
        return HiveErrors.NotFound;
    }

    pub fn addKey(self: *Hive,name: []const u8) !*Key {
        self.num_keys += 1;
        try self.keys.append(Key{
            .name = std.mem.zeroes([64]u8),
            .num_entries = 0,
            .num_subkeys = 0,
            .entries = std.ArrayList(Entry).init(std.heap.page_allocator),
            .subkeys = std.ArrayList(Key).init(std.heap.page_allocator),
        });
        if(name.len > 64) unreachable;
        @memcpy(self.keys.items[self.num_keys - 1].name[0..name.len], name);

        return &self.keys.items[self.num_keys - 1];
    }

    pub fn readKeys(self: *Hive,in_stream: anytype) !void {
        var i: u32 = 0;
        while(i < self.num_keys) : (i += 1) {
            try self.keys.append(try Key.read(in_stream));
        }
    }

    pub fn read(filename: []const u8) !Hive {
        var file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var newHive = Hive{
            .magic = 0,
            .num_keys = 0,
            .checksum = 0,
            .name = std.mem.zeroes([64]u8),
            .keys = std.ArrayList(Key).init(std.heap.page_allocator),
        };
        newHive.magic = try in_stream.readInt(u32, .big);
        newHive.num_keys = try in_stream.readInt(u32, .big);
        newHive.checksum = try in_stream.readInt(u8, .big);
        _ = try in_stream.readAll(newHive.name[0..64]);

        if(newHive.magic != 0xB16B00B5) unreachable;

        try newHive.readKeys(in_stream);

        return newHive;
    }

    pub fn writeKeys(self: Hive,out_stream: anytype) !void {
        var i: u32 = 0;
        while(i < self.num_keys) : (i += 1) {
            try Key.write(out_stream,self.keys.items[i]);
        }
    }

    pub fn create(filename: []const u8,hive_name: []const u8) !Hive {
        var file = try std.fs.cwd().createFile(filename, .{});

        var buf_writer = std.io.bufferedWriter(file.writer());
        var out_stream = buf_writer.writer();

        var newHive = Hive{
            .magic = 0xB16B00B5,
            .num_keys = 0,
            .checksum = 0,
            .name = std.mem.zeroes([64]u8),
            .keys = std.ArrayList(Key).init(std.heap.page_allocator)
        };
 
        if(hive_name.len > 64) unreachable;
        @memcpy(newHive.name[0..hive_name.len], hive_name);

        try out_stream.writeInt(u32, newHive.magic, .big);
        try out_stream.writeInt(u32, newHive.num_keys, .big);
        try out_stream.writeInt(u8, newHive.checksum, .big);
        try out_stream.writeAll(&newHive.name);

        try buf_writer.flush();

        return newHive;
    }

    pub fn write(self: Hive, filename: []const u8) !void {
        var file = try std.fs.cwd().createFile(filename, .{});
        var buf_writer = std.io.bufferedWriter(file.writer());
        var out_stream = buf_writer.writer();
        try out_stream.writeInt(u32, self.magic, .big);
        try out_stream.writeInt(u32, self.num_keys, .big);
        try out_stream.writeInt(u8, self.checksum, .big);
        try out_stream.writeAll(&self.name);
        try self.writeKeys(out_stream);
        try buf_writer.flush();
    }
};
