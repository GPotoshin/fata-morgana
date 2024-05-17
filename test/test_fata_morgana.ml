module Fm = Fata_morgana

let (<~) = Fm.(<~)

let height = 480/2
let width = 720/2

let () =
    let v = Fm.init "test.mpeg" width height in
    let problem = "Show that all convex unbounded closed figures contain at least one ray" in

    let sq = []
    <~ Fm.addBackground
    <~ Fm.addText problem (-0.9) (0.9) 0 0 Medium in

    Fm.visualise_scene v sq 3.;
    Fm.write_and_close v;
;;
