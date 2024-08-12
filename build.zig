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
    lib.addLibraryPath(b.path("bin"));
    lib.linkSystemLibrary("freetype");
    lib.linkSystemLibrary("libavcodec");

    const test_step = b.step("test", "Run unit tests!");
    const unit_test = b.addTest(.{
        .root_source_file = b.path("src/fata_morgana.zig"),
        .target = target,
    });
    
    unit_test.addIncludePath(b.path("include"));
    unit_test.addIncludePath(b.path("include/freetype2"));
    unit_test.addLibraryPath(b.path("bin"));
    unit_test.linkSystemLibrary("freetype");
    unit_test.linkSystemLibrary("libavcodec");
    const run_unit_tests = b.addRunArtifact(unit_test);
    test_step.dependOn(&run_unit_tests.step);
    b.installArtifact(lib);
}
