const std = @import("std");
const console = @import("console.zig").getWriter().writer();
const zeptolibc = @import("zeptolibc");
const ZVTerm = @import("zvterm").ZVTerm;

const mibu = @import("mibu");
const zigtris = @import("zigtris");
var nextEvent:mibu.events.Event = .none;

var term:ZVTerm = undefined;
var termwriter:ZVTerm.TermWriter.Writer = undefined;

const Game = @import("game.zig").Game;
var gFontSmall: Game.Font = undefined;
var gFontSmallBold: Game.Font = undefined;
var gSurface: Game.Surface = undefined;
var gRenderer: Game.Renderer = undefined;

const ROWS:usize = 24;
const COLS:usize = 80;
const FONTSIZE:usize = 16;

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
    _ = console.print("PANIC: {s}", .{msg}) catch 0;
    while (true) {}
}

extern fn getTimeUs() u32;
pub fn millis() u32 {
    return (getTimeUs() - startTime) / 1000;
}

export fn keyevent(keycode: u32, down: bool, isRepeat:bool) void {
    _ = isRepeat;
//    _ = console.print("keycode {d} {any} {any}\n", .{keycode, down, isRepeat}) catch 0;

    if (down) {
        switch(keycode) {
            32 => nextEvent = mibu.events.Event{.key = .{.char = ' '}},
            37 => nextEvent = mibu.events.Event{.key = .left},
            39 => nextEvent = mibu.events.Event{.key = .right},
            38 => nextEvent = mibu.events.Event{.key = .up},
            40 => nextEvent = mibu.events.Event{.key = .down},
            else => {},
        }
    }
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

export fn init() void {
    // init zepto with a memory allocator and console writer
    zeptolibc.init(allocator, consoleWriteFn);

    gSurface = Game.Surface.init(&gfxFramebuffer, 0, 0, WIDTH, HEIGHT, WIDTH);
    gRenderer = Game.Renderer.init(&gSurface);

    gFontSmall = Game.Font.init("pc.ttf", FONTSIZE) catch |err| {
        _ = console.print("err {any}\n", .{err}) catch 0;
        return;
    };
    gFontSmallBold = Game.Font.init("pc-bold.ttf", FONTSIZE) catch |err| {
        _ = console.print("err {any}\n", .{err}) catch 0;
        return;
    };

    startTime = getTimeUs();

    term = ZVTerm.init(80, 24) catch |err| {
        _ = console.print("err {any}\n", .{err}) catch 0;
        return;
    };
    termwriter = term.getWriter();

    try zigtris.gamesetup(termwriter, millis());

}

var lastUpdate:u32 = 0;

export fn update(deltaMs: u32) void {
    _ = deltaMs;

    if (millis() > lastUpdate + 100 or nextEvent != .none) {
        const gameRunning = zigtris.gameloop(termwriter, millis(), nextEvent) catch false;
        nextEvent = .none;
        if (!gameRunning) {
            _ = console.print("new game!\n", .{}) catch 0;

            _ = zigtris.gamesetup(termwriter, millis()) catch 0;
        }

        lastUpdate = millis();
    }
}

export fn renderGfx() void {
    // background
    gRenderer.fill(0xFF000000); // black background

    for (0..ROWS) |y| {
        for (0..COLS) |x| {
            const cell = term.getCell(x, y);
            if (cell.char) |c| {
                var font:*Game.Font = &gFontSmall;
                if (cell.bold) {
                    font = &gFontSmallBold;
                }

                gRenderer.fillRect(Game.Rect.init(@floatFromInt(x*FONTSIZE/2), @floatFromInt(y*FONTSIZE), FONTSIZE/2, FONTSIZE), cell.bgRGBA);

                const yo:i32 = -4;
                gRenderer.drawString(font, &.{c}, @intCast(x*FONTSIZE/2), @as(i32, @intCast(y*FONTSIZE+FONTSIZE)) + yo, cell.fgRGBA);
            }
        }
    }
}

