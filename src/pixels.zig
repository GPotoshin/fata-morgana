const std = @import("std");
const FMVideo = @import("essence.zig").FMVideo;
const print = std.debug.print;
const png = @import("c/png.zig");
const maths = @import("maths.zig");
const gpa = &@import("essence.zig").gpa;

const c = @cImport({
    @cInclude("stdio.h");
});

const Image = struct {
    data: [*][*]u8,
    rows: u32,
    width: u32,
};

pub export fn open_image (allocator: *std.mem.Allocator, name: [*:0]const u8) *Image {
    var bit_depth: i32 = undefined;
    var color_type: i32 = undefined;
    var interlace_type: i32 = undefined;

    var retval = allocator.create(Image) catch {
        print("Out of memory for image!\n", .{});
        std.process.exit(1);
    };

    // to remove dependece on libc we need not to use ffmpg
    const file: *c.FILE = c.fopen(name, "r") orelse {
        print("Could not open a file\n", .{});
        std.process.exit(1);
    };
    defer _ = c.fclose(file);

    var png_ptr = png.png_create_read_struct(png.PNG_LIBPNG_VER_STRING, null,
        null, null);
    if (png_ptr == null) std.process.exit(1);
    defer png.png_destroy_read_struct(&png_ptr, null, null);

    // print("creating info structure\n", .{});
    var info_ptr = png.png_create_info_struct(png_ptr);
    if (info_ptr == null) std.process.exit(1);
    defer png.png_destroy_info_struct(png_ptr, &info_ptr);

    png.png_init_io(png_ptr, @ptrCast(file));

    png.png_read_info(png_ptr, info_ptr);
    _ = png.png_get_IHDR(png_ptr, info_ptr, &retval.width, &retval.rows, 
        &bit_depth, &color_type, &interlace_type, null, null);

    const row_pointers = allocator.alloc([*c]u8, retval.rows) catch {
        print ("can't allocate raw pointers\n", .{});
        std.process.exit(1);
    };
    errdefer allocator.free(row_pointers);
    for (0..retval.rows) |y| {
        const array = allocator.alloc(u8, retval.width*4) catch {
            print("can't allocate a row", .{});
            std.process.exit(1);
        };
        row_pointers[y] = array.ptr; 
    }

    // print("reading_image\n", .{});
    png.png_read_image(png_ptr, row_pointers.ptr);

    // converting rgb to yuv
    // add SIMD here one day
    for (0..retval.rows) |y| {
        const row = row_pointers[y];
        for (0..retval.width) |x| {
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

    retval.data = @ptrCast(row_pointers.ptr);
    return retval;
}

pub export fn place_pixel_art (v: ?*FMVideo, pos_xf: f32, pos_yf: f32, img: *Image,
    scale: u32) void {
    var state = v.?;
    const fw: f32 = @floatFromInt(state.codec_ctx.width);
    const fh: f32 = @floatFromInt(state.codec_ctx.height);
    const pos_x: u32 = @bitCast(@as(i32, @intFromFloat((pos_xf+1)*fw/2.0)));
    const pos_y: u32 = @bitCast(@as(i32, @intFromFloat((1-pos_yf)*fh/2.0)));

    const row_pointers = img.data;
    const width = img.width;
    const height = img.rows;

    const linesize = [3]u32{
        @intCast(state.frame.linesize[0]),
        @intCast(state.frame.linesize[1]),
        @intCast(state.frame.linesize[2]),
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
                    const data_r: f32 = @floatFromInt(state.frame.data[0][(pos_y+y*scale+shift_y)*linesize[0] +
                        pos_x+x*scale+shift_x]);
                    const data_g: f32 = @floatFromInt(state.frame.data[1][(pos_y+y*scale+shift_y)/2*linesize[1] +
                        (pos_x+x*scale+shift_x)/2]);
                    const data_b: f32 = @floatFromInt(state.frame.data[2][(pos_y+y*scale+shift_y)/2*linesize[2] +
                        (pos_x+x*scale+shift_x)/2]);
                    state.frame.data[0][(pos_y+y*scale+shift_y)*linesize[0] +
                        pos_x+x*scale+shift_x] = @truncate(@as(u32,@bitCast(@as(i32, @intFromFloat(
                                            yr*a+data_r*(1-a))))));
                    if (@mod(pos_y+y*scale+shift_y, 2) == 0 and
                        @mod(pos_x+x*scale+shift_x, 2) == 0) {
                        state.frame.data[1][(pos_y+y*scale+shift_y)/2*linesize[1] +
                            (pos_x+x*scale+shift_x)/2] = @truncate(@as(u32,@bitCast(@as(i32, @intFromFloat(
                                                ur*a+data_g*(1-a))))));
                        state.frame.data[2][(pos_y+y*scale+shift_y)/2*linesize[2] +
                            (pos_x+x*scale+shift_x)/2] = @truncate(@as(u32, @bitCast(@as(i32, @intFromFloat
                                            (vr*a+data_b*(1-a))))));
                    }
                }
            }
        }
    }
}

pub export fn destroy_img(allocator: *std.mem.Allocator, img: *Image) void {
    for (0..img.rows) |i| {
        allocator.free(img.data[i][0..img.width*4]); 
    }
    allocator.free(img.data[0..img.rows]);
    allocator.destroy(img);
}
