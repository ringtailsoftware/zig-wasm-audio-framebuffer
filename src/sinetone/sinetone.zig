const std = @import("std");

// WebAudio's render quantum size.
const RENDER_QUANTUM_FRAMES = 128;

var left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var right: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var sampleRate: f32 = 44100;
var l_freqHz: f32 = 220;
var r_freqHz: f32 = 220;

var frameCounter: usize = 0;

export fn setSampleRate(s: f32) void {
    sampleRate = s;
}

export fn getLeftBufPtr() [*]u8 {
    return @ptrCast(&left);
}

export fn getRightBufPtr() [*]u8 {
    return @ptrCast(&right);
}

export fn setLeftFreq(f: f32) void {
    l_freqHz = f;
}

export fn setRightFreq(f: f32) void {
    r_freqHz = f;
}

export fn renderSoundQuantum() void {
    var i: usize = 0;
    while (i < RENDER_QUANTUM_FRAMES) : (i += 1) {
        left[i] = std.math.sin(2 * std.math.pi * l_freqHz * @as(f32, @floatFromInt(frameCounter)) / sampleRate);
        right[i] = std.math.sin(2 * std.math.pi * r_freqHz * @as(f32, @floatFromInt(frameCounter)) / sampleRate);
        frameCounter += 1;
    }
}
