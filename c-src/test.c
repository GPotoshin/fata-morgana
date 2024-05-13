#include <libavutil/opt.h>
#include <libavutil/imgutils.h>

#include "fata_morgana.h"

const int HEIGHT = 480/2;
const int WIDTH = 720/2;

int main () {
    FMVideo *v = init ("test.mpeg", WIDTH, HEIGHT);

    
    u8 bg[3] = {0x2E, 0x34, 0x40};
    u8 c[3] = {0xEC, 0xEF, 0xF4};
    rgb2yuv(c);
    rgb2yuv(bg);
    printf("c: %d, %d, %d\n", bg[0], bg[1], bg[2]);

    float p[2] = {0, 0};
    u32 str[] = {'H', 'e', 'l', 'l', 'o', '?'};

    for (int i = 0; i < 30; i++) {
        add_frame(v);
        paint_background(v, bg);
        float p2[2] = {-0.7, -0.7};
        write_text(v, p2, c, c, str, 6, 6*2, i);
        encode(v);
    }

    write_and_close (v);
}

