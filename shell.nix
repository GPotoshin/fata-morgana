{pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
    buildInputs = [
        pkgs.ffmpeg
        pkgs.libpng
        pkgs.freetype
    ];
}
