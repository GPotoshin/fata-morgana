open Ctypes

(* c file hadling *)
type cfile

val fopen : string -> string -> cfile structure ptr option

val fclose : cfile structure ptr -> int

(* grooph library *)
type grimg

type grcolor
val red : (char, grcolor structure) field
val green : (char, grcolor structure) field
val blue : (char, grcolor structure) field

val grInitDefaultImg : int -> grimg structure ptr option

val grDestroyImg : grimg structure ptr -> unit

val grSetSize : grimg structure ptr -> int -> int -> int

val grWriteImg : grimg structure ptr -> cfile structure ptr -> unit

val grFillBackground : grimg structure ptr -> grcolor structure -> int

val grInitColor : int -> int -> int -> grcolor structure
