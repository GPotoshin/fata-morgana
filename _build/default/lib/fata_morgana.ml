type time = int
type point = (int*int)

type action =
    | DrawLine of point*point*time
    | DrawCircle of point*int*time

let processAction acn = 
    match acn with
    | DrawLine ((sx, sy), (fx, fy), t) ->
            Printf.printf "Drawing line from (%d, %d) to (%d, %d)\n" sx sy fx fy;
    | DrawCircle ((x, y), r, t) ->
            Printf.printf "Drawing circle at (%d, %d) with radius of %d\n" x y t;
;;
