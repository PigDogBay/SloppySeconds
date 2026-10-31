;-----------------------------------------------------------------------------
; Title screen: the Sideways factory (inspired by the incinerator photo in
; Factory.jpeg) under a grey sky, drawn with rectangles and half discs.
; Joe shambles across the yard into the loading bay, again and again.
;-----------------------------------------------------------------------------

; Scene colours (RRRGGGBB)
T_SKY_TOP           equ $6E             ; slate
T_SKY_MID           equ $92
T_SKY_LOW           equ $B7
T_CLAD              equ $DA             ; pale warm grey cladding
T_CLAD_DARK         equ $B6
T_GREEN             equ $B9             ; pale green cladding
T_WINDOW            equ $25
T_FRAME             equ $B6
T_CHIMNEY           equ $B6
T_BAND              equ $2F             ; blue band round the chimney
T_BASE              equ $49
T_TARMAC            equ $6D
T_KERB              equ $92
T_BAY               equ $24
T_POST              equ $FC
T_HOARDING          equ $4B

TITLE_JOE_Y         equ 176             ; feet on the yard, just below the kerb
TITLE_GATE_X        equ 212             ; Joe disappears into the bay here
TITLE_STEP_FRAMES   equ 3               ; frames per pixel walked
TITLE_PAUSE         equ 100             ; frames before he walks in again

title_enter:
        call screen_begin
        call title_draw_scene

        TEXT 0, 10, COL_BLACK, 2            ; shadow
        ld hl, str_title
        call print_centred
        TEXT 0, 8, COL_YELLOW, 2
        ld hl, str_title
        call print_centred
        TEXT 0, 30, COL_WHITE, 1
        ld hl, str_title_sub
        call print_centred
        TEXT 244, 180, T_BAY, 1
        ld hl, str_factory_sign
        call print_string
        TEXT 0, 220, COL_YELLOW, 1
        ld hl, str_clock_on
        call print_centred
        TEXT 0, 234, COL_WHITE, 1
        ld hl, str_title_controls
        call print_centred

        xor a
        ld (joe_facing), a
        ld (title_wait), a
        call bucket_empty           ; he carries an empty bucket in
        ld hl, 0
        ld (joe_x), hl
        ld a, TITLE_STEP_FRAMES
        ld (title_step), a
        jp screen_end

title_update:
        ld a, (input_new)
        bit INPUT_FIRE, a
        jr z, .animate
        call rand_mix
        call new_game
        ld a, ST_LEVEL_INTRO
        jp change_state

.animate:
        ld a, (title_wait)
        or a
        jr z, .walk
        dec a
        ld (title_wait), a
        ret nz
        ld hl, 0                    ; pause over: start again from the left
        ld (joe_x), hl
        ret
.walk:
        ld hl, title_frame
        inc (hl)
        ld hl, title_step
        dec (hl)
        jr nz, .draw
        ld (hl), TITLE_STEP_FRAMES
        ld hl, (joe_x)
        inc hl
        ld (joe_x), hl
        ld de, TITLE_GATE_X
        or a
        sbc hl, de
        jr c, .draw
        call sprites_hide_all       ; through the gates
        ld a, TITLE_PAUSE
        ld (title_wait), a
        ret
.draw:
        ld a, (title_frame)         ; bob a pixel every 8 frames: a shamble
        rrca
        rrca
        rrca
        and 1
        add a, TITLE_JOE_Y
        ld (joe_y), a
        jp joe_draw

title_draw_scene:
        ; Overcast sky in three bands, with cloud tops rolling into each
        FILL_RECT 0, 0, SCREEN_W, 60, T_SKY_TOP
        FILL_RECT 0, 60, SCREEN_W, 64, T_SKY_MID
        FILL_RECT 0, 124, SCREEN_W, 76, T_SKY_LOW
        HALF_DISC 24, 60, 26, T_SKY_MID, 0
        HALF_DISC 58, 60, 12, T_SKY_MID, 0
        HALF_DISC 226, 60, 14, T_SKY_MID, 0
        HALF_DISC 262, 60, 30, T_SKY_MID, 0
        HALF_DISC 304, 60, 12, T_SKY_MID, 0
        HALF_DISC 8, 124, 14, T_SKY_LOW, 0
        HALF_DISC 46, 124, 34, T_SKY_LOW, 0
        HALF_DISC 88, 124, 16, T_SKY_LOW, 0
        HALF_DISC 196, 124, 10, T_SKY_LOW, 0
        HALF_DISC 228, 124, 22, T_SKY_LOW, 0
        HALF_DISC 290, 124, 38, T_SKY_LOW, 0

        ; Autumn trees on the left, behind a blue hoarding
        HALF_DISC 10, 200, 36, $8C, 0
        HALF_DISC 46, 200, 28, $A8, 0
        HALF_DISC 80, 200, 32, $6C, 0
        HALF_DISC 24, 180, 16, $C8, 0
        HALF_DISC 58, 178, 13, $EC, 0
        HALF_DISC 86, 186, 12, $A8, 0
        HALF_DISC 4, 186, 10, $C8, 0
        FILL_RECT 0, 192, 100, 8, T_HOARDING

        ; Right: tall grey shed with an arched window on its roof
        FILL_RECT 236, 140, 84, 30, T_CLAD_DARK
        HALF_DISC 266, 140, 16, T_WINDOW, T_FRAME
        FILL_RECT 206, 150, 30, 20, T_CLAD

        ; Long green building with the loading bay
        FILL_RECT 168, 166, 152, 4, T_CLAD
        FILL_RECT 168, 170, 152, 26, T_GREEN
        FILL_RECT 168, 196, 152, 4, T_BASE
        FILL_RECT 210, 176, 22, 2, T_KERB           ; lintel
        FILL_RECT 212, 178, 18, 22, T_BAY           ; the gates
        FILL_RECT 210, 178, 2, 22, T_POST
        FILL_RECT 230, 178, 2, 22, T_POST

        ; Main block: pale cladding over a green band, four windows
        FILL_RECT 92, 152, 100, 4, T_KERB           ; roof edge
        FILL_RECT 96, 156, 92, 24, T_CLAD
        FILL_RECT 96, 180, 92, 14, T_GREEN
        FILL_RECT 96, 194, 92, 6, T_BASE
        FILL_RECT 104, 160, 12, 16, T_TARMAC
        FILL_RECT 124, 160, 12, 16, T_TARMAC
        FILL_RECT 144, 160, 12, 16, T_TARMAC
        FILL_RECT 168, 160, 12, 16, T_TARMAC
        FILL_RECT 109, 160, 2, 16, T_CLAD_DARK      ; mullions
        FILL_RECT 129, 160, 2, 16, T_CLAD_DARK
        FILL_RECT 149, 160, 2, 16, T_CLAD_DARK
        FILL_RECT 173, 160, 2, 16, T_CLAD_DARK

        ; Upper block: green with two arched windows, grey box on top
        FILL_RECT 116, 112, 64, 40, T_GREEN
        HALF_DISC 132, 152, 12, T_WINDOW, T_FRAME
        HALF_DISC 164, 152, 12, T_WINDOW, T_FRAME
        FILL_RECT 120, 96, 56, 16, T_CLAD

        ; The chimney
        FILL_RECT 140, 44, 14, 52, T_CHIMNEY
        FILL_RECT 140, 44, 3, 52, T_CLAD            ; highlight
        FILL_RECT 140, 52, 14, 6, T_BAND
        FILL_RECT 140, 42, 14, 3, T_CLAD            ; cap

        ; The yard
        FILL_RECT 0, 200, SCREEN_W, 56, T_TARMAC
        FILL_RECT 0, 200, SCREEN_W, 2, T_KERB
        FILL_RECT 240, 204, 20, 3, $C8              ; pallets
        FILL_RECT 240, 207, 20, 5, $A8
        ret

title_wait:     db 0                    ; >0: Joe's inside, counting down
title_step:     db 0
title_frame:    db 0

str_title:          db "SLOPPY SECONDS", 0
str_title_sub:      db "LIFE AT THE SIDEWAYS FACTORY", 0
str_factory_sign:   db "SIDEWAYS", 0
str_clock_on:       db "PRESS FIRE TO CLOCK ON", 0
str_title_controls: db "QAOP + SPACE OR KEMPSTON JOYSTICK", 13
                    db "CAPS SHIFT + SPACE (BREAK) TO PAUSE", 0
