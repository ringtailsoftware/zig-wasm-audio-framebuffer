// player tetronimo

const Stage = @import("stage.zig").Stage;
const std = @import("std");
const Debris = @import("debris.zig").Debris;
const time = @import("time.zig");

pub const TetronimoFrame = [16]Stage.PixelStyle;
pub const TetronimoAnim = [4]TetronimoFrame;

const TetI: TetronimoAnim = .{
    .{
        0, 0, 0, 0,
        2, 2, 2, 2,
        0, 0, 0, 0,
        0, 0, 0, 0,
    },

    .{
        0, 0, 2, 0,
        0, 0, 2, 0,
        0, 0, 2, 0,
        0, 0, 2, 0,
    },
    .{
        0, 0, 0, 0,
        0, 0, 0, 0,
        2, 2, 2, 2,
        0, 0, 0, 0,
    },
    .{
        0, 2, 0, 0,
        0, 2, 0, 0,
        0, 2, 0, 0,
        0, 2, 0, 0,
    },
};

const TetJ: TetronimoAnim = .{
    .{
        3, 0, 0, 0,
        3, 3, 3, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
    },

    .{
        0, 3, 3, 0,
        0, 3, 0, 0,
        0, 3, 0, 0,
        0, 0, 0, 0,
    },
    .{
        0, 0, 0, 0,
        3, 3, 3, 0,
        0, 0, 3, 0,
        0, 0, 0, 0,
    },
    .{
        0, 3, 0, 0,
        0, 3, 0, 0,
        3, 3, 0, 0,
        0, 0, 0, 0,
    },
};

const TetL: TetronimoAnim = .{
    .{
        0, 0, 4, 0,
        4, 4, 4, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
    },

    .{
        0, 4, 0, 0,
        0, 4, 0, 0,
        0, 4, 4, 0,
        0, 0, 0, 0,
    },
    .{
        0, 0, 0, 0,
        4, 4, 4, 0,
        4, 0, 0, 0,
        0, 0, 0, 0,
    },
    .{
        4, 4, 0, 0,
        0, 4, 0, 0,
        0, 4, 0, 0,
        0, 0, 0, 0,
    },
};

const TetO: TetronimoAnim = .{
    .{
        0, 5, 5, 0,
        0, 5, 5, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
    },
    .{
        0, 5, 5, 0,
        0, 5, 5, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
    },
    .{
        0, 5, 5, 0,
        0, 5, 5, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
    },
    .{
        0, 5, 5, 0,
        0, 5, 5, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
    },
};

const TetS: TetronimoAnim = .{
    .{
        0, 6, 6, 0,
        6, 6, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
    },
    .{
        0, 6, 0, 0,
        0, 6, 6, 0,
        0, 0, 6, 0,
        0, 0, 0, 0,
    },
    .{
        0, 0, 0, 0,
        0, 6, 6, 0,
        6, 6, 0, 0,
        0, 0, 0, 0,
    },
    .{
        6, 0, 0, 0,
        6, 6, 0, 0,
        0, 6, 0, 0,
        0, 0, 0, 0,
    },
};

const TetZ: TetronimoAnim = .{
    .{
        1, 1, 0, 0,
        0, 1, 1, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
    },
    .{
        0, 0, 1, 0,
        0, 1, 1, 0,
        0, 1, 0, 0,
        0, 0, 0, 0,
    },
    .{
        0, 0, 0, 0,
        1, 1, 0, 0,
        0, 1, 1, 0,
        0, 0, 0, 0,
    },
    .{
        0, 1, 0, 0,
        1, 1, 0, 0,
        1, 0, 0, 0,
        0, 0, 0, 0,
    },
};

const TetT: TetronimoAnim = .{
    .{
        0, 2, 0, 0,
        2, 2, 2, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
    },
    .{
        0, 2, 0, 0,
        0, 2, 2, 0,
        0, 2, 0, 0,
        0, 0, 0, 0,
    },
    .{
        0, 0, 0, 0,
        2, 2, 2, 0,
        0, 2, 0, 0,
        0, 0, 0, 0,
    },
    .{
        0, 0, 2, 0,
        0, 2, 2, 0,
        0, 0, 2, 0,
        0, 0, 0, 0,
    },
};

pub const pieces = [_]TetronimoAnim{ TetI, TetJ, TetL, TetO, TetS, TetZ, TetT };

pub const Tetronimo = struct {
    const Self = @This();
    anim: TetronimoAnim,
    animFrame: usize,

    pub fn initRandom(rand:std.Random) Self {
        return Self {
            .animFrame = 0,
            .anim = pieces[(rand.int(u8)) % pieces.len],
        };
    }

    pub fn paint(self: *Self, stage: *Stage, px: isize, py: isize) !void {
        // paint to Stage
        for (0..4) |y| {
            for (0..4) |x| {
                const ps = self.anim[self.animFrame][y * 4 + x];
                if (ps != 0) { // 0 is transparent
                    const xo = px + @as(isize, @intCast(x));
                    const yo = py + @as(isize, @intCast(y));

                    if (xo >= 0 and xo < Stage.STAGEW and yo >= 0 and yo < Stage.STAGEH) {
                        try stage.setPixel(@intCast(xo), @intCast(yo), ps);
                    }
                }
            }
        }
    }

    pub fn collidesDebris(self: *Self, px: isize, py: isize, debris: *Debris) bool {
        for (0..4) |y| {
            for (0..4) |x| {
                const ps = self.anim[self.animFrame][y * 4 + x];
                if (ps != 0) { // 0 is transparent
                    const xo = px + @as(isize, @intCast(x));
                    const yo = py + @as(isize, @intCast(y));

                    // check edges
                    if (xo < 0 or xo >= Stage.STAGEW or yo < 0 or yo >= Stage.STAGEH) {
                        return true;
                    }

                    if (!debris.isEmpty(@intCast(xo), @intCast(yo))) {
                        return true;
                    }
                }
            }
        }
        return false;
    }
};

pub const Player = struct {
    const Self = @This();
    px: isize, // need to be signed because coord of top-left of tetronimo could be offscreen
    py: isize,
    timo: Tetronimo,
    nextTimo: Tetronimo,
    atRest: bool,
    atRestTime: u32,
    moveDownTime: u32,
    numLines: usize,
    score: usize,
    level: usize,
    rand: std.Random,

    pub fn init(rand:std.Random) !Self {
        return Self{
            .px = Stage.STAGEW / 2,
            .py = 0,
            .timo = Tetronimo.initRandom(rand),
            .nextTimo = Tetronimo.initRandom(rand),
            .atRest = false,
            .atRestTime = 0,
            .moveDownTime = 0,
            .numLines = 0,
            .score = 0,
            .level = 1,
            .rand = rand,
        };
    }

    pub fn setupTetronimo(self: *Self) void {
        self.px = Stage.STAGEW / 2;
        self.py = 0;
        self.timo = self.nextTimo;
        self.nextTimo = Tetronimo.initRandom(self.rand);
        self.atRest = false;
        self.atRestTime = 0;
        self.moveDownTime = 0;
    }

    fn dropDelay(self: *Self) u32 {
        // decrease the drop delay based on number of lines completed
        // mubi library is hardcoded to 0.1Hz tick

        switch(self.level) {
            1 => return 500,
            2 => return 450,
            3 => return 400,
            4 => return 350,
            5 => return 300,
            6 => return 250,
            7 => return 200,
            8 => return 150,
            else => return 100,
        }
    }

    fn calcLevel(self: *Self) usize {
        return (self.numLines / 5) + 1;
    }

    pub fn advance(self: *Self, debris: *Debris, now:u32) bool {
        if (now > self.moveDownTime + self.dropDelay()) { // try to move down
            if (self.moveDown(debris, now)) {
                self.moveDownTime = now; // update last move time, iff moved ok
            }
        }

        if (self.atRest) {
            if (self.atRest and now > self.atRestTime + self.dropDelay()) {
                // add tetronimo to debris
                self.debrisPaint(debris);
                const lines = debris.collapse();
                self.numLines += lines;
                self.score += lines * self.level * 10;  // multi-line bonus based on level
                self.score += 1;    // for dropping a piece
                self.level = self.calcLevel();
                self.setupTetronimo();
                if (self.timo.collidesDebris(self.px, self.py, debris)) {
                    return false;
                }
            }
        }
        return true;
    }

    pub fn debrisPaint(self: *Self, debris: *Debris) void {
        // paint Player to Debris
        for (0..4) |y| {
            for (0..4) |x| {
                const ps = self.timo.anim[self.timo.animFrame][y * 4 + x];
                if (ps != 0) { // 0 is transparent
                    const xo = self.px + @as(isize, @intCast(x));
                    const yo = self.py + @as(isize, @intCast(y));

                    if (xo >= 0 and xo < Stage.STAGEW and yo >= 0 and yo < Stage.STAGEH) {
                        debris.setPixel(@intCast(xo), @intCast(yo), ps);
                    }
                }
            }
        }
    }

    pub fn paint(self: *Self, stage: *Stage) !void {
        try self.timo.paint(stage, self.px, self.py);
    }

    pub fn rotate(self: *Self, debris: *Debris) void {
        var newTimo:Tetronimo = undefined;

        const nextFrame = (self.timo.animFrame + 1) % 4;

        newTimo = self.timo;
        newTimo.animFrame = nextFrame;

        // only allow if new timo at px,py does not intersect debris (or game walls)
        if (!newTimo.collidesDebris(self.px, self.py, debris)) {
            self.timo = newTimo;
            self.timo.animFrame = nextFrame;
        } else {
            if (!newTimo.collidesDebris(self.px-1, self.py, debris)) { // kick left 1
                self.px -= 1;
                self.timo = newTimo;
            } else if (!newTimo.collidesDebris(self.px+1, self.py, debris)) {   // kick right 1
                self.px += 1;
                self.timo = newTimo;
            } else if (!newTimo.collidesDebris(self.px-2, self.py, debris)) {   // kick left 2
                self.px -= 2;
                self.timo = newTimo;
            } else if (!newTimo.collidesDebris(self.px+2, self.py, debris)) {   // kick right 2
                self.px += 2;
                self.timo = newTimo;
            }
        }
    }

    pub fn moveHorz(self: *Self, xd: i2, debris: *Debris) void {
        var newpx = self.px;

        // self.px could actually be negative as it's top left of tetronimo
        if (xd < 0) {
            newpx -= 1;
        }
        if (xd > 0) {
            newpx += 1;
        }

        if (!self.timo.collidesDebris(newpx, self.py, debris)) {
            self.px = newpx;
        }
    }

    pub fn dropDown(self: *Self, debris: *Debris, now:u32) void {
        while(self.moveDown(debris, now)) {
            self.score += self.level * 2;   // bonus for bigger drops and higher levels
        }
    }

    pub fn moveDown(self: *Self, debris: *Debris, now:u32) bool {
        var newpy = self.py;

        newpy += 1;

        if (!self.timo.collidesDebris(self.px, newpy, debris)) {
            self.py = newpy;
            self.atRest = false;
            return true; // moved down ok
        }
        if (!self.atRest) {
            self.atRest = true;
            self.atRestTime = now;
        }
        return false; // unable to move down
    }
};
