const std = @import("std");
const io = std.io;

const Display = @import("display.zig").Display;

const mibu = @import("mibu");
const events = mibu.events;
const term = mibu.term;
const utils = mibu.utils;
const color = mibu.color;
const cursor = mibu.cursor;

// style 0 = empty
pub const PixelStyleChars = [8]u8{ ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' };
pub const PixelStyleColors = [8]color.Color{ .black, .white, .red, .green, .yellow, .magenta, .cyan, .blue };

pub const Stage = struct {
    pub const STAGEW = 10;
    pub const STAGEH = 18;
    pub const PixelStyle = u3;

    const Self = @This();
    buf: [STAGEW * STAGEH]PixelStyle,

    pub fn init() !Self {
        return Self{
            .buf = undefined,
        };
    }

    pub fn setPixel(self: *Self, x: usize, y: usize, p: PixelStyle) !void {
        self.buf[y * STAGEW + x] = p;
    }

    pub fn cls(self: *Self) void {
        for (0..STAGEH) |y| {
            for (0..STAGEW) |x| {
                self.buf[y * STAGEW + x] = 0;
            }
        }
    }

    pub fn paint(self: *Self, display: *Display, xo: usize, yo: usize) !void {
        // paint stage to screen, doubling up
        for (0..STAGEH) |y| {
            for (0..STAGEW) |x| {
                const p = self.buf[y * STAGEW + x];
                try display.setPixel(xo + (x * 2 + 1), yo + (y + 1), .{ .fg = .white, .bg = PixelStyleColors[p], .c = PixelStyleChars[p], .bold = false });
                try display.setPixel(xo + (x * 2 + 1) + 1, yo + (y + 1), .{ .fg = .white, .bg = PixelStyleColors[p], .c = PixelStyleChars[p], .bold = false });
            }
        }
    }
};
