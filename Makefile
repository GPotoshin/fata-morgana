CC_FLAGS += -O2 -g -I/usr/local/include/freetype2
LD_FLAGS += -L$(CURDIR)/lib -lfreetype -lavcodec -lm -fPIC

lib/libvideo.so: bin/video.o
	cc $(CC_FLAGS) $(LD_FLAGS) -shared -o $@ $<

bin/test: bin lib/libvideo.so lib/test.c
	cc -lvideo -L$(CURDIR)/lib lib/test.c -o bin/test

bin/video.o: bin lib/video.c
	cc $(CC_FLAGS) -g -c -o bin/video.o lib/video.c	

bin:
	mkdir -p bin
run:
	bin/test test.mpeg mpeg1video
