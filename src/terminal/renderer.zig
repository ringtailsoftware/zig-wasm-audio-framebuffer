const std = @import("std");
const olive = @cImport({
    @cInclude("olive.c/olive.h");
});
const ttf = @cImport({
    @cInclude("stb_truetype.h");
});

const Game = @import("game.zig").Game;
const Allocator = std.mem.Allocator;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const FONT_NUMCHARS = 128;
const FONT_FIRSTCHAR = ' ';

fn compat_ptrCast(comptime T:type, value:anytype) T {
    return @as(T, @ptrCast(value));
}

fn compat_intCast(comptime T:type, value:anytype) T {
    return @as(T, @intCast(value));
}

fn compat_intToFloat(comptime T:type, value:anytype) T {
    return @as(T, @floatFromInt(value));
}

fn compat_floatToInt(comptime T:type, value:anytype) T {
    return @as(T, @intFromFloat(value));
}

pub const Surface = struct {
    const Self = @This();
    oc: olive.Olivec_Canvas,
    width: usize,
    height: usize,

    pub fn init(fb: [*]u32, x: usize, y: usize, width: usize, height: usize, stride: usize) Self {
        return Self{
            .width = width,
            .height = height,
            .oc = olive.olivec_canvas(fb + y * stride + x, width, height, stride),
        };
    }

    pub fn create(allocator: Allocator, fb: [*]u32, x: usize, y: usize, width: usize, height: usize, stride: usize) !*Self {
        var s = allocator.create(Self) catch |err| {
            return err;
        };
        s.width = width;
        s.height = height;
        s.oc = olive.olivec_canvas(fb + y * stride + x, width, height, stride);
        return s;
    }
};

pub const RenderStats = struct {
    const Self = @This();

    fill: usize,
    circle: usize,
    drawLine: usize,
    sprite_blend: usize,
    sprite_blend_rotated: usize,
    text: usize,
    drawTriangle: usize,
    drawTriangleTex: usize,
    drawRect: usize,

    pub fn init() Self {
        return Self{
            .fill = 0,
            .circle = 0,
            .drawLine = 0,
            .sprite_blend = 0,
            .sprite_blend_rotated = 0,
            .text = 0,
            .drawTriangle = 0,
            .drawTriangleTex = 0,
            .drawRect = 0,
        };
    }

    pub fn reset(self: *Self) void {
        self.fill = 0;
        self.circle = 0;
        self.drawLine = 0;
        self.sprite_blend = 0;
        self.sprite_blend_rotated = 0;
        self.text = 0;
        self.drawTriangle = 0;
        self.drawTriangleTex = 0;
        self.drawRect = 0;
    }
};

pub const Font = struct {
    const Self = @This();
    bakedFontWidth: usize,
    bakedFontHeight: usize,
    bakedFont: []u8,
    bakedChars: []ttf.stbtt_bakedchar,
    pixelSize: f32,

    pub fn init(ttfname: []const u8, pixelSize: f32) !Self {
        const al = gpa.allocator();
        const bakedFontWidth: usize = compat_floatToInt(usize, FONT_NUMCHARS * pixelSize);
        const bakedFontHeight: usize = compat_floatToInt(usize, FONT_NUMCHARS * pixelSize);

        const bakedFont = al.alloc(u8, bakedFontWidth * bakedFontHeight) catch |err| {
            return err;
        };
        const bakedChars = al.alloc(ttf.stbtt_bakedchar, FONT_NUMCHARS) catch |err| {
            return err;
        };

        const fontData = Game.Assets.ASSET_MAP.get(ttfname);
        if (fontData == null) {
            return error.NoSuchTTF;
        }

        const ret = ttf.stbtt_BakeFontBitmap(compat_ptrCast([*]u8, @constCast(fontData.?)), 0, pixelSize, bakedFont.ptr, compat_intCast(c_int, bakedFontWidth), compat_intCast(c_int, bakedFontHeight), FONT_FIRSTCHAR, FONT_NUMCHARS, bakedChars.ptr);
        if (ret <= 0) {
            std.log.err("BakeFontBitmap ret={d}", .{ret});
            return error.FontInitFailed;
        }

        return Self{
            .bakedFont = bakedFont,
            .bakedChars = bakedChars,
            .pixelSize = pixelSize,
            .bakedFontWidth = bakedFontWidth,
            .bakedFontHeight = bakedFontHeight,
        };
    }
};

pub const Renderer = struct {
    const Self = @This();
    surface: *Surface,
    stats: RenderStats,

    pub fn init(surface: *Surface) Self {
        return Self{
            .surface = surface,
            .stats = RenderStats.init(),
        };
    }

    pub fn fill(self: *Self, colour: u32) void {
        self.stats.fill += 1;
        olive.olivec_fill(self.surface.oc, colour);
    }

    pub fn circle(self: *Self, x: i32, y: i32, r: i32, colour: u32) void {
        self.stats.circle += 1;
        olive.olivec_circle(self.surface.oc, x, y, r, colour);
    }

    pub fn sprite_blend(self: *Self, spriteSurface: *Surface, x: i32, y: i32, w: i32, h: i32) void {
        self.stats.sprite_blend += 1;
        olive.olivec_sprite_blend(self.surface.oc, x, y, w, h, spriteSurface.oc);
    }

    pub fn sprite_blend_rotated(self: *Self, spriteSurface: *Surface, x: i32, y: i32, w: i32, h: i32, angleRad: f32) void {
        self.stats.sprite_blend_rotated += 1;
        // two triangles
        // 1,2,3
        // 3,4,1

        const x1 = x;
        const y1 = y;
        const x2 = x;
        const y2 = y + h;
        const x3 = x + w;
        const y3 = y + h;
        const x4 = x + w;
        const y4 = y;

        const tx1 = 0;
        const ty1 = 0;
        const tx2 = 0;
        const ty2 = 1;
        const tx3 = 1;
        const ty3 = 1;
        const tx4 = 1;
        const ty4 = 0;

        const aboutx = x + @divFloor(w, 2);
        const abouty = y + @divFloor(h, 2);

        const cos = @cos(angleRad);
        const sin = @sin(angleRad);

        // FIXME, this could be optimised as corners are equidistant from midpoint
        const xr1 = aboutx + compat_floatToInt(i32, compat_intToFloat(f32, (x1 - aboutx)) * cos - compat_intToFloat(f32, (y1 - abouty)) * sin);
        const yr1 = abouty + compat_floatToInt(i32, compat_intToFloat(f32, (x1 - aboutx)) * sin + compat_intToFloat(f32, (y1 - abouty)) * cos);

        const xr2 = aboutx + compat_floatToInt(i32, compat_intToFloat(f32, (x2 - aboutx)) * cos - compat_intToFloat(f32, (y2 - abouty)) * sin);
        const yr2 = abouty + compat_floatToInt(i32, compat_intToFloat(f32, (x2 - aboutx)) * sin + compat_intToFloat(f32, (y2 - abouty)) * cos);

        const xr3 = aboutx + compat_floatToInt(i32, compat_intToFloat(f32, (x3 - aboutx)) * cos - compat_intToFloat(f32, (y3 - abouty)) * sin);
        const yr3 = abouty + compat_floatToInt(i32, compat_intToFloat(f32, (x3 - aboutx)) * sin + compat_intToFloat(f32, (y3 - abouty)) * cos);

        const xr4 = aboutx + compat_floatToInt(i32, compat_intToFloat(f32, (x4 - aboutx)) * cos - compat_intToFloat(f32, (y4 - abouty)) * sin);
        const yr4 = abouty + compat_floatToInt(i32, compat_intToFloat(f32, (x4 - aboutx)) * sin + compat_intToFloat(f32, (y4 - abouty)) * cos);

        olive.olivec_triangle3uv_blend(self.surface.oc, xr1, yr1, xr2, yr2, xr3, yr3, tx1, ty1, tx2, ty2, tx3, ty3, 1, 1, 1, spriteSurface.oc);
        olive.olivec_triangle3uv_blend(self.surface.oc, xr3, yr3, xr4, yr4, xr1, yr1, tx3, ty3, tx4, ty4, tx1, ty1, 1, 1, 1, spriteSurface.oc);
    }

    pub fn drawRectPts(self: *Self, x: i32, y: i32, w: i32, h: i32, colour: u32) void {
        self.stats.drawRectPts += 1;
        olive.olivec_frame(self.surface.oc, x, y, w, h, 1, colour);
    }

    pub fn fillRect(self: *Self, r: Game.Rect, colour: u32) void {
        self.stats.drawRect += 1;
        olive.olivec_rect(self.surface.oc, compat_floatToInt(i32, r.tl.x), compat_floatToInt(i32, r.tl.y), compat_floatToInt(i32, r.width()), compat_floatToInt(i32, r.height()), colour);
    }

    pub fn drawRect(self: *Self, r: Game.Rect, colour: u32) void {
        self.stats.drawRect += 1;
        olive.olivec_frame(self.surface.oc, compat_floatToInt(i32, r.tl.x), compat_floatToInt(i32, r.tl.y), compat_floatToInt(i32, r.width()), compat_floatToInt(i32, r.height()), 1, colour);
    }

    pub fn drawTriangle(self: *Self, x1: i32, y1: i32, x2: i32, y2: i32, x3: i32, y3: i32, colour: u32) void {
        self.stats.drawTriangle += 1;
        olive.olivec_triangle(self.surface.oc, x1, y1, x2, y2, x3, y3, colour);
    }

    pub fn drawTriangleTex(self: *Self, x1: i32, y1: i32, x2: i32, y2: i32, x3: i32, y3: i32, tx1: f32, ty1: f32, tx2: f32, ty2: f32, tx3: f32, ty3: f32, spriteSurface: *Surface) void {
        self.stats.drawTriangleTex += 1;
        olive.olivec_triangle3uv(self.surface.oc, x1, y1, x2, y2, x3, y3, tx1, ty1, tx2, ty2, tx3, ty3, 1, 1, 1, spriteSurface.oc);
    }

    pub fn drawLine(self: *Self, x1: i32, y1: i32, x2: i32, y2: i32, colour: u32) void {
        self.stats.drawLine += 1;
        olive.olivec_line(self.surface.oc, x1, y1, x2, y2, colour);
    }

    pub fn measureString(self: *Self, font: *Font, str: []const u8) Game.Rect {
        var startx: f32 = 0;
        var starty: f32 = 0;
        var r = Game.Rect.initPts(Game.vec2(0, 0), Game.vec2(0, 0));

        for (str) |b| {
            if (b - FONT_FIRSTCHAR > FONT_NUMCHARS) {
                continue;
            }

            var q: ttf.stbtt_aligned_quad = undefined;
            ttf.stbtt_GetBakedQuad(self.bakedChars.ptr, font.bakedFontWidth, font.bakedFontHeight, b - FONT_FIRSTCHAR, &startx, &starty, &q, 1);

            r.br.x = q.x0 + (q.s1 - q.s0) * font.bakedFontWidth;
            r.br.y = std.math.max(r.br.y, (q.t1 - q.t0) * font.bakedFontHeight);
        }
        return r;
    }

    pub fn drawStringLines(self: *Self, font: *Font, strs: []const []const u8, posx: i32, posy: i32, colour: u32) void {
        var y = posy;
        for (strs) |str| {
            self.drawString(font, str, posx, y, colour);
            y += compat_floatToInt(i32, font.pixelSize);
        }
    }

    pub fn drawString(self: *Self, font: *Font, str: []const u8, posx: i32, posy: i32, colour: u32) void {
        var startx: f32 = compat_intToFloat(f32, posx);
        var starty: f32 = compat_intToFloat(f32, posy);

        for (str) |b| {
            if (b - FONT_FIRSTCHAR > FONT_NUMCHARS) {
                continue;
            }

            var q: ttf.stbtt_aligned_quad = undefined;
            ttf.stbtt_GetBakedQuad(font.bakedChars.ptr, compat_intCast(c_int, font.bakedFontWidth), compat_intCast(c_int, font.bakedFontHeight), b - FONT_FIRSTCHAR, &startx, &starty, &q, 1);

            const dstx: i32 = compat_floatToInt(i32, q.x0);
            const dsty: i32 = compat_floatToInt(i32, q.y0);

            const srcx: i32 = compat_floatToInt(i32, q.s0 * compat_intToFloat(f32, font.bakedFontWidth));
            const srcy: i32 = compat_floatToInt(i32, q.t0 * compat_intToFloat(f32, font.bakedFontHeight));
            var srcw: i32 = compat_floatToInt(i32, (q.s1 - q.s0) * compat_intToFloat(f32, font.bakedFontWidth));
            var srch: i32 = compat_floatToInt(i32, (q.t1 - q.t0) * compat_intToFloat(f32, font.bakedFontHeight));

            // srcw,srch == dstw,dsth (but stride is different, src is 8bpp, dst is 32bpp)

            var xoff: i32 = 0;
            var yoff: i32 = 0;

            // clip left
            if (dstx < 0) {
                xoff = -dstx;
            }
            // clip top
            if (dsty < 0) {
                yoff = -dsty;
            }
            // clip right
            if (dstx + srcw > self.surface.oc.width) {
                srcw = compat_intCast(i32, self.surface.oc.width) - dstx;
            }
            // clip bottom
            if (dsty + srcw > self.surface.oc.width) {
                srch = compat_intCast(i32, self.surface.oc.height) - dsty;
            }

            var y: i32 = yoff;
            while (y < srch) : (y += 1) {
                var x: i32 = xoff;
                while (x < srcw) : (x += 1) {
                    const srcPixVal: u8 = font.bakedFont[
                        compat_intCast(usize, (srcx + x) +
                            (srcy + y) * compat_intCast(i32, font.bakedFontWidth))
                    ];

                    const r16 = compat_intCast(u16, (colour & 0x000000FF) >> 0);
                    const g16 = compat_intCast(u16, (colour & 0x0000FF00) >> 8);
                    const b16 = compat_intCast(u16, (colour & 0x00FF0000) >> 16);
                    const a16 = compat_intCast(u16, (colour & 0xFF000000) >> 24);

                    const dstPixVal: u32 =
                        (@as(u32, (srcPixVal * a16) >> 8) << 24) |
                        (@as(u32, (srcPixVal * b16) >> 8) << 16) |
                        (@as(u32, (srcPixVal * g16) >> 8) << 8) |
                        (@as(u32, (srcPixVal * r16) >> 8) << 0);

                    const origColourPtr = self.surface.oc.pixels +
                        compat_intCast(usize, (dstx + x) + ((dsty + y) * compat_intCast(i32, self.surface.oc.stride)));
                    olive.olivec_blend_color(origColourPtr, dstPixVal);
                }
            }
        }
    }
};
