const std = @import("std");

fn addExample(b: *std.build.Builder, comptime name: []const u8, flags: ?[]const []const u8, sources: ?[]const []const u8) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addSharedLibrary(name, "src/" ++ name ++ "/" ++ name ++ ".zig", .unversioned);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.rdynamic = true;
    lib.setBuildMode(mode);
    lib.install();
    lib.addIncludePath("src/" ++ name);

    if (flags != null and sources != null) {
        lib.addCSourceFiles(sources.?, flags.?);
    }

    b.installFile("src/" ++ name ++ "/" ++ name ++ ".html", name ++ ".html");
}

pub fn build(b: *std.build.Builder) void {
    b.installFile("src/index.html", "index.html");
    b.installFile("src/pcm-processor.js", "pcm-processor.js");
    b.installFile("src/wasmpcm.js", "wasmpcm.js");
    b.installFile("src/ringbuf.js", "ringbuf.js");
    b.installFile("src/coi-serviceworker.js", "coi-serviceworker.js");

    addExample(b, "sinetone", null, null);
    addExample(b, "synth", null, null);
    addExample(b, "mod", &.{"-Wall"}, &.{"src/mod/pocketmod.c"});
}
