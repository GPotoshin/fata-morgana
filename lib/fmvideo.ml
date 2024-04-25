open Ctypes
open Foreign

type fmvideo = unit ptr
let fmvideo : fmvideo typ = ptr void

let u8_of_int =
    foreign "u8_of_int" (int @-> (returning uint8_t))

let u32_of_int =
    foreign "u32_of_int" (int @-> (returning uint32_t))

let set_pxl =
    foreign "set_pxl" (fmvideo @-> (ptr void) @-> (ptr void) @-> (returning void))

let init =
    foreign "init" (string @-> int @-> int @-> (returning fmvideo))

let add_frame =
    foreign "add_frame" (fmvideo @-> int @-> (returning void))

let encode =
    foreign "encode" (fmvideo @-> (returning void))

let write_and_close =
    foreign "write_and_close" (fmvideo @-> (returning void))


let make_color r g b =
    to_voidp (CArray.start(CArray.of_list uint8_t
    [(u8_of_int r);(u8_of_int g);(u8_of_int b)]))


let make_point x y =
    to_voidp (CArray.start(CArray.of_list uint32_t
    [(u32_of_int x);(u32_of_int y)]))
