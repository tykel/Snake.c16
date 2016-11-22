AS=as16
ASFLAGS=
IMG=img16
IMGFLAGS=

.PHONY: all clean

all: Snake.c16

Snake.c16: Snake.s
	$(AS) $< $(ASFLAGS) -o $@ -m
	ctags --language-force=asm $< 

clean:
	rm -rf Snake.c16
