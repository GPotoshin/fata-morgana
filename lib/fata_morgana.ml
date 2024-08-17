open Ctypes
open Foreign

type fmvideo = unit ptr
let fmvideo : fmvideo typ = ptr void

(* importing functions from zig library *)
let init_video =
    foreign "init" (string @-> int @-> int @-> (ptr int) @-> (returning fmvideo))
let cwrite_and_close =
    foreign "write_and_close" (fmvideo @-> (returning void))
let add_frame =
    foreign "add_frame" (fmvideo @-> (returning void))
let encode =
    foreign "encode" (fmvideo @-> (returning void))
let write_and_close v =
    let (_, video) = v in
    cwrite_and_close video

(*void circle (FMVideo *v, u32 p[2], u8 bgc[3], u8 c[3], int r, int w, float t);*)
let circle =
    foreign "circle" (fmvideo @-> ptr float @-> ptr uint8_t @-> ptr uint8_t
    @-> int @-> int @-> float @-> (returning void))
let write_text =
    foreign "write_text" (fmvideo @-> ptr uint8_t @-> ptr uint8_t @-> ptr uint8_t
    @-> ptr int @-> int @-> int @-> int @-> int @-> ptr char @-> float @-> float
    @-> float @-> float @-> (returning void))
let paint_background =
    foreign "paint_background" (fmvideo @-> ptr uint8_t @-> (returning void))
let place_pixel_art =
    foreign "place_pixel_art" (fmvideo @-> float @-> float @-> ptr char
    @-> uint32_t @-> (returning void))

(* generating c structures *)
let make_color r g b =
    (CArray.start(CArray.of_list uint8_t
    [(Unsigned.UInt8.of_int r);(Unsigned.UInt8.of_int g);(Unsigned.UInt8.of_int b)]))
;;
let make_point x y =
    (CArray.start(CArray.of_list float [x; y]))
;;

module Color = struct 
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

(* monads ?? *)
    let map f = function
        | Dark0 num -> Dark0 (f num) 
        | Dark1 num -> Dark1 (f num) 
        | Dark2 num -> Dark2 (f num) 
        | Dark3 num -> Dark3 (f num) 
        | Light0 num -> Light0 (f num) 
        | Light1 num -> Light1 (f num) 
        | Light2 num -> Light2 (f num) 
        | Red num -> Red (f num) 
        | Green num -> Green (f num) 
        | Yellow num -> Yellow (f num) 
        | Blue num -> Blue (f num) 
        | Purple num -> Purple (f num) 
        | Aqua num -> Aqua (f num) 
        | Orange num -> Orange (f num) 
        | DeepBlue num -> DeepBlue (f num) 
        | LightBlue num -> LightBlue (f num)

(* checking for right color *)
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

    let rgb_to_yuv color =
        map (fun num ->
            let r = float_of_int ((num lsr 16) land 255) in
            let g = float_of_int ((num lsr 8) land 255) in
            let b = float_of_int (num land 255) in
            let y = 0.299*.r +. 0.587*.g +. 0.114*.b in
            let u = -. 0.168736*.r -. 0.331264*.g +. 0.5*.b +. 128. in
            let v = 0.5*.r -. 0.418688*.g -. 0.081312*.b +. 128. in
            ((int_of_float y)lsl 16)+((int_of_float u)lsl 8)+(int_of_float v)
        ) color
    ;;
end

let init name w h =
    let e = allocate int 0 in
    let open Color in
    let colorset = [ (* color preset *)
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
    let v = init_video name w h e in
    let retval = (List.map rgb_to_yuv colorset, v) in
    match !@e with
    | 0 -> Some(retval)
    | _ -> None
;;

(* frame rate is here because I want to do calculations here, maybe I'll regret 
 one day, but I want to master ocaml and not c that I already know well*)

type fontsize =
| Small
| Medium
| Big

type fmbox = float * float * float * float
let middleBox: fmbox = (-0.8, 0.8, -0.66, 0.66)

type fmaction =
| Text of string*fmbox*fontsize
| Circle of float*float*int*int*float
| PixelArt of float*float*int*string
| Background

let (<~) f g = g (f)

let addText s box size = (fun scene ->
    scene @ [Text (s, box, size)])
let addPixelArt x y scale name = (fun scene ->
    scene @ [PixelArt (x, y, scale, name)])
let addBackground = fun scene -> scene @ [Background]

let do_action v acc counter =
    let open Color in
    match acc with
    | PixelArt (x, y, scale, name) ->
            let name_carray = CArray.of_string name in
            let name_ptr = CArray.start name_carray in
            let uscale = Unsigned.UInt32.of_int scale in
            let (_, vid) = v in
            place_pixel_art vid x y name_ptr uscale; 
    | Text (str, box, size) ->
            let (x_l, x_r, y_l, y_t) = box in 
            let size_num = match size with
            | Small -> 12
            | Medium -> 32
            | Big -> 64 in
            if x_l > 1. || x_l < -.1. then
                print_endline "x_l is out of [-1, 1]"
            else if x_r > 1. || x_r < -.1. then
                print_endline "x_r is out of [-1, 1]"
            else if y_l > 1. || y_l < -.1. then
                print_endline "y_l is out of [-1, 1]"
            else if y_t > 1. || y_t < -.1. then
                print_endline "y_t is out of [-1, 1]"
            else
            let seq = String.to_seq str in
            let ascii_list = List.of_seq (Seq.map Char.code seq) in
            let ascii_carray = CArray.of_list int ascii_list in
            let (colors, vid) = v in
            (match find_color orange colors with
            | None -> print_endline "can't find color orange";
            | Some(c) ->
            (match find_color light0 colors with
            | None -> print_endline "can't find color light0";
            | Some(fgc) ->
            (match find_color dark0 colors with
            | None -> print_endline "can't find color dark0";
            | Some(bgc) ->
            let font_name = "/Users/giorno/projects/fata-morgana/fonts/LinLibertine_R.otf" in
            let cfont_name = CArray.of_string font_name in
            write_text vid c fgc bgc (CArray.start ascii_carray) (String.length str)
            (2*(String.length str)) counter size_num (CArray.start cfont_name)
            x_l x_r y_l y_t;
            )))

    | Circle (x, y, r, w, t) -> 
            if x > 1. || x < -.1. then
                print_endline "x is out of [-1, 1]"
            else if y > 1. || x < -.1. then
                print_endline "y is out of [-1, 1]"
            else
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

(*is it what slows down the programm?*)
let visualise_scene scene action_list time =
    let duration = int_of_float (time*.25.) in
    let rec process_actions list counter endc is_root =
        if counter >= endc then
            ()
        else (
            (match list with
            | first :: rest ->
                (match is_root with
                | true -> let (_, v) = scene in
                    add_frame v;
                | false -> ());
                do_action scene first counter;
                process_actions rest counter endc false
            | [] -> ());
            if is_root then
                let (_, v) = scene in
                encode v;
                process_actions list (counter+1) endc true)
    in
    process_actions action_list 0 duration true
;;
