const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "fata_morgana",
        .root_source_file = b.path("src/fata_morgana.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.addIncludePath(b.path("include"));
    lib.addIncludePath(b.path("include/freetype2"));

    lib.linkSystemLibrary("freetype");
    lib.linkSystemLibrary("avcodec");
    lib.linkSystemLibrary("avformat");
    lib.linkSystemLibrary("avutil");
    lib.linkSystemLibrary("png");

    const test_step = b.step("test", "Run unit tests!");
    const unit_test = b.addTest(.{
        .root_source_file = b.path("src/fata_morgana.zig"),
        .target = target,
    });
    
    unit_test.addIncludePath(b.path("include"));
    unit_test.addIncludePath(b.path("include/freetype2"));
    unit_test.linkSystemLibrary("freetype");
    unit_test.linkSystemLibrary("avcodec");
    unit_test.linkSystemLibrary("avformat");
    unit_test.linkSystemLibrary("avutil");
    unit_test.linkSystemLibrary("png");
    const run_unit_tests = b.addRunArtifact(unit_test);
    test_step.dependOn(&run_unit_tests.step);

    b.installArtifact(lib);
}
