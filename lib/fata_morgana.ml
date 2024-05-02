open Ctypes
open Foreign

type fmvideo = unit ptr
let fmvideo : fmvideo typ = ptr void

let u8_of_int =
    foreign "u8_of_int" (int @-> (returning uint8_t))

let u32_of_int =
    foreign "u32_of_int" (int @-> (returning uint32_t))

let init_video =
    foreign "init" (string @-> int @-> int @-> (returning fmvideo))

let write_and_close =
    foreign "write_and_close" (fmvideo @-> (returning void))

(*void circle (FMVideo *v, u32 p[2], u8 bgc[3], u8 c[3], int r, int w, float t);*)
let circle =
    foreign "circle" (fmvideo @-> ptr uint32_t @-> ptr uint8_t @-> ptr uint8_t
    @-> int @-> int @-> float @-> (returning void))
(*void write_text (FMVideo *v, u32 p[2], u8 bg[3], u8 c[3], u8 str[], int len);*)
let write_text =
    foreign "write_text" (fmvideo @-> ptr uint32_t @-> ptr uint8_t @-> ptr uint8_t
    @-> ptr int @-> int @-> (returning void))

let make_color r g b =
    (CArray.start(CArray.of_list uint8_t
    [(u8_of_int r);(u8_of_int g);(u8_of_int b)]))
;;

let make_point x y =
    (CArray.start(CArray.of_list uint32_t
    [(u32_of_int x);(u32_of_int y)]))
;;

type color =
| FMDark0 of int
| FMDark1 of int
| FMDark2 of int
| FMDark3 of int
| FMLight0 of int
| FMLight1 of int
| FMLight2 of int
| FMRed of int
| FMGreen of int
| FMYellow of int
| FMBlue of int
| FMPurple of int
| FMAqua of int
| FMOrange of int
| FMDeepBlue of int
| FMLightBlue of int


let init name w h =
    let colorset = [
        FMDark0 0x2e3440,
        FMDark1 0x3b4252,
        FMDark2 0x434c5e,
        FMDark3 0x4c564a,
        FMLight0 0xeceff4,
        FMLight1 0xe5e9f0,
        FMLight2 0xd8dee9,
        FMRed 0xbf616a,
        FMGreen 0xa3be8c,
        FMYellow 0xebcb8b,
        FMBlue 0x81a1c1,
        FMPurple 0xb48ed,
        FMAqua 0x8fbcbb,
        FMOrange 0xd08770,
        FMDeepBlue 0x5e81ac,
        FMLightBlue 0x88c0d0
    ] in
    (colorset, init_video name w h)
;;

type fmaction =
| FMText of string*int*int(*int*int*)

let do_action v acc =
    match acc with
    | FMText (str, x, y) ->
            let seq = String.to_seq str in
            let ascii_list = List.of_seq (Seq.map Char.code seq) in
            let ascii_carray = CArray.of_list int ascii_list in
            
            let bg = make_color 0x2E 0x34 0x40 in
            let c = make_color 0x8F 0xBC 0xBB in
            let p = make_point x y in

            write_text v p bg c (CArray.start ascii_carray) (String.length str);
    ()
;;
