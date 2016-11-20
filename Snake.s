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
; ra: snake seg num
; rb: snake seg offset
; rc: score
; rd: snake direction (0=up, 1=down, 2=left, 3=right)
; re: wait frames/cycle (1/FPS)
;--------------------------------------

;--------------------------------------
; Constants
;--------------------------------------
SNAKE_SPR_W                equ   16
SNAKE_SEG_NB_INIT          equ   12
SNAKE_SEG_NB_MAX           equ   32
SNAKE_SEG_MASK             equ   0x1f
SCREEN_W                   equ   320
SCREEN_TILES_HORIZ         equ   20
SCREEN_H                   equ   240
SCREEN_TILES_VERT          equ   14
CHAR_SPR_W                 equ   8
CHAR_SPR_LEN               equ   32
CHAR_ASCII_OFFS            equ   32
CHAR_0_OFFS                equ   48
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
m_reset:    ldi r8, 160                ; Snake head at screen center
            ldi r9, 128
            ldi r0, var_snake_pos_arr  ; Zero snake pos. array
            ldi r1, SNAKE_SEG_NB_MAX
            call sub_clear_arr
            ldi ra, 1                  ; Reset snake seg num.            
            ldi rb, 0                  ; Zero snake seg offs.
            ldi rc, 0                  ; Zero score

m_move_hd:  stm r8, var_old_snake_hx
            stm r9, var_old_snake_hy
            ldm r0, 0xfff0             ; Read controller 0
            andi r0, 0xf               ; Mask out all bits but Up,Dn,Lf,Rt
            jz m_move_hZ
            call sub_change_dir        ; Changing direction if != 0
m_move_hZ:  call sub_move_in_dir       ; Now move one step

m_move_seg: ldm r0, var_old_snake_hx   ; int xy = (snake_head_x << 8)
            shr r0, 4
            shl r0, 8                  ;              | snake_head_y;
            ldm r1, var_old_snake_hy
            shr r1, 4
            or r0, r1
            mov r1, rb                 ; int *p = snake_seg_offs
            shl r1, 1                  ;              + &var_snake_pos_arr;
            addi r1, var_snake_pos_arr
            stm r0, r1                 ; *p = xy;
m_move_seZ: nop

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
            drw r8, r9, spr_snake_seg  ; Draw head
            mov r6, rb
            ldi r7, 0
m_bliA:     cmp r7, ra                 ; for (int i=0, o=snake_seg_offs;
            jz m_bliZ                  ;      i!=snake_seg_num;
            ldi r0, 0                  ;      i++, o=(o-1) & SNAKE_SEG_MASK) {
            mov r1, r6                 ;   sub_blit_seg(0, o);   
            call sub_blit_seg          ; }  
            addi r7, 1
            subi r6, 1
            andi r6, SNAKE_SEG_MASK
            jmp m_bliA
m_bliZ:     nop

m_sfx:      sng 0x44, 0x6343           ; Play a short noise sample every step
            ldi r0, var_sfx_move
            snp r0, 32

m_cyc_end:  ldi r0, 12                 ; Wait for 0.16 seconds
            call sub_wait
            addi rc, 10
            addi rb, 1                 ; snake_seg_offs = (snake_seg_offs+1) % 8
            andi rb, SNAKE_SEG_MASK
            cmpi ra, SNAKE_SEG_NB_INIT ; Increase snake size if still going...
            jge m_cyc_enZ              ; ...through initial growth phase
            addi ra, 1
m_cyc_enZ:  jmp m_move_hd              ; And on to next game loop iteration

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
               stm r0, 0                  ;   ptr++;
               addi r0, 2                 ;   i++;
               addi r2, 1                 ; }
               jmp sub_clear_arA
sub_clear_arZ: ret
;--------------------------------------
; sub_blit_seg(i, offs)
;--------------------------------------
sub_blit_seg:  add r0, r1, r2             ; int n = i + offs;
               andi r2, SNAKE_SEG_MASK    ; n = n & SNAKE_SEG_MASK;
               shl r2, 1
               addi r2, var_snake_pos_arr ; n = n + &var_snake_pos_arr;
               ldm r0, r2                 ; int x = *n;
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
;--------------------------------------
var_str_score:
   db "SCORE: "
   db 0
var_str_score_val:
   db 0, 0, 0, 0, 0, 0
;--------------------------------------
var_sfx_move:
   dw 1000
