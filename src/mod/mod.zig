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
    var bytes:usize = RENDER_QUANTUM_FRAMES * 4 * 2;

    // pocketmod produces interleaved l/r/l/r data, so fetch a double batch
    var lrbuf = @ptrCast([*]u8, &leftright);
    bytes = RENDER_QUANTUM_FRAMES * 4 * 2;
    var i:usize = 0;
    while (i < bytes) {
        const count = pocketmod.pocketmod_render(&ctx, lrbuf + i, @intCast(c_int, bytes - i));
        i += @intCast(usize, count);
    }

    // then deinterleave it into the l and r buffers
    i = 0;
    while(i<RENDER_QUANTUM_FRAMES) : (i += 1) {
        left[i] = leftright[i*2];
        right[i] = leftright[i*2+1];
    }
}

