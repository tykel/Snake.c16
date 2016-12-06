AS=as16
ASFLAGS=
IMG=img16
IMGFLAGS=-k 1

.PHONY: all gfx clean

all: Snake.c16

Snake.c16: Snake.s gfx
	$(AS) $< $(ASFLAGS) -o $@ -m
	ctags --language-force=asm $< 

gfx:
	$(IMG) gfx/fruit0.bmp -o gfx/fruit0.bin $(IMGFLAGS)
	$(IMG) gfx/snake_seg.bmp -o gfx/snake_seg.bin $(IMGFLAGS)
	$(IMG) gfx/snake_life.bmp -o gfx/snake_life.bin $(IMGFLAGS)
	$(IMG) gfx/cursor.bmp -o gfx/cursor.bin $(IMGFLAGS)

clean:
	rm -rf Snake.c16
