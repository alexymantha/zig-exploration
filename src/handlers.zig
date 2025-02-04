const std = @import("std");
const messages = @import("message.zig");

pub fn handle_player_join(msg: messages.PlayerJoin) !void {
    std.debug.print("{s} joined the game!\n", .{msg.name});
}
