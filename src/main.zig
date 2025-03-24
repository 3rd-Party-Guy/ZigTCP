const std = @import("std");
const net = std.net;
const posix = std.posix;

pub fn main() !void {
    const address: net.Address = try std.net.Address.resolveIp("127.0.0.1", 6969);
    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;

    const listener = try posix.socket(address.any.family, tpe, protocol);

    defer posix.close(listener);
}
