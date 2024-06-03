const c = @cImport({
    @cInclude("libavcodec/avcodec.h");
    @cInclude("libavutil/opt.h");
    @cInclude("libavutil/imgutils.h");
    @cInclude("stdio.h");
    @cInclude("ft2build.h");
    @cInclude("freetype/freetype.h");
});
const std = @import("std");
const print = std.debug.print;

const FMVideo = struct {
    f: *c.FILE,
    
    ctx: *c.AVCodecContext,
    codec: *c.AVCodec,
    frame: *c.AVFrame,
    pkt: *c.AVPacket,
    counter: u32,
    arena: std.heap.ArenaAllocator,
};

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

// replace exit for errors
export fn init (name: [*c]u8, width: i32, height: i32, e: *i32) *FMVideo {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    print("Welcom to zig world!\n", .{});
    const v_slice: []FMVideo = allocator.alloc(FMVideo, 1) catch |err| {
        std.log.err("Failed to allocate memory: {}", .{err});
        e.* = 1; //passing error to C
        return @ptrFromInt(@alignOf(FMVideo)); // error will be handeled in err
    };   
    const retval: *FMVideo = @ptrCast(v_slice.ptr);

    var ret: i32 = 0;
    retval.counter = 0;
    retval.arena = arena;

    const codec_name = "mpeg1video"; 
    const temp_codec = c.avcodec_find_encoder_by_name (codec_name);
    if (temp_codec == null) {
        print ("Codec {s} not found\n", .{codec_name});
        std.process.exit(1);
    } else {
        retval.codec = @constCast(@ptrCast(temp_codec));
    }

    const temp_ctx = c.avcodec_alloc_context3(retval.codec);
    if (temp_ctx == null) {
        print ("Could not allocate context\n", .{});
        std.process.exit(1);
    } else {
        retval.ctx = @ptrCast(temp_ctx);
    }

    const temp_pkt = c.av_packet_alloc();
    if (temp_pkt == null) {
        print ("Could not allocate packet\n", .{});
        std.process.exit(1);
    } else {
        retval.pkt = @ptrCast(temp_pkt);
    }

    retval.ctx.bit_rate = 400000;
    retval.ctx.width = width*2;
    retval.ctx.height = height*2;
    retval.ctx.time_base.num = 1;
    retval.ctx.time_base.den = 25;
    retval.ctx.framerate.num = 25;
    retval.ctx.framerate.den = 1;
    // emit one intra frame every ten frames
    // check frame pict_type before passing frame
    // to encoder, if frame->pict_type is AV_PICTURE_TYPE_I
    // then gop_size is ignored and the output of encoder
    // will always be I frame irrepective to gop_size

    retval.ctx.gop_size = 10;
    retval.ctx.max_b_frames = 1;
    retval.ctx.pix_fmt = c.AV_PIX_FMT_YUV420P;

    if (retval.codec.id == c.AV_CODEC_ID_H264) {
        ret = c.av_opt_set (retval.ctx.priv_data, "preset", "slow", 0);
        if (ret < 0) {
            print ("Could not set preset to slow\n", .{});
            std.process.exit(1);
        }
    }

    // open it
    ret = c.avcodec_open2 (retval.ctx, retval.codec, null);
    if (ret < 0) {
        print ("Could not open codec\n", .{});
        std.process.exit(1);
    }

    const temp_f = c.fopen (name, "wb");
    if (temp_f == null) {
        print("Could not open {s}\n", .{name});
        std.process.exit(1);
    } else {
        retval.f = @ptrCast(temp_f);
    }

    const temp_frame = c.av_frame_alloc();
    if (temp_frame == null) {
        print ("Could not allocate video frame\n", .{});
        std.process.exit(1);
    } else {
        retval.frame = @ptrCast(temp_frame);
    }
    retval.frame.format = retval.ctx.pix_fmt;
    retval.frame.width  = retval.ctx.width;
    retval.frame.height = retval.ctx.height;

    ret = c.av_frame_get_buffer (retval.frame, 0);
    if (ret < 0) {
        print ("Could not allocate the video frame data\n", .{});
        std.process.exit(1);
    }

    e.* = 0;
    return retval;
}

export fn add_frame (v: *FMVideo) void {
    v.counter += 1;
    const ret = c.av_frame_make_writable(v.frame);
    if (ret < 0) {
        std.process.exit(1);
    }
}

export fn encode (v: *FMVideo) void {
    var ret: i32 = undefined;
    v.frame.pts = v.counter;

    ret = c.avcodec_send_frame (v.ctx, v.frame);
    if (ret < 0) {
        print ("Error sending a frame for encoding\n", .{});
        std.process.exit(1);
    }

    while (ret >= 0) {
        ret = c.avcodec_receive_packet (v.ctx, v.pkt);
        if (ret == c.AVERROR(c.EAGAIN) or ret == c.AVERROR_EOF) {
            return;
        } else if (ret < 0) {
            print ("Error during encoding\n", .{});
            std.process.exit(1);
        }

        _ = c.fwrite (v.pkt.data, 1, @bitCast(@as(c_long, v.pkt.size)), v.f);
        c.av_packet_unref (v.pkt);
    }
}

export fn write_and_close (v: *FMVideo) void {
    const endcode = [4]u8{0, 0, 1, 0xb7};

    if (v.codec.id == c.AV_CODEC_ID_MPEG1VIDEO or v.codec.id == c.AV_CODEC_ID_MPEG2VIDEO) {
        _ = c.fwrite (&endcode, 1, endcode.len, v.f);
    }
    _ = c.fclose (v.f);

    c.avcodec_free_context (@ptrCast(&v.ctx));
    c.av_frame_free (@ptrCast(&v.frame));
    c.av_packet_free (@ptrCast(&v.pkt));
    v.arena.deinit();
}

fn hypsq (x: f32, y: f32) f32 {
    return x*x + y*y;
}

fn vector_angle (x: f32, y: f32) f32 {
    if (y >= 0) {
        return std.math.atan2(y, x);
    } else {
        return std.math.atan2(y, x) + 2*std.math.pi;
    }
}

fn max (a: i32, b: i32) i32 {
    if (a > b) {
        return a;
    } else {
        return b;
    }
}

fn min (a: i32, b: i32) i32 {
    if (a < b) {
        return a;
    } else {
        return b;
    }
}

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
    const x_min: usize = @bitCast(@as(i64, max(p[0]-r-w, 0)));
    const x_max: usize = @bitCast(@as(i64, min(width, p[0]+r+w+1)));
    const y_min: usize = @bitCast(@as(i64, max(p[1]-r-w, 0)));
    const y_max: usize = @bitCast(@as(i64, min(height, p[1]+r+w)));
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

            if (hypsq (x_f+0.25-p_f[0], y_f+0.125-p_f[1]) >= inner_r and
                hypsq (x_f+0.25-p_f[0], y_f+0.125-p_f[1]) <= outer_r and
                vector_angle (x_f+0.25-p_f[0], y_f+0.125-p_f[1]) <= curangle) {
                sm[0] += 0.25 * co_f[0];
                sm[1] += 0.25 * co_f[1];
                sm[2] += 0.25 * co_f[2];
            } else {
                out_counter += 1;
                sm[0] += 0.25 * bgc_f[0];
                sm[1] += 0.25 * bgc_f[1];
                sm[2] += 0.25 * bgc_f[2];
            }
            if (hypsq (x_f+0.125-p_f[0], y_f+0.75-p_f[1]) >= inner_r and
                hypsq (x_f+0.125-p_f[0], y_f+0.75-p_f[1]) <= outer_r and
                vector_angle (x_f+0.125-p_f[0], y_f+0.75-p_f[1]) <= curangle) {
                sm[0] += 0.25 * co_f[0];
                sm[1] += 0.25 * co_f[1];
                sm[2] += 0.25 * co_f[2];
            } else {
                out_counter += 1;
                sm[0] += 0.25 * bgc_f[0];
                sm[1] += 0.25 * bgc_f[1];
                sm[2] += 0.25 * bgc_f[2];
            }
            if (hypsq (x_f+0.75-p_f[0], y_f+0.825-p_f[1]) >= inner_r and
                hypsq (x_f+0.75-p_f[0], y_f+0.825-p_f[1]) <= outer_r and
                vector_angle (x_f+0.75-p_f[0], y_f+0.825-p_f[1]) <= curangle) {
                sm[0] += 0.25 * co_f[0];
                sm[1] += 0.25 * co_f[1];
                sm[2] += 0.25 * co_f[2];
            } else {
                out_counter += 1;
                sm[0] += 0.25 * bgc_f[0];
                sm[1] += 0.25 * bgc_f[1];
                sm[2] += 0.25 * bgc_f[2];
            }
            if (hypsq (x_f+0.875-p_f[0], y_f+0.25-p_f[1]) >= inner_r and
                hypsq (x_f+0.875-p_f[0], y_f+0.25-p_f[1]) <= outer_r and
                vector_angle (x_f+0.875-p_f[0], y_f+0.25-p_f[1]) <= curangle) { 
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

fn read_with_borders (x: i32, y: i32, w: usize, h: usize, a: [*]u8) i32 {
    if (x < 0 or y < 0 or x >= w or y >= h) {
        return 0;
    } else {
        const x_u: usize = @as(u32, @bitCast(x));
        const y_u: usize = @as(u32, @bitCast(y));
        return @bitCast(@as(u32, a[y_u*w + x_u]));
    }
}

fn print_box (a: []u8, w: usize, h: usize) void {
    for (0..w) |x| {
        for (0..h) |y| {
            print ("{} ", .{a[y*w+x]});
        }
        print ("\n", .{});
    }
}

fn calculate_borders (out: []u8, in: c.FT_Bitmap) void {
    var M: i32 = 0;
    for (0..in.width+2) |x| {
        for (0..in.rows+2) |y| {
            const x_i: i32 = @bitCast(@as(u32, @truncate(x)));
            const y_i: i32 = @bitCast(@as(u32, @truncate(y)));
            var m1: f32 = 0.0;
            var m2: f32 = 0.0;
            m1 += @as(f32, @floatFromInt(read_with_borders   (x_i-2, y_i-2, in.width, in.rows, in.buffer)));
            m1 += 2.0*@as(f32, @floatFromInt(read_with_borders (x_i-1, y_i-2, in.width, in.rows, in.buffer)));
            m1 += @as(f32, @floatFromInt(read_with_borders   (x_i,   y_i-2, in.width, in.rows, in.buffer)));
            m1 -= @as(f32, @floatFromInt(read_with_borders   (x_i-2, y_i, in.width, in.rows, in.buffer)));
            m1 -= 2.0*@as(f32, @floatFromInt(read_with_borders (x_i-1, y_i, in.width, in.rows, in.buffer)));
            m1 -= @as(f32, @floatFromInt(read_with_borders   (x_i,   y_i, in.width, in.rows, in.buffer)));
            m2 += @as(f32, @floatFromInt(read_with_borders   (x_i-2, y_i-2, in.width, in.rows, in.buffer)));
            m2 += 2.0*@as(f32, @floatFromInt(read_with_borders (x_i-2, y_i-1, in.width, in.rows, in.buffer)));
            m2 += @as(f32, @floatFromInt(read_with_borders   (x_i-2, y_i,   in.width, in.rows, in.buffer)));
            m2 -= @as(f32, @floatFromInt(read_with_borders   (x_i, y_i-2, in.width, in.rows, in.buffer)));
            m2 -= 2.0*@as(f32, @floatFromInt(read_with_borders (x_i, y_i-1, in.width, in.rows, in.buffer)));
            m2 -= @as(f32, @floatFromInt(read_with_borders   (x_i, y_i,   in.width, in.rows, in.buffer)));

            const fval: f32 = std.math.hypot(m1/8.0, m2/8.0)/1.4142136;
            const ival: i32 = @intFromFloat(fval);
            const uval: u32 = @bitCast(ival);
            const cval: u8  = @truncate(uval);

            out[y*(in.width+2) + x] = cval;
            M = max(out[y*(in.width+2) + x], M);
        }
    }
    for (0..in.width+2) |x| {
        for (0..in.rows+2) |y| {
            const Mf: f32 = @floatFromInt(M);
            const val: f32 = @floatFromInt(out[y*(in.width+2)+x]);
            const nval: f32 = val * 255.0/Mf;
            out[y*(in.width+2)+x] = @truncate(@as(u32, @bitCast(
                        @as(i32, @intFromFloat(nval)))));
        }
    }
}

export fn write_text (v: *FMVideo, pf: [*c]f32, cg: [*c]u8, fg: [*c]u8, str:
    [*c]u32, len: i32, frames: i32, frame: i32, size: i32, [*c] font_name) void {
    const width_f: f32 = @floatFromInt(v.ctx.width);
    const height_f: f32 = @floatFromInt(v.ctx.height);
    const allocator = v.arena.allocator();

    const p = [2]i32{
        @intFromFloat((pf[0]+1.0)*width_f/2.0),
        @intFromFloat((1.0-pf[1])*height_f/2.0),
    };
    const cgf = [3]f32{
        @floatFromInt(@as(i32, cg[0])),
        @floatFromInt(@as(i32, cg[1])),
        @floatFromInt(@as(i32, cg[2])),
    };

    var lib: c.FT_Library = undefined;
    var face: c.FT_Face = undefined;
    var err: i32 = c.FT_Init_FreeType(&lib);
    if (err != 0) {
        print("... an error occurred during library initialization ...\n", .{});
        return;
    }
    const test_font = "/Users/giorno/projects/fata-morgana/fonts/LinLibertine_R.otf";
    err = c.FT_New_Face(lib, font_name, 0, &face); 
    if (err == c.FT_Err_Unknown_File_Format) {
        print (\\... the font file could be opened and read, but it appears
               \\... that its font format is unsupported
               , .{});
        return;
    } else if (err != 0) {
        print ("font file could not be opened or read, or it is broken", .{});
        return;
    }
    err = c.FT_Set_Char_Size (face, 0, 16*size, 300, 300);
    if (err != 0) {
        print ("couldn't set chat size\n", .{});
        return;
    }

    var old_index: c.FT_UInt = 0;
    var pen_x: i32 = 0;
    var pen_y: i32 = 0;
    const tick = @as(f32, @floatFromInt(frames))/@as(f32, @floatFromInt(len+4));
    const tick_number: i32 = @intFromFloat(@as(f32, @floatFromInt(frame))/tick);

    for (0..@bitCast(@as(i64, min(len, tick_number)))) |i| {
        const glyph_index = c.FT_Get_Char_Index(face, str[i]);
        err = c.FT_Load_Glyph(face, glyph_index, c.FT_LOAD_DEFAULT);
        if (err != 0) {
            print ("couldn;t load a glyph\n", .{});
            return;
        }

        if (i > 0) {
            var kerning: c.FT_Vector = undefined;
            err = c.FT_Get_Kerning(face, old_index, glyph_index, c.FT_KERNING_DEFAULT, &kerning);
            if (err != 0) {
                print ("error in defining kerning\n", .{});
                return;
            }
            pen_x += @truncate(kerning.x >> 6);
        }

        err = c.FT_Render_Glyph(face.*.glyph, c.FT_RENDER_MODE_NORMAL);
        if (err != 0) {
            print ("error in rendering\n", .{});
            return;
        }

        const linesize = v.frame.linesize;
        const bitmap = face.*.glyph.*.bitmap;
        if (i < tick_number-4) {

            // showing letters
            for (0..bitmap.width) |x| {
                for (0..bitmap.rows) |y| {
                    const m: f32 = @as(f32,
                        @floatFromInt(bitmap.buffer[y*bitmap.width + x]))/255.0;

                    const x_i: i32 = @bitCast(@as(u32, @truncate(x)));
                    const y_i: i32 = @bitCast(@as(u32, @truncate(y)));
                    const bmtop: i32 = face.*.glyph.*.bitmap_top;
                    const bmleft: i32 = face.*.glyph.*.bitmap_left;
                    const linesize_0: i32 = linesize[0]; 
                    const linesize_1: i32 = linesize[1]; 
                    const linesize_2: i32 = linesize[2]; 

                    const pos_0: i32 = 
                        (y_i+p[1]+pen_y-bmtop) *
                        linesize_0 + (x_i+p[0]+pen_x+bmleft);
                   const pos_1: i32 = 
                        @divFloor(y_i+p[1]+pen_y-bmtop,2) *
                        linesize_1 + @divFloor(x_i+p[0]+pen_x+bmleft,2);
                   const pos_2: i32 =
                        @divFloor(y_i+p[1]+pen_y-bmtop,2) *
                        linesize_2 + @divFloor(x_i+p[0]+pen_x+bmleft,2);

                    const pos = [3]usize{
                        @as(u32, @bitCast(pos_0)),
                        @as(u32, @bitCast(pos_1)),
                        @as(u32, @bitCast(pos_2)),
                    };

                    const bg = [3]f32{
                        @floatFromInt(@as(i32, v.frame.data[0][pos[0]])),
                        @floatFromInt(@as(i32, v.frame.data[1][pos[1]])),
                        @floatFromInt(@as(i32, v.frame.data[2][pos[2]])),
                    };
                    const yr: i32 = @intFromFloat(cgf[0]*m + bg[0]*(1.0-m));
                    const ur: i32 = @intFromFloat(cgf[1]*m + bg[1]*(1.0-m));
                    const vr: i32 = @intFromFloat(cgf[2]*m + bg[2]*(1.0-m));
                    v.frame.data[0][pos[0]] = @truncate(@as(u32, @bitCast(yr)));
                    if ((x&1)==0 and (y&1) == 0) {
                        v.frame.data[1][pos[1]] = @truncate(@as(u32, @bitCast(ur)));
                        v.frame.data[2][pos[2]] = @truncate(@as(u32, @bitCast(vr)));
                    }
                }
            }
        } else if (i > tick_number-4 and i <= tick_number) {

            //calculating borders
            const borders_size: usize = (bitmap.width+2)*(bitmap.rows+2);
            const borders: []u8 = allocator.alloc(u8, borders_size) catch {
                print ("Out of memory for borders\n", .{});
                return;
            };
            calculate_borders (borders, bitmap);
            for (0..bitmap.width+2) |x| {
                for (0..bitmap.rows+2) |y| {
                    const angle_coef: f32 = (@as(f32, @floatFromInt(frame)) -
                        @as(f32, @floatFromInt(@as(i32, @bitCast(@as(u32,
                                            @truncate(i))))))*tick) /
                        (4.0*tick);
                    const m: f32 = @as(f32, @floatFromInt(@as(i32,
                        borders[y*(bitmap.width+2) + x])))/255.0;

                    const x_i: i32 = @bitCast(@as(u32, @truncate(x)));
                    const y_i: i32 = @bitCast(@as(u32, @truncate(y)));
                    const bmtop: i32 = face.*.glyph.*.bitmap_top;
                    const bmleft: i32 = face.*.glyph.*.bitmap_left;
                    const linesize_0: i32 = linesize[0]; 
                    const linesize_1: i32 = linesize[1]; 
                    const linesize_2: i32 = linesize[2]; 

                    const pos_0: i32 = 
                        (y_i+p[1]+pen_y-bmtop) *
                        linesize_0 + (x_i+p[0]+pen_x+bmleft);
                   const pos_1: i32 = 
                        @divFloor(y_i+p[1]+pen_y-bmtop,2) *
                        linesize_1 + @divFloor(x_i+p[0]+pen_x+bmleft,2);
                   const pos_2: i32 =
                        @divFloor(y_i+p[1]+pen_y-bmtop,2) *
                        linesize_2 + @divFloor(x_i+p[0]+pen_x+bmleft,2);

                    const pos = [3]usize{
                        @as(u32, @bitCast(pos_0)),
                        @as(u32, @bitCast(pos_1)),
                        @as(u32, @bitCast(pos_2)),
                    };

                    const bg = [3]f32{
                        @floatFromInt(@as(i32, v.frame.data[0][pos[0]])),
                        @floatFromInt(@as(i32, v.frame.data[1][pos[1]])),
                        @floatFromInt(@as(i32, v.frame.data[2][pos[2]])),
                    };
                    const yr: i32 = @intFromFloat(cgf[0]*m + bg[0]*(1.0-m));
                    const ur: i32 = @intFromFloat(cgf[1]*m + bg[1]*(1.0-m));
                    const vr: i32 = @intFromFloat(cgf[2]*m + bg[2]*(1.0-m));
                    
                    const xf: f32 = @floatFromInt(@as(i32, @bitCast(@as(u32, 
                        @truncate(x)))));
                    const yf: f32 = @floatFromInt(@as(i32, @bitCast(@as(u32,
                        @truncate(y)))));
                    if (std.math.pi/2.0-vector_angle(xf, yf) <= std.math.pi/2.0
                        * angle_coef) {
                        v.frame.data[0][pos[0]] = @truncate(@as(u32, @bitCast(
                                    yr)));
                        if ((x&1)==0 and (y&1) == 0) {
                            v.frame.data[1][pos[1]] = @truncate(@as(u32, 
                                    @bitCast(ur)));
                            v.frame.data[2][pos[2]] = @truncate(@as(u32,
                                    @bitCast(vr)));
                        }
                    }
                }
            }
            allocator.free(borders);
        } else if (i == tick_number-4) {

            const borders_size = (bitmap.width+2)*(bitmap.rows+2);
            const borders = allocator.alloc(u8, borders_size) catch {
                print ("Out of memory for borders\n", .{});
                return;
            };
            calculate_borders (borders, bitmap);
            for (0..bitmap.width+2) |x| {
                for (0..bitmap.rows+2) |y| {
                    const x_i: i32 = @bitCast(@as(u32, @truncate(x)));
                    const y_i: i32 = @bitCast(@as(u32, @truncate(y)));

                    const frame_f: f32 = @floatFromInt(frame);
                    const tick_number_f: f32 = @floatFromInt(tick_number);
                    const buf_val_f: f32 = @floatFromInt(read_with_borders(x_i-1,
                            y_i-1, bitmap.width, bitmap.rows, bitmap.buffer));
                    const borval: f32 = @floatFromInt(borders[y*(bitmap.width+2)+x]);

                    const filling_to_border: f32 = (frame_f-tick_number_f*tick) /
                        tick;
                    const filling_coef: f32 = filling_to_border*buf_val_f/255.0;
                    const border_coef: f32 = (1.0 - filling_to_border) * borval
                        / 255.0;
                    const bg_coef: f32 = 1.0 - filling_coef - border_coef;

                    const bmtop: i32 = face.*.glyph.*.bitmap_top;
                    const bmleft: i32 = face.*.glyph.*.bitmap_left;
                    const linesize_0: i32 = linesize[0]; 
                    const linesize_1: i32 = linesize[1]; 
                    const linesize_2: i32 = linesize[2]; 

                    const pos_0: i32 = 
                        (y_i+p[1]+pen_y-bmtop) *
                        linesize_0 + (x_i+p[0]+pen_x+bmleft);
                   const pos_1: i32 = 
                        @divFloor(y_i+p[1]+pen_y-bmtop,2) *
                        linesize_1 + @divFloor(x_i+p[0]+pen_x+bmleft,2);
                   const pos_2: i32 =
                        @divFloor(y_i+p[1]+pen_y-bmtop,2) *
                        linesize_2 + @divFloor(x_i+p[0]+pen_x+bmleft,2);

                    const pos = [3]usize{
                        @as(u32, @bitCast(pos_0)),
                        @as(u32, @bitCast(pos_1)),
                        @as(u32, @bitCast(pos_2)),
                    };

                    const bg = [3]f32{
                        @floatFromInt(@as(i32, v.frame.data[0][pos[0]])),
                        @floatFromInt(@as(i32, v.frame.data[1][pos[1]])),
                        @floatFromInt(@as(i32, v.frame.data[2][pos[2]])),
                    };
                    const fgf = [3]f32{
                        @floatFromInt(@as(i32, fg[0])),
                        @floatFromInt(@as(i32, fg[1])),
                        @floatFromInt(@as(i32, fg[2])),
                    };
                    const yr: i32 = @intFromFloat(cgf[0]*filling_coef +
                        fgf[0]*border_coef + bg[0]*bg_coef);
                    const ur: i32 = @intFromFloat(cgf[1]*filling_coef +
                        fgf[1]*border_coef + bg[1]*bg_coef);
                    const vr: i32 = @intFromFloat(cgf[2]*filling_coef +
                        fgf[2]*border_coef + bg[2]*bg_coef);
                    
                    v.frame.data[0][pos[0]] = @truncate(@as(u32, @bitCast(yr)));
                    if ((x&1)==0 and (y&1) == 0) {
                        v.frame.data[1][pos[1]] = @truncate(@as(u32, @bitCast(
                                    ur)));
                        v.frame.data[2][pos[2]] = @truncate(@as(u32, @bitCast(
                                    vr)));
                    }
                }
            }
            allocator.free(borders);
        }
        pen_x += @as(i32, @truncate(face.*.glyph.*.advance.x>>6));
        pen_y += @as(i32, @truncate(face.*.glyph.*.advance.y>>6));
        old_index = glyph_index;
    }
}


export fn 
splitTextInLines (x_t: i32, y_l: i32, x_b: i32, y_r: i32, s: [*c]i32, len: i32) [*c]i32 {
    var i: i32 = 0;
    while (i < len) : (i+=1) {
        const glyph_index = c.FT_Get_Char_Index(face, str[i]);
        err = c.FT_Load_Glyph(face, glyph_index, c.FT_LOAD_DEFAULT);
        if (err != 0) {
            print ("couldn;t load a glyph\n", .{});
            return;
        }

        if (i > 0) {
            var kerning: c.FT_Vector = undefined;
            err = c.FT_Get_Kerning(face, old_index, glyph_index, c.FT_KERNING_DEFAULT, &kerning);
            if (err != 0) {
                print ("error in defining kerning\n", .{});
                return;
            }
            pen_x += @truncate(kerning.x >> 6);
        }
    }
}

