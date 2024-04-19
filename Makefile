LD_FLAGS += -lavutil -lavcodec 

OBJECTS := bin/video.o bin/action.o

test: $(OBJECTS)
	cc $(LD_FLAGS) -o test $(OBJECTS)

bin/video.o: lib/video.c
	cc -c -o bin/video.o lib/video.c	

bin/action.o: lib/video.c
	cc -c -o bin/action.o lib/action.c

bin/test.o: lib/test.c
	cc -c -o bin/action.o lib/action.c

run:
	test test.mpeg mpeg1video
