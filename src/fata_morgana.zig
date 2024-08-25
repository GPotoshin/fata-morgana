// by usingnamespace I add modules to then be exported
pub usingnamespace @import("essence.zig");
pub usingnamespace @import("color_magic.zig");
pub usingnamespace @import("shapes.zig");
pub usingnamespace @import("text.zig");
pub usingnamespace @import("pixels.zig");
const print = @import("std").debug.print;

const ft = @import("essence.zig");
const tx = @import("text.zig");

test "core" {
    const face_names = [_][*:0]u8{
        @constCast("/Users/giorno/projects/fata-morgana/fonts/LinLibertine_R.otf"),
        @constCast("/Users/giorno/projects/fata-morgana/fonts/Euler-Math.otf"),
        @constCast("/Users/giorno/projects/fata-morgana/fonts/APL386B.ttf"),
    };
    var e: i32 = 0;
    const probleme = "Show that every convex, closed, unbounded set in euclid space contains a ray";
    var text: [probleme.len]u32 = undefined; 

    for (0..text.len) |i| text[i] = probleme[i];
    const v = ft.init(@constCast("test.mp3"), 360, 270, @ptrCast(@constCast(&face_names)),
        @ptrCast(@constCast(&[_]u8{16,32,64})), &e); 
    for (0..100) |frame_num| {
        print("iteration: {}\n", .{frame_num});
        print("adding frame\n", .{});
        ft.add_frame(v);
        print("writing text\n", .{});
        tx.write_text(
            v,
            @ptrCast(@constCast(&[_]u8{0xe0,0x49,0xa0})),
            @ptrCast(@constCast(&[_]u8{0x73,0x49,0xa0})),
            @ptrCast(@constCast(&[_]u8{0x1f,0xf7,0x7d})),
            @ptrCast(@constCast(&text)),
            text.len,
            100,
            @intCast(frame_num),
            2,
            0,
            -0.4, 0.4, -0.4, 0.4);
        print("encoding\n", .{});
        ft.encode(v);
    }
    ft.write_and_close(v);
}
