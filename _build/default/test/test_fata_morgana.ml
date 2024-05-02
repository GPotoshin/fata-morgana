module fm = Fata_morgana

open Printf

let height = 480/2;;
let width = 720/2;;

let () =
    printf "Start of the test\n";
    let v = init "test.mpeg" width height in

    let c = make_color 0x8f 0xbc 0xbb in
    let bgc = make_color 0x2e 0x34 0x40 in

    let p = make_point 100 100 in

    circle v p bgc c 50 5 1.;
    do_action v (FMText ("Hello!", 100, 100));
    do_action v (FMText ("Hello!", 100, 100));
    do_action v (FMText ("Hello!", 100, 100));
    do_action v (FMText ("Hello!", 100, 100));

    write_and_close v;
;;
