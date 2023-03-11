const std = @import("std");
const console = @import("console.zig").getWriter().writer();

const spriteData = @embedFile("zero64.raw");

const olive = @cImport({
    @cInclude("olive.c/olive.h");
});

const WIDTH = 400;
const HEIGHT = 400;
var gfxFramebuffer: [WIDTH * HEIGHT]u32 = undefined;

var oc:olive.Olivec_Canvas = undefined;

var sprBuf: [64*64]u32 = undefined;
var spriteOc:olive.Olivec_Canvas = undefined;

const RENDER_QUANTUM_FRAMES = 128; // WebAudio's render quantum size
var sampleRate: f32 = 44100;
var mix_left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var mix_right: [RENDER_QUANTUM_FRAMES]f32 = undefined;

var startTime: u32 = 0;

var prng = std.rand.DefaultPrng.init(0);
var rand = prng.random();

const NUMBALLS = 1000;
var balls:[NUMBALLS]Ball = undefined;


const Ball = struct {
    const Self = @This();
    x:f32,
    y:f32,
    xd:f32,
    yd:f32,
    r:i32,
    colour:u32,

    pub fn init(x:f32, y:f32, xd:f32, yd:f32, r:i32, colour:u32) Self {
        return Self{
            .x=x,
            .y=y,
            .xd=xd,
            .yd=yd,
            .r=r,
            .colour=colour,
        };
    }

    pub fn step(self:*Self) void {
        self.x += self.xd;
        self.y += self.yd;
        if (self.x < 0 or self.x > WIDTH) {
            self.xd = -self.xd;
        }
        if (self.y < 0 or self.y > HEIGHT) {
            self.yd = -self.yd;
        }
    }

    pub fn render(self:*const Self, ctx:olive.Olivec_Canvas) void {
        olive.olivec_sprite_blend(ctx, @floatToInt(i32, self.x), @floatToInt(i32, self.y), 64, 64, spriteOc);
    }
};


pub const std_options = struct {
    pub fn logFn(
        comptime message_level: std.log.Level,
        comptime scope: @TypeOf(.enum_literal),
        comptime format: []const u8,
        args: anytype,
    ) void {
        _ = message_level;
        _ = scope;
        _ = console.print(format, args) catch 0;
    }
};

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = ret_addr;
    _ = trace;
    @setCold(true);
    _ = console.print("PANIC: {s}", .{msg}) catch 0;
    while (true) {}
}

extern fn getTimeUs() u32;

pub fn millis() u32 {
    return (getTimeUs() - startTime) / 1000;
}

export fn keyevent(keycode: u32, down: bool) void {
    _ = keycode;
    _ = down;
}

export fn getGfxBufPtr() [*]u8 {
    return @ptrCast([*]u8, &gfxFramebuffer);
}

export fn setSampleRate(s: f32) void {
    sampleRate = s;
}

export fn getLeftBufPtr() [*]u8 {
    return @ptrCast([*]u8, &mix_left);
}

export fn getRightBufPtr() [*]u8 {
    return @ptrCast([*]u8, &mix_right);
}

export fn renderSoundQuantum() void {}

fn randColour() u32 {
    const r8:u8 = rand.int(u8);
    const g8:u8 = rand.int(u8);
    const b8:u8 = rand.int(u8);
    return 0xFF000000 | @as(u32,b8)<<16 | @as(u32,g8) << 8 | @as(u32,r8);
}

export fn init() void {
    startTime = getTimeUs();
    frameCount = 0;

    oc = olive.olivec_canvas(&gfxFramebuffer, WIDTH, HEIGHT, WIDTH);
    olive.olivec_fill(oc, 0xFF000000);

    std.mem.copy(u32, &sprBuf, std.mem.bytesAsSlice(u32, @alignCast(4, spriteData)));
    spriteOc = olive.olivec_canvas(&sprBuf, 64, 64, 64);

    for (&balls) |*ball| {
        ball.* = Ball.init(
            rand.float(f32) * @as(f32,WIDTH),
            rand.float(f32) * @as(f32,HEIGHT),
            rand.float(f32)*4 - 2,
            rand.float(f32)*4 - 2,
            @floatToInt(i32, (rand.float(f32)*10 + 2)),
            randColour());
    }
}

export fn update(deltaMs: u32) void {
    _ = deltaMs;

    olive.olivec_fill(oc, 0xFF000000);  // black background
    olive.olivec_circle(oc, WIDTH/2, HEIGHT/2, WIDTH/2, 0xFF0000FF);   // big red circle

    for (&balls) |*ball| {
        ball.step();
        ball.render(oc);
    }
    var buf:[16:0]u8 = undefined;
    _ = std.fmt.bufPrintZ(&buf, "{d}", .{lastFPS}) catch 0;
    olive.olivec_text(oc, &buf, 0, 0, olive.olivec_default_font, 2, 0xFFFFFFFF);
}

var lastTime: u32 = 0;
var lastFPSTime: u32 = 0;
var frameCount: usize = 0;
var lastFPS: u32 = 0;

fn printFPS() void {
    if (millis() > lastFPSTime + 1000) {
        lastFPS = frameCount / (millis() / 1000);
        _ = console.print("FPS {d}\n", .{lastFPS}) catch 0;
        lastFPSTime = millis();
    }
    frameCount +%= 1;
    lastTime = millis();
}

export fn renderGfx() void {
    printFPS();
}

