const server = @import("server.zig");
const messages = @import("networking").messages;

pub const Dispatcher = union(enum) {
    server: *server.Server,

    pub fn dispatch(self: Dispatcher, msg: messages.Message) !void {
        switch (self) {
            inline else => |impl| return impl.dispatch(msg),
        }
    }
};
