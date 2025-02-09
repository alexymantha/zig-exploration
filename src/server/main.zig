const std = @import("std");
const posix = std.posix;
const messages = @import("networking").messages;
const server = @import("server.zig");

pub fn main() !void {
    std.debug.print("Running server\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var srv = try server.Server.init(allocator, .{});
    defer srv.deinit();
    try srv.start();
}

test {
    std.testing.refAllDecls(@This());
}
