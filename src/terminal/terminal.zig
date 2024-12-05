const std = @import("std");
const console = @import("console.zig").getWriter().writer();
const terminal = @cImport({
    @cInclude("libvterm/terminal.h");
});

var vterm:?*terminal.VTerm = null;
var screen:?*terminal.VTermScreen = null;

const Game = @import("game.zig").Game;
var gFontSmall: Game.Font = undefined;
var gSurface: Game.Surface = undefined;
var gRenderer: Game.Renderer = undefined;

//var ag: ?*agnes.agnes_t = null;
//var ag_input: agnes.agnes_input_t = undefined;
//var vt: ?[*c]terminal.TMT = null;

//const romData = @embedFile("croom.nes");

const ROWS:usize = 24;
const COLS:usize = 80;
const FONTSIZE:usize = 16;

const cast = @embedFile("assets/cast.ansi");

// WebAudio's render quantum size.
const RENDER_QUANTUM_FRAMES = 128;

var fx_left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var fx_right: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var mix_left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var mix_right: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var music_leftright: [RENDER_QUANTUM_FRAMES * 2]f32 = undefined;
var sampleRate: f32 = 44100;

const WIDTH = COLS*FONTSIZE/2;
const HEIGHT = ROWS*FONTSIZE;

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

export fn agnes_memset(dst: [*]u8, val: u8, size: c_int) callconv(.C) [*]u8 {
    @memset(dst[0..@intCast(size)], val);
    return dst;
}

export fn zmemset(dst: [*]u8, val: c_int, size: c_int) callconv(.C) [*]u8 {
    return agnes_memset(dst, @intCast(val), size);
}

export fn zmemcpy(dst: [*]u8, src: [*]u8, size: c_int) callconv(.C) [*]u8 {
    return agnes_memcpy(dst, src, size);
}

export fn zsin(x: f64) callconv(.C) f64 {
    return @sin(x);
}
export fn zcos(x: f64) callconv(.C) f64 {
    return @cos(x);
}
export fn zsqrt(x: f64) callconv(.C) f64 {
    return std.math.sqrt(x);
}
export fn zpow(x: f64, y: f64) callconv(.C) f64 {
    return std.math.pow(f64, x, y);
}
export fn zfabs(x: f64) callconv(.C) f64 {
    return @abs(x);
}
export fn zfloor(x: f64) callconv(.C) f64 {
    return @floor(x);
}
export fn zceil(x: f64) callconv(.C) f64 {
    return @ceil(x);
}
export fn zfmod(x: f64, y: f64) callconv(.C) f64 {
    return @mod(x, y);
}


const alloc_align = 16;
const alloc_metadata_len = std.mem.alignForward(usize, alloc_align, @sizeOf(usize));

fn getGpaBuf(ptr: [*]u8) []align(alloc_align) u8 {
    const start = @intFromPtr(ptr) - alloc_metadata_len;
    const len = @as(*usize, @ptrFromInt(start)).*;
    return @alignCast(@as([*]u8, @ptrFromInt(start))[0..len]);
}

export fn zmalloc(size: usize) callconv(.C) ?[*]align(alloc_align) u8 {
    return agnes_malloc(size);
}

export fn agnes_malloc(size: usize) callconv(.C) ?[*]align(alloc_align) u8 {
//_ = console.print("malloc {d}", .{size}) catch 0;
    std.debug.assert(size > 0); // TODO: what should we do in this case?
    const full_len = alloc_metadata_len + size;
    const buf = allocator.alignedAlloc(u8, alloc_align, full_len) catch |err| switch (err) {
        error.OutOfMemory => {
            return null;
        },
    };
    @as(*usize, @ptrCast(buf)).* = full_len;
    const result = @as([*]align(alloc_align) u8, @ptrFromInt(@intFromPtr(buf.ptr) + alloc_metadata_len));
    return result;
}

export fn agnes_realloc(ptr: ?[*]align(alloc_align) u8, size: usize) callconv(.C) ?[*]align(alloc_align) u8 {
//_ = console.print("realloc {d}", .{size}) catch 0;

    const gpa_buf = getGpaBuf(ptr orelse {
        const result = agnes_malloc(size);
        return result;
    });
    if (size == 0) {
        allocator.free(gpa_buf);
        return null;
    }

    const gpa_size = alloc_metadata_len + size;
    if (allocator.rawResize(gpa_buf, std.math.log2(alloc_align), gpa_size, @returnAddress())) {
        @as(*usize, @ptrCast(gpa_buf.ptr)).* = gpa_size;
        return ptr;
    }

    const new_buf = allocator.reallocAdvanced(
        gpa_buf,
        gpa_size,
        @returnAddress(),
    ) catch |e| switch (e) {
        error.OutOfMemory => {
            return null;
        },
    };
    @as(*usize, @ptrCast(new_buf.ptr)).* = gpa_size;
    const result = @as([*]align(alloc_align) u8, @ptrFromInt(@intFromPtr(new_buf.ptr) + alloc_metadata_len));
    return result;
}

export fn agnes_calloc(nmemb: usize, size: usize) callconv(.C) ?[*]align(alloc_align) u8 {
//_ = console.print("calloc {d}", .{size}) catch 0;

    const total = std.math.mul(usize, nmemb, size) catch {
        // TODO: set errno
        //errno = c.ENOMEM;
        return null;
    };
    const ptr = agnes_malloc(total) orelse return null;
    @memset(ptr[0..total], 0);
    return ptr;
}

pub export fn zfree(ptr: ?[*]align(alloc_align) u8) callconv(.C) void {
    return agnes_free(ptr);
}

pub export fn agnes_free(ptr: ?[*]align(alloc_align) u8) callconv(.C) void {
//_ = console.print("free", .{}) catch 0;
    const p = ptr orelse return;
    allocator.free(getGpaBuf(p));
}

//export fn agnes_malloc(size: c_int) callconv(.C) ?[*]u8 {
//    //_ = console.print("zmalloc {d}\n", .{size}) catch 0;
//    const mem = allocator.alloc(u8, @as(usize, @intCast(size + @sizeOf(usize)))) catch {
//        _ = console.print("ALLOCFAIL", .{}) catch 0;
//        return null;
//    };
//    const sz = @as(*usize, @ptrCast(@alignCast(mem.ptr)));
//    sz.* = @as(usize, @intCast(size));
//    //_ = console.print("<- zmalloc ptr={any}\n", .{mem.ptr}) catch 0;
//    return mem.ptr + @sizeOf(usize);
//}
//
//export fn agnes_free(ptr: ?[*]u8) callconv(.C) void {
//    if (ptr == null) {
//        return;
//    }
//    //_ = console.print("zfree ptr={any}\n", .{ptr}) catch 0;
//
//    const singleP = @as(*usize, @ptrCast(ptr.?));
//    const sz = @as(*const usize, @ptrCast(@as(*usize, @alignCast(singleP)) - @sizeOf(usize)));
//    const p = singleP - @sizeOf(usize);
//    allocator.free(p[0 .. sz.* + @sizeOf(usize)]);
//}

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
fn damageFn(rect:terminal.VTermRect, user:?*anyopaque) callconv(.C) c_int {
    _ = rect;
    _ = user;
    _ = console.print("damage\n", .{}) catch 0;
    return 0;
}

fn moverectFn(dest:terminal.VTermRect, src:terminal.VTermRect, user:?*anyopaque) callconv(.C) c_int {
    _ = dest;
    _ = src;
    _ = user;
    _ = console.print("moverect\n", .{}) catch 0;
    return 0;
}

fn movecursorFn(pos:terminal.VTermPos, oldpos:terminal.VTermPos, visible:c_int, user:?*anyopaque) callconv(.C) c_int {
    _ = pos;
    _ = oldpos;
    _ = visible;
    _ = user;
    _ = console.print("movecursor\n", .{}) catch 0;
    return 0;
}

fn settermpropFn(prop:terminal.VTermProp, val:?*terminal.VTermValue, user:?*anyopaque) callconv(.C) c_int {
    _ = prop;
    _ = val;
    _ = user;
    _ = console.print("settermprop\n", .{}) catch 0;
    return 0;
}

fn bellFn(user:?*anyopaque) callconv(.C) c_int {
    _ = user;
    _ = console.print("bell\n", .{}) catch 0;
    return 0;
}

fn resizeFn(rows:c_int, cols:c_int, user:?*anyopaque) callconv(.C) c_int {
    _ = user;
    _ = rows;
    _ = cols;
    _ = console.print("resize\n", .{}) catch 0;
    return 0;
}

fn sb_pushlineFn(cols:c_int, cells:?[*]const terminal.VTermScreenCell, user:?*anyopaque) callconv(.C) c_int {
    _ = cols;
    _ = cells;
    _ = user;
    _ = console.print("sb_pushlineFn\n", .{}) catch 0;
    return 0;
}

fn sb_poplineFn(cols:c_int, cells:?[*]terminal.VTermScreenCell, user:?*anyopaque) callconv(.C) c_int {
    _ = cols;
    _ = cells;
    _ = user;
    _ = console.print("sb_poplineFn\n", .{}) catch 0;
    return 0;
}

fn sb_clearFn(user:?*anyopaque) callconv(.C) c_int {
    _ = user;
    _ = console.print("sb_clear\n", .{}) catch 0;
    return 0;
}

const screen_callbacks:terminal.VTermScreenCallbacks = .{
    // FIXME
    .damage = damageFn,
    .moverect = moverectFn,
    .movecursor = movecursorFn,
    .settermprop = settermpropFn,
    .bell = bellFn,
    .resize = resizeFn,
    .sb_pushline = sb_pushlineFn,
    .sb_popline = sb_poplineFn,
    .sb_clear = sb_clearFn,
};

export fn init() void {

    gSurface = Game.Surface.init(&gfxFramebuffer, 0, 0, WIDTH, HEIGHT, WIDTH);
    gRenderer = Game.Renderer.init(&gSurface);

    gFontSmall = Game.Font.init("pc.ttf", FONTSIZE) catch |err| {
    //gFontSmall = Game.Font.init("SourceCodePro-Regular.ttf", FONTSIZE) catch |err| {
//    gFontSmall = Game.Font.init("Sweet16.ttf", FONTSIZE) catch |err| {
        _ = console.print("err {any}\n", .{err}) catch 0;
        return;
    };

    startTime = getTimeUs();
    frameCount = 0;

    vterm = terminal.vterm_new(ROWS, COLS);
    //terminal.vterm_set_utf8(vterm, 1);
    terminal.vterm_output_set_callback(vterm, output_callback, null);
    screen = terminal.vterm_obtain_screen(vterm);
    terminal.vterm_screen_set_callbacks(screen, &screen_callbacks, null);
    terminal.vterm_screen_reset(screen, 1);
//    _ = terminal.vterm_input_write(vterm, "G", 1);

//    const cmd_moveto = "\x1b[20;10H";
//    _ = terminal.vterm_input_write(vterm, cmd_moveto, cmd_moveto.len);
//    _ = terminal.vterm_input_write(vterm, "ABC", 3);

//const KNRM = "\x1B[0m" ++ "nrm";
const KRED = "\x1B[31m" ++ "Red\r\n";
const KGRN = "\x1B[32m" ++ "Green\r\n";
const KYEL = "\x1B[33m" ++ "Yellow\r\n";
const KBLU = "\x1B[34m" ++ "Blue\r\n";
const KMAG = "\x1B[35m" ++ "Magenta\r\n";
const KCYN = "\x1B[36m" ++ "Cyan\r\n";
const KWHT = "\x1B[37m" ++ "White\r\n";
const GOR = "\x1b[1;32;41m Green On Red \x1b[0m";

    _ = terminal.vterm_input_write(vterm, KRED, KRED.len);
    _ = terminal.vterm_input_write(vterm, KGRN, KGRN.len);
    _ = terminal.vterm_input_write(vterm, KBLU, KBLU.len);
    _ = terminal.vterm_input_write(vterm, KMAG, KMAG.len);
    _ = terminal.vterm_input_write(vterm, KCYN, KCYN.len);
    _ = terminal.vterm_input_write(vterm, KWHT, KWHT.len);
    _ = terminal.vterm_input_write(vterm, KYEL, KYEL.len);
    _ = terminal.vterm_input_write(vterm, GOR, GOR.len);

//int main()
//{
//    printf("%sred\n", KRED);
//    printf("%sgreen\n", KGRN);
//    printf("%syellow\n", KYEL);
//    printf("%sblue\n", KBLU);
//    printf("%smagenta\n", KMAG);
//    printf("%scyan\n", KCYN);
//    printf("%swhite\n", KWHT);
//    printf("%snormal\n", KNRM);
//
//    return 0;
//}

//    const chess = @embedFile("assets/chess.ansi");
//    _ = terminal.vterm_input_write(vterm, chess, chess.len);

//    _ = terminal.vterm_input_write(vterm, chess, chess.len);

//printf("\033[%d;%dH", (y), (x))

}

var lastCast: u32 = 0;
var castIndex: usize = 0;

export fn update(deltaMs: u32) void {
    _ = deltaMs;
    if (millis() > lastCast) {
        lastCast = millis();
    }

    if (castIndex < cast.len - 100) {
        const sl = cast[castIndex..castIndex+100];
        _ = terminal.vterm_input_write(vterm, sl.ptr, sl.len);
        castIndex += 100;
    }


//    if (deltaMs > 100) {
//        _ = console.print("Skipping\n", .{}) catch 0;
//        return;
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
    gRenderer.fill(0xFF000000); // black background

    for (0..ROWS) |y| {
        //_ = console.print("{d:0>2}", .{y}) catch 0;
        for (0..COLS) |x| {
            const pos:terminal.VTermPos = .{.row=@intCast(y), .col=@intCast(x)};
            var cell:terminal.VTermScreenCell = undefined;
            _ = terminal.vterm_screen_get_cell(screen, pos, &cell);
//            _ = console.print("{d},{d} = {any}\n", .{x,y,cell}) catch 0;
            if (cell.chars[0] == 0) {
//                _ = console.print(" ", .{}) catch 0;
            } else {
                var buf:[16]u8 = undefined;
                buf[0] = @intCast(cell.chars[0]);
                const sl = buf[0..1];

                var fgcolour:u32 = 0xFFFFFFFF;    // white
                var bgcolour:u32 = 0x00000000;    // transparent
                if (terminal.VTERM_COLOR_IS_INDEXED(&cell.fg)) {
                    terminal.vterm_screen_convert_color_to_rgb(screen, &cell.fg);
                }
                if (terminal.VTERM_COLOR_IS_RGB(&cell.fg)) {
                    fgcolour = @as(u32, @intCast(0xFF)) << 24 | @as(u32, @intCast(cell.fg.rgb.blue)) << 16 | @as(u32, @intCast(cell.fg.rgb.green)) << 8 | @as(u32, @intCast(cell.fg.rgb.red));
                }
                if (terminal.VTERM_COLOR_IS_INDEXED(&cell.bg)) {
                    terminal.vterm_screen_convert_color_to_rgb(screen, &cell.bg);
                }
                if (terminal.VTERM_COLOR_IS_RGB(&cell.bg)) {
                    bgcolour = @as(u32, @intCast(0xFF)) << 24 | @as(u32, @intCast(cell.bg.rgb.blue)) << 16 | @as(u32, @intCast(cell.bg.rgb.green)) << 8 | @as(u32, @intCast(cell.bg.rgb.red));
                }

                gRenderer.fillRect(Game.Rect.init(@floatFromInt(x*FONTSIZE/2), @floatFromInt(y*FONTSIZE), FONTSIZE/2, FONTSIZE), bgcolour);

                //gRenderer.drawRect(Game.Rect.init(@floatFromInt(x*FONTSIZE/2), @floatFromInt(y*FONTSIZE), FONTSIZE/2, FONTSIZE), 0xFF404040);
                const yo:i32 = -4;
                gRenderer.drawString(&gFontSmall, sl, @intCast(x*FONTSIZE/2), @as(i32, @intCast(y*FONTSIZE+FONTSIZE)) + yo, fgcolour);
            }
        }
        //_ = console.print("\n", .{}) catch 0;
    }
//    var buf: [16]u8 = undefined;
//    const sl = std.fmt.bufPrint(&buf, "Hello world", .{}) catch |err| {
//        _ = console.print("err {any}\n", .{err}) catch 0;
//        return;
//    };
//    gRenderer.drawString(&gFontSmall, sl, 0, 24, 0xFFFFFFFF);

    printFPS();
}
