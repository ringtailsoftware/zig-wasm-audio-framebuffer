const std = @import("std");
const console = @import("console.zig").getWriter().writer();
const ziggysynth = @import("ziggysynth.zig");
const pocketmod = @cImport({
    @cInclude("pocketmod.h");
});

const synth_font = @embedFile("TimGM6mb.sf2");
const mod_data = @embedFile("escape.mod");

const SoundFont = ziggysynth.SoundFont;
const Synthesizer = ziggysynth.Synthesizer;
const SynthesizerSettings = ziggysynth.SynthesizerSettings;

// WebAudio's render quantum size.
const RENDER_QUANTUM_FRAMES = 128;

var fx_left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var fx_right: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var mix_left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var mix_right: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var music_leftright: [RENDER_QUANTUM_FRAMES * 2]f32 = undefined;
var sampleRate: f32 = 44100;
var synthesizer: Synthesizer = undefined;

const WIDTH = 320;
const HEIGHT = 240;
var gfxFramebuffer: [WIDTH * HEIGHT]u32 = undefined; // ABGR

var ctx: pocketmod.pocketmod_context = undefined;

const fx_volume = 1.0;
const music_volume = 0.1;

var prng = std.rand.DefaultPrng.init(0);
var rand = prng.random();

var startTime: u32 = 0;

const COLOUR_BLACK = 0xFF000000;
const COLOUR_WHITE = 0xFFFFFFFF;

var ballx: f32 = undefined;
var bally: f32 = undefined;
var ballxd: f32 = undefined;
var ballyd: f32 = undefined;

var batwidth: f32 = undefined;
var batheight: f32 = undefined;
var batx: f32 = undefined;
var baty: f32 = undefined;
var batxd: f32 = undefined;

var leftPressed = false;
var rightPressed = false;

fn game_init() void {
    ballx = WIDTH / 2;
    bally = 10;
    ballxd = WIDTH / 4;
    ballyd = WIDTH / 4;
    batwidth = 75;
    batheight = 8;
    batx = WIDTH / 2 - batwidth / 2; // centre
    baty = HEIGHT - batheight; // above bottom of screen
    batxd = 0;
}

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
    //_ = console.print("keyevent: {d} {}\n", .{keycode, down}) catch 0;
    const keycode_left = 37;
    const keycode_right = 39;

    switch (keycode) {
        keycode_left => {
            if (down) leftPressed = true else leftPressed = false;
        },
        keycode_right => {
            if (down) rightPressed = true else rightPressed = false;
        },
        else => {},
    }

    batxd = 0;
    if (leftPressed and !rightPressed) {
        batxd = -WIDTH;
    }
    if (!leftPressed and rightPressed) {
        batxd = WIDTH;
    }
}

export fn getGfxBufPtr() [*]u8 {
    return @ptrCast(&gfxFramebuffer);
}

export fn setSampleRate(s: f32) void {
    sampleRate = s;

    // create the synthesizer
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var fbs = std.io.fixedBufferStream(synth_font);
    const reader = fbs.reader();
    const sound_font = SoundFont.init(allocator, reader) catch unreachable;
    var settings = SynthesizerSettings.init(@as(i32, @intFromFloat(s)));
    settings.block_size = RENDER_QUANTUM_FRAMES;
    synthesizer = Synthesizer.init(allocator, &sound_font, &settings) catch unreachable;

    // create mod player
    _ = pocketmod.pocketmod_init(&ctx, mod_data, mod_data.len, @as(c_int, @intFromFloat(sampleRate)));
}

export fn getLeftBufPtr() [*]u8 {
    return @ptrCast(&mix_left);
}

export fn getRightBufPtr() [*]u8 {
    return @ptrCast(&mix_right);
}

export fn renderSoundQuantum() void {
    // uncomment to use broken ziggysynth
    @memset(&fx_left, 0);
    @memset(&fx_right, 0);
    //synthesizer.render(&fx_left, &fx_right);

    var bytes: usize = RENDER_QUANTUM_FRAMES * 4 * 2;

    // pocketmod produces interleaved l/r/l/r data, so fetch a double batch
    const lrbuf:[*]u8 = @ptrCast(&music_leftright);
    bytes = RENDER_QUANTUM_FRAMES * 4 * 2;
    var i: usize = 0;
    while (i < bytes) {
        const count = pocketmod.pocketmod_render(&ctx, lrbuf + i, @as(c_int, @intCast(bytes - i)));
        i += @as(usize, @intCast(count));
    }

    // deinterleave music into the l and r buffers and mix fx
    i = 0;
    while (i < RENDER_QUANTUM_FRAMES) : (i += 1) {
        mix_left[i] = music_volume * music_leftright[i * 2] + fx_volume * fx_left[i];
        mix_right[i] = music_volume * music_leftright[i * 2 + 1] + fx_volume * fx_right[i];
    }
}

export fn init() void {
    startTime = getTimeUs();
    frameCount = 0;

    game_init();

    fillRect(0, 0, WIDTH, HEIGHT, COLOUR_BLACK);
}

export fn update(deltaMs: u32) void {
    if (deltaMs > 100) {
        _ = console.print("Skipping\n", .{}) catch 0;
        return;
    }

    // scale factor deltaMs to give constant speed regardless of fps
    const deltaScale = @as(f32, @floatFromInt(deltaMs)) / 1000.0;

    // bounce ball
    // left and right
    const newballx = ballx + ballxd * deltaScale;
    if (newballx < 0 or newballx >= WIDTH) {
        synthesizer.noteOn(0, 48, 127);
        ballxd = -ballxd;
    } else {
        ballx = newballx;
    }
    // top
    const newbally = bally + ballyd * deltaScale;
    if (newbally < 0) {
        synthesizer.noteOn(0, 55, 127);
        ballyd = -ballyd;
    }

    // hit bat?
    if (newbally >= baty and newbally < newbally + batheight and newballx >= batx and newballx < batx + batwidth) {
        // bounce
        ballyd = -ballyd;
        bally = baty - 1;
        synthesizer.noteOn(9, 60, 127);
    } else {
        if (newbally >= HEIGHT) {
            // dead
            synthesizer.noteOn(0, 36, 127);
            game_init();
        } else {
            bally = newbally;
        }
    }

    // move bat, keep on screen
    var newbatx = batx + batxd * deltaScale;
    if (newbatx < 0) {
        newbatx = 0;
    }
    if (newbatx + batwidth >= WIDTH) {
        newbatx = WIDTH - batwidth;
    }
    batx = newbatx;
}

fn fillRect(xpos: i32, ypos: i32, width: i32, height: i32, colour: u32) void {
    var x = xpos;
    var y = ypos;
    var w = width;
    var h = height;

    if (x < 0) {
        x = 0;
    }
    if (x >= WIDTH) {
        x = WIDTH - 1;
    }
    if (x + w >= WIDTH) {
        w = WIDTH - x;
    }

    if (y < 0) {
        y = 0;
    }
    if (y >= HEIGHT) {
        y = HEIGHT - 1;
    }
    if (y + h >= HEIGHT) {
        h = HEIGHT - y;
    }

    const x2 = x + w;
    const y2 = y + h;

    while (y < y2) : (y += 1) {
        var xi = x;
        while (xi < x2) : (xi += 1) {
            gfxFramebuffer[@as(usize, @intCast(y)) * WIDTH + @as(usize, @intCast(xi))] = colour;
        }
    }
}

var lastTime: u32 = 0;
var lastFPSTime: u32 = 0;
var frameCount: usize = 0;

fn printFPS() void {
    if (millis() > lastFPSTime + 1000) {
        _ = console.print("FPS {d}\n", .{frameCount / (millis() / 1000)}) catch 0;
        lastFPSTime = millis();
    }
    frameCount +%= 1;
    lastTime = millis();
}

fn HSVtoRGB(h: f32, s: f32, v: f32) u32 {
    const i: f32 = std.math.floor(h * 6);
    const f: f32 = h * 6 - i;
    const p: f32 = v * (1 - s);
    const q: f32 = v * (1 - f * s);
    const t: f32 = v * (1 - (1 - f) * s);
    var r: f32 = undefined;
    var g: f32 = undefined;
    var b: f32 = undefined;
    switch (@as(u32, @intFromFloat(i)) % 6) {
        0 => {
            r = v;
            g = t;
            b = p;
        },
        1 => {
            r = q;
            g = v;
            b = p;
        },
        2 => {
            r = p;
            g = v;
            b = t;
        },
        3 => {
            r = p;
            g = q;
            b = v;
        },
        4 => {
            r = t;
            g = p;
            b = v;
        },
        5 => {
            r = v;
            g = p;
            b = q;
        },
        else => {},
    }

    const rf = std.math.round(r * 255);
    const gf = std.math.round(g * 255);
    const bf = std.math.round(b * 255);
    const r8:u8 = @intFromFloat(rf);
    const g8:u8 = @intFromFloat(gf);
    const b8:u8 = @intFromFloat(bf);
    const colour: u32 = 0xFF000000 | @as(u32, b8) << 16 | @as(u32, g8) << 8 | @as(u32, r8);
    return colour;
}

// https://rosettacode.org/wiki/Plasma_effect#JavaScript
fn drawPlasma() void {
    var x: f32 = 0;
    while (x < WIDTH) : (x += 1) {
        var y: f32 = 0;
        while (y < HEIGHT) : (y += 1) {
            var value = @sin(x / 16.0);
            value += @sin(y / 8.0);
            value += @sin((x + y) / 16.0);
            value += @sin(std.math.sqrt(x * x + y * y) / 8.0);
            value += 4; // shift range from -4 .. 4 to 0 .. 8
            value /= 8; // bring range down to 0 .. 1

            const t: f32 = @as(f32, @floatFromInt(millis())) / 10000;

            gfxFramebuffer[@as(usize, @intFromFloat(y)) * WIDTH + @as(usize, @intFromFloat(x))] = HSVtoRGB(value + t, 0.5, 2);
        }
    }
}

export fn renderGfx() void {
    // background
    // fillRect(0, 0, WIDTH, HEIGHT, COLOUR_BLACK);
    drawPlasma();

    // ball
    fillRect(@intFromFloat(ballx - 4), @intFromFloat(bally - 4), 8, 8, COLOUR_BLACK);
    fillRect(@intFromFloat(ballx - 2), @intFromFloat(bally - 2), 4, 4, COLOUR_WHITE);

    // bat
    fillRect(@intFromFloat(batx), @intFromFloat(baty), @intFromFloat(batwidth), @intFromFloat(batheight), COLOUR_BLACK);

    printFPS();
}
