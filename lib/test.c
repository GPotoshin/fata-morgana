#include <libavutil/opt.h>
#include <libavutil/imgutils.h>

#include "video.h"

const int HEIGHT = 480/2;
const int WIDTH = 720/2;

int main () {
    FMVideo *v = init ("test.mpeg", WIDTH, HEIGHT);

    
    u8 bg[3] = {0x2E, 0x34, 0x40};
    u8 c[3] = {0xEC, 0xEF, 0xF4};
    printf("c: %d, %d, %d\n", c[0], c[1], c[2]);
    rgb2yuv(c);
    rgb2yuv(bg);
    printf("c: %d, %d, %d\n", c[0], c[1], c[2]);

    u32 p[2] = {100, 100};

    paint_background(v, bg);
    paint_background(v, bg);
    paint_background(v, bg);
    circle(v, p, bg, c, 50, 5, 2.);
    p[0] = 200;
    p[1] = 200;
    u32 str[] = {'H', 'e', 'l', 'l', 'o', '!'};
    write_text (v, p, bg, c, str, 6);
    write_text (v, p, bg, c, str, 6);
    write_text (v, p, bg, c, str, 6);
    write_text (v, p, bg, c, str, 6);
    write_and_close (v);
}

