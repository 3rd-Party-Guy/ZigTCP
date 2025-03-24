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
        try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.SNDTIMEO, &std.mem.toBytes(timeout));

        const numBytesRead: usize = posix.read(socket, &buf) catch |err| {
            std.debug.print("Error reading\n{}\n", .{err});
            continue;
        };

        if (numBytesRead == 0) {
            writeMessage(socket, "Error: no input provided") catch |err| {
                std.debug.print("Error writing error\n{}\n", .{err});
            };
            continue;
        }

        writeMessage(socket, buf[0..numBytesRead]) catch |err| {
            std.debug.print("Error echoing back\n{}\n", .{err});
        };
    }
}

fn writeMessage(socket: posix.socket_t, msg: []const u8) !void {
    var buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &buf, @intCast(msg.len), .little);
    try writeAll(socket, &buf);
    try writeAll(socket, msg);
}

fn writeAll(socket: posix.socket_t, msg: []const u8) !void {
    var pos: usize = 0;

    while (pos < msg.len) {
        const numBytesWritten = try posix.write(socket, msg[pos..]);
        if (numBytesWritten == 0) {
            return error.Closed;
        }

        pos += numBytesWritten;
    }
}

fn readMessage(socket: posix.socket_t, buf: []u8) ![]u8 {
    var header: [4]u8 = undefined;
    try readAll(socket, &header);

    const len = std.mem.readInt(u32, &header, .little);
    if (len > buf.len) {
        return error.BufferTooSmall;
    }

    const msg = buf[0..len];
    try readAll(socket, msg);
    return msg;
}

fn readAll(socket: posix.socket_t, buf: []u8) !void {
    var into = buf;
    while (into.len > 0) {
        const numBytesRead = try posix.read(socket, into);
        if (numBytesRead == 0) {
            return error.Closed;
        }

        into = into[numBytesRead..];
    }
}
