open Fmvideo
open Printf

type time   = float
type point  = (int*int)
type color  = (int*int*int)

type action =
    | DrawCircle of point*color*int*int*time*time

let pi = 3.1415926535897932384626433832795;;

let rec process actions = 
    match actions with
    | a :: r -> 
        (match a with
        | DrawCircle ((x, y), (r, g, b), rad, w, s, f) ->
            add_circle x y r g b rad w s f;)

        process r;

    | [] -> ()
