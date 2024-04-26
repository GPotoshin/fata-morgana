open Fmvideo
open Printf

let height = 480/2;;
let width = 720/2;;

let () =
    printf "Start of the test\n";
    let v = init "test.mpeg" width height in

    for i = 0 to 10 do
        add_frame v i;
        for y = 0 to 2*height do
            for x = 0 to 2*width do
                let p = make_point x y in
                let c = make_color 0x2E 0x34 0x40 in 
                set_pxl v p c;
            done;
        done;
        encode v;
    done;
    write_and_close v;
;;
