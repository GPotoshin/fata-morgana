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

let cwrite_and_close =
    foreign "write_and_close" (fmvideo @-> (returning void))

let write_and_close v =
    let (_, video) = v in
    cwrite_and_close video

(*void circle (FMVideo *v, u32 p[2], u8 bgc[3], u8 c[3], int r, int w, float t);*)
let circle =
    foreign "circle" (fmvideo @-> ptr uint32_t @-> ptr uint8_t @-> ptr uint8_t
    @-> int @-> int @-> float @-> (returning void))
(*void write_text (FMVideo *v, u32 p[2], u8 bg[3], u8 c[3], u8 str[], int len);*)
let write_text =
    foreign "write_text" (fmvideo @-> ptr uint32_t @-> ptr uint8_t @-> ptr uint8_t
    @-> ptr int @-> int @-> (returning void))

let paint_background =
    foreign "paint_background" (fmvideo @-> ptr uint8_t @-> (returning void))

let make_color r g b =
    (CArray.start(CArray.of_list uint8_t
    [(u8_of_int r);(u8_of_int g);(u8_of_int b)]))
;;

let make_point x y =
    (CArray.start(CArray.of_list uint32_t
    [(u32_of_int x);(u32_of_int y)]))
;;

type fmcolor =
| Dark0 of int
| Dark1 of int
| Dark2 of int
| Dark3 of int
| Light0 of int
| Light1 of int
| Light2 of int
| Red of int
| Green of int
| Yellow of int
| Blue of int
| Purple of int
| Aqua of int
| Orange of int
| DeepBlue of int
| LightBlue of int

let dark0 c =
    match c with
    | Dark0 num -> Some(num)
    | _ -> None
;;
let dark1 c =
    match c with
    | Dark1 num -> Some(num)
    | _ -> None
;;
let dark2 c =
    match c with
    | Dark2 num -> Some(num)
    | _ -> None
;;
let dark3 c =
    match c with
    | Dark3 num -> Some(num)
    | _ -> None
;;
let light0 c =
    match c with
    | Light0 num -> Some(num)
    | _ -> None
;;
let light1 c =
    match c with
    | Light1 num -> Some(num)
    | _ -> None
;;
let light2 c =
    match c with
    | Light2 num -> Some(num)
    | _ -> None
;;
let red c =
    match c with
    | Red num -> Some(num)
    | _ -> None
;;
let green c =
    match c with
    | Green num -> Some(num)
    | _ -> None
;;
let yellow c =
    match c with
    | Yellow num -> Some(num)
    | _ -> None
;;
let blue c =
    match c with
    | Blue num -> Some(num)
    | _ -> None
;;
let purple c =
    match c with
    | Purple num -> Some(num)
    | _ -> None
;;
let aqua c =
    match c with
    | Aqua num -> Some(num)
    | _ -> None
;;
let orange c =
    match c with
    | Orange num -> Some(num)
    | _ -> None
;;
let deepBlue c =
    match c with
    | DeepBlue num -> Some(num)
    | _ -> None
;;
let lightBlue c =
    match c with
    | LightBlue num -> Some(num)
    | _ -> None
;;

let rec find_color color_type colors =
    match colors with
    | f :: r -> (match color_type f with
        | Some(num) -> Some(make_color ((num lsr 16) land 255) ((num lsr 8) land 255) (num land 255))
        | None -> find_color color_type r)
    | [] -> None
;;

let init name w h =
    let colorset = [
        Dark0 0x2e3440;
        Dark1 0x3b4252;
        Dark2 0x434c5e;
        Dark3 0x4c564a;
        Light0 0xeceff4;
        Light1 0xe5e9f0;
        Light2 0xd8dee9;
        Red 0xbf616a;
        Green 0xa3be8c;
        Yellow 0xebcb8b;
        Blue 0x81a1c1;
        Purple 0xb48ed;
        Aqua 0x8fbcbb;
        Orange 0xd08770;
        DeepBlue 0x5e81ac;
        LightBlue 0x88c0d0;
    ] in
    (colorset, init_video name w h)
;;

type fmaction =
| Text of string*int*int(*int*int*)
| Circle of int*int*int*int*float
| Background
(*void circle (FMVideo *v, u32 p[2], u8 bgc[3], u8 c[3], int r, int w, float t);*)

let do_action v acc =
    match acc with
    | Text (str, x, y) ->
            let seq = String.to_seq str in
            let ascii_list = List.of_seq (Seq.map Char.code seq) in
            let ascii_carray = CArray.of_list int ascii_list in
            
            let (colors, vid) = v in

            (match find_color dark0 colors with
            | None -> print_endline "can't find color dark0";
            | Some(bg) -> 
            (match find_color orange colors with
            | None -> print_endline "can't find color light0";
            | Some(c) -> let p = make_point x y in
            write_text vid p bg c (CArray.start ascii_carray) (String.length str);
            ))
    | Circle (x, y, r, w, t) -> 
            let (colors, vid) = v in

            (match find_color dark0 colors with
            | None -> print_endline "can't find color dark0";
            | Some(bg) -> 
            (match find_color light0 colors with
            | None -> print_endline "can't find color light0";
            | Some(c) -> let p = make_point x y in
            circle vid p bg c r w t;
            ))
    | Background ->
            let (colors, vid) = v in
            match find_color dark0 colors with
            | None -> print_endline "can't fin color dark0";
            | Some(c) -> paint_background vid c
;;
