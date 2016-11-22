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
; re: wait frames/cycle (1/FPS)
; rf: zero register
;--------------------------------------

; TODO:
;  - Write head + segs to level collision map
;  - Make items appear randomly, write to map
;  - Check head for collisions with items/segs
;  - Increase num_segs + score for item collision
;  - Increase speed every N items picked up
;  - Add intro screen
;  - Add game over screen
;  - Add music to intro/game over screens

;--------------------------------------
; Constants
;--------------------------------------
SNAKE_SPR_W                equ   16
SNAKE_SEG_NB_INIT          equ   12
SNAKE_SEG_NB_MAX           equ   32
SNAKE_SEG_MASK             equ   0x1f
SCREEN_W                   equ   320
SCREEN_TILES_HRZ           equ   20
SCREEN_H                   equ   240
SCREEN_TILES_VRT           equ   14
CHAR_SPR_W                 equ   8
CHAR_SPR_LEN               equ   32
CHAR_ASCII_OFFS            equ   32
CHAR_0_OFFS                equ   48
MAP_SIZE                   equ   280
;--------------------------------------

;--------------------------------------
; Graphics imports
;--------------------------------------
importbin gfx/snake_seg.bin 0 128 spr_snake_seg
importbin gfx/font.bin 0 3072 spr_font
;--------------------------------------


;--------------------------------------
; Main code
;--------------------------------------
m_reset:    ldi rf, 0                  ; Reset zero register
m_start:    ldi rc, 1                  ; Reset snake size
            ldi r8, 160                ; Snake head at screen center
            ldi r9, 128
            ldi r0, var_snake_pos_arr  ; Zero snake pos. array
            ldi r1, SNAKE_SEG_NB_MAX
            call sub_clear_arr
            ldi r0, var_levelmap       ; Zero level collision map
            ldi r1, MAP_SIZE
            call sub_clear_arr
            ldi ra, 0                  ; Reset snake head index
            ldi rb, 0                  ; Reset snake tail index
            mov r0, r8                 ; Store initial head position in array
            shr r0, 4
            shl r0, 8
            mov r1, r9
            shr r1, 4
            or r0, r1
            stm r0, var_snake_pos_arr

m_cyc_loop: nop

m_move_hd:  ldm r0, var_input_acc      ; Read controller 0
            andi r0, 0xf               ; Mask out all bits but Up,Dn,Lf,Rt
            jz m_move_hZ
            call sub_change_dir        ; Changing direction if != 0
m_move_hZ:  call sub_move_in_dir       ; Now move one step

m_check_hd: mov r0, r8
            shr r0, 4
            mov r1, r9
            shr r1, 4
            call sub_getmapv
            cmpi r0, 0                 ; If the head moves to a non-zero cell...
            jz m_check_hZ
            call sub_death             ; ...it's game over!
            jmp m_start                ; Followed by a restart
m_check_hZ: nop
            
m_inc_size: addi ra, 1
            stm rf, var_snake_grew
            cmpi rc, SNAKE_SEG_NB_INIT ; Increase snake size if still going...
            jge m_inc_sizY             ; ...through initial growth phase...
            addi rc, 1 
            ldi r0, 1
            stm r0, var_snake_grew     ; ...and record it in a boolean
            jmp m_inc_sizZ
m_inc_sizY: addi rb, 1                 ; snake_seg_offs = (snake_seg_offs+1) % 8
            andi rb, SNAKE_SEG_MASK
m_inc_sizZ: nop

m_move_seg: mov r0, r8                 ; int xy = (snake_head_x << 8)
            shr r0, 4
            shl r0, 8                  ;              | snake_head_y;
            mov r1, r9
            shr r1, 4
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

m_blit:     cls
            bgc 1                      ; Black background
            spr 0x0804                 ; Font sprite size is 8x8
            ldi r0, var_str_score      ; Print "SCORE: "
            ldi r1, 0
            ldi r2, 0
            call sub_print
            ldi r0, var_str_score_val  ; Convert score to ASCII-BCD
            mov r1, rc
            call sub_valtobcd
            ldi r0, var_str_score_val  ; And print it
            ldi r1, 56
            ldi r2, 0
            call sub_print
            spr 0x1008                 ; Snake sprite size is 16x16
            mov r6, rb
            mov r7, ra
            addi r7, 1
m_bliA:     cmp r6, r7                 ; for (int i=0, o=snake_seg_offs;
            jz m_bliZ                  ;      i!=snake_seg_num;
            mov r0, r6                 ;   sub_blit_seg(0, o);   
            call sub_blit_seg          ; }  
            addi r6, 1
            andi r6, SNAKE_SEG_MASK
            jmp m_bliA
m_bliZ:     nop

m_sfx:      sng 0x44, 0x6343           ; Play a short noise sample every step
            ldi r0, var_sfx_move
            snp r0, 32

m_cyc_end:  ldi r0, 0                  ; Reset accumulated input mask
            stm r0, var_input_acc
            ldi r0, 15                 ; Wait for 0.16 seconds
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
               shl r0, 4
               andi r1, 0xff              ; y = y & 0xff;
               shl r1, 4
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
               ret
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
sub_set_av8:  shl r1, 1
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
               shl r0, 8
               andi r1, 0xff
               ret
;--------------------------------------
; sub_unpack4b(x)
;--------------------------------------
sub_unpack4b:  mov r1, r0
               mov r2, r0
               mov r3, r0
               shl r0, 12
               shl r1, 8
               andi r1, 0xf
               shl r2, 4
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
;--------------------------------------
var_snake_dir_dx:
   dw 0, 0, -16, 16
var_snake_dir_dy:
   dw -16, 16, 0, 0
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
;--------------------------------------
var_sfx_move:
   dw 1000
;--------------------------------------
var_sfx_death0:
   dw 1102
var_sfx_death1:
   dw 890
var_sfx_death2:
   dw 1020
;--------------------------------------
var_snake_grew:
   dw 0
;--------------------------------------
var_score:
   dw 0
