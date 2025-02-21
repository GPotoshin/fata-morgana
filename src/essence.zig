const std = @import("std");
const print = std.debug.print;

const c = @cImport({
    @cInclude("stdio.h");
});
const avc = @import("c/avcodec.zig");
const avf = @import("c/avformat.zig");
const avo = @import("c/avopt.zig");
const ft = @import("c/freetype.zig");

pub const Face = enum {
    Regular,
    Maths,
    Code,
};

pub const Bitmap = struct {
    data: ?[]u8,
    borders: ?[]u8,
    rows: u32,
    width: u32,
    top: i32,
    left: i32,
    advance_x: i64,
    advance_y: i64,
};

// Refactoring plan:
// * change allocation stretegy to arena
//   > allocation
//   > deallocation +
// * debug text prossessing function
//   > as I remeber there advances are not taken from precomputed bitmaps
// * read through all the code
//   > the refactor stratagy is to refactor 'block par block'[fr]
 
pub const FMVideo = struct {
    codec: *const avc.AVCodec,
    codec_ctx: *avc.AVCodecContext,
    format: *const avf.AVOutputFormat,
    format_ctx: *avf.AVFormatContext,
    frame: *avc.AVFrame,
    packet: *avc.AVPacket,
    stream: *avf.AVStream,
    counter: u32,
    
    scene_arena: std.heap.ArenaAllocator,

    // font fields
    font_size: []u32,
    ft_lib: ft.FT_Library,
    faces: [3]ft.FT_Face,
    glyphmaps: [3][3]std.AutoHashMap(u32, Bitmap),
};

var framework_state: FMVideo = undefined;

pub export fn get_allocator (v: ?*FMVideo) *const std.mem.Allocator {
    return &v.?.scene_arena.allocator();
}

pub export fn init(name: [*:0]u8, width: i32, height: i32, face_names: [*][*:0]u8,
    font_sizes: [*]u32, e: *i32) ?*FMVideo {
    framework_state.scene_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    const allocator = framework_state.scene_arena.allocator();

    framework_state.counter = 0;

    var ret: i32 = 0;

    // otherwise getting excesive linking from libx264
    avf.av_log_set_level(avf.AV_LOG_FATAL);

    var temp_format_ctx: [*c]avf.AVFormatContext = null;
    ret = avf.avformat_alloc_output_context2(&temp_format_ctx, null, "mp4", name);
    if (temp_format_ctx == null or ret < 0) {
        print("can not allocate av context\n", .{});
        std.process.exit(1);
    } else {
        framework_state.format_ctx = @ptrCast(temp_format_ctx);
    }
    // init codec format
    framework_state.format = @ptrCast(framework_state.format_ctx.oformat);
    
    const temp_codec = avc.avcodec_find_encoder(avf.AV_CODEC_ID_H264);
    if (temp_codec == null) {
        print ("Codec not found\n", .{});
        std.process.exit(1);
    } else {
        framework_state.codec = @ptrCast(temp_codec);
    }

    const temp_pkt = avc.av_packet_alloc();
    if (temp_pkt == null) {
        print ("Could not allocate packet\n", .{});
        std.process.exit(1);
    } else {
        framework_state.packet = @ptrCast(temp_pkt);
    }

    const temp_stream = avf.avformat_new_stream(framework_state.format_ctx, null); 
    if (temp_pkt == null) {
        print("Could not allocate stream\n", .{});
        std.process.exit(1);
    } else {
        framework_state.stream = @ptrCast(temp_stream);
    }
    framework_state.stream.id = @bitCast(framework_state.format_ctx.nb_streams-1);

    const temp_codec_ctx = avc.avcodec_alloc_context3(framework_state.codec);
    if (temp_codec_ctx == null) {
        print ("Could not allocate context\n", .{});
        std.process.exit(1);
    } else {
        framework_state.codec_ctx = @ptrCast(temp_codec_ctx);
    }

    if (framework_state.format.flags & avf.AVFMT_GLOBALHEADER != 0) {
        framework_state.codec_ctx.flags |= avc.AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    framework_state.codec_ctx.codec_id = avc.AV_CODEC_ID_H264;
    framework_state.codec_ctx.bit_rate = 800000;
    framework_state.codec_ctx.width = width*2;
    framework_state.codec_ctx.height = height*2;
    framework_state.codec_ctx.time_base.num = 1;
    framework_state.codec_ctx.time_base.den = 25;
    framework_state.codec_ctx.framerate.num = 25;
    framework_state.codec_ctx.framerate.den = 1;
    framework_state.stream.time_base = framework_state.codec_ctx.time_base;
    framework_state.codec_ctx.gop_size = 10;
    framework_state.codec_ctx.pix_fmt = avc.AV_PIX_FMT_YUV420P;

    ret = avo.av_opt_set(framework_state.codec_ctx.priv_data, "preset", "slow", 0);
    if (ret < 0) {
        print("Could not set preset to slow\n", .{});
        std.process.exit(1);
    }
    // compression rate
    ret = avo.av_opt_set(framework_state.codec_ctx.priv_data, "crf", "20", 0);
    if (ret < 0) {
        print("Could not set crf to 20\n", .{});
    }
    // [psnr, ssim, grain, zerolatency, fastdecode, animation]
    ret = avo.av_opt_set(framework_state.codec_ctx.priv_data, "tune", "animation", 0);
    if (ret < 0) {
        print("Could not set tune to animation\n", .{});
    }

    ret = avc.avcodec_open2(@ptrCast(framework_state.codec_ctx), @ptrCast(framework_state.codec),
    null);

    const temp_frame = avf.av_frame_alloc();
    if (temp_frame == null) {
        print ("Could not allocate video frame\n", .{});
        std.process.exit(1);
    } else {
        framework_state.frame = @ptrCast(temp_frame);
    }
    framework_state.frame.format = framework_state.codec_ctx.pix_fmt;
    framework_state.frame.width  = framework_state.codec_ctx.width;
    framework_state.frame.height = framework_state.codec_ctx.height;

    ret = avc.av_frame_get_buffer (framework_state.frame, 0);
    if (ret < 0) {
        print("Could not allocate the video frame data\n", .{});
        std.process.exit(1);
    }

    ret = avc.avcodec_parameters_from_context(framework_state.stream.codecpar, framework_state.codec_ctx);
    if (ret < 0) {
        print("Could not put parameters frome the context to a stream\n", .{});
        std.process.exit(1);
    }
    avf.av_dump_format(framework_state.format_ctx, 0, name, 1);

    if (framework_state.format.flags & avf.AVFMT_NOFILE == 0) {
        ret = avf.avio_open(&framework_state.format_ctx.pb, name, avf.AVIO_FLAG_WRITE);
        if (ret < 0) {
            print("Could not open output file '{s}'\n", .{name});
        }
    }
    ret = avf.avformat_write_header(framework_state.format_ctx, null);
    if (ret < 0) {
        print("Could not write header\n", .{});
        std.process.exit(1);
    }

    // initializing freetype
    e.* = ft.FT_Init_FreeType(&framework_state.ft_lib);
    if (e.* != 0) {
        print("Could not initiate freetype library\n", .{});
        std.process.exit(1);
    }
    e.* = ft.FT_New_Face(
        framework_state.ft_lib,
        face_names[@intFromEnum(Face.Regular)],
        0,
        &framework_state.faces[@intFromEnum(Face.Regular)]
    );
    if (e.* != 0) {
        print("Could not open {s} font\n", .{face_names[@intFromEnum(Face.Regular)]});
        std.process.exit(1);
    }
    e.* = ft.FT_New_Face(
        framework_state.ft_lib,
        face_names[@intFromEnum(Face.Maths)],
        0,
        &framework_state.faces[@intFromEnum(Face.Maths)]
    );
    if (e.* != 0) {
        print("Could not open {s} font\n", .{face_names[@intFromEnum(Face.Maths)]});
        std.process.exit(1);
    }
    e.* = ft.FT_New_Face(
        framework_state.ft_lib,
        face_names[@intFromEnum(Face.Code)],
        0,
        &framework_state.faces[@intFromEnum(Face.Code)],
    );
    if (e.* != 0) {
        print("Could not open {s} font\n", .{face_names[@intFromEnum(Face.Code)]});
        std.process.exit(1);
    }
    for (0..3) |i| {
        for (0..3) |j| {
            framework_state.glyphmaps[i][j] = std.AutoHashMap(u32, Bitmap).init(allocator);
        }
    }
    // who knows how memory is allocated in ocaml? 
    framework_state.font_size.ptr = font_sizes;
    framework_state.font_size.len = 3;
    return &framework_state;
}

pub export fn add_frame (v: ?*FMVideo) void {
    var state = v.?;
    state.counter += 1;
    const ret = avc.av_frame_make_writable(state.frame);
    if (ret < 0) {
        std.process.exit(1);
    }
}

pub export fn encode (v: ?*FMVideo) void {
    var ret: i32 = undefined;
    var state = v.?;
    state.frame.pts = state.counter;

    ret = avc.avcodec_send_frame (@ptrCast(state.codec_ctx), @ptrCast(state.frame));
    if (ret < 0) {
        print ("Error sending a frame for encoding\n", .{});
        std.process.exit(1);
    }

    while (ret >= 0) {
        ret = avc.avcodec_receive_packet(@ptrCast(state.codec_ctx), @ptrCast(state.packet));
        if (ret == avc.AVERROR(avf.EAGAIN) or ret == avf.AVERROR_EOF) {
            return;
        } else if (ret < 0) {
            print ("Error during encoding\n", .{});
            std.process.exit(1);
        }

        avf.av_packet_rescale_ts(state.packet, state.codec_ctx.time_base, state.stream.time_base);
        state.packet.stream_index = state.stream.index;

        // write compressed packet
        ret = avf.av_interleaved_write_frame(state.format_ctx, state.packet);
        if (ret < 0) {
            print("error while writing output packet\n", .{});
            std.process.exit(1);
        }
    }
}

pub export fn write_and_close (v: ?*FMVideo) void {
    var state = v.?;
    const arena = state.scene_arena;
    arena.deinit();

    const ret = avf.av_write_trailer(state.format_ctx);
    if (ret < 0) {
        print("Could not write trailer\n", .{});
        std.process.exit(1);
    }
    if (state.format.flags & avf.AVFMT_NOFILE == 0) {
        _ = avf.avio_closep(&state.format_ctx.pb);
    }
            
    // why cstdlib allocator ??
    avc.avcodec_free_context(@ptrCast(&state.codec_ctx));
    avc.av_frame_free(@ptrCast(&state.frame));
    avc.av_packet_free(@ptrCast(&state.packet));
    avf.avformat_free_context(@ptrCast(state.format_ctx));
}
