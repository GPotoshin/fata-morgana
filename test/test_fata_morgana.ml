module Fm = Fata_morgana

let (<~) = Fm.(<~)

let height = 480/2
let width = 720/2

let () =
    let v = match Fm.init "test.mpeg" width height with
    | Some(x) -> x
    | None -> exit 1
    in
    let problem = "Show" in

    let sq = []
    <~ Fm.addBackground
    <~ Fm.addText problem (-0.9) (0.7) 0. 0. Medium in

    Fm.visualise_scene v sq 3.;
    Fm.write_and_close v;
;;
