const std = @import("std");
const messages = @import("message.zig");

pub const Player = struct {
    name: []const u8,
    id: u32,
};

pub const ServerConfig = struct {
    max_players: u32 = 20,
    seed: ?u64 = null,
};

pub const Server = struct {
    allocator: std.mem.Allocator,
    rand: std.Random.DefaultPrng,

    max_players: u32,
    players: std.ArrayList(Player) = undefined,

    pub fn init(allocator: std.mem.Allocator, config: ServerConfig) !Server {
        const players = try std.ArrayList(Player).initCapacity(allocator, config.max_players);
        errdefer players.deinit();

        const seed = config.seed orelse blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        };
        const prng = std.Random.DefaultPrng.init(seed);

        return .{
            .allocator = allocator,
            .rand = prng,
            //no-collapse
            .max_players = config.max_players,
            .players = players,
        };
    }

    pub fn deinit(self: *Server) void {
        self.players.deinit();
    }

    pub fn dispatch(self: *Server, message: messages.Message) !void {
        switch (message) {
            .player_join => try self.handle_player_join(message.player_join),
            else => return error.NoHandlerForMessage,
        }
    }

    fn handle_player_join(self: *Server, msg: messages.PlayerJoin) !void {
        if (self.players.items.len >= self.max_players) {
            return error.ServerFull;
        }

        const player = Player{
            .id = self.rand.random().int(u32),
            .name = msg.name,
        };

        try self.players.append(player);

        std.debug.print("{s} ({}) joined the server!", .{ player.name, player.id });
    }

    test "player joins server" {
        var server = try Server.init(std.testing.allocator, .{ .max_players = 1 });
        defer server.deinit();

        try server.handle_player_join(.{
            .name = "test-player",
        });

        try std.testing.expectError(error.ServerFull, server.handle_player_join(.{
            .name = "test-player2",
        }));
    }
};
