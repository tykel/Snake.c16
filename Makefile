AS=as16
ASFLAGS=
IMG=img16
IMGFLAGS=-k 1
GFX=gfx/fruit0.bin gfx/snake_seg.bin gfx/snake_life.bin gfx/cursor.bin

.PHONY: all gfx clean

all: Snake.c16 Music.c16

Snake.c16: Snake.s $(GFX)
	$(AS) $< $(ASFLAGS) -o $@ -m
	ctags --language-force=asm $< 

Music.c16: Music.s
	$(AS) $< $(ASFLAGS) -o $@ -m
	ctags --language-force=asm $< 

gfx/%.bin: gfx/%.bmp
	$(IMG) $< -o $@ $(IMGFLAGS)

clean:
	rm -rf Snake.c16
