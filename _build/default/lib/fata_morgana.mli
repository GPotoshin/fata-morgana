open Ctypes
open Unsigned

type fmvideo

val make_color : int -> int -> int -> UInt8.t ptr
val make_point : int -> int -> UInt32.t ptr

val init : string -> int -> int -> fmvideo
val write_and_close : fmvideo -> unit

val circle : fmvideo -> UInt32.t ptr -> UInt8.t ptr ->
    UInt8.t ptr -> int -> int -> float -> unit
