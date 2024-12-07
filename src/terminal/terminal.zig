const std = @import("std");
const console = @import("console.zig").getWriter().writer();
const zeptolibc = @import("zeptolibc");
const terminal = @cImport({
    @cInclude("libvterm/terminal.h");
});
const CastPlayer = @import("castplay.zig").CastPlayer;


var vterm:?*terminal.VTerm = null;
var screen:?*terminal.VTermScreen = null;

const Game = @import("game.zig").Game;
var gFontSmall: Game.Font = undefined;
var gSurface: Game.Surface = undefined;
var gRenderer: Game.Renderer = undefined;

const ROWS:usize = 24;
const COLS:usize = 80;
const FONTSIZE:usize = 16;

const castData = Game.Assets.ASSET_MAP.get("637727.cast");

var castplayer:CastPlayer = undefined;

// WebAudio's render quantum size.
const RENDER_QUANTUM_FRAMES = 128;

var mix_left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var mix_right: [RENDER_QUANTUM_FRAMES]f32 = undefined;

const WIDTH = COLS*FONTSIZE/2;
const HEIGHT = ROWS*FONTSIZE;

var gfxFramebuffer: [WIDTH * HEIGHT]u32 = undefined; // ABGR

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

extern fn getTimeUs() u32;
pub fn millis() u32 {
    return (getTimeUs() - startTime) / 1000;
}

export fn keyevent(keycode: u32, down: bool) void {
    _ = console.print("keycode {d} {any}\n", .{keycode, down}) catch 0;
}

export fn getGfxBufPtr() [*]u8 {
    return @ptrCast(&gfxFramebuffer);
}

export fn setSampleRate(s: f32) void {
    _ = s;
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
    //_ = console.print("output_callback\n", .{}) catch 0;
}

fn damageFn(rect:terminal.VTermRect, user:?*anyopaque) callconv(.C) c_int {
    _ = rect;
    _ = user;
    //_ = console.print("damage\n", .{}) catch 0;
    return 0;
}

fn moverectFn(dest:terminal.VTermRect, src:terminal.VTermRect, user:?*anyopaque) callconv(.C) c_int {
    _ = dest;
    _ = src;
    _ = user;
    //_ = console.print("moverect\n", .{}) catch 0;
    return 0;
}

fn movecursorFn(pos:terminal.VTermPos, oldpos:terminal.VTermPos, visible:c_int, user:?*anyopaque) callconv(.C) c_int {
    _ = pos;
    _ = oldpos;
    _ = visible;
    _ = user;
    //_ = console.print("movecursor\n", .{}) catch 0;
    return 0;
}

fn settermpropFn(prop:terminal.VTermProp, val:?*terminal.VTermValue, user:?*anyopaque) callconv(.C) c_int {
    _ = prop;
    _ = val;
    _ = user;
    //_ = console.print("settermprop\n", .{}) catch 0;
    return 0;
}

fn bellFn(user:?*anyopaque) callconv(.C) c_int {
    _ = user;
    //_ = console.print("bell\n", .{}) catch 0;
    return 0;
}

fn resizeFn(rows:c_int, cols:c_int, user:?*anyopaque) callconv(.C) c_int {
    _ = user;
    _ = rows;
    _ = cols;
    //_ = console.print("resize\n", .{}) catch 0;
    return 0;
}

fn sb_pushlineFn(cols:c_int, cells:?[*]const terminal.VTermScreenCell, user:?*anyopaque) callconv(.C) c_int {
    _ = cols;
    _ = cells;
    _ = user;
    //_ = console.print("sb_pushlineFn\n", .{}) catch 0;
    return 0;
}

fn sb_poplineFn(cols:c_int, cells:?[*]terminal.VTermScreenCell, user:?*anyopaque) callconv(.C) c_int {
    _ = cols;
    _ = cells;
    _ = user;
    //_ = console.print("sb_poplineFn\n", .{}) catch 0;
    return 0;
}

fn sb_clearFn(user:?*anyopaque) callconv(.C) c_int {
    _ = user;
    //_ = console.print("sb_clear\n", .{}) catch 0;
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

    if (castData) |data| {
        castplayer = CastPlayer.init(allocator, data) catch |err| {
            _ = console.print("err {any}\n", .{err}) catch 0;
            return;
        };
    } else {
        _ = console.print("cast data missing\n", .{}) catch 0;
    }

    gSurface = Game.Surface.init(&gfxFramebuffer, 0, 0, WIDTH, HEIGHT, WIDTH);
    gRenderer = Game.Renderer.init(&gSurface);

    gFontSmall = Game.Font.init("pc.ttf", FONTSIZE) catch |err| {
        _ = console.print("err {any}\n", .{err}) catch 0;
        return;
    };

    startTime = getTimeUs();

    vterm = terminal.vterm_new(ROWS, COLS);
    terminal.vterm_output_set_callback(vterm, output_callback, null);
    screen = terminal.vterm_obtain_screen(vterm);
    terminal.vterm_screen_set_callbacks(screen, &screen_callbacks, null);
    terminal.vterm_screen_reset(screen, 1);
}

export fn update(deltaMs: u32) void {
    _ = deltaMs;

    while (castplayer.getData(millis())) |s| {
        _ = terminal.vterm_input_write(vterm, s.ptr, s.len);
    }
}

export fn renderGfx() void {
    // background

    gRenderer.fill(0xFF000000); // black background

    for (0..ROWS) |y| {
        for (0..COLS) |x| {
            const pos:terminal.VTermPos = .{.row=@intCast(y), .col=@intCast(x)};
            var cell:terminal.VTermScreenCell = undefined;
            _ = terminal.vterm_screen_get_cell(screen, pos, &cell);
            if (cell.chars[0] != 0) {
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
    }
}
