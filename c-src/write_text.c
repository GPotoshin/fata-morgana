#include "fata_morgana.h"
#include "fmmath.h"
#include <ft2build.h>
#include <freetype/freetype.h>

#define max(a, b) (a>b ? a : b)
#define min(a, b) (a<b ? a : b)

u8 read_with_borders(i32 x, i32 y, i32 w, i32 h, u8 *a) {
    if (x < 0 || y < 0 || x >= w || y >= h) {
        return 0;
    } else {
        return a[y*w + x];
    }
}

void calculate_borders (u8 *out, FT_Bitmap in) {
    int M = 0;
    for (int x = 0; x < in.width+2; x++) {
        for (int y = 0; y < in.rows+2; y++) {
            float m1 = 0;
            float m2 = 0;
            m1 += read_with_borders   (x-2, y-2, in.width, in.rows, in.buffer);
            m1 += 2*read_with_borders (x-1, y-2, in.width, in.rows, in.buffer);
            m1 += read_with_borders   (x,   y-2, in.width, in.rows, in.buffer);
            m1 -= read_with_borders   (x-2, y, in.width, in.rows, in.buffer);
            m1 -= 2*read_with_borders (x-1, y, in.width, in.rows, in.buffer);
            m1 -= read_with_borders   (x,   y, in.width, in.rows, in.buffer);
            m2 += read_with_borders   (x-2, y-2, in.width, in.rows, in.buffer);
            m2 += 2*read_with_borders (x-2, y-1, in.width, in.rows, in.buffer);
            m2 += read_with_borders   (x-2, y,   in.width, in.rows, in.buffer);
            m2 -= read_with_borders   (x, y-2, in.width, in.rows, in.buffer);
            m2 -= 2*read_with_borders (x, y-1, in.width, in.rows, in.buffer);
            m2 -= read_with_borders   (x, y,   in.width, in.rows, in.buffer);
            out[y*(in.width+2) + x] = hypotf(m1/8., m2/8.)/1.41421356;
            M = max(out[y*(in.width+2) + x], M);
        }
    }
    for (int x = 0; x < in.width+2; x++) {
        for (int y = 0; y < in.rows+2; y++) {
            out[y*(in.width+2) + x] = out[y*(in.width+2) + x] * 255./M;
        }
    }
}

void write_text (FMVideo *v, float pf[2], u8 c[3], u8 fg[3], u32 str[], int len, int frames, int frame) {
    i32 p[2] = {(pf[0]+1.)*v->ctx->width/2., (1.-pf[0])*v->ctx->height/2.};
    FT_Library lib;
    FT_Face face;
    int err = FT_Init_FreeType(&lib);
    if (err) {
        puts("... an error occurred during library initialization ...");
        return;
    }
    err = FT_New_Face(lib, "/Users/giorno/Library/Fonts/Euler-Math.otf", 0, &face);    
    if (err == FT_Err_Unknown_File_Format) {
        puts("... the font file could be opened and read, but it appears\n"
                "... that its font format is unsupported");
        return;
    } else if (err) {
        puts("font file could not be opened or read, or it is broken");
        return;
    }
    err = FT_Set_Char_Size (face, 0, 16*64, 300, 300);
    if (err) {
        puts("couldn't set char size");
        return;
    }

    FT_UInt old_index = 0;
    int pen_x = 0;
    int pen_y = 0;
    // converting relative position to absolute
    float tick = ((float)frames)/(len+4);
    int tick_number = frame/tick;
    // tick+1 as it's drawing tick's charcter
    for (int i = 0; i < min(len, tick_number+1); i++) {
        FT_UInt glyph_index = FT_Get_Char_Index(face, str[i]);
        err = FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT);
        if (err) {
            puts("couldn't load a glyph");
            return;
        }

        if (i > 0) {
            FT_Vector kerning;
            err = FT_Get_Kerning(face, old_index, glyph_index, FT_KERNING_DEFAULT, &kerning);
            if (err) {
                puts("error in defining kerning");
                return;
            }
            pen_x += kerning.x >> 6;
        }

        err = FT_Render_Glyph(face->glyph, FT_RENDER_MODE_NORMAL);
        if (err) {
            puts("error in rendering");
            return;
        }

        int *linesize = v->frame->linesize;
        FT_Bitmap bitmap = face->glyph->bitmap;
        if (i < tick_number-4) {
            // showing letters
            // printf("drawn (i: %d, tn: %d)\n", i, tick_number);
            for (int x = 0; x < bitmap.width; x++) {
                for (int y = 0; y < bitmap.rows; y++) {
                    float m = bitmap.buffer[y*bitmap.width + x]/255.;
                    u8 bg[3];

                    size_t pos[3];
                    pos[0] = (y+p[1]+pen_y-face->glyph->bitmap_top) *
                        linesize[0] + (x+p[0]+pen_x+face->glyph->bitmap_left);
                    pos[1] = (y+p[1]+pen_y-face->glyph->bitmap_top)/2 *
                        linesize[1] + (x+p[0]+pen_x+face->glyph->bitmap_left)/2;
                    pos[2] = (y+p[1]+pen_y-face->glyph->bitmap_top)/2 *
                        linesize[2] + (x+p[0]+pen_x+face->glyph->bitmap_left)/2;

                    bg[0] = v->frame->data[0][pos[0]];
                    bg[1] = v->frame->data[1][pos[1]];
                    bg[2] = v->frame->data[2][pos[2]];

                    int yr = c[0]*m + bg[0]*(1-m);
                    int ur = c[1]*m + bg[1]*(1-m);
                    int vr = c[2]*m + bg[2]*(1-m);
                    v->frame->data[0][pos[0]] = yr;
                    if ((x&1)==0 && (y&1)==0) {
                        v->frame->data[1][pos[1]] = ur;
                        v->frame->data[2][pos[2]] = vr;
                    }
                }
            }
        } else if (i > tick_number-4 && i <= tick_number) {
            // calculating borders
            // printf ("border appearence (i: %d, tn: %d)\n", i, tick_number);
            u8 *borders = malloc((bitmap.width+2)*(bitmap.rows+2));
            if (!borders) {
                free(borders);
                puts("Out of memory for borders");
                return;
            }

            calculate_borders (borders, bitmap);
            for (int x = 0; x < bitmap.width+2; x++) {
                for (int y = 0; y < bitmap.rows+2; y++) {
                    float angle_coef = (frame-i*tick)/(4.*tick);
                    float border_coef = borders[y*(bitmap.width+2) + x]/255.;
                    u8 bg[3];

                    size_t pos[3];
                    pos[0] = (y+p[1]+pen_y-face->glyph->bitmap_top-1) *
                        linesize[0] + (x+p[0]+pen_x+face->glyph->bitmap_left-1);
                    pos[1] = (y+p[1]+pen_y-face->glyph->bitmap_top-1)/2 *
                        linesize[1] + (x+p[0]+pen_x+face->glyph->bitmap_left-1)/2;
                    pos[2] = (y+p[1]+pen_y-face->glyph->bitmap_top-1)/2 *
                        linesize[2] + (x+p[0]+pen_x+face->glyph->bitmap_left-1)/2;

                    bg[0] = v->frame->data[0][pos[0]];
                    bg[1] = v->frame->data[1][pos[1]];
                    bg[2] = v->frame->data[2][pos[2]];

                    int yr = fg[0]*border_coef+ bg[0]*(1-border_coef);
                    int ur = fg[1]*border_coef+ bg[1]*(1-border_coef);
                    int vr = fg[2]*border_coef+ bg[2]*(1-border_coef);
                    if (M_PI/2. - vector_angle(x, y) <= M_PI/2.*angle_coef) {
                        v->frame->data[0][pos[0]] = yr;
                        if ((x&1)==0 && (y&1)==0) {
                            v->frame->data[1][pos[1]] = ur;
                            v->frame->data[2][pos[2]] = vr;
                        }
                    }
                }
            }
            free(borders);
        } else if (i == tick_number-4) {
            // calculating borders
            // printf ("borders+shade in (i: %d, tn: %d)\n", i, tick_number);
            
            u8 *borders = malloc((bitmap.width+2)*(bitmap.rows+2));
            if (!borders) {
                free(borders);
                puts("Out of memory for borders");
                return;
            }

            calculate_borders (borders, bitmap);
            for (int x = 0; x < bitmap.width+2; x++) {
                for (int y = 0; y < bitmap.rows+2; y++) {
                    float filling_to_border = (frame-tick_number*tick)/tick;
                    float filling_coef = filling_to_border*read_with_borders(x-1,
                            y-1, bitmap.width, bitmap.rows, bitmap.buffer)/255.;
                    float border_coef = (1.-filling_to_border)*borders[y*(bitmap.width+2) + x]/255.;
                    float bg_coef = 1. - (filling_coef + border_coef);
                    u8 bg[3];

                    size_t pos[3];
                    pos[0] = (y+p[1]+pen_y-face->glyph->bitmap_top-1) *
                        linesize[0] + (x+p[0]+pen_x+face->glyph->bitmap_left-1);

                    pos[1] = (y+p[1]+pen_y-face->glyph->bitmap_top-1)/2 *
                        linesize[1] + (x+p[0]+pen_x+face->glyph->bitmap_left-1)/2;

                    pos[2] = (y+p[1]+pen_y-face->glyph->bitmap_top-1)/2 *
                        linesize[2] + (x+p[0]+pen_x+face->glyph->bitmap_left-1)/2;

                    bg[0] = v->frame->data[0][pos[0]];
                    bg[1] = v->frame->data[1][pos[1]];
                    bg[2] = v->frame->data[2][pos[2]];

                    int yr = c[0]*filling_coef+ fg[0]*border_coef+ bg[0]*bg_coef;
                    int ur = c[1]*filling_coef+ fg[1]*border_coef+ bg[1]*bg_coef;
                    int vr = c[2]*filling_coef+ fg[2]*border_coef+ bg[2]*bg_coef;
                    v->frame->data[0][pos[0]] = yr;
                    if ((x&1)==0 && (y&1)==0) {
                        v->frame->data[1][pos[1]] = ur;
                        v->frame->data[2][pos[2]] = vr;
                    }
                }
            }
            free(borders);
        }
        pen_x += face->glyph->advance.x>>6;
        pen_y += face->glyph->advance.y>>6;
        old_index = glyph_index;
    }
}
