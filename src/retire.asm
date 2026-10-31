;-----------------------------------------------------------------------------
; Game won: Joe retires with a cheap gold clock... and shortly afterwards
; ends up under a headstone. Dusk sky; the clock (with its
; 99p price tag still on) on the left, the grave on the right.
; The scene is a shape list (see draw_shapes) to save memory.
;-----------------------------------------------------------------------------

R_SKY_TOP           equ $45             ; purple dusk
R_SKY_MID           equ $69
R_SKY_LOW           equ $8D
R_GRASS             equ $2C
R_TUFT              equ $28
R_GOLD              equ $F4
R_GOLD_DARK         equ $B0
R_GOLD_LIGHT        equ $FD
R_WOOD              equ $88
R_WOOD_LIGHT        equ $A8
R_STONE             equ $92
R_STONE_DARK        equ $6D
R_CARVING           equ $49
R_SOIL              equ $44
R_GROUND_Y          equ 176
R_CLOCK_X           equ 80              ; clock centre
R_GRAVE_X           equ 240             ; headstone centre

game_won_enter:
        call screen_begin
        ld hl, retire_scene
        call draw_shapes

        TEXT 0, 10, COL_BLACK, 2            ; shadow
        ld hl, str_won_title
        call print_centred
        TEXT 0, 8, R_GOLD, 2
        ld hl, str_won_title
        call print_centred
        TEXT 0, 30, COL_WHITE, 1
        ld hl, str_won_text
        call print_centred

        TEXT R_GRAVE_X - 7 * 4, 48, COL_WHITE, 1
        ld hl, str_won_shortly
        call print_string
        TEXT R_GRAVE_X - 13 * 4, 60, COL_WHITE, 1
        ld hl, str_won_after
        call print_string

        TEXT R_GRAVE_X - 6 * 4, 98, R_CARVING, 1
        ld hl, str_rip
        call print_string
        TEXT R_GRAVE_X - 3 * 8, 112, R_CARVING, 2
        ld hl, str_joe
        call print_string

        TEXT 116, 110, COL_BLACK, 1
        ld hl, str_price
        call print_string

        TEXT 0, 224, COL_WHITE, 1
        call print_wages_centred
        TEXT 0, 240, COL_YELLOW, 1
        ld hl, str_press_fire
        call print_centred
        call screen_end
        ld hl, tune_retire
        jp music_start

game_won_update:
        ld a, ST_TITLE
        jp wait_fire_then

retire_scene:
        ; Dusk sky
        S_RECT 0, 0, SCREEN_W, 60, R_SKY_TOP
        S_RECT 0, 60, SCREEN_W, 60, R_SKY_MID
        S_RECT 0, 120, SCREEN_W, R_GROUND_Y - 120, R_SKY_LOW

        ; Grass, with a few darker tufts
        S_RECT 0, R_GROUND_Y, SCREEN_W, SCREEN_H - R_GROUND_Y, R_GRASS
        S_RECT 12, 200, 6, 2, R_TUFT
        S_RECT 150, 194, 8, 2, R_TUFT
        S_RECT 300, 206, 6, 2, R_TUFT
        S_RECT 120, 214, 6, 2, R_TUFT
        S_RECT 176, 186, 6, 2, R_TUFT

        ; The plinth
        S_RECT R_CLOCK_X - 60, 150, 120, 12, R_WOOD
        S_RECT R_CLOCK_X - 60, 150, 120, 2, R_WOOD_LIGHT

        ; The carriage clock: handle, arched top, body, feet
        S_HALF R_CLOCK_X, 72, 9, R_GOLD, 0
        S_HALF R_CLOCK_X, 72, 5, R_SKY_MID, 0
        S_HALF R_CLOCK_X, 100, 30, R_GOLD, 0
        S_RECT R_CLOCK_X - 30, 100, 60, 46, R_GOLD
        S_RECT R_CLOCK_X + 24, 100, 6, 46, R_GOLD_DARK        ; shading
        S_RECT R_CLOCK_X - 28, 100, 3, 44, R_GOLD_LIGHT       ; shine
        S_RECT R_CLOCK_X - 28, 146, 10, 4, R_GOLD_DARK
        S_RECT R_CLOCK_X + 18, 146, 10, 4, R_GOLD_DARK

        ; Clock face, marks and hands (ten to three... ish)
        S_DISC R_CLOCK_X, 123, 20, R_GOLD_DARK
        S_DISC R_CLOCK_X, 123, 17, COL_WHITE
        S_RECT R_CLOCK_X - 1, 107, 2, 3, COL_BLACK            ; 12
        S_RECT R_CLOCK_X + 13, 122, 3, 2, COL_BLACK           ; 3
        S_RECT R_CLOCK_X - 1, 136, 2, 3, COL_BLACK            ; 6
        S_RECT R_CLOCK_X - 16, 122, 3, 2, COL_BLACK           ; 9
        S_RECT R_CLOCK_X - 1, 112, 2, 11, COL_BLACK           ; minute hand
        S_RECT R_CLOCK_X, 122, 10, 2, COL_BLACK               ; hour hand
        S_RECT R_CLOCK_X - 2, 121, 4, 4, $E0                  ; centre

        ; The price tag, still on
        S_RECT R_CLOCK_X + 30, 104, 6, 1, COL_GREY            ; string
        S_RECT R_CLOCK_X + 35, 104, 1, 5, COL_GREY
        S_RECT R_CLOCK_X + 34, 108, 28, 11, COL_WHITE

        ; The grave: soil mound with flowers, then the headstone
        S_RECT R_GRAVE_X - 36, 190, 72, 14, R_SOIL
        S_DISC R_GRAVE_X - 36, 197, 7, R_SOIL
        S_DISC R_GRAVE_X + 36, 197, 7, R_SOIL
        S_HALF R_GRAVE_X, 116, 40, R_STONE, 0
        S_RECT R_GRAVE_X - 40, 116, 80, 72, R_STONE
        S_RECT R_GRAVE_X + 34, 104, 6, 84, R_STONE_DARK       ; shading
        S_RECT R_GRAVE_X - 44, 186, 88, 4, R_STONE_DARK       ; base
        S_RECT R_GRAVE_X - 20, 195, 1, 6, $14                 ; flowers
        S_RECT R_GRAVE_X + 4, 194, 1, 7, $14
        S_RECT R_GRAVE_X + 24, 196, 1, 5, $14
        S_DISC R_GRAVE_X - 20, 195, 2, $E0
        S_DISC R_GRAVE_X + 4, 194, 2, COL_YELLOW
        S_DISC R_GRAVE_X + 24, 196, 2, $E7
        S_END

str_won_title:      db "JOE RETIRES!", 0
str_won_text:       db "A LIFETIME OF SLOP.", 0
str_won_shortly:    db "SHORTLY", 0
str_won_after:      db "AFTERWARDS...", 0
str_rip:            db "R.I.P.", 0
str_joe:            db "JOE", 0
str_price:          db "99P", 0
