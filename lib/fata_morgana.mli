type fmvideo

module Color : sig
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

    val dark0 : fmcolor -> int option
    val dark1 : fmcolor -> int option
    val dark2 : fmcolor -> int option
    val dark3 : fmcolor -> int option
    val light0 : fmcolor -> int option
    val light1 : fmcolor -> int option
    val light2 : fmcolor -> int option
    val red : fmcolor -> int option
    val green : fmcolor -> int option
    val yellow : fmcolor -> int option
    val blue : fmcolor -> int option
    val purple : fmcolor -> int option
    val aqua : fmcolor -> int option
    val orange : fmcolor -> int option
    val deepBlue : fmcolor -> int option
    val lightBlue : fmcolor -> int option
end

type fmaction =
    | Text of string*float*float(*int*int*)
    | Circle of float*float*int*int*float
    | Background

val init : string -> int -> int -> (Color.fmcolor list) * fmvideo
val write_and_close : (Color.fmcolor list) * fmvideo -> unit

val do_action : (Color.fmcolor list) * fmvideo -> fmaction -> unit

