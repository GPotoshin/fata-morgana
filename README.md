# Fata-Morgana

## How to build
Framework depends on fmpeg and freetype2, so you need to have them installed.
Build framework with command `make && dune build`

## How to use
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
type fontsize =
| Small
| Medium
| Big

type fmaction =
| Text of string*float*float*int*int*fontsize (*Unicode string * rel_x * rel_y * start * duration*)
| Circle of float*float*int*int*float
| Background
```

You can create a sequence of actions with `<~` operator
```ocaml
    let sq = []
    <~ Fm.addBackground
    <~ Fm.addText problem (-0.9) (0.9) 0 0 Medium in
```

and then pass it to another procedure, that takes scene, action list and time
```ocaml
    Fm.visualise_scene v sq 3.;
```

write and close video
```ocaml
    Fm.write_and_close v;
```

Colors are represented by their indicator functions that starts with names in
lower case, for example `dark0`, `red` etc.

### How to change colors
Just add your color to the front of the list of colors. Scene for now is
just a product type of list of colors and pointer to C structure. Colors are
added with corresponding type constructor, `Dark0`, `Red` etc. Color should
be in yuv format. There is `Color.rgb_to_yuv` to help you with convertion.

## How to write your animation
Write a function in C in `video.c` file that takes visual parameters and which
frame from animation is drawn. Then add type to `fmaction` in fmaction and
add call of c function to function `do_action`.

# To do list
- make a better coloring
- make text boxes
- make borders
- write latex parser
