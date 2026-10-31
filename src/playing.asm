;-----------------------------------------------------------------------------
; PLAYING and PAUSED states
;
; Each frame: move Joe, fire bangs a nearby pipe, run the belt, empty a full
; bucket into any tub it touches, run the pipes, draw sprites, refresh the
; HUD, then check for level complete (deposits >= quota) or game over
; (cynicism maxed).
;
; Test keys (left out by `make RELEASE=1`): N = finish level, 2 = Joe quits.
;-----------------------------------------------------------------------------

CYNICISM_MAX        equ 100             ; Joe quits at this
CYNICISM_MISS       equ 4               ; per drop that hits the floor
SCORE_CATCH         equ 1               ; wages in pence
SCORE_BANG          equ 1
SCORE_DEPOSIT       equ 10

playing_enter:
        call screen_begin
        call level_load
        call joe_reset
        call pipes_reset
        call tubs_reset
        call snacks_reset
        call draw_playfield
        jp screen_end

playing_update:
        ld a, (input_new)
        bit INPUT_BREAK, a
        jr z, 1F
        ld a, ST_PAUSED
        jp change_state
1:
        IFNDEF RELEASE
        bit INPUT_DEBUG1, a
        jr z, 1F
        ld a, (cur_quota)
        ld (deposits), a
1:
        ld a, (input_new)
        bit INPUT_DEBUG2, a
        jr z, 1F
        ld a, CYNICISM_MAX
        ld (cynicism), a
1:
        ENDIF

        call joe_update
        call snacks_update
        ld a, (input_new)
        bit INPUT_FIRE, a
        call nz, pipes_bang
        call tubs_update
        call try_deposit
        call pipes_update
        call tubs_draw
        call joe_draw
        call hud_update

        ld a, (cynicism)
        cp CYNICISM_MAX
        jr c, 1F
        ld a, ST_GAME_OVER
        jp change_state
1:
        ld a, (cur_quota)
        ld b, a
        ld a, (deposits)
        cp b
        ret c
        ld a, ST_LEVEL_COMPLETE
        jp change_state

; Empty a full bucket into any tub it touches (no button needed).
; Out: carry set if the bucket was emptied (right tub or not).
try_deposit:
        ld a, (bucket_count)
        cp BUCKET_CAPACITY
        jr nz, .no
        call joe_bucket_pos         ; HL = bucket x, A = bucket y
        cp TUB_Y - 12
        jr c, .no                   ; not down at the belt
        call tubs_find_under
        jr nc, .no
        ld b, a
        ld a, (bucket_colour)
        cp b
        push af
        call bucket_empty
        pop af
        jr nz, .wrong
        ld hl, deposits
        inc (hl)
        ld hl, hud_dirty
        set HUD_STATUS, (hl)
        ld a, SCORE_DEPOSIT
        call add_wages
.wrong:                             ; wrong tub: the slop is lost
        scf
        ret
.no:
        or a
        ret

draw_playfield:
        FILL_RECT 0, 0, SCREEN_W, HUD_H, COL_BLACK
        FILL_RECT 0, HUD_H, SCREEN_W, BELT_Y - HUD_H, COL_FLOOR
        FILL_RECT 0, BELT_Y, SCREEN_W, 8, COL_BELT_EDGE
        FILL_RECT 0, BELT_Y + 8, SCREEN_W, SCREEN_H - BELT_Y - 8, COL_BELT
        call pipes_draw
        call hud_draw_labels
        ld a, HUD_ALL
        ld (hud_dirty), a
        jp hud_update

;-----------------------------------------------------------------------------
; PAUSED: box over the playfield. Fire resumes, BREAK quits to the title.
;-----------------------------------------------------------------------------
paused_enter:
        call sprites_hide_all
        FILL_RECT 64, 88, 192, 72, COL_BLACK
        TEXT 0, 98, COL_YELLOW, 2
        ld hl, str_paused
        call print_centred
        TEXT 0, 124, COL_WHITE, 1
        ld hl, str_paused_help
        jp print_centred

paused_update:
        ld a, (input_new)
        bit INPUT_BREAK, a
        jr z, 1F
        ld a, ST_TITLE
        jp change_state
1:
        bit INPUT_FIRE, a
        ret z
        ; Resume without resetting the level: redraw and switch directly.
        ; The next playing_update puts the sprites back.
        call screen_begin
        call draw_playfield
        call screen_end
        ld a, ST_PLAYING
        ld (game_state), a
        ret

str_paused:         db "PAUSED", 0
str_paused_help:    db "FIRE: CARRY ON", 13, "BREAK: QUIT TO TITLE", 0
