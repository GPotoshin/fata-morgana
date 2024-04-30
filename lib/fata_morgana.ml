open Ctypes
open Foreign

type fmvideo = unit ptr
let fmvideo : fmvideo typ = ptr void

let u8_of_int =
    foreign "u8_of_int" (int @-> (returning uint8_t))

let u32_of_int =
    foreign "u32_of_int" (int @-> (returning uint32_t))

let init =
    foreign "init" (string @-> int @-> int @-> (returning fmvideo))

let write_and_close =
    foreign "write_and_close" (fmvideo @-> (returning void))

(*void circle (FMVideo *v, u32 p[2], u8 bgc[3], u8 c[3], int r, int w, float t);*)
let circle =
    foreign "circle" (fmvideo @-> ptr uint32_t @-> ptr uint8_t @-> ptr uint8_t
    @-> int @-> int @-> float @-> (returning void))

let make_color r g b =
    (CArray.start(CArray.of_list uint8_t
    [(u8_of_int r);(u8_of_int g);(u8_of_int b)]))


let make_point x y =
    (CArray.start(CArray.of_list uint32_t
    [(u32_of_int x);(u32_of_int y)]))
