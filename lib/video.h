#ifndef FM_VIDEO_H
#define FM_VIDEO_H

#include <libavcodec/avcodec.h>
#include "rusty_int.h"

typedef struct {
    FILE *f;

    AVCodecContext *ctx;

    const AVCodec *codec;
    AVFrame *frame;
    AVPacket *pkt;
    u32 counter;
} FMVideo;

void encode (FMVideo v);

#endif
