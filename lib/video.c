#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <libavcodec/avcodec.h>

#include <libavutil/opt.h>
#include <libavutil/imgutils.h>

#include "video.h"

const double Kr = 0.299;
const double Kg = 0.587;
const double Kb = 0.114;

typedef struct {
    int x, y;
} int2;

typedef struct {
    int x,y,z;
} int3;

int3 rgb2ycrcb (int3 c) {
    int3 retval;
    retval.x = Kr*c.x + Kg*c.y + Kb*c.z;
    retval.y = 0.5*(c.z-retval.x)/(1-Kb);
    retval.z = 0.5*(c.x-retval.x)/(1-Kr);
    return retval;
}

FMVideo init (char* name, int width, int height) {
    FMVideo retval;
    int ret;
    retval.counter = 0;

    const char *codec_name = "mpeg1video";

    retval.codec = avcodec_find_encoder_by_name(codec_name);
    if (!retval.codec) {
        fprintf (stderr, "Codec '%s' not found\n", codec_name);
        exit(1);
    }

    retval.ctx = avcodec_alloc_context3(retval.codec);
    if (!retval.ctx) {
        fprintf (stderr, "Could not allocate video codec context\n");
        exit(1);
    }

    retval.pkt = av_packet_alloc();
    if (!retval.pkt) {
        fprintf (stderr, "Could not allocate video packet\n");
        exit(1);
    }

    // put sample parameters
    retval.ctx->bit_rate = 400000;
    // resolution must be a multiple of two
    retval.ctx->width = width*2;
    retval.ctx->height = height*2;
    // frames per second
    retval.ctx->time_base = (AVRational){1, 25};
    retval.ctx->framerate = (AVRational){25, 1};

    /* emit one intra frame every ten frames
     * check frame pict_type before passing frame
     * to encoder, if frame->pict_type is AV_PICTURE_TYPE_I
     * then gop_size is ignored and the output of encoder
     * will always be I frame irrepective to gop_size
     */

    retval.ctx->gop_size = 10;
    retval.ctx->max_b_frames = 1;
    retval.ctx->pix_fmt = AV_PIX_FMT_YUV420P;

    if (retval.codec->id == AV_CODEC_ID_H264) {
        av_opt_set (retval.ctx->priv_data, "preset", "slow", 0);
    }

    /* open it */
    ret = avcodec_open2 (retval.ctx, retval.codec, NULL);
    if (ret < 0) {
        fprintf (stderr, "Could not open codec: %s\n", av_err2str (ret));
        exit(1);
    }

    retval.f = fopen (name, "wb");
    if (!retval.f) {
        fprintf (stderr, "Cloud not open %s\n", name);
        exit(1);
    }

    retval.frame = av_frame_alloc();
    if (!retval.frame) {
        fprintf (stderr, "Could not sllocate video frame\n");
        exit(1);
    }
    retval.frame->format = retval.ctx->pix_fmt;
    retval.frame->width = retval.ctx->width;
    retval.frame->height = retval.ctx->height;

    ret = av_frame_get_buffer (retval.frame, 0);
    if (ret < 0) {
        fprintf (stderr, "Could not allocate the video frame data\n");
        exit(1);
    }

    return retval;
}

void add_frame (FMVideo v) {
    int ret;

    ret = av_frame_make_writable (v.frame);
    if (ret < 0) {
        exit(1);
    }
}

// staying simple for now
void set_pxl (FMVideo v, int2 p, int3 c) {
    c = rgb2ycrcb(c);

    v.frame->data[0][p.y * v.frame->linesize[0] + p.x] = c.x;
    v.frame->data[1][p.y + v.frame->linesize[1] + p.x] = c.y;
    v.frame->data[2][p.y + v.frame->linesize[2] + p.x] = c.z;
}

void encode (FMVideo v) {
    int ret;
    v.frame->pts = v.counter;

    ret = avcodec_send_frame (v.ctx, v.frame);
    if (ret < 0) {
        fprintf (stderr, "Error sending a frame for encoding\n");
        exit(1);
    }

    while (ret >= 0) {
        ret = avcodec_receive_packet (v.ctx, v.pkt);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            return;
        } else if (ret < 0) {
            fprintf (stderr, "Error during encoding\n");
            exit(1);
        }

        fwrite (v.pkt->data, 1, v.pkt->size, v.f);
        av_packet_unref (v.pkt);
    }
}

void write_and_close (FMVideo v) {
    /* Add sequence end code to have a real MPEG file.
       It makes only sense because this tiny examples writes packets
       directly. This is called "elementary stream" and only works for some
       codecs. To create a valid file, you usually need to write packets
       into a proper file format or protocol; see mux.c.
       */
    if (v.codec->id == AV_CODEC_ID_MPEG1VIDEO || v.codec->id == AV_CODEC_ID_MPEG2VIDEO) {
        fwrite (encode, 1, sizeof(encode), v.f);
    }
    fclose(v.f);

    avcodec_free_context (&v.ctx);
    av_frame_free (&v.frame);
    av_packet_free (&v.pkt);
}
