const std = @import("std");
//var cw = ConsoleWriter{};
//
extern fn console_write(data: [*]const u8, len: usize) void;
//
//// Implement a std.io.Writer backed by console_write()
//const ConsoleWriter = struct {
//    const Writer = std.io.Writer(
//        *ConsoleWriter,
//        error{},
//        write,
//    );
//
//    fn write(
//        self: *ConsoleWriter,
//        data: []const u8,
//    ) error{}!usize {
//        _ = self;
//        console_write(data.ptr, data.len);
//        return data.len;
//    }
//
//    pub fn writer(self: *ConsoleWriter) Writer {
//        return .{ .context = self };
//    }
//};
//
//pub fn getWriter() *ConsoleWriter {
//    return &cw;
//}

var wbuf:[4096]u8 = undefined;
var cw = ConsoleWriter.init(&wbuf);

pub const WriteError = error{ Unsupported, NotConnected };

pub const ConsoleWriter = struct {
    interface: std.Io.Writer,
    err: ?WriteError = null,

    fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        var ret: usize = 0;

        const b = w.buffered();
        _ = console_write(b.ptr, b.len);
        _ = w.consume(b.len);

        for (data) |d| {
            _ = console_write(d.ptr, d.len);
            ret += d.len;
        }

        const pattern = data[data.len - 1];
        for (0..splat) |_| {
            _ = console_write(pattern.ptr, pattern.len);
            ret += pattern.len;
        }

        return ret;
    }

    pub fn init(buf: []u8) ConsoleWriter {
        return ConsoleWriter{
            .interface = .{
                .buffer = buf,
                .vtable = &.{
                    .drain = drain,
                },
            },
        };
    }
};

pub fn getWriter() *std.Io.Writer {
    return &cw.interface;
}

