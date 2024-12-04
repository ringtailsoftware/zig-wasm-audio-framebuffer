const std = @import("std");
const console = @import("console.zig").getWriter().writer();
const terminal = @cImport({
    @cInclude("libvterm/terminal.h");
});

var vterm:?*terminal.VTerm = null;
var screen:?*terminal.VTermScreen = null;

//var ag: ?*agnes.agnes_t = null;
//var ag_input: agnes.agnes_input_t = undefined;
//var vt: ?[*c]terminal.TMT = null;

//const romData = @embedFile("croom.nes");

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

export fn _fwrite_buf(ptr: [*]const u8, size: usize, stream: *terminal.FILE) callconv(.C) usize {
    _ = console.print("_fwrite_buf FIXME", .{}) catch 0;
    _ = ptr;
    _ = stream;
    return size;
}

// NOTE: this is not a libc function, it's exported so it can be used
//       by vformat in libc.c
// buf must be at least 100 bytes
export fn _formatCInt(buf: [*]u8, value: c_int, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCUint(buf: [*]u8, value: c_uint, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCLong(buf: [*]u8, value: c_long, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCUlong(buf: [*]u8, value: c_ulong, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCLonglong(buf: [*]u8, value: c_longlong, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCUlonglong(buf: [*]u8, value: c_ulonglong, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}

export fn agnes_exit(code:c_int) void {
    _ = console.print("EXIT {d}\n", .{code}) catch 0;
    while (true) {}
}

export fn agnes_abort() void {
    _ = console.print("ABORT\n", .{}) catch 0;
    while (true) {}
}

export fn agnes_strlen(s: [*:0]const u8) callconv(.C) usize {
    const result = std.mem.len(s);
    return result;
}

export fn agnes_memmove(dest: ?[*]u8, src: ?[*]const u8, n: usize) ?[*]u8 {
    if (@intFromPtr(dest) < @intFromPtr(src)) {
        var index: usize = 0;
        while (index != n) : (index += 1) {
            dest.?[index] = src.?[index];
        }
    } else {
        var index = n;
        while (index != 0) {
            index -= 1;
            dest.?[index] = src.?[index];
        }
    }

    return dest;
}

export fn agnes_strncmp(a: [*:0]const u8, b: [*:0]const u8, n: usize) callconv(.C) c_int {
    var i: usize = 0;
    while (a[i] == b[i] and a[0] != 0) : (i += 1) {
        if (i == n - 1) return 0;
    }
    return @as(c_int, @intCast(a[i])) -| @as(c_int, @intCast(b[i]));
}

export fn agnes_strchr(s: [*:0]const u8, char: c_int) callconv(.C) ?[*:0]const u8 {
    var next = s;
    while (true) : (next += 1) {
        if (next[0] == char) return next;
        if (next[0] == 0) return null;
    }
}

export fn agnes_print(msg: [*:0]const u8) callconv(.C) void {
    _ = console.print("{s}", .{std.mem.span(msg)}) catch 0;
}

export fn agnes_strnlen(s: [*:0]const u8, max_len: usize) usize {
    var i: usize = 0;
    while (i < max_len and s[i] != 0) : (i += 1) {}
    return i;
}

export fn agnes_strncpy(s1: [*]u8, s2: [*:0]const u8, n: usize) callconv(.C) [*]u8 {
    const len = agnes_strnlen(s2, n);
    @memcpy(s1[0..len], s2);
    @memset(s1[len..][0 .. n - len], 0);
    return s1;
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

export fn agnes_abs(n:c_int) c_int {
    return @intCast(@abs(n));
}

extern fn getTimeUs() u32;
pub fn millis() u32 {
    return (getTimeUs() - startTime) / 1000;
}

export fn keyevent(keycode: u32, down: bool) void {
    _ = console.print("keycode {d} {any}\n", .{keycode, down}) catch 0;
//    ag_input.a = false;
//    ag_input.b = false;
//    ag_input.left = false;
//    ag_input.right = false;
//    ag_input.up = false;
//    ag_input.down = false;
//    ag_input.select = false; // shift
//    ag_input.start = false; // enter
//
//    switch (keycode) {
//        90 => ag_input.a = down,
//        88 => ag_input.b = down,
//        37 => ag_input.left = down,
//        39 => ag_input.right = down,
//        38 => ag_input.up = down,
//        40 => ag_input.down = down,
//        17 => ag_input.select = down, // shift
//        13 => ag_input.start = down, // enter
//        else => {},
//    }
//    agnes.agnes_set_input(ag, &ag_input, 0);
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


//fn tmt_cb(m:terminal.tmt_msg_t, _vt:[*c]terminal.TMT, a:?*const anyopaque, p:?*anyopaque) callconv(.C) void {
//    _ = console.print("tmt_cb\n", .{}) catch 0;
//    _ = m;
//    _ = _vt;
//    _ = a;
//    _ = p;
//}

fn output_callback(s:[*c]const u8, len:usize, user:?*anyopaque) callconv(.C) void {
    _ = s;
    _ = len;
    _ = user;
    _ = console.print("output_callback\n", .{}) catch 0;
}

//  int (*damage)(VTermRect rect, void *user);
//  int (*moverect)(VTermRect dest, VTermRect src, void *user);
//  int (*movecursor)(VTermPos pos, VTermPos oldpos, int visible, void *user);
//  int (*settermprop)(VTermProp prop, VTermValue *val, void *user);
//  int (*bell)(void *user);
//  int (*resize)(int rows, int cols, void *user);
//  int (*sb_pushline)(int cols, const VTermScreenCell *cells, void *user);
//  int (*sb_popline)(int cols, VTermScreenCell *cells, void *user);
//  int (*sb_clear)(void* user);
//
const screen_callbacks:terminal.VTermScreenCallbacks = .{
    // FIXME
};

export fn init() void {
    startTime = getTimeUs();
    frameCount = 0;

    const rows:usize = 24;
    const cols:usize = 80;
    vterm = terminal.vterm_new(rows, cols);
    terminal.vterm_set_utf8(vterm, 1);
    terminal.vterm_output_set_callback(vterm, output_callback, null);
    screen = terminal.vterm_obtain_screen(vterm);
    terminal.vterm_screen_set_callbacks(screen, &screen_callbacks, null);
    terminal.vterm_screen_reset(screen, 1);
    _ = terminal.vterm_input_write(vterm, "G", 1);

    const cmd_moveto = "\x1b[20;10H";
    _ = terminal.vterm_input_write(vterm, cmd_moveto, cmd_moveto.len);
    _ = terminal.vterm_input_write(vterm, "A", 1);

//printf("\033[%d;%dH", (y), (x))

    for (0..rows) |y| {
        _ = console.print("{d:0>2}", .{y}) catch 0;
        for (0..cols) |x| {
            const pos:terminal.VTermPos = .{.row=@intCast(y), .col=@intCast(x)};
            var cell:terminal.VTermScreenCell = undefined;
            _ = terminal.vterm_screen_get_cell(screen, pos, &cell);
//            _ = console.print("{d},{d} = {any}\n", .{x,y,cell}) catch 0;
            if (cell.chars[0] == 0) {
                _ = console.print(" ", .{}) catch 0;
            } else {
                _ = console.print("{c}", .{@as(u8, @intCast(cell.chars[0]))}) catch 0;
            }
        }
        _ = console.print("\n", .{}) catch 0;
    }

//for (int row = 0; row < matrix.getRows(); row++) {
//                for (int col = 0; col < matrix.getCols(); col++) {
//                    if (matrix(row, col)) {
//                        VTermPos pos = { row, col };
//                        VTermScreenCell cell;
//                        vterm_screen_get_cell(screen, pos, &cell);
//
//    const vt = terminal.tmt_open(2, 10, tmt_cb, null, null);
//    _ = vt;

//    ag = agnes.agnes_make();
//    if (agnes.agnes_load_ines_data(ag, @ptrCast(romData), romData.len)) {
//        _ = console.print("load rom ok\n", .{}) catch 0;
//    } else {
//        _ = console.print("load rom failed\n", .{}) catch 0;
//    }
//    agnes.agnes_set_input(ag, &ag_input, 0);
}

export fn update(deltaMs: u32) void {
    if (deltaMs > 100) {
        _ = console.print("Skipping\n", .{}) catch 0;
        return;
    }

//    if (!agnes.agnes_next_frame(ag)) {
//        _ = console.print("Next frame failed!\n", .{}) catch 0;
//    }
//
//    for (0..agnes.AGNES_SCREEN_HEIGHT) |y| {
//        for (0..agnes.AGNES_SCREEN_WIDTH) |x| {
//            const c = agnes.agnes_get_screen_pixel(ag, @intCast(x), @intCast(y));
//            const c_val = @as(u32, @intCast(0xFF)) << 24 | @as(u32, @intCast(c.b)) << 16 | @as(u32, @intCast(c.g)) << 8 | @as(u32, @intCast(c.r));
//            gfxFramebuffer[@as(usize, @intCast(y)) * WIDTH + @as(usize, @intCast(x))] = c_val;
//        }
//    }
}

var lastTime: u32 = 0;
var lastFPSTime: u32 = 0;
var frameCount: usize = 0;

fn printFPS() void {
    if (millis() > lastFPSTime + 5000) {
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
