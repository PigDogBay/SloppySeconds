;-----------------------------------------------------------------------------
; Game over: Joe has told Fumduck where to shove it and retired to a sunny
; beach. Sky, sun, gulls, sea with waves, sand, a palm tree and a cocktail,
; drawn with rectangles and (half) discs; the story is printed on the sand.
;-----------------------------------------------------------------------------

B_SKY_TOP           equ $37
B_SKY_MID           equ $5B
B_SKY_LOW           equ $7F
B_SUN               equ $FC
B_SUN_GLOW          equ $FD
B_SEA_FAR           equ $0B
B_SEA_NEAR          equ $13
B_FOAM              equ COL_WHITE
B_SAND              equ $F9
B_SAND_WET          equ $D5
B_TRUNK             equ $A8
B_TRUNK_RING        equ $88
B_FROND             equ $14
B_FROND_DARK        equ $0C
B_COCONUT           equ $64
B_DRINK             equ $F0
B_BROLLY            equ $E6
B_GULL              equ $49
B_TEXT              equ $64             ; dark brown on the sand

SEA_Y               equ 116
SAND_Y              equ 152

game_over_enter:
        call screen_begin
        call beach_draw_scene

        TEXT 0, 10, COL_BLACK, 2            ; shadow
        ld hl, str_quit_title
        call print_centred
        TEXT 0, 8, COL_WHITE, 2
        ld hl, str_quit_title
        call print_centred
        TEXT 0, 182, B_TEXT, 1
        ld hl, str_quit_text
        call print_centred
        TEXT 0, 232, B_TEXT, 1
        call print_wages_centred
        TEXT 0, 245, COL_BLACK, 1
        ld hl, str_press_fire
        call print_centred
        jp screen_end

game_over_update:
        ld a, ST_TITLE
        jp wait_fire_then

beach_draw_scene:
        ; Sky
        FILL_RECT 0, 0, SCREEN_W, 48, B_SKY_TOP
        FILL_RECT 0, 44, SCREEN_W, 40, B_SKY_MID
        FILL_RECT 0, 84, SCREEN_W, SEA_Y - 84, B_SKY_LOW

        ; Sun with a soft glow
        DISC 268, 64, 26, B_SUN_GLOW
        DISC 268, 64, 21, B_SUN

        ; Gulls
        FILL_RECT 164, 46, 4, 1, B_GULL
        FILL_RECT 168, 47, 1, 1, B_GULL
        FILL_RECT 169, 46, 4, 1, B_GULL
        FILL_RECT 190, 58, 3, 1, B_GULL
        FILL_RECT 193, 59, 1, 1, B_GULL
        FILL_RECT 194, 58, 3, 1, B_GULL

        ; Sea, getting lighter towards the shore, with white wave crests
        FILL_RECT 0, SEA_Y, SCREEN_W, 16, B_SEA_FAR
        FILL_RECT 0, SEA_Y + 16, SCREEN_W, SAND_Y - SEA_Y - 16, B_SEA_NEAR
        FILL_RECT 20, 122, 14, 1, B_FOAM
        FILL_RECT 150, 120, 10, 1, B_FOAM
        FILL_RECT 236, 125, 16, 1, B_FOAM
        FILL_RECT 120, 136, 18, 1, B_FOAM
        FILL_RECT 200, 140, 12, 1, B_FOAM
        FILL_RECT 284, 135, 20, 1, B_FOAM
        FILL_RECT 170, 146, 24, 1, B_FOAM
        FILL_RECT 250, 144, 18, 1, B_FOAM
        FILL_RECT 0, SAND_Y - 2, SCREEN_W, 2, B_FOAM     ; surf

        ; Sand
        FILL_RECT 0, SAND_Y, SCREEN_W, 4, B_SAND_WET
        FILL_RECT 0, SAND_Y + 4, SCREEN_W, SCREEN_H - SAND_Y - 4, B_SAND

        ; Palm trunk: segments leaning right as they go up
        FILL_RECT 56, 160, 9, 14, B_TRUNK
        FILL_RECT 58, 148, 9, 12, B_TRUNK_RING
        FILL_RECT 61, 136, 8, 12, B_TRUNK
        FILL_RECT 64, 124, 8, 12, B_TRUNK_RING
        FILL_RECT 68, 112, 7, 12, B_TRUNK
        FILL_RECT 72, 100, 7, 12, B_TRUNK_RING
        FILL_RECT 76, 88, 6, 12, B_TRUNK
        FILL_RECT 80, 76, 6, 12, B_TRUNK_RING

        ; Fronds: drooping ones underneath (darker), arching ones on top
        FILL_RECT 84, 71, 14, 6, B_FROND_DARK            ; right, drooping
        FILL_RECT 96, 73, 12, 6, B_FROND_DARK
        FILL_RECT 106, 76, 9, 6, B_FROND_DARK
        FILL_RECT 113, 81, 6, 6, B_FROND_DARK
        FILL_RECT 117, 87, 4, 7, B_FROND_DARK
        FILL_RECT 70, 71, 14, 6, B_FROND_DARK            ; left, drooping
        FILL_RECT 60, 73, 12, 6, B_FROND_DARK
        FILL_RECT 53, 76, 9, 6, B_FROND_DARK
        FILL_RECT 49, 81, 6, 6, B_FROND_DARK
        FILL_RECT 46, 87, 4, 7, B_FROND_DARK
        FILL_RECT 86, 64, 14, 7, B_FROND                 ; right, arching
        FILL_RECT 98, 60, 12, 6, B_FROND
        FILL_RECT 108, 58, 9, 5, B_FROND
        FILL_RECT 115, 59, 6, 4, B_FROND
        FILL_RECT 120, 62, 3, 5, B_FROND
        FILL_RECT 68, 64, 14, 7, B_FROND                 ; left, arching
        FILL_RECT 58, 60, 12, 6, B_FROND
        FILL_RECT 51, 58, 9, 5, B_FROND
        FILL_RECT 46, 59, 6, 4, B_FROND
        FILL_RECT 43, 62, 3, 5, B_FROND
        FILL_RECT 78, 56, 10, 12, B_FROND                ; crown
        FILL_RECT 74, 52, 6, 5, B_FROND                  ; top leaves
        FILL_RECT 87, 52, 6, 5, B_FROND
        DISC 81, 76, 3, B_COCONUT
        DISC 88, 77, 3, B_COCONUT

        ; A cocktail on the sand, with a little umbrella and a straw
        FILL_RECT 160, 147, 1, 10, COL_WHITE             ; straw
        HALF_DISC 172, 152, 6, B_BROLLY, 0               ; umbrella
        FILL_RECT 172, 152, 1, 6, COL_WHITE
        FILL_RECT 158, 156, 16, 2, COL_WHITE             ; rim
        FILL_RECT 159, 158, 14, 2, B_DRINK               ; the glass, narrowing
        FILL_RECT 161, 160, 10, 2, B_DRINK
        FILL_RECT 163, 162, 6, 2, B_DRINK
        FILL_RECT 165, 164, 2, 8, COL_WHITE              ; stem
        FILL_RECT 161, 172, 10, 2, COL_WHITE             ; foot
        ret

str_quit_title:     db "JOE'S HAD ENOUGH!", 0
str_quit_text:      db "HE STORMED INTO THE CHAIRMAN'S OFFICE", 13
                    db "AND TOLD FUMDUCK TO SHOVE THE JOB", 13
                    db "WHERE THE SUN DON'T SHINE.", 13
                    db "NOW JOE GETS ALL THE SUN HE WANTS.", 0
