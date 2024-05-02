module Fm = Fata_morgana
open Printf

let height = 480/2;;
let width = 720/2;;

let () =
    printf "Start of the test\n";
    let v = Fm.init "test.mpeg" width height in

    Fm.do_action v (FMText ("Hello!", 100, 100));
    Fm.do_action v (FMText ("Hello!", 100, 100));
    Fm.do_action v (FMText ("Hello!", 100, 100));
    Fm.do_action v (FMText ("Hello!", 100, 100));

    Fm.write_and_close v;
;;
