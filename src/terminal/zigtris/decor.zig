// Decor, scores, etc

const std = @import("std");
const Display = @import("display.zig").Display;
const Tetronimo = @import("player.zig").Tetronimo;
const PixelStyleChars = @import("stage.zig").PixelStyleChars;
const PixelStyleColors = @import("stage.zig").PixelStyleColors;

pub const Decor = struct {
    const Self = @This();

    pub fn init() !Self {
        return Self{};
    }

    fn paintString(self: *Self, display: *Display, xpos: usize, ypos: usize, sl: []u8) !void {
        _ = self;

        var strx = xpos;
        for (sl) |elem| {
            const p: Display.DisplayPixel = .{ .fg = .white, .bg = .black, .c = elem, .bold = true };
            try display.setPixel(strx, ypos, p);
            strx += 1;
        }
    }

    pub fn paint(self: *Self, display: *Display, xpos: usize, ypos: usize, level: usize, lines: usize, score:usize, nextTimo: Tetronimo) !void {
        var buf: [32]u8 = undefined;
        const sl0 = try std.fmt.bufPrint(&buf, "Level: {d}", .{level});
        try self.paintString(display, xpos, ypos + 1, sl0);
        const sl1 = try std.fmt.bufPrint(&buf, "Lines: {d}", .{lines});
        try self.paintString(display, xpos, ypos + 3, sl1);
        const sl2 = try std.fmt.bufPrint(&buf, "Score: {d}", .{score});
        try self.paintString(display, xpos, ypos + 5, sl2);
        const sl3 = try std.fmt.bufPrint(&buf, "(q)uit", .{});
        try self.paintString(display, xpos, ypos + 12, sl3);

        const nextTimoX = xpos;
        const nextTimoY = ypos + 6;

        for (0..4) |y| {
            for (0..4) |x| {
                const p = nextTimo.anim[nextTimo.animFrame][y * 4 + x];
                try display.setPixel(nextTimoX + (x * 2 + 1), nextTimoY + (y + 1), .{ .fg = .white, .bg = PixelStyleColors[p], .c = PixelStyleChars[p], .bold = false });
                try display.setPixel(nextTimoX + (x * 2 + 1) + 1, nextTimoY + (y + 1), .{ .fg = .white, .bg = PixelStyleColors[p], .c = PixelStyleChars[p], .bold = false });
            }
        }
    }
};
