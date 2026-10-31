;-----------------------------------------------------------------------------
; Cockroaches (levels with LVF_COCKROACH: Wednesday onwards)
;
; Up to MAX_ROACHES scuttle in from the sides and wander the floor, changing
; direction at random. Each live roach adds 1 cynicism every ROACH_TICK
; frames. Fire with a roach at Joe's feet stomps it (it lies squashed for
; ROACH_SQUASH_TIME frames, then goes).
;-----------------------------------------------------------------------------

MAX_ROACHES         equ 3
ROACH_TICK          equ 100             ; frames per cynicism point, per roach
ROACH_SPAWN_MIN     equ 300             ; 6 s; plus up to ~5 s random
ROACH_SQUASH_TIME   equ 25
ROACH_MIN_X         equ 0
ROACH_MAX_X         equ SCREEN_W - 16
ROACH_MIN_Y         equ JOE_MIN_Y + 16
ROACH_MAX_Y         equ TUB_Y - 16
ROACH_STOMP_X       equ 14              ; x distance from Joe that counts

RS_NONE             equ 0
RS_ALIVE            equ 1
RS_SQUASHED         equ 2

        STRUCT ROACH
state       BYTE 0
x           WORD 0
y           BYTE 0
dx          BYTE 0      ; -1, 0 or +1
dy          BYTE 0
turn        BYTE 0      ; frames until a new direction
timer       BYTE 0      ; cynicism tick, or squash countdown
anim        BYTE 0
        ENDS

roaches_reset:
        ld ix, roaches
        ld b, MAX_ROACHES
.next:
        ld (ix + ROACH.state), RS_NONE
        ld de, ROACH
        add ix, de
        djnz .next
        ; fall through

roach_start_gap:
        ld e, 255
        call rand_below
        ld hl, ROACH_SPAWN_MIN
        add hl, a
        ld (roach_gap), hl
        ret

roaches_update:
        ld a, (cur_flags)
        and LVF_COCKROACH
        ret z

        ld hl, (roach_gap)
        dec hl
        ld (roach_gap), hl
        ld a, h
        or l
        call z, roach_spawn

        ld ix, roaches
        xor a
        ld (roach_index), a
.next:
        call roach_step
        ld de, ROACH
        add ix, de
        ld hl, roach_index
        inc (hl)
        ld a, (hl)
        cp MAX_ROACHES
        jr c, .next
        ret

; Bring in a new roach from a random side, if there's a free slot.
roach_spawn:
        call roach_start_gap
        ld ix, roaches
        ld b, MAX_ROACHES
.find:
        ld a, (ix + ROACH.state)
        cp RS_NONE
        jr z, .found
        ld de, ROACH
        add ix, de
        djnz .find
        ret                         ; all busy
.found:
        ld e, ROACH_MAX_Y - ROACH_MIN_Y
        call rand_below
        add a, ROACH_MIN_Y
        ld (ix + ROACH.y), a
        call rand
        and 1
        jr z, .from_right
        ld (ix + ROACH.x), ROACH_MIN_X
        ld (ix + ROACH.x + 1), 0
        ld (ix + ROACH.dx), 1
        jr .go
.from_right:
        ld (ix + ROACH.x), low ROACH_MAX_X
        ld (ix + ROACH.x + 1), high ROACH_MAX_X
        ld (ix + ROACH.dx), -1
.go:
        ld (ix + ROACH.dy), 0
        ld (ix + ROACH.timer), ROACH_TICK
        ld (ix + ROACH.state), RS_ALIVE
        jp roach_new_turn_time

; One frame for the roach at IX (slot roach_index).
roach_step:
        ld a, (ix + ROACH.state)
        cp RS_ALIVE
        jr z, .alive
        cp RS_SQUASHED
        jr z, .squashed
        ld a, (roach_index)
        add a, SPR_ROACH
        jp sprite_hide

.squashed:
        dec (ix + ROACH.timer)
        jr nz, .draw_squashed
        ld (ix + ROACH.state), RS_NONE
        ld a, (roach_index)
        add a, SPR_ROACH
        jp sprite_hide
.draw_squashed:
        ld d, PAT_ROACH_SQUASH
        ld c, 0
        jr .draw

.alive:
        ; Pick a new direction now and then
        dec (ix + ROACH.turn)
        call z, roach_new_direction

        ; x += dx, bouncing off the sides
        ld l, (ix + ROACH.x)
        ld h, (ix + ROACH.x + 1)
        ld a, (ix + ROACH.dx)
        ld e, a
        add a, a
        sbc a, a
        ld d, a
        add hl, de
        bit 7, h
        jr z, 1F
        ld hl, ROACH_MIN_X
        ld (ix + ROACH.dx), 1
1:      push hl
        ld de, ROACH_MAX_X + 1
        or a
        sbc hl, de
        pop hl
        jr c, 1F
        ld hl, ROACH_MAX_X
        ld (ix + ROACH.dx), -1
1:      ld (ix + ROACH.x), l
        ld (ix + ROACH.x + 1), h

        ; y += dy, bouncing off the top and bottom
        ld a, (ix + ROACH.y)
        add a, (ix + ROACH.dy)
        cp ROACH_MIN_Y
        jr nc, 1F
        ld a, ROACH_MIN_Y
        ld (ix + ROACH.dy), 1
1:      cp ROACH_MAX_Y + 1
        jr c, 1F
        ld a, ROACH_MAX_Y
        ld (ix + ROACH.dy), -1
1:      ld (ix + ROACH.y), a

        ; Slowly wear Joe down
        dec (ix + ROACH.timer)
        jr nz, 1F
        ld (ix + ROACH.timer), ROACH_TICK
        ld a, 1
        call add_cynicism
1:
        ; Legs: swap frames every 4 frames; face the way it's going
        inc (ix + ROACH.anim)
        ld a, (ix + ROACH.anim)
        rrca
        rrca
        and 1
        add a, PAT_ROACH
        ld d, a
        ld c, 0
        bit 7, (ix + ROACH.dx)
        jr z, .draw
        ld c, ATTR2_MIRROR_X
.draw:
        ld l, (ix + ROACH.x)
        ld h, (ix + ROACH.x + 1)
        ld e, (ix + ROACH.y)
        ld a, (roach_index)
        add a, SPR_ROACH
        jp sprite_show

; Random dx/dy in -1..1 (never both 0), and when to turn next.
roach_new_direction:
        ld e, 3
        call rand_below
        dec a
        ld (ix + ROACH.dx), a
        ld e, 3
        call rand_below
        dec a
        ld (ix + ROACH.dy), a
        or (ix + ROACH.dx)
        jr nz, roach_new_turn_time
        ld (ix + ROACH.dx), 1
roach_new_turn_time:
        ld e, 64
        call rand_below
        add a, 20
        ld (ix + ROACH.turn), a
        ret

; Fire pressed: stomp a roach at Joe's feet.
; Out: carry set if one was stomped.
roaches_stomp:
        ld a, (cur_flags)
        and LVF_COCKROACH
        ret z                       ; (carry clear)
        ld ix, roaches
        ld b, MAX_ROACHES
.next:
        push bc
        ld a, (ix + ROACH.state)
        cp RS_ALIVE
        jr nz, .skip
        ld hl, (joe_x)
        ld e, (ix + ROACH.x)
        ld d, (ix + ROACH.x + 1)
        call abs_diff16
        ld a, h
        or a
        jr nz, .skip
        ld a, l
        cp ROACH_STOMP_X
        jr nc, .skip
        ld a, (joe_y)               ; roach y within joe_y+4 .. joe_y+28
        ld c, a
        ld a, (ix + ROACH.y)
        sub c
        sub 4
        cp 25
        jr nc, .skip
        ld (ix + ROACH.state), RS_SQUASHED
        ld (ix + ROACH.timer), ROACH_SQUASH_TIME
        pop bc
        ld a, SCORE_STOMP
        call add_wages
        ld a, SFX_STOMP
        call sfx_play
        scf
        ret
.skip:
        ld de, ROACH
        add ix, de
        pop bc
        djnz .next
        or a
        ret

roaches:        ds ROACH * MAX_ROACHES
roach_gap:      dw 0
roach_index:    db 0
