# Fata-Morgana

## How to build
Framework depends on fmpeg and freetype2, so you need to have them installed.
For ocaml part you need to install ctypes and ctypes-foreign
Build framework with command `make`. To run test run `make run`.

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
type fmbox = float * float * float * float

type fontsize =
| Small
| Medium
| Big

type fmaction =
| Text of string*fmbox*fontsize
| Circle of float*float*int*int*float
| Background
```

You can create a sequence of actions with `<~` operator
```ocaml
    let sq = []
    <~ Fm.addBackground
    <~ Fm.addText problem middleBox Medium in
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
Write a function in ZIG in that takes visual parameters and which frame from
animation is drawn. Then add type to `fmaction` in fmaction and add call of c
function to function `do_action`.

# How library is structured
Framework is powered by `avlib` library which is a part of FFMPEG. The video
data is stored in a single data structure `FMVideo` most other functions
operates on a single instance of `FMVideo`.


# To do list
- add support to a better format
- make generalised transformation's animation
- make a better coloring
- write latex parser
