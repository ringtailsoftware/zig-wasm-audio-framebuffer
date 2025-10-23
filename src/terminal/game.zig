const math = @import("zlm").as(f32);

pub const Game = struct {
    pub const Renderer = @import("renderer.zig").Renderer;
    pub const Surface = @import("renderer.zig").Surface;
    pub const Font = @import("renderer.zig").Font;
    pub const Assets =  @import("assets.zig").Assets;
    pub const Rect = @import("rect.zig").Rect;
    pub const vec2 = math.vec2;
    pub const Vec2 = math.Vec2;
};
