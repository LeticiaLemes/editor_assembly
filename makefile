# Makefile corrigido
.PHONY: all clean run

NASM = nasm
LD = x86_64-w64-mingw32-ld
OBJ = editor.obj
EXE = editor.exe

all: $(EXE)

$(EXE): $(OBJ)
	$(LD) -m i386pep --subsystem console --entry start -o $@ $^ -lkernel32 -luser32 -ladvapi32

$(OBJ): editor.asm
	$(NASM) -f win64 $< -o $@

clean:
	rm -f $(OBJ) $(EXE)

run: $(EXE)
	wine $(EXE)