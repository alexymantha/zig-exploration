const std = @import("std");
const posix = std.posix;
const messages = @import("networking").messages;
const dispatch = @import("dispatch.zig");

pub const Listener = struct {
    address: std.net.Address,
    socket: std.posix.socket_t,
    dispatcher: dispatch.Dispatcher,

    const max_message_length = 1024;

    pub fn init(dispatcher: dispatch.Dispatcher) !Listener {
        const address = std.net.Address.initIp4([_]u8{ 0, 0, 0, 0 }, 7890);

        const socket = try std.posix.socket(address.any.family, std.posix.SOCK.DGRAM, std.posix.IPPROTO.UDP);
        errdefer std.posix.close(socket);

        // const timeout = posix.timeval{ .sec = 2, .usec = 500_000 };
        // try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.RCVTIMEO, &std.mem.toBytes(timeout));
        // try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.SNDTIMEO, &std.mem.toBytes(timeout));
        try posix.setsockopt(socket, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
        try posix.bind(socket, &address.any, address.getOsSockLen());

        return .{
            .address = address,
            .socket = socket,
            .dispatcher = dispatcher,
        };
    }

    pub fn deinit(self: Listener) void {
        std.posix.close(self.socket);
    }

    pub fn listen(self: *Listener) !void {
        var buf: [max_message_length]u8 = undefined;
        var src_addr: std.net.Address = undefined;
        var addr_len: std.posix.socklen_t = @sizeOf(std.net.Address);

        while (true) {
            std.debug.print("Listening for messages on socket {}\n", .{self.socket});
            const n = posix.recvfrom(self.socket, buf[0..], 0, &src_addr.any, &addr_len) catch |err| {
                std.debug.print("Failed to receive handler: {}\n", .{err});
                return err;
            };

            std.debug.print("Received {} bytes from {}\n", .{ n, src_addr });

            const msg = try messages.init(src_addr, buf[0..n]);
            try self.dispatcher.dispatch(msg);
        }
    }
};
