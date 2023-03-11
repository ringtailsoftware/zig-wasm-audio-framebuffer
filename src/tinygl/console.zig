const std = @import("std");
var cw = ConsoleWriter{};

extern fn console_write(data: [*]const u8, len: usize) void;
//fn console_write(data:[*]const u8, len:usize) void {
//    std.log.info("{s}", .{data[0..len]});
//}

// Implement a std.io.Writer backed by console_write()
const ConsoleWriter = struct {
    const Writer = std.io.Writer(
        *ConsoleWriter,
        error{},
        write,
    );

    fn write(
        self: *ConsoleWriter,
        data: []const u8,
    ) error{}!usize {
        _ = self;
        console_write(data.ptr, data.len);
        return data.len;
    }

    pub fn writer(self: *ConsoleWriter) Writer {
        return .{ .context = self };
    }
};

pub fn getWriter() *ConsoleWriter {
    return &cw;
}
