const std = @import("std");
const console = @import("console.zig").getWriter().writer();

const WIDTH = 1200;
const HEIGHT = 800;
var gfxFramebuffer: [WIDTH * HEIGHT]u32 = undefined;

var renderBuffer: [WIDTH * HEIGHT]u32 = undefined;

const RENDER_QUANTUM_FRAMES = 128; // WebAudio's render quantum size
var sampleRate: f32 = 44100;
var mix_left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var mix_right: [RENDER_QUANTUM_FRAMES]f32 = undefined;

var startTime: u32 = 0;

const MAX_ITERATIONS = 1024;

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

const ZoomBox = struct {
    left: f64,
    top: f64,
    right: f64,
    bottom: f64,
};

var zoom = ZoomBox{
    .left = -2.0,
    .top = 1.0,
    .right = 1.0,
    .bottom = -1.0,
};

var inDrag: bool = false;
var x1: f32 = 0;
var y1: f32 = 0;
var x2: f32 = 0;
var y2: f32 = 0;

export fn mouseMoveEvent(x: f32, y: f32) void {
    if (inDrag) {
        x2 = x;
        _ = y;
        //y2 = y;
        // force fixed aspect-ratio
        y2 = y1 + (x2 - x1) * (@as(f32, HEIGHT) / @as(f32, WIDTH));

        //redraw();
    }
}

export fn mouseClickEvent(x: f32, y: f32, down: bool) void {
    //_ = console.print("mouse {d},{d} {?} inDrag={?}\n", .{x, y, down, inDrag}) catch 0;

    if (down) {
        if (!inDrag) {
            x1 = x;
            y1 = y;
            x2 = x;
            y2 = y;

            inDrag = true;
        }
    } else {
        if (inDrag) {
            x2 = x;
            //y2 = y;
            // force fixed aspect-ratio
            y2 = y1 + (x2 - x1) * (@as(f32, HEIGHT) / @as(f32, WIDTH));

            inDrag = false;

            const start_pix_x = @min(x1, x2);
            const start_pix_y = @min(y1, y2);
            const end_pix_x = @max(x1, x2);
            const end_pix_y = @max(y1, y2);

            const w: f32 = @floatFromInt(WIDTH);
            const h: f32 = @floatFromInt(HEIGHT);

            const imag_w = (zoom.right - zoom.left);
            const imag_h = (zoom.top - zoom.bottom);

            const new_zoom_left = zoom.left + start_pix_x / w * imag_w;
            const new_zoom_right = zoom.left + end_pix_x / w * imag_w;

            const new_zoom_bottom = zoom.bottom + start_pix_y / h * imag_h;
            const new_zoom_top = zoom.bottom + end_pix_y / h * imag_h;

            zoom = ZoomBox{
                .left = new_zoom_left,
                .right = new_zoom_right,
                .top = new_zoom_top,
                .bottom = new_zoom_bottom,
            };
            redraw();
        }
    }
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
    redraw();
}

export fn update(deltaMs: u32) void {
    _ = deltaMs;
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

    const x2a = x + w;
    const y2a = y + h;

    while (y < y2a) : (y += 1) {
        var xi = x;
        while (xi < x2a) : (xi += 1) {
            gfxFramebuffer[@as(usize, @intCast(y)) * WIDTH + @as(usize, @intCast(xi))] = colour;
        }
    }
}

fn redraw() void {
    const w = WIDTH;
    const h = HEIGHT;
    const imag_w = (zoom.right - zoom.left);
    const imag_h = (zoom.top - zoom.bottom);

    var pix_y: u31 = 0;
    while (pix_y < HEIGHT) : (pix_y += 1) {
        var pix_x: u31 = 0;
        while (pix_x < WIDTH) : (pix_x += 1) {
            const cx = zoom.left + @as(f64, @floatFromInt(pix_x)) / w * imag_w;
            const cy = zoom.bottom + @as(f64, @floatFromInt(pix_y)) / h * imag_h;

            var zx1 = cx;
            var zy1 = cy;
            var iterations: usize = 0;
            const iteration_limit = MAX_ITERATIONS;
            const escaped = while (iterations < iteration_limit) : (iterations += 1) {
                const zx = zx1;
                const zy = zy1;
                zx1 = zx * zx - zy * zy + cx;
                zy1 = zx * zy * 2 + cy;

                if (zx1 * zx1 + zy1 * zy1 > 4) {
                    break true;
                }
            } else false;

            if (escaped) {
                const r8: u8 = 0;
                const g8: u8 = @intCast(iterations);
                const b8: u8 = 255 - @as(u8, @intCast(iterations));
                renderBuffer[pix_y * WIDTH + pix_x] = 0xFF000000 | @as(u32, b8) << 16 | @as(u32, g8) << 8 | @as(u32, r8);
            } else {
                renderBuffer[pix_y * WIDTH + pix_x] = 0xFF000000;
            }
        }
    }
}

export fn renderGfx() void {
    printFPS();

    @memcpy(&gfxFramebuffer, &renderBuffer);

    if (inDrag) {
        const start_pix_x = @min(x1, x2);
        const start_pix_y = @min(y1, y2);
        const end_pix_x = @max(x1, x2);
        const end_pix_y = @max(y1, y2);

        fillRect(@intFromFloat(start_pix_x), @intFromFloat(start_pix_y), @intFromFloat(end_pix_x - start_pix_x), @intFromFloat(end_pix_y - start_pix_y), 0xFF808080);
    }
}
