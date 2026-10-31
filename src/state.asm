;-----------------------------------------------------------------------------
; Game state machine
;
; Each state has an `enter` routine (called once by change_state, usually
; draws the screen) and an `update` routine (called once per frame by the
; main loop). To switch state from an update routine: ld a, ST_x / jp change_state.
;
;   TITLE -> LEVEL_INTRO -> PLAYING -> LEVEL_COMPLETE -> LEVEL_INTRO ...
;                              |  \-> GAME_OVER (Joe quits: beach) -> TITLE
;                              |       LEVEL_COMPLETE after level 5 -> GAME_WON -> TITLE
;                              \-> PAUSED -> PLAYING (resume) / TITLE (quit)
;-----------------------------------------------------------------------------

ST_TITLE            equ 0
ST_LEVEL_INTRO      equ 1
ST_PLAYING          equ 2
ST_PAUSED           equ 3
ST_LEVEL_COMPLETE   equ 4
ST_GAME_OVER        equ 5
ST_GAME_WON         equ 6

state_enter_table:
        dw title_enter
        dw level_intro_enter
        dw playing_enter
        dw paused_enter
        dw level_complete_enter
        dw game_over_enter
        dw game_won_enter

state_update_table:
        dw title_update
        dw level_intro_update
        dw playing_update
        dw paused_update
        dw level_complete_update
        dw game_over_update
        dw game_won_update

        ASSERT state_update_table - state_enter_table == (ST_GAME_WON + 1) * 2

; In: A = new state.
change_state:
        ld (game_state), a
        push af
        call music_stop             ; each screen starts its own tune
        pop af
        ld hl, state_enter_table
        ; fall through

; Jump to entry A of the word table at HL.
jump_table:
        add a, a
        add hl, a
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        jp (hl)

state_update:
        ld a, (game_state)
        ld hl, state_update_table
        jr jump_table

; Reset everything for a fresh game.
new_game:
        xor a
        ld (current_level), a
        ld (cynicism), a
        ld hl, 0
        ld (wages), hl
        ret

; Out: IX = record for current_level in the levels table.
get_level_ptr:
        ld a, (current_level)
        ld e, a
        ld d, LEVEL
        mul d, e
        ld ix, levels
        add ix, de
        ret

; Copy the current level's settings into the cur_* variables.
level_load:
        call get_level_ptr
        ld a, (ix + LEVEL.pipes)
        ld (active_pipes), a
        ld a, (ix + LEVEL.colours)
        ld (cur_colours), a
        ld a, (ix + LEVEL.quota)
        ld (cur_quota), a
        ld a, (ix + LEVEL.ooze_delay)
        ld (cur_ooze_delay), a
        ld a, (ix + LEVEL.belt_speed)
        ld (cur_belt_speed), a
        ld a, (ix + LEVEL.flags)
        ld (cur_flags), a
        xor a
        ld (deposits), a
        ld (cynicism), a            ; each level starts calm
        ret

; Blank Layer 2 (and hide sprites) while a full screen is redrawn.
screen_begin:
        call wait_frame
        nextreg NR_DISPLAY_CTRL1, 0
        jp sprites_hide_all

screen_end:
        call wait_frame
        nextreg NR_DISPLAY_CTRL1, %10000000
        ret

game_state:     db ST_TITLE
current_level:  db 0                    ; 0-based index into levels
cynicism:       db 0                    ; 0-100
wages:          dw 0                    ; score, in pence
deposits:       db 0                    ; correct tubs filled this level

; Current level settings (copied from the levels table by level_load)
cur_colours:    db 2
cur_quota:      db 5
cur_ooze_delay: db 8
cur_belt_speed: db 1
cur_flags:      db 0                    ; LVF_*
