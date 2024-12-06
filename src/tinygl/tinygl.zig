const std = @import("std");
const console = @import("console.zig").getWriter().writer();
const zeptolibc = @import("zeptolibc");
const tgl = @cImport({
    @cInclude("GL/gl.h");
    @cInclude("zgl.h");
});

const WIDTH = 400;
const HEIGHT = 400;
var gfxFramebuffer: [WIDTH * HEIGHT]u32 = undefined;

const RENDER_QUANTUM_FRAMES = 128; // WebAudio's render quantum size
var sampleRate: f32 = 44100;
var mix_left: [RENDER_QUANTUM_FRAMES]f32 = undefined;
var mix_right: [RENDER_QUANTUM_FRAMES]f32 = undefined;

var startTime: u32 = 0;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var view_rotx: tgl.GLfloat = 20.0;
var view_roty: tgl.GLfloat = 30.0;
var view_rotz: tgl.GLfloat = 0.0;
var gear1: tgl.GLuint = undefined;
var gear2: tgl.GLuint = undefined;
var gear3: tgl.GLuint = undefined;
var angle: tgl.GLfloat = 0.0;
var pos: [4]tgl.GLfloat = .{ 5.0, 5.0, 10.0, 0.0 };
var red: [4]tgl.GLfloat = .{ 0.8, 0.1, 0.0, 1.0 };
var green: [4]tgl.GLfloat = .{ 0.0, 0.8, 0.2, 1.0 };
var blue: [4]tgl.GLfloat = .{ 0.2, 0.2, 1.0, 1.0 };

fn gear(inner_radius: tgl.GLfloat, outer_radius: tgl.GLfloat, width: tgl.GLfloat, teeth: tgl.GLint, tooth_depth: tgl.GLfloat) void {
    var i: tgl.GLint = undefined;
    var r0: tgl.GLfloat = undefined;
    var r1: tgl.GLfloat = undefined;
    var r2: tgl.GLfloat = undefined;
    var ang: tgl.GLfloat = undefined;
    var da: tgl.GLfloat = undefined;
    var u: tgl.GLfloat = undefined;
    var v: tgl.GLfloat = undefined;
    var len: tgl.GLfloat = undefined;

    r0 = inner_radius;
    r1 = outer_radius - tooth_depth / 2.0;
    r2 = outer_radius + tooth_depth / 2.0;

    da = 2.0 * std.math.pi / @as(tgl.GLfloat, @floatFromInt(teeth)) / 4.0;

    tgl.glShadeModel(tgl.GL_FLAT);

    tgl.glNormal3f(0.0, 0.0, 1.0);

    // draw front face
    tgl.glBegin(tgl.GL_QUAD_STRIP);

    i = 0;
    while (i <= teeth) : (i += 1) {
        ang = @as(tgl.GLfloat, @floatFromInt(i)) * 2.0 * std.math.pi / @as(tgl.GLfloat, @floatFromInt(teeth));
        tgl.glVertex3f(r0 * @cos(ang), r0 * @sin(ang), width * 0.5);
        tgl.glVertex3f(r1 * @cos(ang), r1 * @sin(ang), width * 0.5);
        tgl.glVertex3f(r0 * @cos(ang), r0 * @sin(ang), width * 0.5);
        tgl.glVertex3f(r1 * @cos(ang + 3 * da), r1 * @sin(ang + 3 * da), width * 0.5);
    }
    tgl.glEnd();

    // draw front sides of teeth
    tgl.glBegin(tgl.GL_QUADS);
    da = 2.0 * std.math.pi / @as(tgl.GLfloat, @floatFromInt(teeth)) / 4.0;
    i = 0;
    while (i < teeth) : (i += 1) {
        ang = @as(tgl.GLfloat, @floatFromInt(i)) * 2.0 * std.math.pi / @as(tgl.GLfloat, @floatFromInt(teeth));

        tgl.glVertex3f(r1 * @cos(ang), r1 * @sin(ang), width * 0.5);
        tgl.glVertex3f(r2 * @cos(ang + da), r2 * @sin(ang + da), width * 0.5);
        tgl.glVertex3f(r2 * @cos(ang + 2 * da), r2 * @sin(ang + 2 * da), width * 0.5);
        tgl.glVertex3f(r1 * @cos(ang + 3 * da), r1 * @sin(ang + 3 * da), width * 0.5);
    }
    tgl.glEnd();

    tgl.glNormal3f(0.0, 0.0, -1.0);

    // draw back face
    tgl.glBegin(tgl.GL_QUAD_STRIP);
    i = 0;
    while (i <= teeth) : (i += 1) {
        ang = @as(tgl.GLfloat, @floatFromInt(i)) * 2.0 * std.math.pi / @as(tgl.GLfloat, @floatFromInt(teeth));
        tgl.glVertex3f(r1 * @cos(ang), r1 * @sin(ang), -width * 0.5);
        tgl.glVertex3f(r0 * @cos(ang), r0 * @sin(ang), -width * 0.5);
        tgl.glVertex3f(r1 * @cos(ang + 3 * da), r1 * @sin(ang + 3 * da), -width * 0.5);
        tgl.glVertex3f(r0 * @cos(ang), r0 * @sin(ang), -width * 0.5);
    }
    tgl.glEnd();

    // draw back sides of teeth
    tgl.glBegin(tgl.GL_QUADS);
    da = 2.0 * std.math.pi / @as(tgl.GLfloat, @floatFromInt(teeth)) / 4.0;
    i = 0;
    while (i < teeth) : (i += 1) {
        ang = @as(tgl.GLfloat, @floatFromInt(i)) * 2.0 * std.math.pi / @as(tgl.GLfloat, @floatFromInt(teeth));

        tgl.glVertex3f(r1 * @cos(ang + 3 * da), r1 * @sin(ang + 3 * da), -width * 0.5);
        tgl.glVertex3f(r2 * @cos(ang + 2 * da), r2 * @sin(ang + 2 * da), -width * 0.5);
        tgl.glVertex3f(r2 * @cos(ang + da), r2 * @sin(ang + da), -width * 0.5);
        tgl.glVertex3f(r1 * @cos(ang), r1 * @sin(ang), -width * 0.5);
    }
    tgl.glEnd();

    // draw outward faces of teeth
    tgl.glBegin(tgl.GL_QUAD_STRIP);
    i = 0;
    while (i <= teeth) : (i += 1) {
        ang = @as(tgl.GLfloat, @floatFromInt(i)) * 2.0 * std.math.pi / @as(tgl.GLfloat, @floatFromInt(teeth));

        tgl.glVertex3f(r1 * @cos(ang), r1 * @sin(ang), width * 0.5);
        tgl.glVertex3f(r1 * @cos(ang), r1 * @sin(ang), -width * 0.5);
        u = r2 * @cos(ang + da) - r1 * @cos(ang);
        v = r2 * @sin(ang + da) - r1 * @sin(ang);
        len = std.math.sqrt(u * u + v * v);
        u /= len;
        v /= len;
        tgl.glNormal3f(v, -u, 0.0);
        tgl.glVertex3f(r2 * @cos(ang + da), r2 * @sin(ang + da), width * 0.5);
        tgl.glVertex3f(r2 * @cos(ang + da), r2 * @sin(ang + da), -width * 0.5);
        tgl.glNormal3f(@cos(ang), @sin(ang), 0.0);
        tgl.glVertex3f(r2 * @cos(ang + 2 * da), r2 * @sin(ang + 2 * da), width * 0.5);
        tgl.glVertex3f(r2 * @cos(ang + 2 * da), r2 * @sin(ang + 2 * da), -width * 0.5);
        u = r1 * @cos(ang + 3 * da) - r2 * @cos(ang + 2 * da);
        v = r1 * @sin(ang + 3 * da) - r2 * @sin(ang + 2 * da);
        tgl.glNormal3f(v, -u, 0.0);
        tgl.glVertex3f(r1 * @cos(ang + 3 * da), r1 * @sin(ang + 3 * da), width * 0.5);
        tgl.glVertex3f(r1 * @cos(ang + 3 * da), r1 * @sin(ang + 3 * da), -width * 0.5);
        tgl.glNormal3f(@cos(ang), @sin(ang), 0.0);
    }

    tgl.glVertex3f(r1 * @cos(0.0), r1 * @sin(0.0), width * 0.5);
    tgl.glVertex3f(r1 * @cos(0.0), r1 * @sin(0.0), -width * 0.5);

    tgl.glEnd();

    tgl.glShadeModel(tgl.GL_SMOOTH);

    // draw inside radius cylinder
    tgl.glBegin(tgl.GL_QUAD_STRIP);
    i = 0;
    while (i <= teeth) : (i += 1) {
        ang = @as(tgl.GLfloat, @floatFromInt(i)) * 2.0 * std.math.pi / @as(tgl.GLfloat, @floatFromInt(teeth));
        tgl.glNormal3f(-@cos(ang), -@sin(ang), 0.0);
        tgl.glVertex3f(r0 * @cos(ang), r0 * @sin(ang), -width * 0.5);
        tgl.glVertex3f(r0 * @cos(ang), r0 * @sin(ang), width * 0.5);
    }
    tgl.glEnd();
}

fn make_object() tgl.GLuint {
    var list: tgl.GLuint = undefined;

    list = tgl.glGenLists(1);

    tgl.glNewList(list, tgl.GL_COMPILE);

    tgl.glBegin(tgl.GL_LINE_LOOP);
    tgl.glColor3f(1.0, 1.0, 1.0);
    tgl.glVertex3f(1.0, 0.5, -0.4);
    tgl.glColor3f(1.0, 0.0, 0.0);
    tgl.glVertex3f(1.0, -0.5, -0.4);
    tgl.glColor3f(0.0, 1.0, 0.0);
    tgl.glVertex3f(-1.0, -0.5, -0.4);
    tgl.glColor3f(0.0, 0.0, 1.0);
    tgl.glVertex3f(-1.0, 0.5, -0.4);
    tgl.glEnd();

    tgl.glColor3f(1.0, 1.0, 1.0);

    tgl.glBegin(tgl.GL_LINE_LOOP);
    tgl.glVertex3f(1.0, 0.5, 0.4);
    tgl.glVertex3f(1.0, -0.5, 0.4);
    tgl.glVertex3f(-1.0, -0.5, 0.4);
    tgl.glVertex3f(-1.0, 0.5, 0.4);
    tgl.glEnd();

    tgl.glBegin(tgl.GL_LINES);
    tgl.glVertex3f(1.0, 0.5, -0.4);
    tgl.glVertex3f(1.0, 0.5, 0.4);
    tgl.glVertex3f(1.0, -0.5, -0.4);
    tgl.glVertex3f(1.0, -0.5, 0.4);
    tgl.glVertex3f(-1.0, -0.5, -0.4);
    tgl.glVertex3f(-1.0, -0.5, 0.4);
    tgl.glVertex3f(-1.0, 0.5, -0.4);
    tgl.glVertex3f(-1.0, 0.5, 0.4);
    tgl.glEnd();

    tgl.glEndList();

    return list;
}

fn reshape(width: c_int, height: c_int) void {
    const h: tgl.GLfloat = @as(tgl.GLfloat, @floatFromInt(height)) / @as(tgl.GLfloat, @floatFromInt(width));

    tgl.glViewport(0, 0, @intCast(width), @intCast(height));
    tgl.glMatrixMode(tgl.GL_PROJECTION);
    tgl.glLoadIdentity();
    tgl.glFrustum(-1.0, 1.0, -h, h, 5.0, 60.0);
    tgl.glMatrixMode(tgl.GL_MODELVIEW);
    tgl.glLoadIdentity();
    tgl.glTranslatef(0.0, 0.0, -40.0);
    tgl.glClear(tgl.GL_COLOR_BUFFER_BIT | tgl.GL_DEPTH_BUFFER_BIT);
}

pub fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = message_level;
    _ = scope;
    _ = console.print(format, args) catch 0;
}

pub const std_options: std.Options = .{
    .logFn = logFn,
};

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = ret_addr;
    _ = trace;
    @setCold(true);
    _ = console.print("PANIC: {s}", .{msg}) catch 0;
    while (true) {}
}

extern fn getTimeUs() u32;

pub fn millis() u32 {
    return (getTimeUs() - startTime) / 1000;
}

var leftPressed: bool = false;
var rightPressed: bool = false;
var upPressed: bool = false;
var downPressed: bool = false;

export fn keyevent(keycode: u32, down: bool) void {
    switch (keycode) {
        37 => leftPressed = down,
        38 => upPressed = down,
        39 => rightPressed = down,
        40 => downPressed = down,
        else => {},
    }
}

export fn getGfxBufPtr() [*]u8 {
    return @ptrCast(&gfxFramebuffer);
}

export fn setSampleRate(s: f32) void {
    sampleRate = s;
}

export fn getLeftBufPtr() [*]u8 {
    return @ptrCast(&mix_left);
}

export fn getRightBufPtr() [*]u8 {
    return @ptrCast(&mix_right);
}

export fn renderSoundQuantum() void {}

fn consoleWriteFn(data:[]const u8) void {
    _ = console.print("{s}", .{data}) catch 0;
}

export fn init() void {
    startTime = getTimeUs();
    frameCount = 0;

    // init zepto with a memory allocator and console writer
    zeptolibc.init(allocator, consoleWriteFn);

    const zb: *tgl.ZBuffer = tgl.ZB_open(WIDTH, HEIGHT, tgl.ZB_MODE_RGBA, 0, 0, 0, &gfxFramebuffer);
    tgl.glInit(zb);

    const glCtx: *tgl.GLContext = tgl.gl_get_context();
    glCtx.zb = zb;

    reshape(WIDTH, HEIGHT);

    tgl.glLightfv(tgl.GL_LIGHT0, tgl.GL_POSITION, &pos);
    tgl.glEnable(tgl.GL_CULL_FACE);
    tgl.glEnable(tgl.GL_LIGHTING);
    tgl.glEnable(tgl.GL_LIGHT0);
    tgl.glEnable(tgl.GL_DEPTH_TEST);

    // make the gears
    gear1 = tgl.glGenLists(1);
    tgl.glNewList(gear1, tgl.GL_COMPILE);
    tgl.glMaterialfv(tgl.GL_FRONT, tgl.GL_AMBIENT_AND_DIFFUSE, &red);
    gear(1.0, 4.0, 1.0, 20, 0.7);
    tgl.glEndList();

    gear2 = tgl.glGenLists(1);
    tgl.glNewList(gear2, tgl.GL_COMPILE);
    tgl.glMaterialfv(tgl.GL_FRONT, tgl.GL_AMBIENT_AND_DIFFUSE, &green);
    gear(0.5, 2.0, 2.0, 10, 0.7);
    tgl.glEndList();

    gear3 = tgl.glGenLists(1);
    tgl.glNewList(gear3, tgl.GL_COMPILE);
    tgl.glMaterialfv(tgl.GL_FRONT, tgl.GL_AMBIENT_AND_DIFFUSE, &blue);
    gear(1.3, 2.0, 0.5, 10, 0.7);
    tgl.glEndList();

    tgl.glEnable(tgl.GL_NORMALIZE);
}

export fn update(deltaMs: u32) void {
    _ = deltaMs;

    if (leftPressed) {
        view_roty += 5.0;
    }
    if (rightPressed) {
        view_roty -= 5.0;
    }
    if (upPressed) {
        view_rotx += 5.0;
    }
    if (downPressed) {
        view_rotx -= 5.0;
    }

    angle += 2.0;
}

var lastTime: u32 = 0;
var lastFPSTime: u32 = 0;
var frameCount: usize = 0;

fn printFPS() void {
    if (millis() > lastFPSTime + 1000) {
        _ = console.print("FPS {d}\n", .{frameCount / (millis() / 1000)}) catch 0;
        lastFPSTime = millis();
    }
    frameCount +%= 1;
    lastTime = millis();
}

export fn renderGfx() void {
    tgl.glClear(tgl.GL_COLOR_BUFFER_BIT | tgl.GL_DEPTH_BUFFER_BIT);

    tgl.glPushMatrix();
    tgl.glRotatef(view_rotx, 1.0, 0.0, 0.0);
    tgl.glRotatef(view_roty, 0.0, 1.0, 0.0);
    tgl.glRotatef(view_rotz, 0.0, 0.0, 1.0);

    tgl.glPushMatrix();
    tgl.glTranslatef(-3.0, -2.0, 0.0);
    tgl.glRotatef(angle, 0.0, 0.0, 1.0);
    tgl.glCallList(gear1);
    tgl.glPopMatrix();

    tgl.glPushMatrix();
    tgl.glTranslatef(3.1, -2.0, 0.0);
    tgl.glRotatef(-2.0 * angle - 9.0, 0.0, 0.0, 1.0);
    tgl.glCallList(gear2);
    tgl.glPopMatrix();

    tgl.glPushMatrix();
    tgl.glTranslatef(-3.1, 4.2, 0.0);
    tgl.glRotatef(-2.0 * angle - 25.0, 0.0, 0.0, 1.0);
    tgl.glCallList(gear3);
    tgl.glPopMatrix();

    tgl.glPopMatrix();

    printFPS();
}
