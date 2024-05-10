CC_FLAGS += -O2 -g -I/usr/local/include/freetype2
LD_FLAGS += -L$(CURDIR)/lib -lfreetype -lavcodec -lm -fPIC

OBJECTS := bin/fata_morgana.o bin/fmmath.o bin/write_text.o


lib/libfata_morgana.so: $(OBJECTS) bin
	cc $(CC_FLAGS) $(LD_FLAGS) -shared -o $@ $(OBJECTS)

bin/test: c-src/test.c bin lib/libfata_morgana.so
	cc -lfata_morgana -L$(CURDIR)/lib -o bin/test $<

bin/fmmath.o: c-src/fmmath.c bin
	cc $(CC_FLAGS) -g -c -o $@ $<

bin/write_text.o: c-src/write_text.c bin
	cc $(CC_FLAGS) -g -c -o $@ $<

bin/fata_morgana.o: c-src/fata_morgana.c bin
	cc $(CC_FLAGS) -g -c -o $@ $<

bin:
	mkdir -p bin
run:
	bin/test test.mpeg mpeg1video
