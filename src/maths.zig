const std = @import("std");

pub fn hypsq (x: f32, y: f32) f32 {
    return x*x + y*y;
}

pub fn vector_angle (x: f32, y: f32) f32 {
    if (y >= 0) {
        return std.math.atan2(y, x);
    } else {
        return std.math.atan2(y, x) + 2*std.math.pi;
    }
}

pub fn max (a: i32, b: i32) i32 {
    if (a > b) {
        return a;
    } else {
        return b;
    }
}

pub fn min (a: i32, b: i32) i32 {
    if (a < b) {
        return a;
    } else {
        return b;
    }
}
