const std = @import("std");
const ziggysynth = @import("ziggysynth.zig");

const SoundFont = ziggysynth.SoundFont;
const Synthesizer = ziggysynth.Synthesizer;
const SynthesizerSettings = ziggysynth.SynthesizerSettings;

// WebAudio's render quantum size.
const RENDER_QUANTUM_FRAMES = 128;

var left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var right: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var sampleRate: f32 = 44100;
var synthesizer: Synthesizer = undefined;
var reader = std.Io.Reader.fixed(@embedFile("TimGM6mb.sf2"));

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

pub const std_options: std.Options = .{
    .logFn = logFn,
};

export fn noteOn(note: i32, vel: i32) void {
    synthesizer.noteOn(0, note, vel);
}

export fn noteOff(note: i32) void {
    synthesizer.noteOff(0, note);
}

export fn setSampleRate(s: f32) void {
    sampleRate = s;

    // create the synthesizer
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const sound_font = SoundFont.init(allocator, &reader) catch unreachable;
    var settings = SynthesizerSettings.init(@intFromFloat(s));
    settings.block_size = RENDER_QUANTUM_FRAMES;
    synthesizer = Synthesizer.init(allocator, &sound_font, &settings) catch unreachable;
}

export fn getLeftBufPtr() [*]u8 {
    return @ptrCast(&left);
}

export fn getRightBufPtr() [*]u8 {
    return @ptrCast(&right);
}

export fn renderSoundQuantum() void {
    synthesizer.render(&left, &right);
}
