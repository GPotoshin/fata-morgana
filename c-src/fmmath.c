#include <math.h>

float vector_angle (int x, int y) {
    if (y >= 0) {
        return atan2(y,x);
    } else {
        return atan2(y,x)+2*M_PI;
    }
}
