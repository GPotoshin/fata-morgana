const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "fata_morgana",
        .root_source_file = .{ .path = "src/fata_morgana.zig" },
        .target = target,
        .optimize = optimize,
    });

    lib.addIncludePath(.{ .path = "/opt/homebrew/include"});
    lib.addIncludePath(.{ .path = "/opt/homebrew/include/freetype2"});
    lib.addLibraryPath(.{ .path = "/opt/homebrew/lib"});
    lib.linkSystemLibrary("freetype");
    lib.linkSystemLibrary("libavcodec");

    b.installArtifact(lib);
}
