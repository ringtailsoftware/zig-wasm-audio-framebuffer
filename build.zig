const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    b.installFile("src/index.html", "index.html");
    b.installFile("src/pcm-processor.js", "pcm-processor.js");
    b.installFile("src/wasmpcm.js", "wasmpcm.js");
    b.installFile("src/ringbuf.js", "ringbuf.js");
    b.installFile("src/coi-serviceworker.js", "coi-serviceworker.js");

    const sinetoneLib = b.addSharedLibrary("sinetone", "src/sinetone.zig", .unversioned);
    sinetoneLib.setTarget(.{.cpu_arch = .wasm32, .os_tag = .freestanding});
    sinetoneLib.rdynamic = true;
    sinetoneLib.setBuildMode(mode);
    sinetoneLib.install();
    b.installFile("src/sinetone.html", "sinetone.html");


}
