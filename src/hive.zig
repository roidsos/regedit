const std = @import("std");

//    0x0: I8: 8 bit signed integer.
//    0x1: I16: 16 bit signed integer.
//    0x2: I32: 32 bit signed integer.
//    0x3: I64: 64 bit signed integer.
//    0x4: U8: 8 bit unsigned integer.
//    0x5: U16: 16 bit unsigned integer.
//    0x6: U32: 32 bit unsigned integer.
//    0x7: U64: 64 bit unsigned integer.
//    0x8: BOOL: A boolean.
//    0x9: CHAR: A unicode character, it is 32 bits wide.
//    0x8: SZ: A string in the system's preferred encoding, zero-terminated.
//    0x9: FLOAT: A 32-bit floating point number.
//    0xA: DOUBLE: A 64-bit floating point number.

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
    SZ = 0x8,
    FLOAT = 0xA,
    DOUBLE = 0xB,
};

pub const Entry = struct {
    name: [64]u8,
    type: u8,
    length: u8,
    data: []u8,

    pub fn read(in_stream: anytype) Entry {
        var newEntry = Entry{
            .name = std.mem.zeroes([64]u8),
            .type = 0,
            .length = 0,
            .data = &[_]u8{}
        };
        try in_stream.readNoEof(newEntry.name);
        newEntry.type = try in_stream.readByte();
        newEntry.length = try in_stream.readByte();
        newEntry.data = try in_stream.readAllAlloc(std.heap.page_allocator, @intFromEnum(newEntry.length));
        return newEntry;
    }

    pub fn write(out_stream: anytype,newEntry: Entry) !void {
        try out_stream.writeAll(&newEntry.name);
        try out_stream.writeByte(newEntry.type);
        try out_stream.writeByte(newEntry.length);
        try out_stream.writeAll(newEntry.data);
        return;
    }
};
pub const Key = struct {
    name: [64]u8,
    num_entries: u32,
    num_subkeys: u32,
    entries: []Entry,
    subkeys: []Key,

    pub fn addEntry(self: Key,name: []const u8,Type: EntryType) !void {
        self.num_entries += 1;
        self.entries[self.num_entries] = Entry{
            .name = std.mem.zeroes([64]u8),
            .type = @intFromEnum(Type),
            .length = 0,
            .data = &[_]u8{}
        };
        @memcpy(self.entries[self.num_entries].name[0..name.len], name);
    }

    pub fn addSubkey(self: Key,name: []const u8) !void {
        self.num_subkeys += 1;
        self.subkeys[self.num_subkeys] = Key{
            .name = std.mem.zeroes([64]u8),
            .num_entries = 0,
            .num_subkeys = 0,
            .entries = &[_]Entry{},
            .subkeys = &[_]Key{}
        };
        @memcpy(self.subkeys[self.num_subkeys].name[0..name.len], name);
    }

    pub fn read(in_stream: anytype) !Key {
        var newKey = Key{
            .name = std.mem.zeroes([64]u8),
            .num_entries = 0,
            .num_subkeys = 0,
            .entries = &[_]Entry{},
            .subkeys = &[_]Key{}
        };
        newKey.num_entries = try in_stream.readInt(u32, .big);
        newKey.num_subkeys = try in_stream.readInt(u32, .big);
        var i: u32 = 0;
        while(i < newKey.num_entries) : (i += 1) {
            newKey.subkeys[i] = Entry.read(in_stream);
        }
        i = 0;
        while(i < newKey.num_subkeys) : (i += 1) {
            newKey.subkeys[i] = Key.read(in_stream);
        }
        try in_stream.readNoEof(newKey.name);
        return newKey;
    }

    pub fn write(out_stream: anytype,newKey: Key) !void {
        try out_stream.writeInt(u32, newKey.num_entries, .big);
        try out_stream.writeInt(u32, newKey.num_subkeys, .big);
        try out_stream.writeAll(&newKey.name);
        var i: u32 = 0;
        while(i < newKey.num_entries) : (i += 1) {
            try Entry.write(out_stream,newKey.entries[i]);
        }
        i = 0;
        while(i < newKey.num_subkeys) : (i += 1) {
            try Key.write(out_stream,newKey.subkeys[i]);
        }
    }
};
pub const Hive = struct {
    magic: u32,
    num_keys: u32,
    checksum: u8,
    name: [64]u8,
    keys: []Key,

    pub fn addKey(self: Hive,key: Key) !void {
        self.num_keys += 1;
        self.keys[self.num_keys] = key;
    }

    pub fn readKeys(self: Hive,in_stream: anytype) !void {
        var i: u32 = 0;
        while(i < self.num_keys) : (i += 1) {
            self.keys[i] = try Key.read(in_stream);
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
            .name = std.mem.zeroes([64]u8)
        };
        newHive.magic = try in_stream.readInt(u32, .big);
        newHive.num_keys = try in_stream.readInt(u32, .big);
        newHive.checksum = try in_stream.readInt(u8, .big);
        _ = try in_stream.readAll(newHive.name[0..64]);

        if(newHive.magic != 0x69420666) unreachable;

        try newHive.readKeys(in_stream);

        return newHive;
    }

    pub fn writeKeys(self: Hive,out_stream: anytype) !void {
        var i: u32 = 0;
        while(i < self.num_keys) : (i += 1) {
            try Key.write(out_stream,self.keys[i]);
        }
    }

    pub fn create(filename: []const u8,hive_name: []const u8) !Hive {
        var file = try std.fs.cwd().createFile(filename, .{});

        var buf_writer = std.io.bufferedWriter(file.writer());
        var out_stream = buf_writer.writer();

        var newHive = Hive{
            .magic = 0x69420666,
            .num_keys = 0,
            .checksum = 0,
            .name = std.mem.zeroes([64]u8),
            .keys = &[_]Key{}
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