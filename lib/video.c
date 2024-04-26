#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <libavcodec/avcodec.h>

#include <libavutil/opt.h>
#include <libavutil/imgutils.h>

#include "video.h"

const double Kr = 0.299;
const double Kg = 0.587;
const double Kb = 0.114;

u8 u8_of_int (int x) {
    return x;
}

u32 u32_of_int (int x) {
    return x;
}

u8vec3 rgb2yuv (u8vec3 c) {
    u8vec3 retval;
    retval.x = Kr*c.x + Kg*c.y + Kr*c.z;
    retval.y = -0.168736*c.x + -0.331264*c.y + 0.5*c.z + 128;
    retval.z = 0.5*c.x + -0.418688*c.y + -0.081312*c.z + 128;;
    return retval;
}

FMVideo *init (char* name, int width, int height) {
    FMVideo *retval = malloc (sizeof(FMVideo));
    if (!retval) {
        puts("No ram for fmvideo\n");
        exit(1);
    }
    int ret;
    retval->counter = 0;

    const char *codec_name = "mpeg1video";

    retval->codec = avcodec_find_encoder_by_name(codec_name);
    if (!retval->codec) {
        fprintf (stderr, "Codec '%s' not found\n", codec_name);
        exit(1);
    }

    retval->ctx = avcodec_alloc_context3(retval->codec);
    if (!retval->ctx) {
        fprintf (stderr, "Could not allocate video codec context\n");
        exit(1);
    }

    retval->pkt = av_packet_alloc();
    if (!retval->pkt) {
        fprintf (stderr, "Could not allocate video packet\n");
        exit(1);
    }

    // put sample parameters
    retval->ctx->bit_rate = 400000;
    // resolution must be a multiple of two
    retval->ctx->width = width*2;
    retval->ctx->height = height*2;
    // frames per second
    retval->ctx->time_base = (AVRational){1, 25};
    retval->ctx->framerate = (AVRational){25, 1};

    /* emit one intra frame every ten frames
     * check frame pict_type before passing frame
     * to encoder, if frame->pict_type is AV_PICTURE_TYPE_I
     * then gop_size is ignored and the output of encoder
     * will always be I frame irrepective to gop_size
     */

    retval->ctx->gop_size = 10;
    retval->ctx->max_b_frames = 1;
    retval->ctx->pix_fmt = AV_PIX_FMT_YUV420P;

    if (retval->codec->id == AV_CODEC_ID_H264) {
        av_opt_set (retval->ctx->priv_data, "preset", "slow", 0);
    }

    /* open it */
    ret = avcodec_open2 (retval->ctx, retval->codec, NULL);
    if (ret < 0) {
        fprintf (stderr, "Could not open codec: %s\n", av_err2str (ret));
        exit(1);
    }

    retval->f = fopen (name, "wb");
    if (!retval->f) {
        fprintf (stderr, "Cloud not open %s\n", name);
        exit(1);
    }

    retval->frame = av_frame_alloc();
    if (!retval->frame) {
        fprintf (stderr, "Could not sllocate video frame\n");
        exit(1);
    }
    retval->frame->format = retval->ctx->pix_fmt;
    retval->frame->width = retval->ctx->width;
    retval->frame->height = retval->ctx->height;

    ret = av_frame_get_buffer (retval->frame, 0);
    if (ret < 0) {
        fprintf (stderr, "Could not allocate the video frame data\n");
        exit(1);
    }

    return retval;
}

void add_frame (FMVideo *v) {
    int ret;
    v->counter++;

    ret = av_frame_make_writable (v->frame);
    if (ret < 0) {
        exit(1);
    }
}

// staying simple for now
void set_pxl (FMVideo *v, u32 p[2], u8 b[3]) {
    u8vec3 c = (u8vec3){b[0], b[1], b[2]};
    c = rgb2yuv (c);

    v->frame->data[0][p[1] * v->frame->linesize[0] + p[0]] = c.x;
    v->frame->data[1][p[1]/2 * v->frame->linesize[1] + p[0]/2] = c.y;
    v->frame->data[2][p[1]/2 * v->frame->linesize[2] + p[0]/2] = c.z;
}

void encode (FMVideo *v) {
    int ret;
    v->frame->pts = v->counter;
    // printf ("frame->pts %lld, countert %d\n", v.frame->pts, v.counter);

    ret = avcodec_send_frame (v->ctx, v->frame);
    if (ret < 0) {
        fprintf (stderr, "Error sending a frame for encoding\n");
        exit(1);
    }

    while (ret >= 0) {
        ret = avcodec_receive_packet (v->ctx, v->pkt);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            return;
        } else if (ret < 0) {
            fprintf (stderr, "Error during encoding\n");
            exit(1);
        }

        fwrite (v->pkt->data, 1, v->pkt->size, v->f);
        av_packet_unref (v->pkt);
    }
}

void write_and_close (FMVideo *v) {
    uint8_t endcode[] = {0, 0, 1, 0xb7};
    /* Add sequence end code to have a real MPEG file.
       It makes only sense because this tiny examples writes packets
       directly. This is called "elementary stream" and only works for some
       codecs. To create a valid file, you usually need to write packets
       into a proper file format or protocol; see mux.c.
       */
    if (v->codec->id == AV_CODEC_ID_MPEG1VIDEO || v->codec->id == AV_CODEC_ID_MPEG2VIDEO) {
        fwrite (endcode, 1, sizeof(endcode), v->f);
    }
    fclose(v->f);

    avcodec_free_context (&v->ctx);
    av_frame_free (&v->frame);
    av_packet_free (&v->pkt);
}

void circle (FMVideo *v, u32 p[2], u8 bgc[3], u8 c[3], u32 r, u32 w, float t) {
    int nframes = t * v->ctx->framerate.den / v->ctx->framerate.num;
    int *linesize = v->frame->linesize;
    int height = v->ctx->height;
    int width = v->ctx->width;

    u8 **data = v->frame->data;
    for (int i = 0; i < nframes; i++) {
        add_frame(v);
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                data[0][y * linesize[0] + x] = bgc[0];
                data[1][y/2 * linesize[1] + x/2] = bgc[1];
                data[2][y/2 * linesize[2] + x/2] = bgc[2];
            }
        }
        for (float a = 0; a < (1+i)*2.*M_PI/nframes; a += 1./(r+w)) {
            for (int d = -w*0.5; d < w*0.5; d++) {
                u32 x = p[0]+(r+d)*cos(a);
                u32 y = p[1]+(r+d)*cos(a);
                if (x >= width || y >= height) {
                    continue;
                }

                data[0][y * linesize[0] + x] = c[0];
                data[1][y/2 * linesize[1] + x/2] = c[1];
                data[2][y/2 * linesize[2] + x/2] = c[2];
            }
        }

        // 0.0625 0.5
        for (int y = 0; y < height/2; y++) {
            for (int x = 0; x < width/2; x++) {
                u8 sm[3] = {0,0,0};
                float mask[3][3] =
                    {1./16, 1./16, 1./16,
                     1./16, 1./2 , 1./16,
                     1./16, 1./16, 1./16};
                for (int xx = -1; xx < 2; xx++) {
                    for (int yy = -1; yy < 2; yy++) {
                        if (xx+x<0||xx+x>=width/2||yy+y<0||yy+y>=height/2) {
                            continue;
                        }

                        sm[0] += data[0][2*(y+yy)*linesize[0] + 2*(x+xx)] * mask[1+yy][1+xx];
                        sm[1] += data[1][(y+yy)*linesize[1] + (x+xx)] * mask[1+yy][1+xx];
                        sm[2] += data[2][(y+yy)*linesize[2] + (x+xx)] * mask[1+yy][1+xx];
                    }
                }
            }
        }
        encode (v);
    }
}
