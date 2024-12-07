// background debris

const std = @import("std");
const Stage = @import("stage.zig").Stage;

pub const Debris = struct {
    const Self = @This();
    buf: [Stage.STAGEW * Stage.STAGEH]Stage.PixelStyle,
    rand: std.Random,

    pub fn init(rand:std.Random) !Self {
        return Self{
            .buf = undefined,
            .rand = rand,
        };
    }

    pub fn addRandom(self: *Self) void {
        for (0..Stage.STAGEW) |x| {
            if (self.rand.int(u8) % 2 == 0) {
                self.setPixel(x, Stage.STAGEH - 1, self.rand.int(u3));
            }
            if (self.rand.int(u8) % 4 == 0) {
                self.setPixel(x, Stage.STAGEH - 2, 1);
            }
            if (self.rand.int(u8) % 8 == 0) {
                self.setPixel(x, Stage.STAGEH - 3, 1);
            }
        }
    }

    pub fn setPixel(self: *Self, x: usize, y: usize, p: Stage.PixelStyle) void {
        self.buf[y * Stage.STAGEW + x] = p;
    }

    pub fn cls(self: *Self) void {
        for (0..Stage.STAGEH) |y| {
            for (0..Stage.STAGEW) |x| {
                self.buf[y * Stage.STAGEW + x] = 0;
            }
        }
    }

    pub fn checkLineIsCompleted(self: *Self, y: usize) bool {
        for (0..Stage.STAGEW) |x| {
            if (self.buf[y * Stage.STAGEW + x] == 0) {
                return false;
            }
        }
        return true;
    }

    pub fn collapseLine(self: *Self, y: usize) bool {
        if (self.checkLineIsCompleted(y)) {
            // zap this line, move all higher lines down by one.
            // start at line above, copy down
            var y2: isize = @intCast(y);
            while (y2 >= 0) : (y2 -= 1) {
                for (0..Stage.STAGEW) |x| {
                    var ps: Stage.PixelStyle = 0; // default fill with empty
                    if (y2 - 1 >= 0) { // copying from a valid line
                        ps = self.buf[@as(usize, @intCast(y2 - 1)) * Stage.STAGEW + x];
                    }
                    self.setPixel(x, @intCast(y2), ps);
                }
            }
            return true;
        }
        return false;
    }

    pub fn collapse(self: *Self) usize { // returns number of collapsed lines
        var numLines: usize = 0;
        // look for and remove lines
        var workRemaining = true;
        outer: while (workRemaining) {
            var y: usize = Stage.STAGEH - 1;
            while (y > 0) : (y -= 1) {
                if (self.collapseLine(y)) {
                    numLines += 1;
                    continue :outer;
                }
            }
            workRemaining = false; // didn't collapse any lines
        }
        return numLines;
    }

    pub fn isEmpty(self: *Self, x: usize, y: usize) bool {
        if (x >= Stage.STAGEW or y >= Stage.STAGEH) {
            return false; // edge
        }
        return self.buf[y * Stage.STAGEW + x] == 0;
    }

    pub fn paint(self: *Self, stage: *Stage) !void {
        // paint Debris to Stage
        for (0..Stage.STAGEH) |y| {
            for (0..Stage.STAGEW) |x| {
                const p = self.buf[y * Stage.STAGEW + x];
                try stage.setPixel(x, y, p);
            }
        }
    }
};
