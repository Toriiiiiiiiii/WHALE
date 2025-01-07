ASM = fasm
ASMFLAGS = -m 1000000

SRC = src/main.asm
INC = $(wildcard src/*.inc)
BIN = whale

$(BIN): $(SRC) $(INC)
	$(ASM) $< $@ $(ASMFLAGS)

clean:
	rm $(BIN)

