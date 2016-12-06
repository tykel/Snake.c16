;--------------------------------------
; Snake.s
;--------------------------------------
; Simple Snake clone written for Chip16
; Showcases graphics, input, sound
;
; Subroutine arguments are r0-7.
;
; Game-persistent registers:
; r8: snake head x
; r9: snake head y
; ra: snake head index
; rb: snake tail index
; rc: snake length
; rd: snake direction (0=up, 1=down, 2=left, 3=right)
; re: wait frames/cycle << 2
; rf: zero register
;--------------------------------------

; TODO:
; [x]Write head + segs to level collision map
; [x]Make items appear randomly, write to map
; [x]Check head for collisions with items/segs
; [x]Increase num_segs + score for item collision
; [x]Increase speed every N items picked up
; [ ]Add intro screen
; [x]Add game over screen
; [ ]Add music to intro/game over screens

;--------------------------------------
; Constants
;--------------------------------------
SNAKE_SPR_W                equ   8
SNAKE_SEG_NB_INIT          equ   3
SNAKE_SEG_NB_MAX           equ   128 
SNAKE_SEG_MASK             equ   31
SCREEN_W                   equ   320
SCREEN_TILES_HRZ           equ   40
SCREEN_H                   equ   240
SCREEN_TILES_VRT           equ   29
CHAR_SPR_W                 equ   8
CHAR_SPR_LEN               equ   32
CHAR_ASCII_OFFS            equ   32
CHAR_0_OFFS                equ   48
MAP_SIZE                   equ   280
NUM_LIVES                  equ   3
;--------------------------------------

;--------------------------------------
; Graphics imports
;--------------------------------------
importbin gfx/snake_seg.bin 0 32 spr_snake_seg
importbin gfx/snake_life.bin 0 32 spr_snake_life
importbin gfx/cursor.bin 0 32 spr_cursor
importbin gfx/fruit0.bin 0 32 spr_fruit0
importbin gfx/font.bin 0 3072 spr_font
;--------------------------------------
 
;--------------------------------------
; Main code
;--------------------------------------
m_reset:    ldi rf, 0                  ; Reset zero register
            stm rf, var_score
            ldi r0, NUM_LIVES
            stm r0, var_lives

m_intro:    call sub_intro

m_start:    ldi rc, 1                  ; Reset snake size
            ldi re, 60                 ; Reset game speed (15 cyc/step)
            ldi r8, 160                ; Snake head at screen center
            ldi r9, 128
            ldi r0, var_snake_pos_arr  ; Zero snake pos. array
            ldi r1, SNAKE_SEG_NB_MAX
            call sub_clear_arr
            ldi r0, var_levelmap       ; Zero level collision map
            ldi r1, MAP_SIZE
            call sub_clear_arr
            stm rf, var_itemxy
            stm rf, var_gotitem
            stm rf, var_snake_grew
            ldi ra, 0                  ; Reset snake head index
            ldi rb, 0                  ; Reset snake tail index
            mov r0, r8                 ; Store initial head position in array
            shr r0, 3
            shl r0, 8
            mov r1, r9
            shr r1, 3
            or r0, r1
            stm r0, var_snake_pos_arr

m_cyc_loop: nop
            stm rf, var_snake_grew
            stm rf, var_gotitem

m_itm_spwn: ldm r0, var_itemxy
            cmpi r0, 0
            jnz m_itm_spwZ
is:         rnd r0, 39
            rnd r1, 28
            addi r1, 1
            mov r2, r0
            shl r2, 8
            or r2, r1
            stm r2, var_itemxy
            ldi r2, 2
            call sub_setmapv
m_itm_spwZ: nop

m_chkpause: ldm r0, var_input_acc       ; Read controller 0
            andi r0, 32                 ; Preserve START bit
            jz m_move_hd
            call sub_pause              ; Go into Pause mode

m_move_hd:  ldm r0, var_input_acc      ; Read controller 0
            andi r0, 0xf               ; Mask out all bits but Up,Dn,Lf,Rt
            jz m_move_hZ
            call sub_change_dir        ; Changing direction if != 0
m_move_hZ:  call sub_move_in_dir       ; Now move one step

m_clearscr: cls
            bgc 1                      ; Black background
m_check_hd: mov r0, r8
            shr r0, 3
            mov r1, r9
            shr r1, 3
            call sub_getmapv
            cmpi r0, 0                 ; If the head hits a zero cell,
            jz m_check_hZ              ; nothing happens
            cmpi r0, 1                 ; If the head hits a one cell...
            jnz m_check_hB
            call sub_death             ; ...we dead
            cmpi r0, 0                 ; If no lives are left, game over!
            jg m_check_hA
            call sub_gameover
            jmp m_reset
m_check_hA: jmp m_start                ; Followed by a restart
m_check_hB: cmpi r0, 2                 ; If the head hits a two cell...
            jnz m_check_hZ
            call sub_getitem           ; ...we got an item!
            ldm r0, var_itemxy         ; Reset item's map cell to 0
            call sub_unpack8b
            ldi r2, 0
            call sub_setmapv
            stm rf, var_itemxy         ; Reset item's x/y to 0
m_check_hZ: nop
            
m_inc_size: addi ra, 1
            andi ra, SNAKE_SEG_MASK
            cmpi rc, SNAKE_SEG_NB_INIT ; Increase snake size if still going...
            jl m_inc_sizA             ; ...through initial growth phase...
            ldm r0, var_gotitem
            cmpi r0, 0
            jz m_inc_sizY
m_inc_sizA: addi rc, 1 
            ldi r0, 1
            stm r0, var_snake_grew     ; ...and record it in a boolean
            jmp m_inc_sizZ
m_inc_sizY: addi rb, 1                 ; snake_seg_offs = (snake_seg_offs+1) % 8
            andi rb, SNAKE_SEG_MASK
m_inc_sizZ: nop

m_move_seg: mov r0, r8                 ; int xy = (snake_head_x << 8)
            shr r0, 3
            shl r0, 8                  ;              | snake_head_y;
            mov r1, r9
            shr r1, 3
            or r0, r1
            mov r1, ra                 ; int *p = snake_seg_offs
            shl r1, 1                  ;              + &var_snake_pos_arr;
            addi r1, var_snake_pos_arr
            stm r0, r1                 ; *p = xy;
m_move_seZ: nop

m_updmap:   mov r0, ra                 ; Set new head map cell to 1 since it is
            call sub_getsegxy          ; now occupied
            ldi r2, 1
            call sub_setmapv
            ldm r0, var_snake_grew
            cmpi r0, 0
            jnz m_updmaZ
            mov r0, rb                 ; If snake did NOT grow, set old tail
            subi r0, 1                 ; map cell to 0 since it is now empty
            andi r0, SNAKE_SEG_MASK
            call sub_getsegxy
            ldi r2, 0
            call sub_setmapv
m_updmaZ:   nop

m_blit:     spr 0x0804                 ; Font sprite size is 8x8
            ldi r0, var_str_score      ; Print "SCORE: "
            ldi r1, 0
            ldi r2, 0
            call sub_print
            ldi r0, var_str_score_val  ; Convert score to ASCII-BCD
            ldm r1, var_score
            call sub_valtobcd
            ldi r0, var_str_score_val  ; And print it
            ldi r1, 56
            ldi r2, 0
            call sub_print
            ldi r0, var_str_lives      ; Print "LIVES: "
            ldi r1, 104
            ldi r2, 0
            call sub_print
            ldi r0, 160                ; Draw a sprite for each life left
            ldi r1, 0
            ldm r2, var_lives
m_bliA:     cmpi r2, 0
            jz m_bliB
            drw r0, r1, spr_snake_life
            addi r0, 16
            subi r2, 1
            jmp m_bliA
m_bliB:     spr 0x0804                 ; Snake sprite size is 8x8
            ldm r0, var_itemxy
            cmpi r0, 0                 ; If an item has spawned...
            jz m_bliC                  ; ...draw it
            call sub_unpack8b
            shl r0, 3
            shl r1, 3
            drw r0, r1, spr_fruit0
m_bliC:     mov r6, rb
            mov r7, ra
            addi r7, 1
            andi r7, SNAKE_SEG_MASK
m_bliD:     cmp r6, r7
            jz m_bliZ
            mov r0, r6
            call sub_blit_seg
            addi r6, 1
            andi r6, SNAKE_SEG_MASK
            jmp m_bliD
m_bliZ:     nop

m_sfx:      ldm r0, var_gotitem
            cmpi r0, 1
            jz m_cyc_end
            sng 0x44, 0x6343           ; Play a short noise sample every step
            ldi r0, var_sfx_move
            snp r0, 32

m_cyc_end:  ldi r0, 0                  ; Reset accumulated input mask
            stm r0, var_input_acc
            mov r0, re                 ; Wait for 0.16 seconds
            shr r0, 2
            call sub_wait
m_cyc_enZ:  jmp m_cyc_loop             ; And on to next game loop iteration

;--------------------------------------

;--------------------------------------
; Subroutine code
;--------------------------------------
;
;--------------------------------------
; sub_clear_arr(ptr, num_elems)
;--------------------------------------
sub_clear_arr: ldi r2, 0                  ; int i;
sub_clear_arA: cmp r2, r1                 ; while (i < num_elems) {
               jz sub_clear_arZ           ;   *ptr = 0;
               stm rf, r0                 ;   ptr++;
               addi r0, 2                 ;   i++;
               addi r2, 1                 ; }
               jmp sub_clear_arA
sub_clear_arZ: ret
;--------------------------------------
; sub_blit_seg(i)
;--------------------------------------
sub_blit_seg:  shl r0, 1
               addi r0, var_snake_pos_arr ; n = n + &var_snake_pos_arr;
               ldm r0, r0                 ; int x = *n;
               mov r1, r0                 ; int y = x;
               shr r0, 8                  ; x = x >> 8;
               shl r0, 3
               andi r1, 0xff              ; y = y & 0xff;
               shl r1, 3
x:             drw r0, r1, spr_snake_seg  ; drw(x, y, spr_snake_seg);
               ret
;--------------------------------------
; sub_change_dir(btn_mask)
;--------------------------------------
sub_change_dir:   tsti r0, 1              ; up
                  jnz sub_change_diA
                  tsti r0, 2              ; down
                  jnz sub_change_diB
                  tsti r0, 4              ; left
                  jnz sub_change_diC
                  jmp sub_change_diD      ; right
sub_change_diA:   cmpi rd, 1              ; check if currently downwards...
                  jz sub_change_diZ       ; illegal to backtrack
                  ldi rd, 0
                  jmp sub_change_diZ
sub_change_diB:   cmpi rd, 0              ; check if currently upwards...
                  jz sub_change_diZ       ; illegal to backtrack
                  ldi rd, 1
                  jmp sub_change_diZ
sub_change_diC:   cmpi rd, 3              ; check if currently rightwards...
                  jz sub_change_diZ       ; illegal to backtrack
                  ldi rd, 2
                  jmp sub_change_diZ
sub_change_diD:   cmpi rd, 2              ; check if currently leftwards...
                  jz sub_change_diZ       ; illegal to backtrack
                  ldi rd, 3
sub_change_diZ:   ret
                  
;--------------------------------------
; sub_move_in_dir()
;--------------------------------------
sub_move_in_dir:  mov r0, rd              ; int dir = snake_direction;
                  shl r0, 1
                  addi r0, var_snake_dir_dy
                  ldm r1, r0              ; int dy = *((dir<<1)+&var_snake_dir_dy);
                  subi r0, 8
                  ldm r0, r0              ; int dx = *(dy - 8);
                  add r8, r0              ; snake_head_x += dx;
                  modi r8, SCREEN_W       ; snake_head_x %= SCREEN_W;
                  add r9, r1              ; snake_head_y += dy;
                  modi r9, SCREEN_H       ; snake_head_y %= SCREEN_H;
                  ret

;--------------------------------------
; sub_wait(num_frames)
;--------------------------------------
sub_wait:      cmpi r0, 0
               jz sub_waiZ
               vblnk
               ldm r1, 0xfff0
               ldm r2, var_input_acc
               or r2, r1
               stm r2, var_input_acc
               subi r0, 1
               jmp sub_wait
sub_waiZ:      ret
;--------------------------------------
; sub_print(str, x, y)
;--------------------------------------
sub_print:     ldi r3, 0
sub_prinA:     cmpi r3, 40
               jz sub_prinZ
               ldm r4, r0
               andi r4, 0xff
               jz sub_prinZ
               subi r4, CHAR_ASCII_OFFS
               jc sub_prinB
               muli r4, CHAR_SPR_LEN
               addi r4, spr_font
               drw r1, r2, r4
sub_prinB:     addi r3, 1
               addi r1, CHAR_SPR_W
               cmpi r1, SCREEN_W
               jl sub_prinC
               ldi r1, 0                  ; Wrap line if necessary
               addi r2, CHAR_SPR_W
sub_prinC:     addi r0, 1
               jmp sub_prinA
sub_prinZ:     ret
;--------------------------------------
; sub_valtobcd(str, val)
;--------------------------------------
sub_valtobcd:  ldi r2, 10000
sub_valtobcA:  cmpi r2, 0
               jz sub_valtobcZ
               div r1, r2, r3
               remi r3, 10
               addi r3, CHAR_0_OFFS
               ldm r4, r0
               andi r4, 0xff00
               or r3, r4
               stm r3, r0
               addi r0, 1
               divi r2, 10
               jmp sub_valtobcA
sub_valtobcZ:  ret
;--------------------------------------
; sub_getsegxy(i)
;--------------------------------------
sub_getsegxy:  shl r0, 1
               addi r0, var_snake_pos_arr
               ldm r1, r0                 ; int x = xy >> 8;
               mov r0, r1                 ; int y = xy & 0xff;
               shr r0, 8
               andi r1, 0xff
               ret                        ; return (x, y);
;--------------------------------------
; sub_getmapv(tx, ty)
;--------------------------------------
sub_getmapv:   muli r1, SCREEN_TILES_HRZ
               add r0, r1
               shl r0, 1
               addi r0, var_levelmap
               ldm r0, r0
               ret
;--------------------------------------
; sub_setmapv(tx, ty, val)
;--------------------------------------
sub_setmapv:   muli r1, SCREEN_TILES_HRZ
               add r0, r1
               shl r0, 1
               addi r0, var_levelmap
               stm r2, r0
               ret
;--------------------------------------
; sub_death()
;--------------------------------------
sub_death:     bgc 3
               ldi r1, var_sfx_death0
               sng 0x44, 0x8383
               snp r1, 100 
               ldi r0, 10
               call sub_wait
               bgc 1
               ldi r1, var_sfx_death1
               sng 0x44, 0x8383
               snp r1, 100 
               ldi r0, 10
               call sub_wait
               bgc 3
               ldi r1, var_sfx_death2
               sng 0x44, 0x838a
               snp r1, 300 
               ldi r0, 135
               call sub_wait
               bgc 1
               ldm r0, var_lives
               subi r0, 1
               stm r0, var_lives
               ret
;--------------------------------------
; sub_gameover()
;--------------------------------------
sub_gameover:  cls
               spr 0x0804
               ldi r0, var_str_gameover
               ldi r1, 88
               ldi r2, 116
               call sub_print
               sng 0x34, 0xc3cb
               ldi r0, var_sfx_gameover
               snp r0, 1000
               ldi r0, 300
               call sub_wait
               ret
;--------------------------------------
; sub_pause()
;--------------------------------------
sub_pause:      ldi r0, var_str_pause
                ldi r1, 240
                ldi r2, 0
                spr 0x0804
                call sub_print
                ldi r1, 2
sub_pausA:      cmpi r1, 0
                jz sub_pausB
                push r1
                ldi r0, var_sfx_pause0
                sng 0x44, 0x6243
                snp r0, 100
                ldi r0, 6 
                call sub_wait
                ldi r0, var_sfx_pause1
                snp r0, 100
                ldi r0, 6
                call sub_wait
                pop r1
                subi r1, 1
                jmp sub_pausA
sub_pausB:      ldm r0, 0xfff0
                andi r0, 32
                jnz sub_pausC
                vblnk
                jmp sub_pausB
sub_pausC:      stm rf, 0xfff0
                stm rf, var_input_acc
                ldi r1, 2
sub_pausD:      cmpi r1, 0
                jz sub_pausZ
                push r1
                ldi r0, var_sfx_pause1
                sng 0x44, 0x6243
                snp r0, 100
                ldi r0, 6 
                call sub_wait
                ldi r0, var_sfx_pause0
                snp r0, 100
                ldi r0, 6
                call sub_wait
                pop r1
                subi r1, 1
                jmp sub_pausD
sub_pausZ:      ret
;--------------------------------------
; sub_intro()
;--------------------------------------
sub_intro:      bgc 1
                cls
                spr 0x0804
                ldi r1, 88
                ldi r2, 82
                drw r1, r2, spr_snake_life
                addi r1, 144
                drw r1, r2, spr_snake_life
                ldi r0, var_str_title
                ldi r1, 112
                ldi r2, 82
                call sub_print
                ldi r0, var_str_copyright
                ldi r1, 104
                ldi r2, 224
                call sub_print
                ldi r0, var_str_start
                ldi r1, 128
                ldi r2, 136
                call sub_print
                ldi r1, 112
                ldi r2, 135
                drw r1, r2, spr_cursor
                ldi r0, var_str_options
                ldi r1, 128
                ldi r2, 152
                call sub_print
sub_intrA:      ldm r0, 0xfff0
                tsti r0, 32
                jnz sub_intrZ
                vblnk
                jmp sub_intrA
sub_intrZ:      ldi r0, 6
                call sub_wait
                stm rf, 0xfff0
                stm rf, var_input_acc
                ret
;--------------------------------------
; sub_getitem()
;--------------------------------------
sub_getitem:   bgc 13
               vblnk
               cmpi rc, SNAKE_SEG_NB_MAX
               jz sub_getiteA
               addi rc, 1
sub_getiteA:   ldm r0, var_score
               addi r0, 100
               stm r0, var_score
               ldi r0, var_sfx_item
               sng 0x44, 0x8387
               snp r0, 100
               cmpi re, 1
               jz sub_getiteY
               subi re, 1
sub_getiteY:   ldi r0, 1
               stm r0, var_gotitem
               cmpi rc, SNAKE_SEG_NB_MAX
               jz sub_getiteZ
               stm r0, var_snake_grew
sub_getiteZ:   ret
;--------------------------------------
; sub_get_av16(ptr, i)
;--------------------------------------
sub_get_av16:  shl r1, 1
               add r0, r1
               ldm r0, r0
               ret
;--------------------------------------
; sub_get_av8(ptr, i)
;--------------------------------------
sub_get_av8:  add r0, r1
               ldm r0, r0
               andi r0, 0xff
               ret
;--------------------------------------
; sub_set_av16(ptr, i, val)
;--------------------------------------
sub_set_av16:  shl r1, 1
               add r0, r1
               stm r2, r0
               ret
;--------------------------------------
; sub_set_av8(ptr, i, val)
;--------------------------------------
sub_set_av8:   shl r1, 1
               add r0, r1
               ldm r1, r0
               andi r1, 0xff00
               andi r2, 0x00ff
               or r2, r1
               stm r2, r0
               ret
;--------------------------------------
; sub_unpack8b(x)
;--------------------------------------
sub_unpack8b:  mov r1, r0
               shr r0, 8
               andi r1, 0xff
               ret
;--------------------------------------
; sub_unpack4b(x)
;--------------------------------------
sub_unpack4b:  mov r1, r0
               mov r2, r0
               mov r3, r0
               shr r0, 12
               shr r1, 8
               andi r1, 0xf
               shr r2, 4
               andi r2, 0xf
               andi r3, 0xf
               ret
;--------------------------------------
; sub_pack8b(b0, b1)
;--------------------------------------
sub_pack8b:    shl r0, 8
               andi r1, 0xff
               or r0, r1
               ret
;--------------------------------------
; sub_pack4b(b0, b1, b2, b3)
;--------------------------------------
sub_pack4b:    shl r0, 12
               andi r1, 0xf
               or r0, r1
               shl r1, 8
               andi r2, 0xf
               or r0, r2
               shl r2, 4
               andi r3, 0xf
               or r0, r3
               ret
;--------------------------------------

;--------------------------------------
; Variables / Arrays
;--------------------------------------
var_snake_pos_arr:
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0
;--------------------------------------
var_snake_dir_dx:
   dw 0, 0, -8, 8
var_snake_dir_dy:
   dw -8, 8, 0, 0
;--------------------------------------
var_levelmap:
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
   dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;--------------------------------------
var_old_snake_hx:
   dw 0
var_old_snake_hy:
   dw 0
var_input_acc:
   dw 0
;--------------------------------------
var_str_score:
   db "SCORE: "
   db 0
var_str_score_val:
   db 0, 0, 0, 0, 0, 0
var_str_lives:
   db "LIVES: "
   db 0
var_str_gameover:
   db "G A M E    O V E R"
   db 0
var_str_pause:
    db "(PAUSED)"
    db 0
var_str_title:
    db "S  N  A  K  E"
    db 0
var_str_copyright:
    db "(C) tykel, 2016"
    db 0
var_str_start:
    db "START"
    db 0
var_str_options:
    db "OPTIONS"
    db 0
;--------------------------------------
var_sfx_move:
   dw 1000
var_sfx_death0:
   dw 1102
var_sfx_death1:
   dw 890
var_sfx_death2:
   dw 1020
var_sfx_gameover:
   dw 300
var_sfx_item:
   dw 1975
var_sfx_pause0:
    dw 1567
var_sfx_pause1:
    dw 1318
;--------------------------------------
var_snake_grew:
   dw 0
var_gotitem:
   dw 0
var_itemxy:
   dw 0
;--------------------------------------
var_score:
   dw 0
var_lives:
    dw 0
