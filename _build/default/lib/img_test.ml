open Grooph

let () =
    let fp = match fopen "test.png" "wb" with
    | Some file -> file
    | None -> exit 1 in

    let image = match grInitDefaultImg 0 with
    | Some img -> img
    | None -> exit 1 in

    let _ = grSetSize image 200 100 in
    let color = grInitColor 33 82 99 in
    let _ = grFillBackground image color in
    grWriteImg image fp;
    grDestroyImg image
