// by usingnamespace I add modules to then be exported
pub usingnamespace @import("essence.zig");
pub usingnamespace @import("color_magic.zig");
pub usingnamespace @import("shapes.zig");
pub usingnamespace @import("text.zig");
pub usingnamespace @import("pixels.zig");
const print = @import("std").debug.print;

const ft = @import("essence.zig");
const tx = @import("text.zig");
const px = @import("pixels.zig");
const sh = @import("shapes.zig");


// Tests are failing for some reason. Perhaps the 
// memory allocator get's destroyed.


// This test fails in write_text function 
//    148                  bitmap.data = null;
//    149              } else {
// -> 150                  bitmap.data = (allocator.alloc(u8, bitmap.rows*bitmap.width)
//    151                  catch {
//    152                      print("no memory for glyph map\n", .{});

fn rgb_to_yuv(c: [3]u8) [3]u8 {
    const fc = [_]f32 {
        @floatFromInt(c[0]),
        @floatFromInt(c[1]),
        @floatFromInt(c[2])
    };

    const tfc = [_]f32 {
        0.299*fc[0] + 0.587*fc[1] + 0.114*fc[2], 
        -0.168736*fc[0] - 0.331264*fc[1] + 0.5*fc[2] + 128,
        0.5*fc[0] - 0.418688*fc[1] - 0.081312*fc[2] + 128,
    };
    
    return [_]u8 {
        @intFromFloat(tfc[0]),
        @intFromFloat(tfc[1]),
        @intFromFloat(tfc[2]),
    };
}

test "showing text" {
    print("running showing text\n", .{});
    const face_names = [_][*:0]const u8{
        "/Users/giorno/projects/fata-morgana/fonts/LinLibertine_R.otf",
        "/Users/giorno/projects/fata-morgana/fonts/Euler-Math.otf",
        "/Users/giorno/projects/fata-morgana/fonts/APL386B.ttf",
    };
    var e: i32 = 0;
    
    // preparing text
    const probleme = "Show that every convex, closed, unbounded set in euclid space contains a ray";
    // const probleme = "Slovo";
    var text: [probleme.len]u32 = undefined; 
    for (0..text.len) |i| text[i] = probleme[i];

    // preparing colors
    
    const cg = rgb_to_yuv([_]u8{0xe0,0x49,0xa0});
    const fg = rgb_to_yuv([_]u8{0x73,0x49,0xa0});
    const bg = rgb_to_yuv([_]u8{0x1f,0xf7,0x7d});

    const v = ft.init(@constCast("showing_text.mp4"), 360, 270, @ptrCast(@constCast(&face_names)),
        @ptrCast(@constCast(&[_]u8{16,32,64})), &e); 
    tx.add_line_splits(v, -0.4, 0.4, &text, text.len, 2, 0);
    for (0..100) |frame_num| {
        ft.add_frame(v);
        sh.paint_background(v, @ptrCast(&bg));
        tx.write_text(
            v,
            @ptrCast(&cg),
            @ptrCast(&fg),
            @ptrCast(&bg),
            @ptrCast(&text),
            text.len,
            100,
            @intCast(frame_num),
            2,
            0,
            -0.4, 0.4, -0.4, 0.4);
        ft.encode(v);
    }
    ft.write_and_close(v);
    print("End of drawing text test\n", .{});
}


// test "drawing pixel art" {
//     const face_names = [_][*:0]const u8{
//         "/Users/giorno/projects/fata-morgana/fonts/LinLibertine_R.otf",
//         "/Users/giorno/projects/fata-morgana/fonts/Euler-Math.otf",
//         "/Users/giorno/projects/fata-morgana/fonts/APL386B.ttf",
//     };
//     var e: i32 = 0;
//     const v = ft.init(@constCast("drawing.mp4"), 360, 270, @ptrCast(@constCast(&face_names)),
//         @ptrCast(@constCast(&[_]u8{16,32,64})), &e); 
//     const allocator = ft.get_allocator(v);
//
//     const img = px.open_image(allocator, "arts/professor.png");
//     for (0..100) |_| {
//         ft.add_frame(v);
//         px.place_pixel_art(v, 0, 0, img, 2);
//         ft.encode(v);
//     }
//     px.destroy_img(allocator, img);
//     ft.write_and_close(v);
// }
