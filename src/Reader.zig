const std = @import("std");
const posix = std.posix;

pub const Reader = struct {
    buf: []u8,
    pos: usize = 0,
    nextStart: usize = 0,
    socket: posix.socket_t,

    fn readMessage(self: *Reader) ![]u8 {
        var buf = self.buf;

        while (true) {
            if (try self.checkBuffer()) |message|
                return message;

            const pos = self.pos;
            const n = try posix.read(self.socket, buf[pos..]);

            if (n == 0)
                return error.Closed;

            self.pos += n;
        }
    }

    fn checkBuffer(self: *Reader) !?[]u8 {
        const buf = self.buf;
        const pos = self.pos;
        const start = self.start;

        std.debug.assert(pos >= start);
        const unprocessed = buf[start..pos];

        if (unprocessed.len < 4) {
            self.ensureSpace(4 - unprocessed.len) catch unreachable;
            return null;
        }

        const messageLength = std.mem.readInt(u32, unprocessed[0..4], .little);
        const totalLength = messageLength + 4;

        if (unprocessed.len < totalLength) {
            try ensureBufferSpace(totalLength);
            return null;
        }

        self.start += totalLength;
        return unprocessed[4..totalLength];
    }

    fn ensureBufferSpace(self: *Reader, space: usize) error{BufferTooSmall}!void {
        const buf = self.buf;
        const start = self.start;
        const spare = buf.len - start;

        if (buf.len < space)
            return error.BufferTooSmall;
        if (spare >= space)
            return;

        const unprocessed = buf[start..self.pos];
        std.mem.copyForwards(u8, buf[0..unprocessed.len], unprocessed);
        self.start = 0;
        self.pos = unprocessed.len;
    }
};
