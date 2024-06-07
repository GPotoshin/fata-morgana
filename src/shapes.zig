const std = @import("std");
const FMVideo = @import("essence.zig").FMVideo;
const maths = @import("maths.zig");

export fn circle (v: *FMVideo, pf: [*c]f32, co: [*c]u8, r: i32, w: i32, t: f32, duration: f32) void {
    const p: [2]i32 = .{@intFromFloat((pf[0]+1.0)*@as(f32, @floatFromInt(v.ctx.width))/2.0),
                        @intFromFloat((1.0-pf[1])*@as(f32, @floatFromInt(v.ctx.height))/2.0)};
    const num: f32 = @floatFromInt(v.ctx.framerate.num);
    const den: f32 = @floatFromInt(v.ctx.framerate.den);
    const nframes: f32 = duration * num / den;
    const curframe: f32 = t * num / den;
    const linesize = v.frame.linesize;
    const height = v.ctx.height;
    const width = v.ctx.width;

    var bgc: [3]u8 = undefined;
    const curangle: f32 = 2.0 * curframe * std.math.pi / nframes;
    const x_min: usize = @bitCast(@as(i64, maths.max(p[0]-r-w, 0)));
    const x_max: usize = @bitCast(@as(i64, maths.min(width, p[0]+r+w+1)));
    const y_min: usize = @bitCast(@as(i64, maths.max(p[1]-r-w, 0)));
    const y_max: usize = @bitCast(@as(i64, maths.min(height, p[1]+r+w)));
    for (x_min..x_max) |x| {
        for (y_min..y_max) |y| {
            var sm = [3]f32{0, 0, 0};
            var out_counter: u8 = 0;
            const linesize_u: [3]usize = .{
                @as(usize, @bitCast(@as(i64, linesize[0]))),
                @as(usize, @bitCast(@as(i64, linesize[1]))),
                @as(usize, @bitCast(@as(i64, linesize[2]))),
            };
            bgc[0] = v.frame.data[0][y * linesize_u[0] + x];
            bgc[1] = v.frame.data[1][y/2 * linesize_u[1] + x/2];
            bgc[2] = v.frame.data[2][y/2 * linesize_u[2] + x/2];

            const x_f: f32 = @floatFromInt(x);
            const y_f: f32 = @floatFromInt(y);
            const p_f: [2]f32 = .{@floatFromInt(p[0]), @floatFromInt(p[1])};
            const inner_r: f32 = @floatFromInt((r-w)*(r-w));
            const outer_r: f32 = @floatFromInt((r+w)*(r+w));

            const co_f: [3]f32 = .{
                @floatFromInt(co[0]),
                @floatFromInt(co[1]),
                @floatFromInt(co[2]),
            };
            const bgc_f: [3]f32 = .{
                @floatFromInt(bgc[0]),
                @floatFromInt(bgc[1]),
                @floatFromInt(bgc[2]),
            };

            if (maths.hypsq (x_f+0.25-p_f[0], y_f+0.125-p_f[1]) >= inner_r and
                maths.hypsq (x_f+0.25-p_f[0], y_f+0.125-p_f[1]) <= outer_r and
                maths.vector_angle (x_f+0.25-p_f[0], y_f+0.125-p_f[1]) <= curangle) {
                sm[0] += 0.25 * co_f[0];
                sm[1] += 0.25 * co_f[1];
                sm[2] += 0.25 * co_f[2];
            } else {
                out_counter += 1;
                sm[0] += 0.25 * bgc_f[0];
                sm[1] += 0.25 * bgc_f[1];
                sm[2] += 0.25 * bgc_f[2];
            }
            if (maths.hypsq (x_f+0.125-p_f[0], y_f+0.75-p_f[1]) >= inner_r and
                maths.hypsq (x_f+0.125-p_f[0], y_f+0.75-p_f[1]) <= outer_r and
                maths.vector_angle (x_f+0.125-p_f[0], y_f+0.75-p_f[1]) <= curangle) {
                sm[0] += 0.25 * co_f[0];
                sm[1] += 0.25 * co_f[1];
                sm[2] += 0.25 * co_f[2];
            } else {
                out_counter += 1;
                sm[0] += 0.25 * bgc_f[0];
                sm[1] += 0.25 * bgc_f[1];
                sm[2] += 0.25 * bgc_f[2];
            }
            if (maths.hypsq (x_f+0.75-p_f[0], y_f+0.825-p_f[1]) >= inner_r and
                maths.hypsq (x_f+0.75-p_f[0], y_f+0.825-p_f[1]) <= outer_r and
                maths.vector_angle (x_f+0.75-p_f[0], y_f+0.825-p_f[1]) <= curangle) {
                sm[0] += 0.25 * co_f[0];
                sm[1] += 0.25 * co_f[1];
                sm[2] += 0.25 * co_f[2];
            } else {
                out_counter += 1;
                sm[0] += 0.25 * bgc_f[0];
                sm[1] += 0.25 * bgc_f[1];
                sm[2] += 0.25 * bgc_f[2];
            }
            if (maths.hypsq (x_f+0.875-p_f[0], y_f+0.25-p_f[1]) >= inner_r and
                maths.hypsq (x_f+0.875-p_f[0], y_f+0.25-p_f[1]) <= outer_r and
                maths.vector_angle (x_f+0.875-p_f[0], y_f+0.25-p_f[1]) <= curangle) { 
                sm[0] += 0.25 * co_f[0];
                sm[1] += 0.25 * co_f[1];
                sm[2] += 0.25 * co_f[2];
            } else {
                out_counter += 1;
                sm[0] += 0.25 * bgc_f[0];
                sm[1] += 0.25 * bgc_f[1];
                sm[2] += 0.25 * bgc_f[2];
            }
            if (out_counter == 4) {
                continue;
            }
            
            v.frame.data[0][y * linesize_u[0] + x] = @as(u8, @intFromFloat(sm[0]));
            if ((x&1)==0 and (y&1)==0) {
                v.frame.data[1][y/2 * linesize_u[1] + x/2] = @as(u8, @intFromFloat(sm[1]));
                v.frame.data[2][y/2 * linesize_u[2] + x/2] = @as(u8, @intFromFloat(sm[2]));
            }
        }
    }
}

export fn paint_background (v: *FMVideo, bgc: [*c]u8) void {
    const linesize = v.frame.linesize;
    const data = v.frame.data;
    const width: usize = @bitCast(@as(i64, v.ctx.width));
    const height: usize = @bitCast(@as(i64, v.ctx.height));
    const linesize_u: [3]usize = .{
        @as(usize, @bitCast(@as(i64, linesize[0]))),
        @as(usize, @bitCast(@as(i64, linesize[1]))),
        @as(usize, @bitCast(@as(i64, linesize[2]))),
    };
    for (0..height) |y| {
        for (0..width) |x| {
            data[0][y*linesize_u[0] + x] = bgc[0];
            data[1][y/2*linesize_u[1] + x/2] = bgc[1];
            data[2][y/2*linesize_u[2] + x/2] = bgc[2];
        }
    }
}

