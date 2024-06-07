export fn rgb2yuv (color: [*]u8) void {
    const t = [_]u8{
        @as(u8, @intFromFloat(0.299 * @as(f32, @floatFromInt(color[0])) +
                       0.587 * @as(f32, @floatFromInt(color[1])) +
                       0.114 * @as(f32, @floatFromInt(color[2])))),
        @as(u8, @intFromFloat(-0.168736 * @as(f32, @floatFromInt(color[0])) +
                       -0.331264 * @as(f32, @floatFromInt(color[1])) +
                             0.5 * @as(f32, @floatFromInt(color[2])) + 128.0)),
        @as(u8, @intFromFloat(      0.5 * @as(f32, @floatFromInt(color[0])) +
                       -0.418688 * @as(f32, @floatFromInt(color[1])) +
                       -0.081312 * @as(f32, @floatFromInt(color[2])) + 128.0)),
    };

    color[0] = t[0];
    color[1] = t[1];
    color[2] = t[2];
}
