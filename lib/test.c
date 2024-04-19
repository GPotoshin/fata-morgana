#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <libavutil/opt.h>
#include <libavutil/imgutils.h>

#include "video.h"

const int HEIGHT = 480;
const int WIDTH = 720;

int main (int argc, char **argv) {
    const char *filename, *codec_name;
    const AVCodec *codec;
    AVCodecContext *c = NULL;
    int i, ret, x, y;
    FILE *f;
    AVFrame *frame;
    AVPacket *pkt;
    uint8_t endcode[] = {0, 0, 1, 0xb7};

    if (argc <= 2) {
        fprintf (stderr, "Usage: %s <output file> <codec name>", argv[0]);
        exit(0);
    }
    filename = argv[1];
    codec_name = argv[2];

    /* find the mpeg1video encoder */
    codec = avcodec_find_encoder_by_name (codec_name);
    if (!codec) {
        fprintf (stderr, "Codec '%s' not found\n", codec_name);
        exit(1);
    }

    c = avcodec_alloc_context3 (codec);
    if (!c) {
        fprintf (stderr, "Could not allocate video codec context\n");
        exit(1);
    }
    pkt = av_packet_alloc();
    if (!pkt) {
        exit(1);
    }

    // put sample parameters
    c->bit_rate = 400000;
    // resolution must be a multiple of two
    c->width = WIDTH*2;
    c->height = HEIGHT*2;
    // frames per second
    c->time_base = (AVRational){1, 25};
    c->framerate = (AVRational){25, 1};

    /* emit one intra frame every ten frames
     * check frame pict_type before passing frame
     * to encoder, if frame->pict_type is AV_PICTURE_TYPE_I
     * then gop_size is ignored and the output of encoder
     * will always be I frame irrepective to gop_size
     */

    c->gop_size = 10;
    c->max_b_frames = 1;
    c->pix_fmt = AV_PIX_FMT_YUV420P;

    if (codec->id == AV_CODEC_ID_H264) {
        av_opt_set (c->priv_data, "preset", "slow", 0);
    }

    /* open it */
    ret = avcodec_open2 (c, codec, NULL);
    if (ret < 0) {
        fprintf (stderr, "Could not open codec: %s\n", av_err2str (ret));
        exit(1);
    }

    f = fopen (filename, "wb");
    if (!f) {
        fprintf (stderr, "Cloud not open %s\n", filename);
        exit(1);
    }

    frame = av_frame_alloc();
    if (!frame) {
        fprintf (stderr, "Could not sllocate video frame\n");
        exit(1);
    }
    frame->format = c->pix_fmt;
    frame->width = c->width;
    frame->height = c->height;

    ret = av_frame_get_buffer (frame, 0);
    if (ret < 0) {
        fprintf (stderr, "Could not allocate the video frame data\n");
        exit(1);
    }

    for (i = 0; i < 100; i++) {
        fflush (stdout);
        /* Make sure the frame data is writable.
           On the first round, the frame is fresh from av_frame_get_buffer()
           and therefore we know it is writable.
           But on the next rounds, encode() will have called
           avcodec_send_frame(), and the codec may have kept a reference to
           the frame in its internal structures, that makes the frame
           unwritable.
           av_frame_make_writable() checks that and allocates a new buffer
           for the frame only if necessary.
         */
        ret = av_frame_make_writable (frame);
        if (ret < 0) {
            exit(1);
        }

        for (y = 0; y < c->height; y++) {
            for (x = 0; x < c->width; x++) {
                if (10 <= y && y <= 10 && 40 <= x && x <= 60) {
                    frame->data[0][y * frame->linesize[0] + x] = 200;
                }
                else {
                    frame->data[0][y * frame->linesize[0] + x] = 0;
                }
            }
        }

        for (y = 0; y < c->height/2; y++) {
            for (x = 0; x < c->width/2; x++) {
                frame->data[1][y * frame->linesize[1] + x] = 128 + y + i * 2;
                frame->data[2][y * frame->linesize[2] + x] = 64 + x + i * 5;
            }
        }

        frame->pts = i;

        /* encode the image */
        encode (c, frame, pkt, f);
    }
    /* Add sequence end code to have a real MPEG file.
       It makes only sense because this tiny examples writes packets
       directly. This is called "elementary stream" and only works for some
       codecs. To create a valid file, you usually need to write packets
       into a proper file format or protocol; see mux.c.
       */
    if (codec->id == AV_CODEC_ID_MPEG1VIDEO || codec->id == AV_CODEC_ID_MPEG2VIDEO) {
        fwrite (endcode, 1, sizeof(endcode), f);
    }
    fclose(f);

    avcodec_free_context (&c);
    av_frame_free (&frame);
    av_packet_free (&pkt);

    return 0;
}

