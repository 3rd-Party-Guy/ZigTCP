const std = @import("std");
const posix = std.posix;
const net = std.net;

const Reader = @import("Reader.zig");

const ClientHandler = struct {
    socket: posix.socket_t,
    address: net.Address,

    fn handleConnection(self: ClientHandler) void {
        self.handleConnectionInternal() catch |err| switch (err) {
            error.Closed => {},
            else => std.debug.print("[{any}] client handle error\n{}\n", .{ self.address, err }),
        };
    }

    fn handleConnectionInternal(self: ClientHandler) !void {
        defer posix.close(self.socket);
        std.debug.print("{} connected\n", .{self.address});

        const timeout = posix.timeval{ .sec = 2, .usec = 500_000 };
        try posix.setsockopt(self.socket, posix.SOL.SOCKET, posix.SO.RCVTIMEO, &std.mem.toBytes(timeout));
        try posix.setsockopt(self.socket, posix.SOL.SOCKET, posix.SO.SNDTIMEO, &std.mem.toBytes(timeout));

        var buf: [1024]u8 = undefined;
        var reader = Reader{ .pos = 0, .buf = buf[0..], .socket = self.socket };

        while (true) {
            const msg = try reader.readMessage();
            std.debug.print("Got: {s}\n", .{msg});
        }
    }
};
