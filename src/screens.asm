;-----------------------------------------------------------------------------
; Full-screen states: title, level intro, level complete and the two endings.
; Backgrounds are placeholder rectangles until real art (gfx2next) exists.
;-----------------------------------------------------------------------------

COL_BRICK           equ $A4
COL_SKY             equ $5F
COL_SEA             equ $0B
COL_SAND            equ $F9
COL_DARK            equ $24
COL_GOLD            equ $F8

; Common update for screens that just wait for fire.
; In: A = state to go to. Returns without switching if fire wasn't pressed.
wait_fire_then:
        ld b, a
        ld a, (input_new)
        bit INPUT_FIRE, a
        ret z
        ld a, b
        jp change_state

;--- Title -------------------------------------------------------------------
title_enter:
        call screen_begin
        ld a, COL_BLACK
        call l2_clear
        FILL_RECT 40, 120, 240, 100, COL_BRICK      ; the factory
        FILL_RECT 136, 164, 48, 56, COL_BLACK       ; the gates
        FILL_RECT 0, 220, SCREEN_W, 36, COL_DARK    ; the yard

        TEXT 0, 24, COL_YELLOW, 2
        ld hl, str_title
        call print_centred
        TEXT 0, 48, COL_WHITE, 1
        ld hl, str_title_sub
        call print_centred
        TEXT 0, 76, COL_WHITE, 1
        ld hl, str_title_controls
        call print_centred
        TEXT 0, 132, COL_YELLOW, 1
        ld hl, str_factory_sign
        call print_centred
        TEXT 0, 234, COL_YELLOW, 1
        ld hl, str_clock_on
        call print_centred
        jp screen_end

title_update:
        ld a, (input_new)
        bit INPUT_FIRE, a
        ret z
        call rand_mix
        call new_game
        ld a, ST_LEVEL_INTRO
        jp change_state

;--- Level intro -------------------------------------------------------------
level_intro_enter:
        call screen_begin
        ld a, COL_FLOOR
        call l2_clear
        call get_level_ptr

        call str_start
        call str_append_day
        TEXT 0, 56, COL_WHITE, 2
        ld hl, strbuf
        call print_centred

        TEXT 0, 84, COL_YELLOW, 2
        ld l, (ix + LEVEL.name)
        ld h, (ix + LEVEL.name + 1)
        call print_centred

        TEXT 0, 128, COL_WHITE, 1
        ld l, (ix + LEVEL.desc)
        ld h, (ix + LEVEL.desc + 1)
        call print_centred

        call str_start
        ld hl, str_fill
        call str_append
        ld a, (ix + LEVEL.quota)
        call str_append_u8
        ld hl, str_buckets
        call str_append
        TEXT 0, 168, COL_WHITE, 1
        ld hl, strbuf
        call print_centred

        TEXT 0, 216, COL_YELLOW, 1
        ld hl, str_press_fire
        call print_centred
        jp screen_end

level_intro_update:
        ld a, ST_PLAYING
        jp wait_fire_then

;--- Level complete ----------------------------------------------------------
level_complete_enter:
        call screen_begin
        ld a, COL_FLOOR
        call l2_clear

        call str_start
        call str_append_day
        TEXT 0, 72, COL_WHITE, 2
        ld hl, strbuf
        call print_centred
        TEXT 0, 96, COL_YELLOW, 2
        ld hl, str_complete
        call print_centred
        TEXT 0, 140, COL_WHITE, 1
        ld hl, str_complete_sub
        call print_centred
        TEXT 0, 164, COL_WHITE, 1
        call print_wages_centred
        TEXT 0, 216, COL_YELLOW, 1
        ld hl, str_press_fire
        call print_centred
        jp screen_end

level_complete_update:
        ld a, (input_new)
        bit INPUT_FIRE, a
        ret z
        ld a, (current_level)
        inc a
        ld (current_level), a
        cp LEVEL_COUNT
        ld a, ST_GAME_WON
        jp z, change_state
        ld a, ST_LEVEL_INTRO
        jp change_state

;--- Game over: Joe quits and goes to the beach ------------------------------
game_over_enter:
        call screen_begin
        ld a, COL_SKY
        call l2_clear
        FILL_RECT 0, 160, SCREEN_W, 40, COL_SEA
        FILL_RECT 0, 200, SCREEN_W, 56, COL_SAND

        TEXT 0, 24, COL_BLACK, 2
        ld hl, str_quit_title
        call print_centred
        TEXT 0, 60, COL_BLACK, 1
        ld hl, str_quit_text
        call print_centred
        TEXT 0, 212, COL_BLACK, 1
        call print_wages_centred
        TEXT 0, 232, COL_BLACK, 1
        ld hl, str_press_fire
        call print_centred
        jp screen_end

game_over_update:
        ld a, ST_TITLE
        jp wait_fire_then

;--- Game won: Joe retires with a cheap gold clock, then... ------------------
game_won_enter:
        call screen_begin
        ld a, COL_DARK
        call l2_clear

        TEXT 0, 32, COL_GOLD, 2
        ld hl, str_won_title
        call print_centred
        TEXT 0, 68, COL_WHITE, 1
        ld hl, str_won_text
        call print_centred
        TEXT 0, 148, COL_WHITE, 2
        ld hl, str_rip
        call print_centred
        TEXT 0, 188, COL_WHITE, 1
        call print_wages_centred
        TEXT 0, 216, COL_YELLOW, 1
        ld hl, str_press_fire
        call print_centred
        jp screen_end

game_won_update:
        ld a, ST_TITLE
        jp wait_fire_then

;"WAGES: nP", centred at text_y in the current text style.
print_wages_centred:
        call str_start
        ld hl, str_hud_wages
        call str_append
        ld hl, (wages)
        call str_append_u16
        ld hl, str_hud_pence
        call str_append
        ld hl, strbuf
        jp print_centred

;--- Strings -----------------------------------------------------------------
str_title:          db "SLOPPY SECONDS", 0
str_title_sub:      db "LIFE AT THE SIDEWAYS FACTORY", 0
str_title_controls: db "QAOP + SPACE OR KEMPSTON JOYSTICK", 13
                    db "CAPS SHIFT + SPACE (BREAK) TO PAUSE", 0
str_factory_sign:   db "SIDEWAYS FACTORY", 0
str_clock_on:       db "PRESS FIRE TO CLOCK ON", 0
str_fill:           db "EMPTY ", 0
str_buckets:        db " BUCKETS INTO THE RIGHT TUBS", 0
str_press_fire:     db "PRESS FIRE", 0
str_complete:       db "COMPLETE!", 0
str_complete_sub:   db "NOT BAD, JOE. SAME AGAIN TOMORROW.", 0
str_quit_title:     db "JOE'S HAD ENOUGH!", 0
str_quit_text:      db "HE STORMED INTO THE CHAIRMAN'S OFFICE", 13
                    db "AND TOLD FUMDUCK TO SHOVE THE JOB", 13
                    db "WHERE THE SUN DON'T SHINE.", 13
                    db 13
                    db "NOW JOE GETS ALL THE SUN HE WANTS.", 0
str_won_title:      db "JOE RETIRES!", 0
str_won_text:       db "A LIFETIME OF SLOP.", 13
                    db "ONE CHEAP GOLD CLOCK.", 13
                    db 13
                    db "SHORTLY AFTERWARDS...", 0
str_rip:            db "R.I.P. JOE", 0
