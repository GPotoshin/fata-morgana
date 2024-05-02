open Ctypes
open Unsigned

type fmvideo

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

type fmaction =
| FMText of string*int*int(*int*int*)

val make_color : int -> int -> int -> UInt8.t ptr
val make_point : int -> int -> UInt32.t ptr

val init : string -> int -> int -> (color List.t) * fmvideo
val write_and_close : fmvideo -> unit

val circle : fmvideo -> UInt32.t ptr -> UInt8.t ptr ->
    UInt8.t ptr -> int -> int -> float -> unit

val do_action : fmvideo -> fmaction -> unit
