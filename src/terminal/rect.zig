const Game = @import("game.zig").Game;
const vec2 = Game.vec2;
const Vec2 = Game.Vec2;

pub const Rect = struct {
    const Self = @This();
    tl: Vec2, // top left
    br: Vec2, // bottom right

    pub const Align = enum {
        Top,
        Bottom,
        Left,
        Right,
        Centre,
        VCentre,
        HCentre,
    };

    pub fn init(x: f32, y: f32, w: f32, h: f32) Self {
        return Self{ .tl = vec2(x, y), .br = vec2(x + w, y + h) };
    }

    pub fn initPts(tl: Vec2, br: Vec2) Self {
        return Self{ .tl = tl, .br = br };
    }

    pub fn size(self: *const Self) Vec2 {
        return self.br.sub(self.tl);
    }

    pub fn width(self: *const Self) f32 {
        return self.size().x;
    }

    pub fn height(self: *const Self) f32 {
        return self.size().y;
    }

    pub fn containsRect(self: *const Self, r: Rect) bool {
        return (self.containsPt(r.tl) and self.containsPt(r.br));
    }

    pub fn containsPt(self: *const Self, p: Vec2) bool {
        if (p.x < self.tl.x or p.x > self.br.x) {
            return false;
        }
        if (p.y < self.tl.y or p.y > self.br.y) {
            return false;
        }
        return true;
    }

    pub fn border(self: *const Self, amount: f32) Self {
        return Self.initPts(self.tl.add(vec2(amount, amount)), self.br.sub(vec2(amount, amount)));
    }

    pub fn offset(self: *const Self, amount: f32) Self {
        return Self.initPts(self.tl.add(vec2(amount, amount)), self.br.add(vec2(amount, amount)));
    }

    pub fn moveTopLeft(self: *const Self, tl: Vec2) Self {
        var copy = initPts(self.tl, self.br);
        const w = copy.width();
        const h = copy.height();
        copy.tl = tl;
        copy.br = tl.add(vec2(w, h));
        return copy;
    }

    pub fn clip(self: *const Self, maxw: ?f32, maxh: ?f32) Self {
        var copy = initPts(self.tl, self.br);
        if (maxw != null) {
            if (copy.width() > maxw.?) {
                copy.br.x = copy.tl.x + maxw.?;
            }
        }
        if (maxh != null) {
            if (copy.height() > maxh.?) {
                copy.br.y = copy.tl.y + maxh.?;
            }
        }
        return copy;
    }

    pub fn scale(self: *const Self, s: Vec2) Self {
        return Self.init(self.tl.x, self.tl.y, self.width() * s.x, self.height() * s.y);
    }

    pub fn alignTo(self: *const Self, to: Self, al: Align) Self {
        var copy = initPts(self.tl, self.br);
        const w = copy.width();
        const h = copy.height();
        switch (al) {
            Align.Top => {
                copy.tl.y = to.tl.y;
                copy.br.y = copy.tl.y + h;
            },
            Align.Bottom => {
                copy.tl.y = to.br.y - h;
                copy.br.y = copy.tl.y + h;
            },
            Align.Left => {
                copy.tl.x = to.tl.x;
                copy.br.x = copy.tl.x + w;
            },
            Align.Right => {
                copy.tl.x = to.br.x - w;
                copy.br.x = copy.tl.x + w;
            },
            Align.Centre => {
                copy.tl.y = to.tl.y + (to.height() - h) / 2;
                copy.tl.x = to.tl.x + (to.width() - w) / 2;
                copy.br.x = copy.tl.x + w;
                copy.br.y = copy.tl.x + h;
            },
            Align.VCentre => {
                copy.tl.y = to.tl.y + (to.height() - h) / 2;
                copy.br.y = copy.tl.x + h;
            },
            Align.HCentre => {
                copy.tl.x = to.tl.x + (to.width() - h) / 2;
                copy.br.x = copy.tl.x + w;
            },
        }
        return copy;
    }
};
