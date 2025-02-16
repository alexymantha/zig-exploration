const std = @import("std");
const posix = std.posix;
const messages = @import("networking").messages;
const flags = @import("flags");

const Config = struct {
    my_flag: u32,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const parser = try flags.Parser(Config).init(.{
        .my_flag = .{ .name = "my_flag", .required = true, .default_value = 2 },
    });

    var args = std.process.args();
    _ = try parser.parse(allocator, &args);

    // const config = parser.parse(std.process.args());

    const address = std.net.Address.initIp4([_]u8{ 127, 0, 0, 1 }, 7890);
    std.debug.print("Connection client to {}...\n", .{address});

    const sock = try std.posix.socket(address.any.family, std.posix.SOCK.DGRAM, std.posix.IPPROTO.UDP);
    defer std.posix.close(sock);

    const msg = messages.PlayerJoin.init("myself");
    const data = try msg.serialize(allocator);
    defer allocator.free(data);

    const n = try std.posix.sendto(sock, data, 0, &address.any, address.getOsSockLen());
    std.debug.print("Sent {} bytes\n", .{n});
}

test {
    std.testing.refAllDecls(@This());
}
