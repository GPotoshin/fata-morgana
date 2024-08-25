.PHONY: rpath

CFLAGS += -O2 -g -I/opt/homebrew/include -I/opt/homebrew/include/freetype2
LFLAGS += -L$(CURDIR)/lib $(shell pkg-config --libs libavcodec freetype2) -fPIC

OBJECTS := bin/fata_morgana.o bin/fmmath.o bin/write_text.o
ZIG_FILES := src/fata_morgana.zig src/text.zig src/maths.zig src/essence.zig src/shapes.zig src/color_magic.zig src/pixels.zig
OCAML_FILES := test/test_fata_morgana.ml lib/fata_morgana.ml lib/fata_morgana.mli

all: zig-out/lib/libfata_morgana.dylib _build/default/test/test_fata_morgana.exe

_build/default/test/test_fata_morgana.exe: $(OCAML_FILES)
	dune build
	install_name_tool -add_rpath $(CURDIR)/zig-out/lib $@

zig-out/lib/libfata_morgana.dylib: $(ZIG_FILES)
	zig build

bin:
	mkdir -p bin

run:
	_build/default/test/test_fata_morgana.exe

install:
	cp zig-out/lib/libfata_morgana.dylib /opt/homebrew/lib
