;-----------------------------------------------------------------------------
; Pipes and slop
;
; Each active pipe runs a little cycle:
;   WAIT  -> pause, then pick a random colour from the level's colours
;   OOZE  -> the drop slides out of the nozzle, one step every ooze_delay frames
;   FALL  -> the drop falls; Joe's bucket can catch it
;   SPLAT -> it hit the floor (missed: cynicism goes up), then back to WAIT
; Banging a pipe (fire nearby) pushes the ooze along.
;-----------------------------------------------------------------------------

MAX_PIPES           equ 6
OOZE_MAX            equ 16
FALL_SPEED          equ 1               ; pixels per frame
SPLAT_Y             equ BELT_Y - 16
SPLAT_TIME          equ 25
WAIT_MIN            equ 60              ; frames between drops: WAIT_MIN + 0..63
BANG_BOOST          equ 4
BANG_RANGE_X        equ 20
CATCH_RANGE_X       equ 10

PS_WAIT             equ 0
PS_OOZE             equ 1
PS_FALL             equ 2
PS_SPLAT            equ 3

; Runtime state, one per pipe.
        STRUCT PIPE
state       BYTE 0
timer       BYTE 0
ooze        BYTE 0
colour      BYTE 0
drop_y      BYTE 0
        ENDS

; Static geometry, one per pipe position. Each rect is laid out like
; rect_x/rect_w/rect_y/rect_h so it can be copied straight in.
PSL_HRECT           equ 0               ; horizontal run from the wall
PSL_VRECT           equ 6               ; downturn to the nozzle
PSL_DROP_X          equ 12              ; drop sprite x (word)
PSL_NOZZLE_Y        equ 14              ; y of the nozzle's mouth
PIPE_SLOT_SIZE      equ 15

        MACRO PIPE_SLOT hx, hw, hy, hh, vx, vw, vy, vh, nozzle_x, nozzle_y
        dw hx, hw
        db hy, hh
        dw vx, vw
        db vy, vh
        dw nozzle_x - 8
        db nozzle_y
        ENDM

; Levels with N pipes use the first N slots.
pipe_slots:
        PIPE_SLOT   0, 52,  52, 12,   40, 12,  52, 24,   46, 76   ; left upper
        PIPE_SLOT 268, 52,  52, 12,  268, 12,  52, 24,  274, 76   ; right upper
        PIPE_SLOT   0, 84, 124, 12,   72, 12, 124, 24,   78, 148  ; left lower
        PIPE_SLOT 236, 84, 124, 12,  236, 12, 124, 24,  242, 148  ; right lower
        PIPE_SLOT 122, 12,  16, 40,  122, 12,  16, 40,  128, 56   ; ceiling
        PIPE_SLOT 186, 12,  16, 40,  186, 12,  16, 40,  192, 56   ; ceiling
        ASSERT $ - pipe_slots == MAX_PIPES * PIPE_SLOT_SIZE

pipes_reset:
        ld ix, pipes
        ld b, MAX_PIPES
        ld c, 20                    ; stagger the first drops
.next:
        ld (ix + PIPE.state), PS_WAIT
        ld (ix + PIPE.timer), c
        ld (ix + PIPE.ooze), 0
        ld a, c
        add a, 45
        ld c, a
        ld de, PIPE
        add ix, de
        djnz .next
        ret

; Draw the active pipes on Layer 2: dark outline, then a lighter inside.
pipes_draw:
        ld a, (active_pipes)
        ld b, a
        ld hl, pipe_slots
.next:
        push bc
        ld a, COL_PIPE_DARK
        ld (rect_colour), a
        call fill_rect_from
        ld de, PSL_VRECT
        add hl, de
        call fill_rect_from
        ld a, COL_PIPE_LIGHT
        ld (rect_colour), a
        ld de, -PSL_VRECT
        add hl, de
        call fill_rect_inset
        ld de, PSL_VRECT
        add hl, de
        call fill_rect_inset
        ld de, PIPE_SLOT_SIZE - PSL_VRECT
        add hl, de
        pop bc
        djnz .next
        ret

; Copy a 6-byte rect record at HL into rect_* and fill it. Preserves HL.
fill_rect_from:
        push hl
        ld de, rect_x
        ld bc, 6
        ldir
        call l2_fill_rect
        pop hl
        ret

; Same, shrunk by 2 pixels on every side. Preserves HL.
fill_rect_inset:
        push hl
        ld de, rect_x
        ld bc, 6
        ldir
        ld hl, (rect_x)
        inc hl
        inc hl
        ld (rect_x), hl
        ld hl, (rect_w)
        ld de, -4
        add hl, de
        ld (rect_w), hl
        ld a, (rect_y)
        add a, 2
        ld (rect_y), a
        ld a, (rect_h)
        sub 4
        ld (rect_h), a
        call l2_fill_rect
        pop hl
        ret

; Run every active pipe for one frame and update its drop sprite.
pipes_update:
        ld ix, pipes
        ld iy, pipe_slots
        xor a
        ld (pipe_index), a
.next:
        ld a, (active_pipes)
        ld b, a
        ld a, (pipe_index)
        cp b
        ret nc
        call pipe_step
        call pipe_draw
        ld de, PIPE
        add ix, de
        ld de, PIPE_SLOT_SIZE
        add iy, de
        ld hl, pipe_index
        inc (hl)
        jr .next

; IX = pipe, IY = its slot.
pipe_step:
        ld a, (ix + PIPE.state)
        cp PS_WAIT
        jr z, .wait
        cp PS_OOZE
        jr z, .ooze
        cp PS_FALL
        jr z, .fall
        ; splat
        dec (ix + PIPE.timer)
        ret nz
        jp pipe_start_wait

.wait:
        dec (ix + PIPE.timer)
        ret nz
        ld a, (cur_colours)
        ld e, a
        call rand_below
        ld (ix + PIPE.colour), a
        ld (ix + PIPE.ooze), 0
        ld a, (cur_ooze_delay)
        ld (ix + PIPE.timer), a
        ld (ix + PIPE.state), PS_OOZE
        ret

.ooze:
        dec (ix + PIPE.timer)
        ret nz
        ld a, (cur_ooze_delay)
        ld (ix + PIPE.timer), a
        inc (ix + PIPE.ooze)
        ld a, (ix + PIPE.ooze)
        cp OOZE_MAX
        ret c
        ld a, (iy + PSL_NOZZLE_Y)
        ld (ix + PIPE.drop_y), a
        ld (ix + PIPE.state), PS_FALL
        ld a, SFX_DRIP
        jp sfx_play

.fall:
        ld a, (ix + PIPE.drop_y)
        add a, FALL_SPEED
        ld (ix + PIPE.drop_y), a
        cp SPLAT_Y - 4
        jr nc, .missed

        ; Caught? The drop must be just above the bucket's mouth...
        call joe_bucket_pos         ; HL = bucket x, A = bucket y
        ld b, a
        ld a, (ix + PIPE.drop_y)
        sub b
        add a, 12
        cp 13
        ret nc
        ; ...and lined up with it.
        ld e, (iy + PSL_DROP_X)
        ld d, (iy + PSL_DROP_X + 1)
        call abs_diff16
        ld a, h
        or a
        ret nz
        ld a, l
        cp CATCH_RANGE_X
        ret nc
        ld a, (ix + PIPE.colour)
        call bucket_try_catch
        ret nc
        ld a, SCORE_CATCH
        call add_wages
        ld a, SFX_CATCH
        call sfx_play
        jr pipe_start_wait

.missed:
        ld (ix + PIPE.state), PS_SPLAT
        ld (ix + PIPE.timer), SPLAT_TIME
        ld a, SFX_SPLAT
        call sfx_play
        ld a, CYNICISM_MISS
        jp add_cynicism

pipe_start_wait:
        ld (ix + PIPE.state), PS_WAIT
        ld e, 64
        call rand_below
        add a, WAIT_MIN
        ld (ix + PIPE.timer), a
        ret

; Show or hide this pipe's drop sprite. IX = pipe, IY = slot.
pipe_draw:
        ld a, (ix + PIPE.state)
        cp PS_WAIT
        jr z, .hide
        ld l, (iy + PSL_DROP_X)
        ld h, (iy + PSL_DROP_X + 1)
        cp PS_FALL
        jr z, .falling
        cp PS_SPLAT
        jr z, .splat
        ; oozing: slides out of the nozzle as ooze goes 0 -> OOZE_MAX
        ld a, (ix + PIPE.ooze)
        cp 4
        jr c, .hide
        ld b, a
        ld a, (iy + PSL_NOZZLE_Y)
        sub OOZE_MAX
        add a, b
        ld e, a
        jr .drop_pattern
.falling:
        ld e, (ix + PIPE.drop_y)
.drop_pattern:
        ld a, (ix + PIPE.colour)
        add a, PAT_DROP
        ld d, a
        jr .show
.splat:
        ld e, SPLAT_Y
        ld a, (ix + PIPE.colour)
        add a, PAT_SPLAT
        ld d, a
.show:
        ld c, 0
        ld a, (pipe_index)
        add a, SPR_DROP
        jp sprite_show
.hide:
        ld a, (pipe_index)
        add a, SPR_DROP
        jp sprite_hide

; Fire pressed: bang the first pipe Joe is standing at.
; Out: carry set if a pipe was banged.
pipes_bang:
        ld ix, pipes
        ld iy, pipe_slots
        ld a, (active_pipes)
        ld b, a
.next:
        push bc
        ld hl, (joe_x)
        ld e, (iy + PSL_DROP_X)
        ld d, (iy + PSL_DROP_X + 1)
        call abs_diff16
        ld a, h
        or a
        jr nz, .skip
        ld a, l
        cp BANG_RANGE_X
        jr nc, .skip
        ; Joe's middle (joe_y + 16) within 24 pixels of the nozzle
        ld a, (iy + PSL_NOZZLE_Y)
        ld c, a
        ld a, (joe_y)
        add a, 16 + 24
        sub c
        cp 48
        jr nc, .skip
        ld a, (ix + PIPE.state)
        cp PS_WAIT
        jr z, .wake
        cp PS_OOZE
        jr nz, .skip
        ld a, (ix + PIPE.ooze)
        add a, BANG_BOOST
        cp OOZE_MAX
        jr c, .store
        ld (ix + PIPE.timer), 1     ; drop it next frame
        ld a, OOZE_MAX - 1
.store:
        ld (ix + PIPE.ooze), a
        jr .banged
.wake:
        ld (ix + PIPE.timer), 1
.banged:
        pop bc
        ld a, SCORE_BANG
        call add_wages
        ld a, SFX_BANG
        call sfx_play
        scf
        ret
.skip:
        ld de, PIPE
        add ix, de
        ld de, PIPE_SLOT_SIZE
        add iy, de
        pop bc
        djnz .next
        or a
        ret

pipes:          ds PIPE * MAX_PIPES
active_pipes:   db 2
pipe_index:     db 0
