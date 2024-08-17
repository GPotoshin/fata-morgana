const std = @import("std");
const print = std.debug.print;

const c = @cImport({
    @cInclude("stdio.h");
});
const avc = @import("c/avcodec.zig");
const avf = @import("c/avformat.zig");
const avo = @import("c/avopt.zig");

pub const FMVideo = struct {
    codec: *avc.AVCodec,
    codec_ctx: *avc.AVCodecContext,
    format: *avf.AVOutputFormat,
    format_ctx: *avf.AVFormatContext,
    frame: *avc.AVFrame,
    packet: *avc.AVPacket,
    stream: *avf.AVStream,
    counter: u32,
    arena: std.heap.ArenaAllocator,
};

// trying to add support for mpeg4 with h264
export fn init (name: [*c]u8, width: i32, height: i32, e: *i32) *FMVideo {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    const v_slice: []FMVideo = allocator.alloc(FMVideo, 1) catch |err| {
        std.log.err("Failed to allocate memory: {}", .{err});
        e.* = 1; //passing error to C
        return @ptrFromInt(@alignOf(FMVideo)); // error will be handeled in err
    };   
    const retval: *FMVideo = @ptrCast(v_slice.ptr);

    var ret: i32 = 0;
    retval.counter = 0;
    retval.arena = arena;

    avf.av_log_set_level(avf.AV_LOG_FATAL);
    var temp_format_ctx: [*c]avf.AVFormatContext = null;
    ret = avf.avformat_alloc_output_context2(&temp_format_ctx, null, "mp4", name);
    if (temp_format_ctx == null or ret < 0) {
        print("can not allocate av context\n", .{});
        std.process.exit(1);
    } else {
        retval.format_ctx = @ptrCast(temp_format_ctx);
    }
    // init codec format
    retval.format = @constCast(@ptrCast(retval.format_ctx.oformat));
    
    const temp_codec = avc.avcodec_find_encoder(avf.AV_CODEC_ID_H264);
    if (temp_codec == null) {
        print ("Codec not found\n", .{});
        std.process.exit(1);
    } else {
        retval.codec = @constCast(@ptrCast(temp_codec));
    }

    const temp_pkt = avc.av_packet_alloc();
    if (temp_pkt == null) {
        print ("Could not allocate packet\n", .{});
        std.process.exit(1);
    } else {
        retval.packet = @ptrCast(temp_pkt);
    }

    const temp_stream = avf.avformat_new_stream(retval.format_ctx, null); 
    if (temp_pkt == null) {
        print("Could not allocate stream\n", .{});
        std.process.exit(1);
    } else {
        retval.stream = @ptrCast(temp_stream);
    }
    retval.stream.id = @bitCast(retval.format_ctx.nb_streams-1);

    const temp_codec_ctx = avc.avcodec_alloc_context3(retval.codec);
    if (temp_codec_ctx == null) {
        print ("Could not allocate context\n", .{});
        std.process.exit(1);
    } else {
        retval.codec_ctx = @ptrCast(temp_codec_ctx);
    }

    if (retval.format.flags & avf.AVFMT_GLOBALHEADER != 0) {
        retval.codec_ctx.flags |= avc.AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    retval.codec_ctx.codec_id = avc.AV_CODEC_ID_H264;
    retval.codec_ctx.bit_rate = 800000;
    retval.codec_ctx.width = width*2;
    retval.codec_ctx.height = height*2;
    retval.codec_ctx.time_base.num = 1;
    retval.codec_ctx.time_base.den = 25;
    retval.codec_ctx.framerate.num = 25;
    retval.codec_ctx.framerate.den = 1;
    retval.stream.time_base = retval.codec_ctx.time_base;
    retval.codec_ctx.gop_size = 10;
    retval.codec_ctx.pix_fmt = avc.AV_PIX_FMT_YUV420P;

    ret = avo.av_opt_set(retval.codec_ctx.priv_data, "preset", "slow", 0);
    if (ret < 0) {
        print("Could not set preset to slow\n", .{});
        std.process.exit(1);
    }
    // compression rate
    ret = avo.av_opt_set(retval.codec_ctx.priv_data, "crf", "35", 0);
    if (ret < 0) {
        print("Could not set crf to 35\n", .{});
    }
    // [psnr, ssim, grain, zerolatency, fastdecode, animation]
    ret = avo.av_opt_set(retval.codec_ctx.priv_data, "tune", "animation", 0);
    if (ret < 0) {
        print("Could not set tune to animation\n", .{});
    }

    ret = avc.avcodec_open2(@ptrCast(retval.codec_ctx), @ptrCast(retval.codec),
    null);

    const temp_frame = avf.av_frame_alloc();
    if (temp_frame == null) {
        print ("Could not allocate video frame\n", .{});
        std.process.exit(1);
    } else {
        retval.frame = @ptrCast(temp_frame);
    }
    retval.frame.format = retval.codec_ctx.pix_fmt;
    retval.frame.width  = retval.codec_ctx.width;
    retval.frame.height = retval.codec_ctx.height;

    ret = avc.av_frame_get_buffer (retval.frame, 0);
    if (ret < 0) {
        print("Could not allocate the video frame data\n", .{});
        std.process.exit(1);
    }

    ret = avc.avcodec_parameters_from_context(retval.stream.codecpar, retval.codec_ctx);
    if (ret < 0) {
        print("Could not put parameters frome the context to a stream\n", .{});
        std.process.exit(1);
    }
    avf.av_dump_format(retval.format_ctx, 0, name, 1);

    if (retval.format.flags & avf.AVFMT_NOFILE == 0) {
        ret = avf.avio_open(&retval.format_ctx.pb, name, avf.AVIO_FLAG_WRITE);
        if (ret < 0) {
            print("Could not open output file '{s}'\n", .{name});
        }
    }
    ret = avf.avformat_write_header(retval.format_ctx, null);
    if (ret < 0) {
        print("Could not write header\n", .{});
        std.process.exit(1);
    }
    e.* = 0;
    return retval;
}

export fn add_frame (v: *FMVideo) void {
    v.counter += 1;
    const ret = avc.av_frame_make_writable(v.frame);
    if (ret < 0) {
        std.process.exit(1);
    }
}

export fn encode (v: *FMVideo) void {
    var ret: i32 = undefined;
    v.frame.pts = v.counter;

    ret = avc.avcodec_send_frame (@ptrCast(v.codec_ctx), @ptrCast(v.frame));
    if (ret < 0) {
        print ("Error sending a frame for encoding\n", .{});
        std.process.exit(1);
    }

    while (ret >= 0) {
        ret = avc.avcodec_receive_packet(@ptrCast(v.codec_ctx), @ptrCast(v.packet));
        if (ret == avc.AVERROR(avf.EAGAIN) or ret == avf.AVERROR_EOF) {
            return;
        } else if (ret < 0) {
            print ("Error during encoding\n", .{});
            std.process.exit(1);
        }

        avf.av_packet_rescale_ts(v.packet, v.codec_ctx.time_base, v.stream.time_base);
        v.packet.stream_index = v.stream.index;

        // write compressed packet
        ret = avf.av_interleaved_write_frame(v.format_ctx, v.packet);
        if (ret < 0) {
            print("error while writing output packet\n", .{});
            std.process.exit(1);
        }
    }
}

export fn write_and_close (v: *FMVideo) void {
    const ret = avf.av_write_trailer(v.format_ctx);
    if (ret < 0) {
        print("Could not write trailer\n", .{});
        std.process.exit(1);
    }
    if (v.format.flags & avf.AVFMT_NOFILE == 0) {
        _ = avf.avio_closep(&v.format_ctx.pb);
    }
    avc.avcodec_free_context (@ptrCast(&v.codec_ctx));
    avc.av_frame_free (@ptrCast(&v.frame));
    avc.av_packet_free (@ptrCast(&v.packet));
    avf.avformat_free_context(@ptrCast(v.format_ctx));
    v.arena.deinit();
}
