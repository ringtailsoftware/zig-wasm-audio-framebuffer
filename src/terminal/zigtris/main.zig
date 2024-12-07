const std = @import("std");

const Display = @import("display.zig").Display;
const Stage = @import("stage.zig").Stage;
const Debris = @import("debris.zig").Debris;
const Player = @import("player.zig").Player;
const Decor = @import("decor.zig").Decor;

const io = std.io;

const mibu = @import("mibu");
const events = mibu.events;

const time = @import("time.zig");

// position of stage in display coords
const STAGE_OFF_X = 2;
const STAGE_OFF_Y = 1;

var gameOver = false;
var display:Display = undefined;
var stage:Stage = undefined;
var debris:Debris = undefined;
var player:Player = undefined;
var decor:Decor = undefined;
var lastTick: u32 = 0;
var prng: std.Random.Xoshiro256 = undefined;
var rand: std.Random = undefined;

pub fn gamesetup(writer:anytype, now:u32) !void {
    gameOver = false;
    prng = std.rand.DefaultPrng.init(@intCast(now));
    rand = prng.random();

    display = try Display.init(writer);
    display.cls();

    stage = try Stage.init();
    stage.cls();

    debris = try Debris.init(rand);
    debris.cls();
    debris.addRandom();

    player = try Player.init(rand);

    try display.paint(writer);

    decor = try Decor.init();

    lastTick = 0;
}

pub fn gamestop(writer:anytype) void {
    display.destroy(writer);
}

pub fn gameloop(writer:anytype, now:u32, next:mibu.events.Event) !bool {
    if (now >= lastTick + 100) { // 100ms tick (mubi operates at 0.1Hz)
        lastTick = now;
        if (!player.advance(&debris, now)) {
            gameOver = true;
        }
    }

    switch (next) {
        .key => |k| switch (k) {
            .down => {
                _ = player.moveDown(&debris, now);
            },
            .up => {
                player.rotate(&debris);
            },
            .left => {
                player.moveHorz(-1, &debris);
            },
            .right => {
                player.moveHorz(1, &debris);
            },
            .char => |c| switch (c) {
                'q' => return false,
                ' ' => player.dropDown(&debris, now),
                else => {},
            },
            else => {},
        },
        else => {},
    }

    stage.cls();
    try debris.paint(&stage);
    try player.paint(&stage);
    try stage.paint(&display, STAGE_OFF_X, STAGE_OFF_Y);
    try decor.paint(&display, (STAGE_OFF_X + Stage.STAGEW) * 2 + 1, 1, player.level, player.numLines, player.score, player.nextTimo);
    try display.paint(writer);
    return !gameOver;
}

pub fn main() !void {
    const writer = std.io.getStdOut().writer();
    const reader = std.io.getStdIn();
    time.initTime();

    var rt = try mibu.term.enableRawMode(reader.handle);
    const seed:u32 = @truncate(@as(u128, @intCast(std.time.nanoTimestamp())));
    try gamesetup(writer, seed);

    while (!gameOver) {
        const next = try display.getEvent(reader);
        if (!try gameloop(writer, time.millis(), next)) {
            gameOver = true;
        }
    }

    gamestop(writer);
    _ = rt.disableRawMode() catch 0;
}
