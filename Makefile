CC = gcc
ASMBIN = nasm
ifeq ($(OS), Windows_NT)
    FORMAT = win64
    EXTENSION = .exe
    RM = del
    ASMFLAGS = --prefix _
    DEFINES = -D__USE_MINGW_ANSI_STDIO=1
else
    FORMAT = elf64
    EXTENSION =
    RM = rm
    ASMFLAGS =
    DEFINES = 
endif

all : asm cc link
asm : 
	#$(ASMBIN) -o rgb_triangle.o -f $(FORMAT) $(ASMFLAGS) -g -l rgb_triangle.lst rgb_triangle.asm
cc :
	$(CC) -m64 -c -g -O0 $(DEFINES) main.c
link :
	#$(CC) -m64 -o rgb_triangle$(EXTENSION) rgb_triangle.o main.o -lm
	$(CC) -m64 -o rgb_triangle$(EXTENSION) main.o -lm
clean :
	$(RM) *.o
	$(RM) rgb_triangle$(EXTENSION)
	$(RM) rgb_triangle.lst
