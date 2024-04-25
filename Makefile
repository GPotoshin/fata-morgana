lib/libvideo.so: bin/video.o
	cc -g -lavutil -lavcodec -lm -fPIC -shared -o $@ $<

bin/test: lib/libvideo.so lib/test.c
	cc -lvideo -L$(CURDIR)/lib lib/test.c -o bin/test

bin/video.o: lib/video.c
	cc -g -c -o bin/video.o lib/video.c	

run:
	bin/test test.mpeg mpeg1video
