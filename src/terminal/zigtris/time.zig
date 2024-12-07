const std = @import("std");

var firstTime = true;
var toff: i128 = 0;
pub fn getTimeUs() u32 {
    if (firstTime) {
        firstTime = false;
        toff = std.time.nanoTimestamp();
    }
    return @intCast(@mod(@divTrunc(std.time.nanoTimestamp() - toff, 1000), std.math.maxInt(u32)));
}

var startTime: u32 = 0;

pub fn initTime() void {
    startTime = getTimeUs();
}

pub fn millis() u32 {
    return (getTimeUs() - startTime) / 1000;
}
