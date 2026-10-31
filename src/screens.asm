;-----------------------------------------------------------------------------
; Full-screen states: level intro, level complete and the retirement ending.
; (The title screen is in title.asm, the beach game over in beach.asm.)
; Backgrounds are placeholder rectangles until real art (gfx2next) exists.
;-----------------------------------------------------------------------------

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
str_fill:           db "EMPTY ", 0
str_buckets:        db " BUCKETS INTO THE RIGHT TUBS", 0
str_press_fire:     db "PRESS FIRE", 0
str_complete:       db "COMPLETE!", 0
str_complete_sub:   db "NOT BAD, JOE. SAME AGAIN TOMORROW.", 0
str_won_title:      db "JOE RETIRES!", 0
str_won_text:       db "A LIFETIME OF SLOP.", 13
                    db "ONE CHEAP GOLD CLOCK.", 13
                    db 13
                    db "SHORTLY AFTERWARDS...", 0
str_rip:            db "R.I.P. JOE", 0
