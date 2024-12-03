const std = @import("std");
const console = @import("console.zig").getWriter().writer();
const agnes = @cImport({
    @cInclude("agnes.h");
});

var ag: ?*agnes.agnes_t = null;
var ag_input: agnes.agnes_input_t = undefined;

const romData = @embedFile("croom.nes");

// WebAudio's render quantum size.
const RENDER_QUANTUM_FRAMES = 128;

var fx_left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var fx_right: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var mix_left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var mix_right: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var music_leftright: [RENDER_QUANTUM_FRAMES * 2]f32 = undefined;
var sampleRate: f32 = 44100;

const WIDTH = 256;
const HEIGHT = 240;

var gfxFramebuffer: [WIDTH * HEIGHT]u32 = undefined; // ABGR

const fx_volume = 1.0;
const music_volume = 0.1;

var prng = std.rand.DefaultPrng.init(0);
var rand = prng.random();

var startTime: u32 = 0;

const COLOUR_BLACK = 0xFF000000;
const COLOUR_WHITE = 0xFFFFFFFF;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

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

export fn agnes_print(msg: [*:0]const u8) callconv(.C) void {
    _ = console.print("{s}", .{std.mem.span(msg)}) catch 0;
}

export fn agnes_memcpy(dst: [*]u8, src: [*]u8, size: c_int) callconv(.C) [*]u8 {
    @memcpy(dst[0..@intCast(size)], src[0..@intCast(size)]);
    return dst;
}

export fn agnes_memset(dst: [*]u8, val: u8, size: c_int) callconv(.C) void {
    @memset(dst[0..@intCast(size)], val);
}

export fn agnes_malloc(size: c_int) callconv(.C) ?[*]u8 {
    const mem = allocator.alloc(u8, @intCast(size + @sizeOf(usize))) catch {
        _ = console.print("ALLOCFAIL", .{}) catch 0;
        return null;
    };
    const sz: *usize = @ptrCast(@alignCast(mem.ptr));
    sz.* = @intCast(size);
    return mem.ptr + @sizeOf(usize);
}

export fn agnes_free(ptr: [*]u8) callconv(.C) void {
    const sz: *const usize = @ptrCast(@alignCast(ptr - @sizeOf(usize)));
    const p = ptr - @sizeOf(usize);
    allocator.free(p[0 .. sz.* + @sizeOf(usize)]);
}

extern fn getTimeUs() u32;
pub fn millis() u32 {
    return (getTimeUs() - startTime) / 1000;
}

export fn keyevent(keycode: u32, down: bool) void {
    //_ = console.print("keycode {d} {any}\n", .{keycode, down}) catch 0;
    ag_input.a = false;
    ag_input.b = false;
    ag_input.left = false;
    ag_input.right = false;
    ag_input.up = false;
    ag_input.down = false;
    ag_input.select = false; // shift
    ag_input.start = false; // enter

    switch (keycode) {
        90 => ag_input.a = down,
        88 => ag_input.b = down,
        37 => ag_input.left = down,
        39 => ag_input.right = down,
        38 => ag_input.up = down,
        40 => ag_input.down = down,
        17 => ag_input.select = down, // shift
        13 => ag_input.start = down, // enter
        else => {},
    }
    agnes.agnes_set_input(ag, &ag_input, 0);
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

export fn init() void {
    startTime = getTimeUs();
    frameCount = 0;

    ag = agnes.agnes_make();
    if (agnes.agnes_load_ines_data(ag, @ptrCast(romData), romData.len)) {
        _ = console.print("load rom ok\n", .{}) catch 0;
    } else {
        _ = console.print("load rom failed\n", .{}) catch 0;
    }
    agnes.agnes_set_input(ag, &ag_input, 0);
}

export fn update(deltaMs: u32) void {
    if (deltaMs > 100) {
        _ = console.print("Skipping\n", .{}) catch 0;
        return;
    }

    if (!agnes.agnes_next_frame(ag)) {
        _ = console.print("Next frame failed!\n", .{}) catch 0;
    }

    for (0..agnes.AGNES_SCREEN_HEIGHT) |y| {
        for (0..agnes.AGNES_SCREEN_WIDTH) |x| {
            const c = agnes.agnes_get_screen_pixel(ag, @intCast(x), @intCast(y));
            const c_val = @as(u32, @intCast(0xFF)) << 24 | @as(u32, @intCast(c.b)) << 16 | @as(u32, @intCast(c.g)) << 8 | @as(u32, @intCast(c.r));
            gfxFramebuffer[@as(usize, @intCast(y)) * WIDTH + @as(usize, @intCast(x))] = c_val;
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

export fn renderGfx() void {
    // background
    printFPS();
}
