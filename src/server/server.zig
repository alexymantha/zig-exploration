const std = @import("std");
const messages = @import("networking").messages;
const network = @import("network.zig");
const dp = @import("dispatch.zig");

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
    listener: network.Listener,
    mutex: std.Thread.Mutex,

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

        var server: Server = .{
            .allocator = allocator,
            .rand = prng,
            .listener = undefined,
            .mutex = std.Thread.Mutex{},
            .max_players = config.max_players,
            .players = players,
        };

        const dispatcher = dp.Dispatcher{ .server = &server };
        server.listener = try network.Listener.init(dispatcher);
        return server;
    }

    pub fn deinit(self: *Server) void {
        self.players.deinit();
    }

    pub fn start(self: *Server) !void {
        const network_thread = try std.Thread.spawn(.{}, network.Listener.listen, .{self.listener});
        network_thread.detach();

        while (true) {
            std.debug.print("Server tick\n", .{});
            std.time.sleep(std.time.ns_per_s);
        }
    }

    pub fn dispatch(self: *Server, message: messages.Message) !void {
        std.debug.print("Server will dispatch message.\n", .{});
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

        {
            self.mutex.lock();
            defer self.mutex.unlock();
            try self.players.append(player);
        }

        std.debug.print("{s} ({}) joined the server!", .{ player.name, player.id });
    }

    test "player joins server" {
        var server = try Server.init(std.testing.allocator, .{ .max_players = 1 });
        defer server.deinit();

        const player1 = messages.PlayerJoin.init("test-player");
        try server.handle_player_join(player1);

        const player2 = messages.PlayerJoin.init("test-player");
        try std.testing.expectError(error.ServerFull, server.handle_player_join(player2));
    }
};
