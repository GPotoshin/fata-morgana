const std = @import("std");
const FMVideo = @import("essence.zig").FMVideo;
const print = std.debug.print;
const c = @cImport({
    @cInclude("stdio.h");
});
const png = @import("c/png.zig");
const maths = @import("maths.zig");

export fn place_pixel_art (v: *FMVideo, pos_xf: f32, pos_yf: f32, name: [*c]u8,
    scale: u32) void {
    const fw: f32 = @floatFromInt(v.codec_ctx.width);
    const fh: f32 = @floatFromInt(v.codec_ctx.height);
    const pos_x: u32 = @bitCast(@as(i32, @intFromFloat((pos_xf+1)*fw/2.0)));
    const pos_y: u32 = @bitCast(@as(i32, @intFromFloat((1-pos_yf)*fh/2.0)));

    const allocator = v.allocator;
    var width: u32 = undefined;
    var height: u32 = undefined;
    var bit_depth: i32 = undefined;
    var color_type: i32 = undefined;
    var interlace_type: i32 = undefined;

    // print("opening file\n", .{});
    const file = c.fopen(name, "r");
    if (file == null) {
        print("can't open the file", .{});
        return;
    }
    defer _ = c.fclose(file);

    // print("creating read structure\n", .{});
    var png_ptr = png.png_create_read_struct(png.PNG_LIBPNG_VER_STRING, null,
        null, null);
    if (png_ptr == null) return;
    defer png.png_destroy_read_struct(&png_ptr, null, null);

    // print("creating info structure\n", .{});
    var info_ptr = png.png_create_info_struct(png_ptr);
    if (info_ptr == null) return;
    defer png.png_destroy_info_struct(png_ptr, &info_ptr);

    png.png_init_io(png_ptr, @ptrCast(file));

    // print("reading info\n", .{});
    png.png_read_info(png_ptr, info_ptr);
    // print("getting IHDR\n", .{});
    _ = png.png_get_IHDR(png_ptr, info_ptr, &width, &height, &bit_depth, &color_type,
       &interlace_type, null, null);
    // where data will be read from png file
    // no opacity
    // print("allocating row pointers\n", .{});
    const row_pointers = allocator.alloc([*c]u8, height) catch {
        print ("can't allocate raw pointers\n", .{});
        return;
    };
    defer allocator.free(row_pointers);
    for (0..height) |y| {
        const array = allocator.alloc(u8, width*4) catch {
            print("can't allocate a row", .{});
            return;
        };
        row_pointers[y] = array.ptr; 
    }
    
    // print("reading_image\n", .{});
    png.png_read_image(png_ptr, row_pointers.ptr);

    // const num: f32 = @floatFromInt(v.ctx.framerate.num);
    // const den: f32 = @floatFromInt(v.ctx.framerate.den);
    // const nframes: i32 = @intFromFloat(duration * num / den);

    // converting rgb to yuv
    // add SIMD here one day


    // print("converting rgb to yuv\n", .{});
    for (0..height) |y| {
        const row = row_pointers[y];
        for (0..width) |x| {
            const px = row[x*4..(x+1)*4];
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

    const linesize = [3]u32{
        @intCast(v.frame.linesize[0]),
        @intCast(v.frame.linesize[1]),
        @intCast(v.frame.linesize[2]),
    };
    // print("writing image to the screen\n", .{});
    for (0..width) |y| {
         const row = row_pointers[y];
         for (0..height) |x| {
             const px = row[x*4..(x+1)*4];
             const yr: f32 = @floatFromInt(px[0]);
             const ur: f32 = @floatFromInt(px[1]);
             const vr: f32 = @floatFromInt(px[2]);
             const a: f32 = @as(f32, @floatFromInt(px[3]))/255.0;
             for (0..scale) |shift_y| {
                 for (0..scale) |shift_x| {
                     const data_r: f32 = @floatFromInt(v.frame.data[0][(pos_y+y*scale+shift_y)*linesize[0] +
                         pos_x+x*scale+shift_x]);
                     const data_g: f32 = @floatFromInt(v.frame.data[1][(pos_y+y*scale+shift_y)/2*linesize[1] +
                         (pos_x+x*scale+shift_x)/2]);
                     const data_b: f32 = @floatFromInt(v.frame.data[2][(pos_y+y*scale+shift_y)/2*linesize[2] +
                         (pos_x+x*scale+shift_x)/2]);
                    v.frame.data[0][(pos_y+y*scale+shift_y)*linesize[0] +
                         pos_x+x*scale+shift_x] = @truncate(@as(u32,@bitCast(@as(i32, @intFromFloat(
                                             yr*a+data_r*(1-a))))));
                    if (@mod(pos_y+y*scale+shift_y, 2) == 0 and
                        @mod(pos_x+x*scale+shift_x, 2) == 0) {
                        v.frame.data[1][(pos_y+y*scale+shift_y)/2*linesize[1] +
                            (pos_x+x*scale+shift_x)/2] = @truncate(@as(u32,@bitCast(@as(i32, @intFromFloat(
                                                ur*a+data_g*(1-a))))));
                        v.frame.data[2][(pos_y+y*scale+shift_y)/2*linesize[2] +
                            (pos_x+x*scale+shift_x)/2] = @truncate(@as(u32, @bitCast(@as(i32, @intFromFloat
                                            (vr*a+data_b*(1-a))))));
                    }
                 }
             }
         }
     }
}
