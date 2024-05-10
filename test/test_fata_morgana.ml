module Fm = Fata_morgana
open Printf

let height = 480/2;;
let width = 720/2;;

let () =
    printf "Start of the test\n";
    let v = Fm.init "test.mpeg" width height in

    Fm.do_action v Fm.Background;
    Fm.do_action v (Fm.Circle (0., 0., 20, 10, 3.));
    Fm.do_action v (Fm.Text ("Hello!", 0., 0.5));
    Fm.do_action v (Fm.Text ("Hello!", 0., 0.5));
    Fm.do_action v (Fm.Text ("Hello!", 0., 0.5));
    Fm.do_action v (Fm.Text ("Hello!", 0., 0.5));

    Fm.write_and_close v;
;;
