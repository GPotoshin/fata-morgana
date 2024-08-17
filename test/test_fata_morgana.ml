module Fm = Fata_morgana

let (<~) = Fm.(<~)

let height = 480
let width = 720

let () =
    let v = match Fm.init "test.mpeg" width height with
    | Some(x) -> x
    | None -> exit 1
    in
    let problem = "Show that every convex, closed, unbounded set in euclid " ^
                  "space contains a ray" in

    let sq = []
    <~ Fm.addBackground
    <~ Fm.addText problem Fm.middleBox Fm.Big
    <~ Fm.addPixelArt (-0.2) (-0.2) 3 "arts/professor.png" in

    Fm.visualise_scene v sq 10.;
    Fm.write_and_close v;
;;
