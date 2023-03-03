const std = @import("std");
const pocketmod = @cImport({
    @cInclude("pocketmod.h");
});

// WebAudio's render quantum size.
const RENDER_QUANTUM_FRAMES = 128;

var left:[RENDER_QUANTUM_FRAMES]f32 = undefined;
var right:[RENDER_QUANTUM_FRAMES]f32 = undefined;
var leftright:[RENDER_QUANTUM_FRAMES*2]f32 = undefined;
var sampleRate:f32 = 44100;
var frameCounter:usize = 0;

var ctx:pocketmod.pocketmod_context = undefined;
const mod_data = @embedFile("bananasplit.mod");

pub const std_options = struct {
    pub fn logFn(
        comptime message_level: std.log.Level,
        comptime scope: @TypeOf(.enum_literal),
        comptime format: []const u8,
        args: anytype,
    ) void {
        _ = message_level;
        _ = scope;
        _ = format;
        _ = args;
    }
};

export fn setSampleRate(s:f32) void {
    sampleRate = s;

    _ = pocketmod.pocketmod_init(&ctx, mod_data, mod_data.len, @floatToInt(c_int, sampleRate));
}

export fn getLeftBufPtr() [*]u8 {
    return @ptrCast([*]u8, &left);
}

export fn getRightBufPtr() [*]u8 {
    return @ptrCast([*]u8, &right);
}

export fn renderSoundQuantum() void {
    var bytes:usize = undefined;
    var i:usize = undefined;

    var lbuf = @ptrCast([*]u8, &left);
    var rbuf = @ptrCast([*]u8, &right);
    bytes = RENDER_QUANTUM_FRAMES * 8;
    i = 0;
    while (i < bytes) {
        const count = pocketmod.pocketmod_render(&ctx, lbuf + i, @intCast(c_int, bytes - i));
        i += @intCast(usize, count);
    }


//    var rbuf = @ptrCast([*]u8, &right);
//    bytes = RENDER_QUANTUM_FRAMES * 4;
//    i = 0;
//    while (i < bytes) {
//        const count = pocketmod.pocketmod_render(&ctx, rbuf + i, @intCast(c_int, bytes - i));
//        i += @intCast(usize, count);
//    }

}

