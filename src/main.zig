const std = @import("std");
const net = std.net;
const posix = std.posix;

const ClientHandler = @import("ClientHandler.zig").ClientHandler;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var pool: std.Thread.Pool = undefined;
    try std.Thread.Pool.init(&pool, .{ .allocator = allocator, .n_jobs = 64 });

    const address: net.Address = try std.net.Address.resolveIp("127.0.0.1", 6969);
    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(listener);

    try setupSocketConfiguration(listener, address);

    const isRunning: bool = true;

    while (isRunning) {
        var clientAddress: net.Address = undefined;
        var addressLen: posix.socklen_t = @sizeOf(net.Address);

        const socket = posix.accept(listener, &clientAddress.any, &addressLen, 0) catch |err| {
            std.debug.print("Connection acception error\n{}\n", .{err});
            continue;
        };
        defer posix.close(socket);

        const clientHandler = ClientHandler{ .socket = socket, .address = clientAddress };
        try pool.spawn(ClientHandler.handleConnection, .{clientHandler});
    }
}

fn setupSocketConfiguration(listener: posix.socket_t, address: net.Address) !void {
    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128);
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
