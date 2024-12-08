const std = @import("std");

var optimize:std.builtin.OptimizeMode = undefined;
var target:std.Build.ResolvedTarget = undefined;

pub fn addAssetsOption(b: *std.Build, exe:anytype, assetpath:[]const u8) !void {
    var options = b.addOptions();

    var files = std.ArrayList([]const u8).init(b.allocator);
    defer files.deinit();

    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const path = try std.fs.cwd().realpath(assetpath, buf[0..]);

    var dir = try std.fs.openDirAbsolute(path, .{.iterate=true});
    var it = dir.iterate();
    while (try it.next()) |file| {
        if (file.kind != .file) {
            continue;
        }
        try files.append(b.dupe(file.name));
    }
    options.addOption([]const []const u8, "files", files.items);
    exe.step.dependOn(&options.step);

    const assets = b.addModule("assets", .{
        .root_source_file = options.getSource(),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("assets", assets);
}

fn addExample(b: *std.Build, comptime name: []const u8, flags: ?[]const []const u8, sources: ?[]const []const u8, includes: ?[]const []const u8) !void {
    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = b.path("src/" ++ name ++ "/" ++ name ++ ".zig"),
        .target = target,
        .optimize = optimize,
        .strip = false,
    });
    exe.entry = .disabled;
    exe.rdynamic = true;
    exe.addIncludePath(b.path("src/" ++ name));

    if (includes != null) {
        for (includes.?) |inc| {
            exe.addIncludePath(b.path(inc));
        }
    }
    if (flags != null and sources != null) {
        exe.addCSourceFiles(.{ 
            .files = sources.?,
            .flags = flags.?,
        });
    }

    // add zeptolibc
    const zeptolibc_dep = b.dependency("zeptolibc", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zeptolibc", zeptolibc_dep.module("zeptolibc"));
    exe.root_module.addIncludePath(zeptolibc_dep.path("include"));
    exe.root_module.addIncludePath(zeptolibc_dep.path("include/zeptolibc"));

    // add zvterm for terminal example
    const zvterm_dep = b.dependency("zvterm", .{
        .target = target,
        .optimize = optimize,
    });
    var zvterm_mod = zvterm_dep.module("zvterm");
    zvterm_mod.addIncludePath(zeptolibc_dep.path("include"));
    zvterm_mod.addIncludePath(zeptolibc_dep.path("include/zeptolibc"));
    exe.root_module.addImport("zvterm", zvterm_mod);

    // add mibu for zigtris event generation
    const mibu = b.dependency("mibu", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("mibu", mibu.module("mibu"));

    // add zigtris for terminal example
    const zigtris = b.dependency("zigtris", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zigtris", zigtris.module("zigtris"));

    exe.addIncludePath(b.path("src/"));

    b.installFile("src/" ++ name ++ "/" ++ name ++ ".html", name ++ ".html");

    // if assets dir exists in project, add @embedFile everything in it
    if (std.fs.cwd().statFile("src/" ++ name ++ "/assets")) |stat| {
        switch(stat.kind) {
            .directory => try addAssetsOption(b, exe, "src/" ++ name ++ "/assets"),
            else => return error.AssetsDirectoryIsAFile,
        }
    } else |err| switch(err) {
        else => {},
    }

    b.installArtifact(exe);
}

pub fn build(b: *std.Build) !void {
    const hosttarget = b.standardTargetOptions(.{});
    optimize = b.standardOptimizeOption(.{});
    target = b.resolveTargetQuery(std.zig.CrossTarget.parse(
            .{ .arch_os_abi = "wasm32-freestanding" },
    ) catch unreachable);

    b.installFile("src/index.html", "index.html");
    b.installFile("src/pcm-processor.js", "pcm-processor.js");
    b.installFile("src/wasmpcm.js", "wasmpcm.js");
    b.installFile("src/ringbuf.js", "ringbuf.js");
    b.installFile("src/coi-serviceworker.js", "coi-serviceworker.js");
    b.installFile("src/unmute.js", "unmute.js");

    try addExample(b, "terminal", &.{"-Wall", "-fno-sanitize=undefined"},&.{
        "src/terminal/olive.c/olive.c",
        "src/terminal/stb_truetype.c"},
    null);

    try addExample(b, "agnes", &.{"-Wall", "-fno-sanitize=undefined"}, &.{"src/agnes/agnes.c"}, null);

    try addExample(b, "sinetone", null, null, null);

    try addExample(b, "synth", null, null, null);

    try addExample(b, "mod", &.{"-Wall"}, &.{"src/mod/pocketmod.c"}, null);

    try addExample(b, "bat", &.{"-Wall"}, &.{"src/mod/pocketmod.c"}, null);

    try addExample(b, "doom", &.{ "-Wall", "-fno-sanitize=undefined" }, &.{
        "src/doom/puredoom/DOOM.c",     "src/doom/puredoom/PureDOOM.c", "src/doom/puredoom/am_map.c",
        "src/doom/puredoom/d_items.c",  "src/doom/puredoom/d_main.c",   "src/doom/puredoom/d_net.c",
        "src/doom/puredoom/doomdef.c",  "src/doom/puredoom/doomstat.c", "src/doom/puredoom/dstrings.c",
        "src/doom/puredoom/f_finale.c", "src/doom/puredoom/f_wipe.c",   "src/doom/puredoom/g_game.c",
        "src/doom/puredoom/hu_lib.c",   "src/doom/puredoom/hu_stuff.c", "src/doom/puredoom/i_net.c",
        "src/doom/puredoom/i_sound.c",  "src/doom/puredoom/i_system.c", "src/doom/puredoom/i_video.c",
        "src/doom/puredoom/info.c",     "src/doom/puredoom/m_argv.c",   "src/doom/puredoom/m_bbox.c",
        "src/doom/puredoom/m_cheat.c",  "src/doom/puredoom/m_fixed.c",  "src/doom/puredoom/m_menu.c",
        "src/doom/puredoom/m_misc.c",   "src/doom/puredoom/m_random.c", "src/doom/puredoom/m_swap.c",
        "src/doom/puredoom/p_ceilng.c", "src/doom/puredoom/p_doors.c",  "src/doom/puredoom/p_enemy.c",
        "src/doom/puredoom/p_floor.c",  "src/doom/puredoom/p_inter.c",  "src/doom/puredoom/p_lights.c",
        "src/doom/puredoom/p_map.c",    "src/doom/puredoom/p_maputl.c", "src/doom/puredoom/p_mobj.c",
        "src/doom/puredoom/p_plats.c",  "src/doom/puredoom/p_pspr.c",   "src/doom/puredoom/p_saveg.c",
        "src/doom/puredoom/p_setup.c",  "src/doom/puredoom/p_sight.c",  "src/doom/puredoom/p_spec.c",
        "src/doom/puredoom/p_switch.c", "src/doom/puredoom/p_telept.c", "src/doom/puredoom/p_tick.c",
        "src/doom/puredoom/p_user.c",   "src/doom/puredoom/r_bsp.c",    "src/doom/puredoom/r_data.c",
        "src/doom/puredoom/r_draw.c",   "src/doom/puredoom/r_main.c",   "src/doom/puredoom/r_plane.c",
        "src/doom/puredoom/r_segs.c",   "src/doom/puredoom/r_sky.c",    "src/doom/puredoom/r_things.c",
        "src/doom/puredoom/s_sound.c",  "src/doom/puredoom/sounds.c",   "src/doom/puredoom/st_lib.c",
        "src/doom/puredoom/st_stuff.c", "src/doom/puredoom/tables.c",   "src/doom/puredoom/v_video.c",
        "src/doom/puredoom/w_wad.c",    "src/doom/puredoom/wi_stuff.c", "src/doom/puredoom/z_zone.c",
    }, null);


    try addExample(b, "tinygl", &.{ "-Wall", "-fno-sanitize=undefined" }, &.{
        "src/tinygl/TinyGL/src/api.c",     "src/tinygl/TinyGL/src/specbuf.c",     "src/tinygl/TinyGL/src/zmath.c",
        "src/tinygl/TinyGL/src/arrays.c",  "src/tinygl/TinyGL/src/image_util.c",  "src/tinygl/TinyGL/src/misc.c",
        "src/tinygl/TinyGL/src/texture.c", "src/tinygl/TinyGL/src/ztriangle.c",   "src/tinygl/TinyGL/src/clear.c",
        "src/tinygl/TinyGL/src/init.c",    "src/tinygl/TinyGL/src/msghandling.c", "src/tinygl/TinyGL/src/vertex.c",
        "src/tinygl/TinyGL/src/clip.c",    "src/tinygl/TinyGL/src/light.c",       "src/tinygl/TinyGL/src/zbuffer.c",
        "src/tinygl/TinyGL/src/error.c",   "src/tinygl/TinyGL/src/list.c",        "src/tinygl/TinyGL/src/zdither.c",
        "src/tinygl/TinyGL/src/get.c",     "src/tinygl/TinyGL/src/matrix.c",      "src/tinygl/TinyGL/src/select.c",
        "src/tinygl/TinyGL/src/zline.c",
    }, &.{
        "src/tinygl/TinyGL/include", "src/tinygl/TinyGL/src",
    });

    try addExample(b, "mandelbrot", null, null, null);

    try addExample(b, "olive", &.{"-Wall"}, &.{"src/olive/olive.c/olive.c"}, null);

    // web server
    const serve_exe = b.addExecutable(.{
        .name = "serve",
        .root_source_file = b.path("httpserver/serve.zig"),
        .target = hosttarget,
        .optimize = optimize,
    });

    const mod_server = b.addModule("StaticHttpFileServer", .{
        .root_source_file = b.path("httpserver/root.zig"),
        .target = hosttarget,
        .optimize = optimize,
    });

    mod_server.addImport("mime", b.dependency("mime", .{
        .target = hosttarget,
        .optimize = optimize,
    }).module("mime"));

    serve_exe.root_module.addImport("StaticHttpFileServer", mod_server);

    const run_serve_exe = b.addRunArtifact(serve_exe);
    if (b.args) |args| run_serve_exe.addArgs(args);

    const serve_step = b.step("serve", "Serve a directory of files");
    serve_step.dependOn(&run_serve_exe.step);

}
