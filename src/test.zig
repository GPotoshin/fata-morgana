const std = @import("std");
const FMVideo = @import("essence.zig").FMVideo;
const Bitmap = @import("essence.zig").Bitmap;
const print = std.debug.print;

test "testing GPA" {
    print("log 1\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    print("log 2\n", .{});
    const allocator = gpa.allocator();
    print("log 3\n", .{});
    const v: *FMVideo = @ptrCast((try allocator.alloc(FMVideo, 1)).ptr);
    print("log 4\n", .{});
    for (0..3) |i| {
        for (0..3) |j| {
            v.glyphmaps[i][j] = std.AutoHashMap(u32, Bitmap).init(allocator);
        }
    }
    print("log 5\n", .{});
    const arr = allocator.alloc(u32, 8) catch {
        print ("can't allocate text spliter", .{});
        return;
    };
    print("{*}\n", .{v});
    print("{any}\n", .{arr});
}
