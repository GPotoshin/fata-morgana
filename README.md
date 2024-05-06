# Fata-Morgana

= How to build
Framework depends on fmpeg and freetype2, so you need to have them installed.
Build framework with command `make && dune build`

= How to use
Import framework
```ocaml
module Fm = Fata_morgana
```

Create video scene with
```ocaml
let scene = Fm.init "video.mpeg" 720 480 in
```
Only mpeg1video format is supported for now

In module Fata-morgana there is a type
```ocaml
type fmaction =
| Text of string*float*float (*text, relative x, relative y*)
| Circle of int*int*int*int*float (* x, y, radius, width, time*)
| Background
```

So to do an action you need to pass the object with the scene to do_action
function:
```ocaml
Fm.do_action scene (Fm.Text ("Hello!", 0, 0));
```

Colors are represented by their indicator functions that starts with names in
lower case for example `dark0`
