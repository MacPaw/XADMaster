CFLAGS=-std=c99 -g

LDFLAGS=
LIBS=

CC=gcc
LD=gcc

C_FILES=ArithmeticDecoder.c \
        Decompressor.c \
        RawDecoder.c \
		../lzma/LzmaDec.c \

OBJS=$(C_FILES:.c=.o)

RawDecoder: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

depend:
	$(CC) -MM $(CFLAGS) $(C_FILES) >Dependencies.tmp
	sed 's/.*: *\([^ ]*\)\.\([^ ]*\)/\1.o: \1.\2/g' <Dependencies.tmp >Dependencies
	rm Dependencies.tmp

include Dependencies

