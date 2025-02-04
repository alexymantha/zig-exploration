const std = @import("std");
const posix = std.posix;
const messages = @import("./message.zig");
const handlers = @import("./handlers.zig");
const server = @import("game_server.zig");

pub fn main() !void {
    const address = std.net.Address.initIp4([_]u8{ 0, 0, 0, 0 }, 7890);

    const listener = try std.posix.socket(address.any.family, std.posix.SOCK.DGRAM, std.posix.IPPROTO.UDP);
    defer std.posix.close(listener);

    try std.posix.setsockopt(listener, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try std.posix.bind(listener, &address.any, address.getOsSockLen());

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var srv = try server.Server.init(allocator, .{});

    while (true) {
        var buf: [1024]u8 = undefined;
        var src_addr: std.net.Address = undefined;
        var addr_len: std.posix.socklen_t = @sizeOf(std.net.Address);
        const n = posix.recvfrom(listener, buf[0..], 0, &src_addr.any, &addr_len) catch |err| {
            std.debug.print("Failed to receive handler: {}\n", .{err});
            return err;
        };
        std.debug.print("Received {} bytes from {}\n", .{ n, src_addr });

        const msg = try messages.init(src_addr, buf[0..n]);
        try srv.dispatch(msg);
    }
}

test {
    std.testing.refAllDecls(@This());
}
