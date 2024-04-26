#include <libavutil/opt.h>
#include <libavutil/imgutils.h>

#include "video.h"
#include <math.h>

const int HEIGHT = 480/2;
const int WIDTH = 720/2;

int main () {
    FMVideo *v = init ("test.mpeg", WIDTH, HEIGHT);

    
    u8 bg[3] = {0x2E, 0x34, 0x40};
    rgb2yuv(bg);
    u8 c[3] = {0x8F, 0xBC, 0xBB};
    rgb2yuv(c);

    u32 p[2] = {100, 100};

    circle (v, p, bg, c, 50, 5, 1.);
    write_and_close (v);
}

