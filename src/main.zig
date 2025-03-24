const std = @import("std");
const net = std.net;
const posix = std.posix;

pub fn main() !void {
    const address: net.Address = try std.net.Address.resolveIp("127.0.0.1", 6969);
    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128);

    const isRunning: bool = true;
    var buf: [128]u8 = undefined;
    while (isRunning) {
        var clientAddress: net.Address = undefined;
        var addressLen: posix.socklen_t = @sizeOf(net.Address);

        const socket = posix.accept(listener, &clientAddress.any, &addressLen, 0) catch |err| {
            std.debug.print("Connection acception error\n{}\n", .{err});
            continue;
        };
        defer posix.close(socket);

        std.debug.print("{} connected\n", .{clientAddress});

        const timeout = posix.timeval{ .sec = 2, .usec = 500_000 };
        try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.RCVTIMEO, &std.mem.toBytes(timeout));

        const numBytesRead: usize = posix.read(socket, &buf) catch |err| {
            std.debug.print("Error reading\n{}\n", .{err});
            continue;
        };

        if (numBytesRead == 0) {
            write(socket, "Error: no input provided") catch |err| {
                std.debug.print("Error writing error\n{}\n", .{err});
            };

            continue;
        }

        write(socket, buf[0..numBytesRead]) catch |err| {
            std.debug.print("Error echoing back\n{}\n", .{err});
        };
    }
}

fn write(socket: posix.socket_t, msg: []const u8) !void {
    var pos: usize = 0;

    while (pos < msg.len) {
        const numBytesWritten = try posix.write(socket, msg[pos..]);
        if (numBytesWritten == 0) {
            return error.Closed;
        }

        pos += numBytesWritten;
    }
}
