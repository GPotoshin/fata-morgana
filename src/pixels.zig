const std = @import("std");
const FMVideo = @import("essence.zig").FMVideo;
const print = std.debug.print;
const c = @cImport({
    @cInclude("png.h");
});
const maths = @import("maths.zig");

pub fn place_pixel_art (v: FMVideo, pos_x: u32, pos_y: u32, name: [*c]u8,
    scale: i32, duration: f32) void {
    const allocator = v.arena.allocator();
    const sig_read: u32 = 0;
    _ = sig_read;
    _ = pos_x;
    _ = pos_y;
    _ = scale;
    _ = name;
    _ = duration;
    const width: u32 = undefined;
    const height: u32 = undefined;
    const bit_depth: i32 = undefined;
    const color_type: i32 = undefined;
    const interlace_type: i32 = undefined;

    const file = std.fs.openFileAbsolute("/Users/giorno/projects/fata-morgana/arts/professor.png",
        .{}) catch {
        print("File not found\n");
    };
    defer file.close();

    const png_ptr = c.png_create_read_struct(c.PNG_LIBPNG_VER_STRING, null,
        null, null);
    if (png_ptr == null) return;
    defer c.png_destroy_read_struct(&png_ptr, null, null);

    const info_ptr = c.png_create_info_struct(png_ptr);
    if (info_ptr == null) return;
    defer c.png_destroy_info_struct(png_ptr, &info_ptr);

    c.png_read_info(png_ptr, info_ptr);
    c.png_get_IHDR(png_ptr, info_ptr, &width, &height, &bit_depth, &color_type,
       &interlace_type, null, null);
    // where data will be read from png file
    // no opacity
    const row_pointers = allocator.alloc(*u8, height) catch {
        print ("can't allocate raw pointers");
        return;
    };
    defer allocator.free(row_pointers);
    for (0..height) |y| {
        row_pointers[y] = allocator.alloc(*u8,
            c.png_get_rowbytes(png_ptr, info_ptr));
    }

    c.png_read_image(png_ptr, row_pointers);

    // const num: f32 = @floatFromInt(v.ctx.framerate.num);
    // const den: f32 = @floatFromInt(v.ctx.framerate.den);
    // const nframes: i32 = @intFromFloat(duration * num / den);

    // converting rgb to yuv
    // add SIMD here one day

    for (0..height) |y| {
        const row = row_pointers[y];
        for (0..width) |x| {
            const px = row + x*4;
            const r: f32 = @floatFromInt(px[0]);
            const g: f32 = @floatFromInt(px[1]);
            const b: f32 = @floatFromInt(px[2]);
            const yr = 0.299*r + 0.587*g + 0.114*b; 
            const ur = -0.168736*r - 0.331264*g + 0.5*b + 128.0;
            const vr = 0.5*r - 0.418688*g - 0.081312*b + 128.0;
            px[0] = @intCast(@as(i32, @intFromFloat(yr)));
            px[1] = @intCast(@as(i32, @intFromFloat(ur)));
            px[2] = @intCast(@as(i32, @intFromFloat(vr)));
        }
    }

     const linesize = v.frame.linesize;
    for (0..@as(u32, @bitCast(nframes))) |n_frame| {
        // do not forget to use scale
        for (0..width) |y| {
            const row = row_pointers[y];
            for (0..height) |x| {
                const px = row + x*4;
                for (0..scale) |shift_y| {
                    for (0..scale) |shift_x| {
                        v.frame.data[0][(pos_y+y*scale+shift_y)*linesize[0] +
                            pos_x+x*scale+shift_x] = px[0];
                        v.frame.data[1][(pos_y+y*scale+shift_y)/2*linesize[1] +
                            (pos_x+x*scale+shift_x)/2] = px[1];
                        v.frame.data[2][(pos_y+y*scale+shift_y)/2*linesize[2] +
                            (pos_x+x*scale+shift_x)/2] = px[2];
                    }
                }
            }
        }
    }
}

test "png" {
    _ = try std.fs.openFileAbsolute("/Users/giorno/projects/fata-morgana/arts/professor.png",
        .{});
}
