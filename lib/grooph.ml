open Ctypes
open Foreign

(* c file handling *)
type cfile
let cfile : cfile structure typ = structure "FILE"

let fopen =
    foreign "fopen" (string @-> string @-> returning (ptr_opt cfile))

let fclose =
    foreign "fclose" (ptr cfile @-> returning int) 

(* calling my c library *)
type grimg
let grimg : grimg structure typ = structure "GrImg"

type grcolor
let grcolor = structure "GrColor"
let (-:) ty label = field grcolor label ty
let red   = char -: "red"
let green = char -: "green"
let blue  = char -: "blue"
let () = seal (grcolor : grcolor structure typ)

let grInitDefaultImg =
    foreign "grInitDefaultImg" (int @-> returning (ptr_opt grimg))

let grDestroyImg =
    foreign "grDestroyImg" (ptr grimg @-> returning void)

let grSetSize =
    foreign "grSetSize" (ptr grimg @-> int @-> int @-> returning int)

let grWriteImg =
    foreign "grWriteImg" (ptr grimg @-> ptr cfile @-> returning void)

let grFillBackground =
    foreign "grFillBackground" (ptr grimg @-> grcolor @-> returning int)

let grInitColor =
    foreign "grInitColor" (int @-> int @-> int @-> returning grcolor)

let grDrawPolygon =
    foreign "grDrawPolygon" (ptr grimg @-> ptr (ptr int) @-> int @-> ptr void @-> returning int)
