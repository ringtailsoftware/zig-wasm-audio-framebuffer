const std = @import("std");
const console = @import("console.zig").getWriter().writer();
const zeptolibc = @import("zeptolibc");
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

fn consoleWriteFn(data:[]const u8) void {
    _ = console.print("{s}", .{data}) catch 0;
}

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

//export fn _fwrite_buf(ptr: [*]const u8, size: usize, stream: *terminal.FILE) callconv(.C) usize {
//    _ = console.print("_fwrite_buf FIXME", .{}) catch 0;
//    _ = ptr;
//    _ = stream;
//    return size;
//}
//

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

fn output_callback(s:[*c]const u8, len:usize, user:?*anyopaque) callconv(.C) void {
    _ = s;
    _ = len;
    _ = user;
    _ = console.print("output_callback\n", .{}) catch 0;
}

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
    // init zepto with a memory allocator and console writer
    zeptolibc.init(allocator, consoleWriteFn);

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
