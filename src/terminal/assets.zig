const std = @import("std");
const assets = @import("assets");

const EmbeddedAsset = struct {
    []const u8,
    []const u8,
};

pub const Assets = struct {
    pub const ASSET_MAP = std.StaticStringMap([]const u8).initComptime(genMap());
};

fn genMap() [assets.files.len]EmbeddedAsset {
    var eas: [assets.files.len]EmbeddedAsset = undefined;
    comptime var i = 0;

    inline for (assets.files) |file| {
        eas[i][0] = file;
        eas[i][1] = @embedFile("assets/" ++ file);
        i = i + 1;
    }
    return eas;
}


