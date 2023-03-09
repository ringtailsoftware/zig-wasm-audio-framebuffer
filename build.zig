const std = @import("std");

fn addExample(b: *std.build.Builder, comptime name: []const u8, flags: ?[]const []const u8, sources: ?[]const []const u8) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addSharedLibrary(name, "src/" ++ name ++ "/" ++ name ++ ".zig", .unversioned);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.rdynamic = true;
    lib.setBuildMode(mode);
    lib.strip = false;
    lib.install();
    lib.addIncludePath("src/" ++ name);

    if (flags != null and sources != null) {
        lib.addCSourceFiles(sources.?, flags.?);
    }

    b.installFile("src/" ++ name ++ "/" ++ name ++ ".html", name ++ ".html");
}

//fn addNativeDebugExample(b: *std.build.Builder, comptime name: []const u8, flags: ?[]const []const u8, sources: ?[]const []const u8) void {
//    const target = b.standardTargetOptions(.{});
//    const mode = b.standardReleaseOptions();
//    const exe = b.addExecutable(name, "src/" ++ name ++ "/" ++ name ++ ".zig");
//    exe.setTarget(target);
//    exe.setBuildMode(mode);
//    exe.strip = false;
//    exe.install();
//    exe.addIncludePath("src/" ++ name);
//
//    if (flags != null and sources != null) {
//        exe.addCSourceFiles(sources.?, flags.?);
//    }
//}

pub fn build(b: *std.build.Builder) void {
    b.installFile("src/index.html", "index.html");
    b.installFile("src/pcm-processor.js", "pcm-processor.js");
    b.installFile("src/wasmpcm.js", "wasmpcm.js");
    b.installFile("src/ringbuf.js", "ringbuf.js");
    b.installFile("src/coi-serviceworker.js", "coi-serviceworker.js");
    b.installFile("src/unmute.js", "unmute.js");

    addExample(b, "sinetone", null, null);
    addExample(b, "synth", null, null);
    addExample(b, "mod", &.{"-Wall"}, &.{"src/mod/pocketmod.c"});
    addExample(b, "bat", &.{"-Wall"}, &.{"src/mod/pocketmod.c"});
    addExample(b, "doom", &.{"-Wall", "-fno-sanitize=undefined"}, &.{
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
    });
}
