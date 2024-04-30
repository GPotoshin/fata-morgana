#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <libavcodec/avcodec.h>

#include <libavutil/opt.h>
#include <libavutil/imgutils.h>

#include "video.h"
#include "../libschrift/schrift.h"
#include "../libschrift/util/utf8_to_utf32.h"

const double Kr = 0.299;
const double Kg = 0.587;
const double Kb = 0.114;

#define max(a, b) (a > b ? a : b)
#define min(a, b) (a < b ? a : b)

float vector_angle (int x, int y) {
    if (y >= 0) {
        return atan2(y,x);
    } else {
        return atan2(y,x)+2*M_PI;
    }
}

u8 u8_of_int (int x) {
    return x;
}

u32 u32_of_int (int x) {
    return x;
}

void rgb2yuv (u8 c[3]) {
    u8vec3 t;
    t.x = Kr*c[0] + Kg*c[1] + Kr*c[2];
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

// staying simple for now
void set_pxl (FMVideo *v, u32 p[2], u8 c[3]) {
    rgb2yuv (c);

    v->frame->data[0][p[1] * v->frame->linesize[0] + p[0]] = c[0];
    v->frame->data[1][p[1]/2 * v->frame->linesize[1] + p[0]/2] = c[1];
    v->frame->data[2][p[1]/2 * v->frame->linesize[2] + p[0]/2] = c[2];
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

void circle (FMVideo *v, u32 p[2], u8 bgc[3], u8 c[3], int r, int w, float t) {
    float nframes = (t * v->ctx->framerate.num) / v->ctx->framerate.den;
    int *linesize = v->frame->linesize;
    int height = v->ctx->height;
    int width = v->ctx->width;
    rgb2yuv(c);
    rgb2yuv(bgc);


    for (int i = 0; i < nframes; i++) {
        add_frame(v);
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                v->frame->data[0][y * linesize[0] + x] = bgc[0];
                v->frame->data[1][y/2 * linesize[1] + x/2] = bgc[1];
                v->frame->data[2][y/2 * linesize[2] + x/2] = bgc[2];
            }
        }
        // drawing circle with Box filter
        // strange warning when passing {0x8F, 0xBC, 0xBB} to c?
        // do not see the reason it should clip
        for (int x = max(p[0]-r-w, 0); x < min(width, p[0]+r+w); x++) {
            for (int y = max(p[1]-r-w, 0); y < min(height, p[1]+r+w); y++) {
                float sm[3] = {0, 0, 0};
                u8 out_counter = 0;

                if ((x+0.25-p[0])*(x+0.25-p[0]) + (y+0.125-p[1])*(y+0.125-p[1]) >= (r-w)*(r-w) &&
                        (x+0.25-p[0])*(x+0.25-p[0]) + (y+0.125-p[1])*(y+0.125-p[1]) <= (r+w)*(r+w) &&
                        vector_angle(x+0.25-p[0], y+0.125-p[1]) <= 2.3*i*M_PI/(nframes-1)) {
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
                        vector_angle(x+0.125-p[0], y+0.75-p[1]) <= 2.3*i*M_PI/(nframes-1)) {
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
                        vector_angle(x+0.75-p[0], y+0.825-p[1]) <= 2.3*i*M_PI/(nframes-1)) {
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
                        vector_angle(x+0.875-p[0], y+0.25-p[1]) <= 2.3*i*M_PI/(nframes-1)) {
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

                v->frame->data[0][y * linesize[0] + x] = sm[0];
                v->frame->data[1][y/2 * linesize[1] + x/2] = sm[1];
                v->frame->data[2][y/2 * linesize[2] + x/2] = sm[2];
            }
        }

        encode (v);
    }
}

void write_text (FMVideo *v, u32 p[2], u8 c[3], char str[], int len) {
    add_frame(v);
    int *linesize = v->frame->linesize;

    SFT sft = {
        .xScale = 16,
        .yScale = 16,
        .flags  = SFT_DOWNWARD_Y,
    };
    char font_name[] = "APL386B.ttf";

    sft.font = sft_loadfile(font_name);
    if (sft.font == NULL) {
        printf ("Couldn't fing font %s\n", font_name);
        exit(1);
    }
    puts ("font is loaded\n");

    unsigned *codepoints = malloc (len*sizeof(unsigned));
    utf8_to_utf32 ((const u8 *)str, codepoints, len);
    puts ("to utf32 converted\n");

    for (int i = 0; i < len; i++) {
        SFT_Glyph gid;
        if (sft_lookup(&sft, codepoints[i], &gid) < 0) {
            printf ("Missing 0x%04X\n", codepoints[i]); 
            exit(1);
        }
        puts ("glyph is found\n");

        SFT_GMetrics mtx;
        if (sft_gmetrics(&sft, gid, &mtx) < 0) {
            printf ("bad glyph metrics 0x%04X\n", codepoints[i]);
            exit(1);
        }
        puts ("metrics is calculated\n");

        SFT_Image img = {
            .width = (mtx.minWidth + 3) & ~3,
            .height = mtx.minHeight
        };
        u8 *pixels = malloc (img.width * img.height);
        img.pixels = pixels;
        if (sft_render(&sft, gid, img) < 0) {
            printf ("not rendered 0x%04X\n", codepoints[i]);
            exit(1);
        }
        puts ("pixels are rendered\n");

        for (int x = 0; x < img.width; x++) {
            for (int y = 0; y < img.height; y++) {
                float m = ((u8 *)img.pixels)[y*img.width + x]/255.;
                v->frame->data[0][(y+p[1]) * linesize[0] + (x+p[0])] = c[0]*m;
                v->frame->data[1][(y+p[1])/2 * linesize[1] + (x+p[0])/2] = c[1];
                v->frame->data[2][(y+p[1])/2 * linesize[2] + (x+p[0])/2] = c[2];
            }
        }

        free (pixels);
    }
    encode(v);
    sft_freefont(sft.font);
}
