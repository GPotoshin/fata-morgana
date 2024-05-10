#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <libavcodec/avcodec.h>

#include <libavutil/opt.h>
#include <libavutil/imgutils.h>

#include "fata_morgana.h"
#include "fmmath.h"

#define max(a, b) (a > b ? a : b)
#define min(a, b) (a < b ? a : b)

u8 u8_of_int (int x) {
    return x;
}

u32 u32_of_int (int x) {
    return x;
}

void rgb2yuv (u8 c[3]) {
    u8vec3 t;
    t.x = 0.299*c[0] + 0.587*c[1] + 0.114*c[2];
    t.y = -0.168736*c[0] + -0.331264*c[1] + 0.5*c[2] + 128;
    t.z = 0.5*c[0] + -0.418688*c[1] + -0.081312*c[2] + 128;;

    c[0] = t.x;
    c[1] = t.y;
    c[2] = t.z;
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

// function take time as ... but to calculate time I need framerate?
// so I need to add framerate to Ocaml...
// rename it>
void circle (FMVideo *v, float pf[2], u8 c[3], int r, int w, float t, float duration) {
    i32 p[2] = {(pf[0]+1.)*v->ctx->width/2., (1.-pf[0])*v->ctx->height/2.};
    float nframes = (duration * v->ctx->framerate.num) / v->ctx->framerate.den;
    float curframe = (t * v->ctx->framerate.num) / v->ctx->framerate.den;
    int *linesize = v->frame->linesize;
    int height = v->ctx->height;
    int width = v->ctx->width;

    // drawing circle with Box filter
    // strange warning when passing {0x8F, 0xBC, 0xBB} to c?
    // do not see the reason it should clip
    u8 bgc[3];
    for (int x = max(p[0]-r-w, 0); x < min(width, p[0]+r+w); x++) {
        for (int y = max(p[1]-r-w, 0); y < min(height, p[1]+r+w); y++) {
            float sm[3] = {0, 0, 0};
            u8 out_counter = 0;
            bgc[0] = v->frame->data[0][y * linesize[0] + x];
            bgc[1] = v->frame->data[1][y/2 * linesize[1] + x/2];
            bgc[2] = v->frame->data[2][y/2 * linesize[2] + x/2];

            if ((x+0.25-p[0])*(x+0.25-p[0]) + (y+0.125-p[1])*(y+0.125-p[1]) >= (r-w)*(r-w) &&
                    (x+0.25-p[0])*(x+0.25-p[0]) + (y+0.125-p[1])*(y+0.125-p[1]) <= (r+w)*(r+w) &&
                    vector_angle(x+0.25-p[0], y+0.125-p[1]) <= 2*curframe*M_PI/nframes) {
                sm[0] += 0.25 * c[0];
                sm[1] += 0.25 * c[1];
                sm[2] += 0.25 * c[2];
            } else {
                out_counter++;
                sm[0] += 0.25 * bgc[0];
                sm[1] += 0.25 * bgc[1];
                sm[2] += 0.25 * bgc[2];
            }

            if ((x+0.125-p[0])*(x+0.125-p[0]) + (y+0.75-p[1])*(y+0.75-p[1]) >= (r-w)*(r-w) &&
                    (x+0.125-p[0])*(x+0.125-p[0]) + (y+0.75-p[1])*(y+0.75-p[1]) <= (r+w)*(r+w)&&
                    vector_angle(x+0.125-p[0], y+0.75-p[1]) <= 2*curframe*M_PI/nframes) {
                sm[0] += 0.25 * c[0];
                sm[1] += 0.25 * c[1];
                sm[2] += 0.25 * c[2];
            } else {
                out_counter++;
                sm[0] += 0.25 * bgc[0];
                sm[1] += 0.25 * bgc[1];
                sm[2] += 0.25 * bgc[2];
            }
            if ((x+0.75-p[0])*(x+0.75-p[0]) + (y+0.875-p[1])*(y+0.875-p[1]) >= (r-w)*(r-w) &&
                    (x+0.75-p[0])*(x+0.75-p[0]) + (y+0.875-p[1])*(y+0.875-p[1]) <= (r+w)*(r+w) &&
                    vector_angle(x+0.75-p[0], y+0.825-p[1]) <= 2*curframe*M_PI/nframes) {
                sm[0] += 0.25 * c[0];
                sm[1] += 0.25 * c[1];
                sm[2] += 0.25 * c[2];
            } else {
                out_counter++;
                sm[0] += 0.25 * bgc[0];
                sm[1] += 0.25 * bgc[1];
                sm[2] += 0.25 * bgc[2];
            }
            if ((x+0.875-p[0])*(x+0.875-p[0]) + (y+0.25-p[1])*(y+0.25-p[1]) >= (r-w)*(r-w) &&
                    (x+0.875-p[0])*(x+0.875-p[0]) + (y+0.25-p[1])*(y+0.25-p[1]) <= (r+w)*(r+w) &&
                    vector_angle(x+0.875-p[0], y+0.25-p[1]) <= 2*curframe*M_PI/nframes) {
                sm[0] += 0.25 * c[0];
                sm[1] += 0.25 * c[1];
                sm[2] += 0.25 * c[2];
            } else {
                out_counter++;
                sm[0] += 0.25 * bgc[0];
                sm[1] += 0.25 * bgc[1];
                sm[2] += 0.25 * bgc[2];
            }
            if (out_counter == 4) {
                continue;
            }
            if (sm[0] > 255 || sm[1] > 255 || sm[2] > 255 ||
                    sm[0] < -255 || sm[1] < -255 || sm[2] < -255) {
                printf("%f, %f, %f\n", sm[0], sm[1], sm[2]);
            }

            v->frame->data[0][y * linesize[0] + x] = sm[0];
            if ((x&1)==0 && (y&1)==0) {
                v->frame->data[1][y/2 * linesize[1] + x/2] = sm[1];
                v->frame->data[2][y/2 * linesize[2] + x/2] = sm[2];
            }
        }
    }

}

void paint_background (FMVideo *v, u8 bgc[3]) {
    int *linesize = v->frame->linesize; 
    for (int y = 0; y < v->ctx->height; y++) {
        for (int x = 0; x < v->ctx->width; x++) {
            v->frame->data[0][y * linesize[0] + x] = bgc[0];
            v->frame->data[1][y/2 * linesize[1] + x/2] = bgc[1];
            v->frame->data[2][y/2 * linesize[2] + x/2] = bgc[2];
        }
    }
}
