#include <libavutil/opt.h>
#include <libavutil/imgutils.h>

#include "video.h"
#include <math.h>

const int HEIGHT = 480/2;
const int WIDTH = 720/2;

int main () {
    FMVideo *v = init ("test.mpeg", WIDTH, HEIGHT);

    
    u8 bg[3] = {0x2E, 0x34, 0x40};
    u8 c[3] = {0x8F, 0xBC, 0xBB};

    for (int i = 0; i < 50; i++) {
        add_frame (v);
        for (int y = 0; y < HEIGHT*2; y++) {
            for (int x = 0; x < WIDTH*2; x++) {
                u32 p[2] = {x, y};
                set_pxl(v, p, c);
                // (127, 127, 127) -> 8b8d8a
                // (0, 0, 0) -> 255811
                // (255, 0, 0) -> 73F440
                // (0, 0, 255) -> d7322d
                // (0, 255, 0) -> 0e35c2
                // v.frame->data[0][y * v.frame->linesize[0] + x] = 0;
                // v.frame->data[1][y/2 * v.frame->linesize[1] + x/2] = 225;
                // v.frame->data[2][y/2 * v.frame->linesize[2] + x/2] = 0;
            }
        }


        for (float a = 0; a < (i+1)*2.*M_PI/500; a += M_PI/1000.) {
            for (int r = 0; r < 20 ; r++) {
                u32 p[2] = {360+(100+r)*cos(a), 240+(100+r)*sin(a)};
                set_pxl(v, p, c);
            }
        }

        encode (v);
    }
    write_and_close (v);
}

