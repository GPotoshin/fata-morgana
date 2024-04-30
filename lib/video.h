#ifndef FM_VIDEO_H
#define FM_VIDEO_H

#include <libavcodec/avcodec.h>
#include "rusty_int.h"

typedef struct {
    u32 x, y;
} u32vec2;

typedef struct {
    u8 x,y,z;
} u8vec3;

typedef struct {
    FILE *f;

    AVCodecContext *ctx;

    const AVCodec *codec;
    AVFrame *frame;
    AVPacket *pkt;
    u32 counter;
} FMVideo;

// for ocaml
u8 u8_of_int (int x);
u32 u32_of_int (int x);

void rgb2yuv (u8 c[3]);
FMVideo *init (char *name, int width, int height);
void add_frame (FMVideo *v);
void set_pxl (FMVideo *v, u32 p[3], u8 c[2]);
void encode (FMVideo *v);
void write_and_close (FMVideo *v);

void circle (FMVideo *v, u32 p[2], u8 bgc[3], u8 c[3], int r, int w, float t);
void write_text (FMVideo *v, u32 p[2], u8 c[3], char str[], int len);
#endif
