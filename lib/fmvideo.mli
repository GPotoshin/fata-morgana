open Ctypes

type fmvideo

val make_color : int -> int -> int -> unit ptr
val make_point : int -> int -> unit ptr

val init : string -> int -> int -> fmvideo
val add_frame : fmvideo -> int -> unit
val set_pxl : fmvideo -> unit ptr -> unit ptr -> unit
val encode : fmvideo -> unit
val write_and_close : fmvideo -> unit
