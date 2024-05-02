#include <libavutil/opt.h>
#include <libavutil/imgutils.h>

#include "video.h"

const int HEIGHT = 480/2;
const int WIDTH = 720/2;

int main () {
    FMVideo *v = init ("test.mpeg", WIDTH, HEIGHT);

    
    u8 bg[3] = {0x2E, 0x34, 0x40};
    u8 c[3] = {0x8F, 0xBC, 0xBB};

    u32 p[2] = {100, 100};

    printf ("writing circle\n");
    circle (v, p, bg, c, 50, 5, 1.);
    printf ("writing text\n");
    p[0] = 200;
    p[1] = 200;
    u32 str[] = {'H', 'e', 'l', 'l', 'o', '!'};
    write_text (v, p, bg, c, str, 6);
    write_text (v, p, bg, c, str, 6);
    write_text (v, p, bg, c, str, 6);
    write_text (v, p, bg, c, str, 6);
    write_and_close (v);
}

