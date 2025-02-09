const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const networking_mod = b.createModule(.{
        .root_source_file = b.path("src/networking/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const server_mod = b.createModule(.{
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const server = b.addExecutable(.{
        .name = "zig-server",
        .root_module = server_mod,
    });
    server.root_module.addImport("networking", networking_mod);

    b.installArtifact(server);

    const server_cmd = b.addRunArtifact(server);
    server_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        server_cmd.addArgs(args);
    }

    const server_step = b.step("server", "Run the server");
    server_step.dependOn(&server_cmd.step);

    const client_mod = b.createModule(.{
        .root_source_file = b.path("src/client/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const client_exe = b.addExecutable(.{
        .name = "zig-client",
        .root_module = client_mod,
    });
    client_exe.root_module.addImport("networking", networking_mod);

    b.installArtifact(client_exe);

    const client_cmd = b.addRunArtifact(client_exe);
    client_cmd.step.dependOn(b.getInstallStep());
    const client_step = b.step("client", "Run the client");
    client_step.dependOn(&client_cmd.step);

    const server_check = b.addExecutable(.{
        .name = "server-tests",
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    server_check.root_module.addImport("networking", networking_mod);

    const client_check = b.addExecutable(.{
        .name = "client-tests",
        .root_source_file = b.path("src/client/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    client_check.root_module.addImport("networking", networking_mod);

    const check = b.step("check", "Check if exe compiles");
    check.dependOn(&server_check.step);
    check.dependOn(&client_check.step);

    const server_unit_tests = b.addTest(.{
        .root_module = server_mod,
    });
    const client_unit_tests = b.addTest(.{
        .root_module = client_mod,
    });

    const run_server_unit_tests = b.addRunArtifact(server_unit_tests);
    const run_client_unit_tests = b.addRunArtifact(client_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_server_unit_tests.step);
    test_step.dependOn(&run_client_unit_tests.step);
}
