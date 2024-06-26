const std = @import("std");
const print = std.debug.print;

const c = @cImport({
    @cInclude("libavcodec/avcodec.h");
    @cInclude("libavutil/opt.h");
    @cInclude("libavutil/imgutils.h");
    @cInclude("stdio.h");
});

pub const FMVideo = struct {
    f: *c.FILE,
    
    ctx: *c.AVCodecContext,
    codec: *c.AVCodec,
    frame: *c.AVFrame,
    pkt: *c.AVPacket,
    counter: u32,
    arena: std.heap.ArenaAllocator,
};

// trying to add support for mpeg4 with h264
// export fn mpeg4fn (name: [*c]u8, width: i32, height: i32, e: *i32) *FMVideo {
//     print("Trying something new!\n", .{});
//
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     var allocator = arena.allocator();
//     const v_slice: []FMVideo = allocator.alloc(FMVideo, 1) catch |err| {
//         std.log.err("Failed to allocate memory: {}", .{err});
//         e.* = 1; //passing error to C
//         return @ptrFromInt(@alignOf(FMVideo)); // error will be handeled in err
//     };   
//     const retval: *FMVideo = @ptrCast(v_slice.ptr);
//
//     const codec_id: i32 = c.AV_CODEC_ID_MPEG4;
//     const c_codec = c.avcodec_find_encoder(c.AV_CODEC_ID_H264);
//     if (c_codec == 0) {
//         print("Can't find codec\n", .{});
//         std.process.exit(1);
//     } else {
//         retval.codec = @constCast(@ptrCast(c_codec));
//     }
//
//     const temp_ctx = c.avcodec_alloc_context3(retval.codec);
//     if (temp_ctx == null) {
//         print ("Could not allocate context\n", .{});
//         std.process.exit(1);
//     } else {
//         retval.ctx = @ptrCast(temp_ctx);
//     }
//
//     retval.ctx.bit_rate = 400000;
//     retval.ctx.width = width*2;
//     retval.ctx.height = height*2;
//     retval.ctx.time_base.num = 1;
//     retval.ctx.time_base.den = 25;
//     retval.ctx.framerate.num = 25;
//     retval.ctx.framerate.den = 1;
//
//     retval.ctx.gop_size = 10;
//     retval.ctx.max_b_frames = 1;
//     retval.ctx.pix_fmt = c.AV_PIX_FMT_YUV420P;
//     if(codec_id == c.AV_CODEC_ID_H264) {
//         c.av_opt_set(retval.ctx.priv_data, "preset", "slow", 0);
//     }
//
//     if (c.avcodec_open2(retval.ctx, retval.codec, 0) < 0) {
//         print ("could not open codec\n", .{});
//         std.process.exit(1);
//     }
//
//     const temp_f = c.fopen (name, "wb");
//     if (temp_f == 0) {
//         print("Could not open {s}\n", .{name});
//         std.process.exit(1);
//     } else {
//         retval.f = @ptrCast(temp_f);
//     }
//
//     retval.frame = c.av_frame_alloc();
//     const outbuf_size: usize = 100000 + 12*@as(u32, @bitCast(width)) *
//         @as(u32, @bitCast(height));
//     const outbuf = allocator.alloc(u8, outbuf_size) catch {
//         print ("no memory!\n", .{});
//         std.process.exit(1);
//     };
//     c.av_image_alloc (retval.frame.data, retval.frame.linesize,
//         width, height, retval.ctx.pix_fmt, 1);
//
//     var out_size: i32 = undefined;
//     var had_output: i32 = 0;
//     for (0..25) |i| {
//         c.fflush(c.stdout);
//         for (0..height*2) |y| {
//             for (0..width*2) |x| {
//                 retval.frame.data[0][y * retval.frame.linesize[0] + x] = @truncate(x+y+i*3);
//             }
//         }
//
//         for(0..height) |y| {
//             for(0..width) |x| {
//                 retval.frame.data[1][y * retval.frame.linesize[1] + x] = 128 + y + i * 2;
//                 retval.frame.data[2][y * retval.frame.linesize[2] + x] = 64 + x + i * 5;
//             }
//         }
//
//         out_size = c.avcodec_encode_video (retval.ctx, outbuf.ptr, outbuf_size,
//             retval.frame);
//         had_output |= out_size;
//         print ("encoding frame {} (size={})\n", .{i, out_size});
//         c.fwrite(outbuf, 1, out_size, retval.f);
//     }
//
//     return retval;
// }
//
// test "mpeg + h264" {
//     var e: i32 = undefined;
//     _ = mpeg4fn ("t.mp4", 200, 100, &e);
// }

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
