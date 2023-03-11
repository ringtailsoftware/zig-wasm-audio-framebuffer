const std = @import("std");
const olive = @cImport({
    @cInclude("olive.c/olive.h");
});

pub const Surface = struct {
    const Self = @This();
    oc: olive.Olivec_Canvas,
    width: usize,
    height: usize,

    pub fn init(fb: [*]u32, width: usize, height: usize) Self {
        return Self{
            .width = width,
            .height = height,
            .oc = olive.olivec_canvas(fb, width, height, width),
        };
    }
};

pub const Renderer = struct {
    const Self = @This();
    surface: *Surface,

    pub fn init(surface: *Surface) Self {
        return Self{
            .surface = surface,
        };
    }

    pub fn fill(self: *Self, colour: u32) void {
        olive.olivec_fill(self.surface.oc, colour);
    }

    pub fn circle(self: *Self, x: i32, y: i32, r: i32, colour: u32) void {
        olive.olivec_circle(self.surface.oc, x, y, r, colour);
    }

    pub fn sprite_blend(self: *Self, spriteSurface: *Surface, x: i32, y: i32, w: i32, h: i32) void {
        olive.olivec_sprite_blend(self.surface.oc, x, y, w, h, spriteSurface.oc);
    }

    /// Note, font is incomplete, some glyphs do not appear
    pub fn text(self: *Self, x: i32, y: i32, str: []const u8) void {
        var buf: [256:0]u8 = undefined;
        _ = std.fmt.bufPrintZ(&buf, "{s}", .{str}) catch 0;
        olive.olivec_text(self.surface.oc, &buf, x, y, olive.olivec_default_font, 2, 0xFFFFFFFF);
    }
};
