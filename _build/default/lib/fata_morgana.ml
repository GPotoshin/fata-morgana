(*open Fmvideo
open Printf
open Fmtypes*)

let pi = 3.1415926535897932384626433832795;;
(*
let rec processAction v actions cur fin =
    if cur >= fin then ()
    else
    let _ = match actions with
    | acn :: rest ->
            (match acn with
            | DrawLine ((sx, sy), (fx, fy), t) ->
                Printf.printf "Drawing line from (%d, %d) to (%d, %d)\n" sx sy fx fy
            | DrawCircle ((x, y), r, t) ->
                Printf.printf "Drawing circle at (%d, %d) with radius of %d\n" x y r)
                                let fcur = float_of_int cur in
                let ft = float_of_int t in
                let a = ref 0. in
                while !a < (fcur+.1.)*.2.*.pi/.ft do
                    for i = 0 to 20 do
                        set_pxl v (360.+.(100.+.float_of_int i)*.cos !a)
                        (240.+.(100.+.float_of_int i)*.sin !a) 0x8f 0xbc 0xbb;
                    done
                done in

            processAction v rest cur+1 fin;
    | [] -> ()
;;*)
