const std = @import("std");
const net = std.net;
const posix = std.posix;

const Client = @import("Client.zig");

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

    while (isRunning) {
        var clientAddress: net.Address = undefined;
        var addressLen: posix.socklen_t = @sizeOf(net.Address);

        const socket = posix.accept(listener, &clientAddress.any, &addressLen, 0) catch |err| {
            std.debug.print("Connection acception error\n{}\n", .{err});
            continue;
        };
        defer posix.close(socket);

        const client = Client{ .socket = socket, .address = clientAddress };
        const thread = try std.Thread.spawn(.{}, client.handleConnection, .{client});
        thread.detach();
    }
}

fn writeMessage(socket: posix.socket_t, msg: []const u8) !void {
    var buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &buf, @intCast(msg.len), .little);

    var vec = [2]posix.iovec_const{
        .{ .len = 4, .base = &buf },
        .{ .len = msg.len, .base = msg.ptr },
    };

    try writeAllV(socket, &vec);
}

fn writeAllV(socket: posix.socket_t, vec: posix.iovec_const) !void {
    var i: usize = 0;
    while (true) {
        var numBytesWritten = try posix.writev(socket, vec[i..]);
        while (numBytesWritten >= vec[i].len) {
            numBytesWritten -= vec[i].len;
            i += 1;
            if (i >= vec.len) return;
        }

        vec[i].base += numBytesWritten;
        vec[i].len -= numBytesWritten;
    }
}
