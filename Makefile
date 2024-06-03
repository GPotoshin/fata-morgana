.PHONY: rpath

CFLAGS += -O2 -g -I/opt/homebrew/include -I/opt/homebrew/include/freetype2
LFLAGS += -L$(CURDIR)/lib $(shell pkg-config --libs libavcodec freetype2) -fPIC

OBJECTS := bin/fata_morgana.o bin/fmmath.o bin/write_text.o

all: zig-out/lib/libfata_morgana.dylib _build/default/test/test_fata_morgana.exe

_build/default/test/test_fata_morgana.exe: test/test_fata_morgana.ml lib/fata_morgana.ml lib/fata_morgana.mli
	dune build
	install_name_tool -add_rpath $(CURDIR)/zig-out/lib $@

zig-out/lib/libfata_morgan.dylib: srs/fata_morgana.zig
	cp zig-out/lib/libfata_morgana.dylib lib/libfata_morgana.dylib

bin:
	mkdir -p bin

run:
	_build/default/test/test_fata_morgana.exe
