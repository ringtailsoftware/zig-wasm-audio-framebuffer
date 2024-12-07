const std = @import("std");
const console = @import("console.zig").getWriter().writer();

// Extract an asciinema .cast file, each line is a complete JSON array with 3 elements
// calling getData() repeatedly will give each line as the timestamps dictate

pub const CastPlayerStep = struct {
    t: f64,
    s: []u8,
};

pub const CastPlayer = struct {
    const Self = @This();

    vals:std.ArrayList(CastPlayerStep),
    startTime:?u32,
    dataIndex:usize,

    // assume it's available forever
    pub fn init(allocator: std.mem.Allocator, lineData:[]const u8) !Self {

        var vals = std.ArrayList(CastPlayerStep).init(allocator);
        var fbs = std.io.fixedBufferStream(lineData);
        var br = std.io.bufferedReader(fbs.reader());
        var r = br.reader();

        while(true) {
            var msg_buf: [4096]u8 = undefined;
            const msg = r.readUntilDelimiterOrEof(&msg_buf, '\n');

            if (msg) |m| {
                if (m) |jsonline| {
                    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, jsonline, .{});
                    defer parsed.deinit();

                    switch(parsed.value) {
                        .array => |arr| {
                            var step:CastPlayerStep = undefined;


                            if (arr.items.len == 3) {
                                switch(arr.items[0]) {
                                    .float => |f| step.t = f,
                                    else => step.t = 0,
                                }
                                switch(arr.items[2]) {
                                    .string => |s| step.s = try allocator.dupe(u8, s),
                                    else => {},
                                }

                                try vals.append(step);
                            }

                        },
                        else => {},
                    }
                } else {
                    break;
                }
            } else |err| {
                _ = console.print("err2 {any}\n", .{err}) catch 0;
                break;
            }
        }

        return Self {
            .vals = vals,
            .startTime = null,
            .dataIndex = 0,
        };
    }

    pub fn getData(self: *Self, timems:u32) ?[]const u8 {
        if (self.vals.items.len == 0) {
            return null;
        }


        if (self.startTime == null) {
            self.startTime = timems;
            self.dataIndex = 0;
        }

        if (self.dataIndex == self.vals.items.len) {   // completed
            return null;
        }

        const step = self.vals.items[self.dataIndex];
        if (timems >= self.startTime.? + @as(u32, @intFromFloat(step.t * 1000))) {
            self.dataIndex += 1;
            return step.s;
        } else {
            return null;
        }
    }
};


