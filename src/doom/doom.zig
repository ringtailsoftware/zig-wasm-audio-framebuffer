const std = @import("std");
const console = @import("console.zig").getWriter().writer();
const ziggysynth = @import("ziggysynth.zig");

const zeptolibc = @import("zeptolibc");
const pd = @cImport({
    @cInclude("puredoom/PureDOOM.h");
});

const synth_font = @embedFile("gzdoom.sf2");
const wad_data = @embedFile("doom1.wad");

const SoundFont = ziggysynth.SoundFont;
const Synthesizer = ziggysynth.Synthesizer;
const SynthesizerSettings = ziggysynth.SynthesizerSettings;

const RENDER_QUANTUM_FRAMES = 128; // WebAudio's render quantum size

var music_left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var music_right: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var mix_left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var mix_right: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var music_leftright: [RENDER_QUANTUM_FRAMES * 2]f32 = undefined;
var sampleRate: f32 = 22050;
var synthesizer: Synthesizer = undefined;

const WIDTH = 320;
const HEIGHT = 200;
var gfxFramebuffer: [WIDTH * HEIGHT]u32 = undefined;

var audioBlockIndex: usize = 0;
var doomSndBuf: [*]i16 = undefined;
const fx_volume = 2.0;
const music_volume = 0.5;

var startTime: u32 = 0;

const WAD_FILE_HANDLE: *c_int = @ptrFromInt(0x00000008); // some unique value we give when wad file opened
var wad_stream_offset: usize = 0;

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
    @setCold(true);
    _ = console.print("PANIC: {s} ret_addr={any}\n", .{msg, ret_addr}) catch 0;
    _ = console.print("{any}\n", .{trace}) catch 0;
    while (true) {}
}

fn consoleWriteFn(data:[]const u8) void {
    _ = console.print("{s}", .{data}) catch 0;
}

extern fn getTimeUs() u32;

// implement a backend for puredoom
export fn doom_print_impl(msg: [*:0]const u8) callconv(.C) void {
    _ = console.print("{s}", .{std.mem.span(msg)}) catch 0;
}

export fn doom_gettime_impl(sec: *c_int, usec: *c_int) callconv(.C) void {
    sec.* = @intCast(millis() / 1000);
    usec.* = @intCast(@mod(millis() * 1000, 1000000));
}

export fn doom_open_impl(filename: [*:0]const u8, mode: [*]const u8) callconv(.C) ?*c_int {
    _ = mode;
    _ = console.print("doom_open_impl {s}\n", .{std.mem.span(filename)}) catch 0;
    if (std.mem.eql(u8, std.mem.span(filename), "/doom1.wad")) {
        return WAD_FILE_HANDLE;
    }
    return null;
}
export fn doom_close_impl(handle: *anyopaque) callconv(.C) void {
    // don't care, all files are in memory
    _ = handle;
}
export fn doom_read_impl(handle: *c_int, buf: [*]u8, count: c_int) callconv(.C) c_int {
    if (handle != WAD_FILE_HANDLE) {
        _ = console.print("doom_read_impl invalid handle!\n", .{}) catch 0;
        return 0;
    }
    const dst = buf[0..@intCast(count)];
    const src = wad_data[wad_stream_offset .. wad_stream_offset + @as(usize, @intCast(count))];

    std.mem.copyForwards(u8, dst, src);
    wad_stream_offset += @intCast(count);
    return count;
}
export fn doom_write_impl(handle: *c_int, buf: *const anyopaque, count: c_int) callconv(.C) c_int {
    _ = handle;
    _ = buf;
    _ = count;
    _ = console.print("doom_write_impl unsupported!\n", .{}) catch 0;
    return 0;
}
export fn doom_seek_impl(handle: *c_int, offset: c_int, origin: pd.doom_seek_t) callconv(.C) c_int {
    if (handle != WAD_FILE_HANDLE) {
        _ = console.print("doom_seek_impl invalid handle!\n", .{}) catch 0;
        return 0;
    }
    switch (origin) {
        pd.DOOM_SEEK_CUR => wad_stream_offset += @intCast(offset),
        pd.DOOM_SEEK_END => wad_stream_offset = wad_data.len - @as(usize, @intCast(offset)),
        pd.DOOM_SEEK_SET => wad_stream_offset = @as(usize, @intCast(offset)),
        else => {},
    }
    return 0;
}
export fn doom_tell_impl(handle: *c_int) callconv(.C) c_int {
    if (handle != WAD_FILE_HANDLE) {
        _ = console.print("doom_tell_impl invalid handle!\n", .{}) catch 0;
        return 0;
    }
    return @intCast(wad_stream_offset);
}
export fn doom_eof_impl(handle: *c_int) callconv(.C) c_int {
    if (handle != WAD_FILE_HANDLE) {
        _ = console.print("doom_eof_impl invalid handle!\n", .{}) catch 0;
        return 1;
    }
    if (wad_stream_offset >= wad_data.len) {
        return 1;
    } else {
        return 0;
    }
}

pub fn millis() u32 {
    return (getTimeUs() - startTime) / 1000;
}

export fn keyevent(keycode: u32, down: bool) void {
    if (down) {
        pd.doom_key_down(keycodeToDoomKey(keycode));
    } else {
        pd.doom_key_up(keycodeToDoomKey(keycode));
    }
}

export fn getGfxBufPtr() [*]u8 {
    return @ptrCast(&gfxFramebuffer);
}

export fn setSampleRate(s: f32) void {
    sampleRate = s;

    // create the synthesizer
    var fbs = std.io.fixedBufferStream(synth_font);
    const reader = fbs.reader();
    var sound_font = SoundFont.init(allocator, reader) catch unreachable;
    var settings = SynthesizerSettings.init(@intFromFloat(s));
    settings.block_size = RENDER_QUANTUM_FRAMES;
    synthesizer = Synthesizer.init(allocator, &sound_font, &settings) catch unreachable;
}

export fn getLeftBufPtr() [*]u8 {
    return @ptrCast(&mix_left);
}

export fn getRightBufPtr() [*]u8 {
    return @ptrCast(&mix_right);
}

export fn renderSoundQuantum() void {
    synthesizer.render(&music_left, &music_right);

    // doom_get_sound_buffer always delivers 2048 bytes (1024 x 16bit samples, interleaved l/r)
    // we need 128 samples at a time, so fetch the buffer, then empty it over multiple calls to renderSoundQuantum

    if (audioBlockIndex == 0) {
        doomSndBuf = pd.doom_get_sound_buffer();
    }
    var i: usize = 0;
    while (i < RENDER_QUANTUM_FRAMES) : (i += 2) {
        // double up audio samples as doom produces at 11025, but webaudio will only go down to 22050
        mix_left[i] = fx_volume * @as(f32, @floatFromInt(doomSndBuf[i + (audioBlockIndex * 64)])) / 32768.0;
        mix_left[i + 1] = fx_volume * @as(f32, @floatFromInt(doomSndBuf[i + (audioBlockIndex * 64)])) / 32768.0;
        mix_right[i] = fx_volume * @as(f32, @floatFromInt(doomSndBuf[i + (audioBlockIndex * 2 * 64)])) / 32768.0;
        mix_right[i + 1] = fx_volume * @as(f32, @floatFromInt(doomSndBuf[i + (audioBlockIndex * 2 * 64)])) / 32768.0;
    }

    i = 0;
    while (i < RENDER_QUANTUM_FRAMES) : (i += 1) {
        // add music
        mix_left[i] += music_volume * music_left[i];
        mix_right[i] += music_volume * music_right[i];
    }
    audioBlockIndex = @mod(audioBlockIndex + 1, 8);
}

export fn init() void {
    startTime = getTimeUs();
    frameCount = 0;

    // init zepto with a memory allocator and console writer
    zeptolibc.init(allocator, consoleWriteFn);

    pd.doom_set_resolution(WIDTH, HEIGHT);
    pd.pd_init();
}

export fn update(deltaMs: u32) void {
    _ = deltaMs;
    pd.doom_update();

    // handle midi, doom wants us to poll at 7ms intervals for data, but we can't as we're only called once per frame
    // polling twice seems to work
    var rounds: usize = 2;
    while (rounds > 0) : (rounds -= 1) {
        while (true) {
            const midi_msg = pd.doom_tick_midi();
            if (midi_msg == 0) {
                break;
            }
            const status: u8 = @truncate(midi_msg & 0x000000FF);
            const note: u8 = @truncate((midi_msg & 0x0000FF00) >> 8);
            const vel: u8 = @truncate((midi_msg & 0x00FF0000) >> 16);

            const channel: i32 = @intCast(status & 0x0F);
            const command: i32 = @intCast(status & 0xF0);
            var data1: i32 = @intCast(note);
            const data2: i32 = @intCast(vel);

            //0xC0 34 is a problem for gzdoom.sf2 (replace electric bass finger -> electic bass pick)
            if (command == 0xC0 and data1 == 34) {
                data1 = 35;
            }
            synthesizer.processMidiMessage(channel, command, data1, data2);
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
    printFPS();

    const fb: [*]const u8 = pd.doom_get_framebuffer(4);
    const fb32 = @as([*]const u32, @ptrCast(@alignCast(fb)))[0 .. WIDTH * HEIGHT];
    @memcpy(&gfxFramebuffer, fb32);
}

fn keycodeToDoomKey(keycode: u32) pd.doom_key_t {
    switch (keycode) {
        9 => return pd.DOOM_KEY_TAB,
        13 => return pd.DOOM_KEY_ENTER,
        27 => return pd.DOOM_KEY_ESCAPE,
        32 => return pd.DOOM_KEY_SPACE,
        222 => return pd.DOOM_KEY_APOSTROPHE,
        106 => return pd.DOOM_KEY_MULTIPLY,
        188 => return pd.DOOM_KEY_COMMA,
        189 => return pd.DOOM_KEY_MINUS,
        190 => return pd.DOOM_KEY_PERIOD,
        191 => return pd.DOOM_KEY_SLASH,
        48 => return pd.DOOM_KEY_0,
        49 => return pd.DOOM_KEY_1,
        50 => return pd.DOOM_KEY_2,
        51 => return pd.DOOM_KEY_3,
        52 => return pd.DOOM_KEY_4,
        53 => return pd.DOOM_KEY_5,
        54 => return pd.DOOM_KEY_6,
        55 => return pd.DOOM_KEY_7,
        56 => return pd.DOOM_KEY_8,
        57 => return pd.DOOM_KEY_9,
        186 => return pd.DOOM_KEY_SEMICOLON,
        187 => return pd.DOOM_KEY_EQUALS,
        219 => return pd.DOOM_KEY_LEFT_BRACKET,
        221 => return pd.DOOM_KEY_RIGHT_BRACKET,
        65 => return pd.DOOM_KEY_A,
        66 => return pd.DOOM_KEY_B,
        67 => return pd.DOOM_KEY_C,
        68 => return pd.DOOM_KEY_D,
        69 => return pd.DOOM_KEY_E,
        70 => return pd.DOOM_KEY_F,
        71 => return pd.DOOM_KEY_G,
        72 => return pd.DOOM_KEY_H,
        73 => return pd.DOOM_KEY_I,
        74 => return pd.DOOM_KEY_J,
        75 => return pd.DOOM_KEY_K,
        76 => return pd.DOOM_KEY_L,
        77 => return pd.DOOM_KEY_M,
        78 => return pd.DOOM_KEY_N,
        79 => return pd.DOOM_KEY_O,
        80 => return pd.DOOM_KEY_P,
        81 => return pd.DOOM_KEY_Q,
        82 => return pd.DOOM_KEY_R,
        83 => return pd.DOOM_KEY_S,
        84 => return pd.DOOM_KEY_T,
        85 => return pd.DOOM_KEY_U,
        86 => return pd.DOOM_KEY_V,
        87 => return pd.DOOM_KEY_W,
        88 => return pd.DOOM_KEY_X,
        89 => return pd.DOOM_KEY_Y,
        90 => return pd.DOOM_KEY_Z,
        8 => return pd.DOOM_KEY_BACKSPACE,
        17 => return pd.DOOM_KEY_CTRL,
        220 => return pd.DOOM_KEY_CTRL,
        37 => return pd.DOOM_KEY_LEFT_ARROW,
        38 => return pd.DOOM_KEY_UP_ARROW,
        39 => return pd.DOOM_KEY_RIGHT_ARROW,
        40 => return pd.DOOM_KEY_DOWN_ARROW,
        16 => return pd.DOOM_KEY_SHIFT,
        18 => return pd.DOOM_KEY_ALT,
        112 => return pd.DOOM_KEY_F1,
        113 => return pd.DOOM_KEY_F2,
        114 => return pd.DOOM_KEY_F3,
        115 => return pd.DOOM_KEY_F4,
        116 => return pd.DOOM_KEY_F5,
        117 => return pd.DOOM_KEY_F6,
        118 => return pd.DOOM_KEY_F7,
        119 => return pd.DOOM_KEY_F8,
        120 => return pd.DOOM_KEY_F9,
        121 => return pd.DOOM_KEY_F10,
        122 => return pd.DOOM_KEY_F11,
        123 => return pd.DOOM_KEY_F12,
        19 => return pd.DOOM_KEY_PAUSE,
        else => return pd.DOOM_KEY_UNKNOWN,
    }
}
