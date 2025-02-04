const std = @import("std");
const handlers = @import("handlers.zig");

pub const Metadata = struct {
    source_address: std.net.Address,
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
    protocol_version: u16,
    message_id: u16,

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
            .protocol_version = std.mem.readInt(u16, buf[0..2], .big),
            .message_id = std.mem.readInt(u16, buf[2..4], .big),
        };
        return header;
    }
};

const PingMessage = struct {};

pub const PlayerJoin = struct {
    metadata: Metadata,
    name: []const u8,

    pub fn parse(metadata: Metadata, buf: []u8) !PlayerJoin {
        const name_length = std.mem.readInt(u8, &buf[0], .big);
        std.debug.print("Got length of {} for name\n", .{name_length});
        return .{
            .metadata = metadata,
            .name = buf[1 .. 1 + name_length],
        };
    }
};

const PlayerLeft = struct {
    id: []const u8,
};
