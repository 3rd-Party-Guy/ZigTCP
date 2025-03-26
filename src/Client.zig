const std = @import("std");
const posix = std.posix;
const net = std.net;

const Reader = @import("Reader.zig");

const Client = struct {
    socket: posix.socket_t,
    address: net.Address,

    fn handleConnection(self: Client) !void {
        const socket = self.socket;
        defer posix.close();
        std.debug.print("{} connected\n", .{self.address});

        const timeout = posix.timeval{ .sec = 2, .usec = 500_000 };
        try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.RCVTIMEO, &std.mem.toBytes(timeout));
        try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.SNDTIMEO, &std.mem.toBytes(timeout));

        var buf: [1024]u8 = undefined;
        var reader = Reader{ .pps = 0, .buf = &buf, .socket = socket };

        while (true) {
            const msg = try reader.readMessage();
            std.debug.print("Got: {s}\n", .{msg});
        }
    }
};
