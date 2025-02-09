const std = @import("std");
const testing = std.testing;

pub const Metadata = struct {
    source_address: ?std.net.Address,
    header: Header,
};

pub const Message = union(enum) {
    ping: PingMessage,
    player_join: PlayerJoin,
    player_left: PlayerLeft,
};

pub fn init(source_address: std.net.Address, buf: []u8) !Message {
    const header = try Header.read(buf[0..Header.header_len]);
    std.debug.print("Using header length: {}\n", .{Header.header_len});
    std.debug.print("Got message with protocol_version: {} and message id: {}\n", .{ header.protocol_version, header.message_id });

    const MessageType = @typeInfo(Message).@"union".tag_type.?;
    const message_type: MessageType = @enumFromInt(header.message_id);

    const metadata = Metadata{
        .source_address = source_address,
        .header = header,
    };

    switch (message_type) {
        .player_join => return Message{ .player_join = try PlayerJoin.parse(metadata, buf[Header.header_len..]) },
        else => return error.UnknownMessage,
    }
}

pub const Header = struct {
    protocol_version: u8 = 1,
    message_id: u8,

    const header_len = blk: {
        const info = @typeInfo(Header);
        var len: u16 = 0;
        for (info.@"struct".fields) |f| {
            len += @sizeOf(f.type);
        }

        break :blk len;
    };

    pub fn read(buf: []u8) !Header {
        if (buf.len < header_len) {
            return error.MessageTooShort;
        }

        const header = Header{
            .protocol_version = std.mem.readInt(u8, buf[0..1], .big),
            .message_id = std.mem.readInt(u8, buf[1..2], .big),
        };
        return header;
    }

    pub fn serialize(self: Header, buf: []u8) void {
        buf[0] = self.protocol_version;
        buf[1] = self.message_id;
    }
};

const PingMessage = struct {};

pub const PlayerJoin = struct {
    metadata: Metadata,
    name: []const u8,

    pub fn init(name: []const u8) PlayerJoin {
        return .{
            .metadata = .{
                .source_address = null,
                .header = Header{
                    .message_id = @intFromEnum(Message.player_join),
                },
            },
            .name = name,
        };
    }

    pub fn parse(metadata: Metadata, buf: []u8) !PlayerJoin {
        const name_length = std.mem.readInt(u8, &buf[0], .big);
        std.debug.print("Got length of {} for name\n", .{name_length});
        return .{
            .metadata = metadata,
            .name = "test",
        };
    }

    pub fn serialize(self: PlayerJoin, allocator: std.mem.Allocator) ![]u8 {
        if (self.name.len > std.math.maxInt(u8)) {
            return error.NameTooLong;
        }
        const name_length: u8 = @intCast(self.name.len);
        std.debug.print("Serializing name with length: {}\n", .{name_length});

        var buf = try allocator.alloc(u8, Header.header_len + name_length + 1);
        errdefer allocator.free(buf);

        const header_offset = Header.header_len;
        self.metadata.header.serialize(buf[0..header_offset]);
        buf[header_offset] = name_length;
        std.mem.copyForwards(u8, buf[header_offset + 1 ..], self.name);
        return buf;
    }

    test "serialize and parse" {
        const allocator = std.testing.allocator;

        const name = "myself";
        const msg = PlayerJoin.init(name);
        const data = try msg.serialize(allocator);
        defer allocator.free(data);
        const parsed = try PlayerJoin.parse(msg.metadata, data[Header.header_len..]);

        testing.expectEqualStrings(u8, name, parsed.name);
    }
};

const PlayerLeft = struct {
    id: []const u8,
};
