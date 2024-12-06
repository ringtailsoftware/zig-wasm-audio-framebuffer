const math = @import("zlm/zlm.zig");

pub const Game = struct {
    pub usingnamespace @import("renderer.zig");
    pub usingnamespace @import("assets.zig");
    pub const Rect = @import("rect.zig").Rect;
    pub const vec2 = math.vec2;
    pub const Vec2 = math.Vec2;
};
