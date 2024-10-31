const std = @import("std");
const console = @import("console.zig").getWriter().writer();
const spriteData = @embedFile("zero64.raw");
const math = @import("zlm.zig");
const Vec2 = math.Vec2;
const vec2 = math.vec2;

const WIDTH = 400;
const HEIGHT = 400;
var gfxFramebuffer: [WIDTH * HEIGHT]u32 = undefined;

const RENDER_QUANTUM_FRAMES = 128; // WebAudio's render quantum size
var sampleRate: f32 = 44100;
var mix_left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var mix_right: [RENDER_QUANTUM_FRAMES]f32 = undefined;

var startTime: u32 = 0;

var prng = std.rand.DefaultPrng.init(0);
var rand = prng.random();

const NUMBALLS = 1000;
var balls: [NUMBALLS]Ball = undefined;

const Renderer = @import("renderer.zig").Renderer;
const Surface = @import("renderer.zig").Surface;

var gSurface: Surface = undefined; //Surface.init(&gfxFramebuffer, WIDTH, HEIGHT);
var gRenderer: Renderer = undefined; //Renderer.init(&gSurface);
var sprBuf: [64 * 64]u32 = undefined;
var spriteSurface: Surface = undefined; //Surface.init(sprBuf, 64, 64);

const Ball = struct {
    const Self = @This();
    pos: Vec2,
    vel: Vec2,
    r: i32,
    colour: u32,

    pub fn init(pos: Vec2, vel: Vec2, r: i32, colour: u32) Self {
        return Self{
            .pos = pos,
            .vel = vel,
            .r = r,
            .colour = colour,
        };
    }

    pub fn step(self: *Self) void {
        self.pos = self.pos.add(self.vel);
        if (self.pos.x < 0 or self.pos.x > WIDTH) {
            self.vel.x = -self.vel.x;
        }
        if (self.pos.y < 0 or self.pos.y > HEIGHT) {
            self.vel.y = -self.vel.y;
        }
    }

    pub fn render(self: *const Self, renderer: *Renderer) void {
        renderer.sprite_blend(&spriteSurface, @intFromFloat(self.pos.x), @intFromFloat(self.pos.y), 64, 64);
    }
};

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

pub const std_options: std.Options = .{
    .logFn = logFn,
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
    return @ptrCast(&gfxFramebuffer);
}

export fn setSampleRate(s: f32) void {
    sampleRate = s;
}

export fn getLeftBufPtr() [*]u8 {
    return @ptrCast(&mix_left);
}

export fn getRightBufPtr() [*]u8 {
    return @ptrCast(&mix_right);
}

export fn renderSoundQuantum() void {}

fn randColour() u32 {
    const r8: u8 = rand.int(u8);
    const g8: u8 = rand.int(u8);
    const b8: u8 = rand.int(u8);
    return 0xFF000000 | @as(u32, b8) << 16 | @as(u32, g8) << 8 | @as(u32, r8);
}

export fn init() void {
    startTime = getTimeUs();
    frameCount = 0;

    gSurface = Surface.init(&gfxFramebuffer, WIDTH, HEIGHT);
    gRenderer = Renderer.init(&gSurface);

    @memcpy(&sprBuf, @as([*]const u32, @ptrCast(@alignCast(spriteData))));

    spriteSurface = Surface.init(&sprBuf, 64, 64);

    gRenderer.fill(0xFF000000);

    for (&balls) |*ball| {
        ball.* = Ball.init(vec2(rand.float(f32) * @as(f32, WIDTH), rand.float(f32) * @as(f32, HEIGHT)), vec2(rand.float(f32) * 4 - 2, rand.float(f32) * 4 - 2), @intFromFloat((rand.float(f32) * 10 + 2)), randColour());
    }
}


var buf: [16]u8 = undefined;

export fn update(deltaMs: u32) void {
    _ = deltaMs;

    gRenderer.fill(0xFF000000); // black background
    gRenderer.circle(WIDTH / 2, HEIGHT / 2, WIDTH / 2, 0xFF0000FF); // big red circle

    for (&balls) |*ball| {
        ball.step();
        ball.render(&gRenderer);
    }
    _ = std.fmt.bufPrint(&buf, "{d}", .{lastFPS}) catch return;
    gRenderer.text(0, 0, &buf);
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
