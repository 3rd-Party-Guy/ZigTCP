const std = @import("std");
const net = std.net;
const posix = std.posix;

pub fn main() !void {
    const address = try net.Address.parseIp("127.0.0.1", 6969);
    const tpe = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const socket = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(socket);

    try posix.connect(socket, &address.any, address.getOsSockLen());
    try writeMessage(socket, "Hello, World!");
    try writeMessage(socket, "I have no mouth and I must scream");
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

fn writeAllV(socket: posix.socket_t, ioVector: []posix.iovec_const) !void {
    var i: usize = 0;

    while (true) {
        var n = try posix.writev(socket, ioVector[i..]);

        while (n >= ioVector[i].len) {
            n -= ioVector[i].len;
            i += 1;

            if (i >= ioVector.len)
                return;
        }

        ioVector[i].base += n;
        ioVector[i].len -= n;
    }
}
