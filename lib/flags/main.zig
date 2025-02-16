const std = @import("std");
const testing = std.testing;

fn Flag(comptime T: anytype) type {
    return struct {
        name: []const u8,
        required: bool = false,
        default_value: ?T = null,
    };
}

fn Flags(comptime T: anytype) type {
    const info = @typeInfo(T);
    const in_fields = info.@"struct".fields;
    var fields: [in_fields.len]std.builtin.Type.StructField = undefined;

    for (in_fields, 0..) |field, i| {
        fields[i] = .{
            .name = field.name,
            .type = Flag(field.type),
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = 0,
        };
    }

    return @Type(.{
        //no-fold
        .@"struct" = .{
            //no-fold
            .layout = .auto,
            .fields = &fields,
            .decls = info.@"struct".decls,
            .is_tuple = false,
        },
    });
}

pub fn Parser(T: anytype) type {
    return struct {
        const InnerFlags = Flags(T);
        const Self = @This();

        flags: Flags(T),

        pub fn init(flags: InnerFlags) !Self {
            return .{
                .flags = flags,
            };
        }

        pub fn parse(_: *const Self, allocator: std.mem.Allocator, args: *std.process.ArgIterator) !T {
            var argsMap = std.StringHashMap([]const u8).init(allocator);
            defer argsMap.deinit();

            _ = args.next(); // Skip program name
            while (args.next()) |raw| {
                const arg = try Arg.parse(raw);
                try argsMap.put(arg.key, arg.value);
            }

            var value: T = undefined;
            inline for (
                std.meta.fields(T),
            ) |field| {
                const str = argsMap.get(field.name) orelse return error.ArgumentNotFound;
                var val: field.type = undefined;
                switch (field.type) {
                    u32 => val = try std.fmt.parseInt(u32, str, 10),
                    else => @compileError("Unsupported type in flag struct"),
                }
                @field(value, field.name) = val;
            }
            return undefined;
        }
    };
}

const Arg = struct {
    key: []const u8,
    value: []const u8,

    fn parse(value: []const u8) !Arg {
        if (!std.mem.startsWith(u8, value, "--")) {
            return error.NotArgument;
        }
        const arg = value[2..];

        const i = std.mem.indexOf(u8, value, "=");
        if (i == null) {
            return .{ .key = arg, .value = "true" };
        }

        return .{ .key = arg[0..i.?], .value = arg[i.?..] };
    }
};

test "parse argument" {
    std.debug.print("test parsing", .{});
    testing.expectEqual(try Arg.parse("--flag=value"), .{ .key = "flag", .value = "value" });
    try testing.exp(Arg{ .key = "flag", .value = "value" }, try Arg.parse("--flag=value"));
}
