CFLAGS += -O2 -g -I/opt/homebrew/include -I/opt/homebrew/include/freetype2
LFLAGS += -L$(CURDIR)/lib $(shell pkg-config --libs libavcodec freetype2) -fPIC

OBJECTS := bin/fata_morgana.o bin/fmmath.o bin/write_text.o

lib/libfata_morgana.so: $(OBJECTS) bin
	cc $(CFLAGS) $(LFLAGS) -shared -o $@ $(OBJECTS)

bin/test: c-src/test.c bin
	cc $(CFLAGS) -lfata_morgana -L$(CURDIR)/lib -o bin/test $<

bin/fmmath.o: c-src/fmmath.c bin
	cc $(CFLAGS) -g -c -o $@ $<

bin/write_text.o: c-src/write_text.c bin
	cc $(CFLAGS) -g -c -o $@ $<

bin/fata_morgana.o: c-src/fata_morgana.c bin
	cc $(CFLAGS) -g -c -o $@ $<

izl:
	cp zig-out/lib/libfata_morgana.dylib lib/libfata_morgana.so

bin:
	mkdir -p bin

run:
	bin/test test.mpeg mpeg1video
