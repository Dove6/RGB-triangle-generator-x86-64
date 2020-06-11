CC = gcc
ASMBIN = nasm
FORMAT = elf64
EXTENSION =
RM = rm
ASMFLAGS =
DEFINES = 

all : asm cc link
asm : 
	$(ASMBIN) -o draw_horizontal_line.o -f $(FORMAT) $(ASMFLAGS) -g -l draw_horizontal_line.lst draw_horizontal_line.asm
cc :
	$(CC) -m64 -std=c99 -c -g -O0 $(DEFINES) main.c
link :
	$(CC) -m64 -o rgb_triangle$(EXTENSION) draw_horizontal_line.o main.o -lm
clean :
	$(RM) *.o
	$(RM) rgb_triangle$(EXTENSION)
	$(RM) draw_horizontal_line.lst
