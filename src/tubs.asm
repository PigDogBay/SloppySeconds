;-----------------------------------------------------------------------------
; Tubs on the conveyor belt
;
; TUB_COUNT tubs ride a loop TUB_TRACK pixels long, moving right to left.
; When a tub passes off the left edge it jumps back to the right (off screen)
; and gets the next colour in the cycle, so every colour keeps coming round.
; Tub x is signed: -16 is just off the left edge.
;-----------------------------------------------------------------------------

TUB_COUNT           equ 5
TUB_SPACING         equ 80
TUB_TRACK           equ TUB_COUNT * TUB_SPACING
TUB_Y               equ BELT_Y - 16
TUB_REACH           equ 13              ; bucket-to-tub x distance that counts as touching

        STRUCT TUB
x           WORD 0
colour      BYTE 0
        ENDS

tubs_reset:
        ld a, (cur_colours)
        ld e, a
        call rand_below
        ld (tub_next_colour), a
        ld ix, tubs
        ld hl, 40
        ld b, TUB_COUNT
.next:
        ld (ix + TUB.x), l
        ld (ix + TUB.x + 1), h
        push hl
        call tub_take_colour
        pop hl
        ld (ix + TUB.colour), a
        ld de, TUB_SPACING
        add hl, de
        ld de, TUB
        add ix, de
        djnz .next
        ret

; Out: A = next colour in the cycle.
tub_take_colour:
        ld a, (tub_next_colour)
        push af
        inc a
        ld hl, cur_colours
        cp (hl)
        jr c, 1F
        xor a
1:      ld (tub_next_colour), a
        pop af
        ret

tubs_update:
        ld ix, tubs
        ld b, TUB_COUNT
.next:
        push bc
        ld l, (ix + TUB.x)
        ld h, (ix + TUB.x + 1)
        ld a, (cur_belt_speed)
        ld e, a
        ld d, 0
        or a
        sbc hl, de
        bit 7, h
        jr z, .store                ; still on screen (x >= 0)
        ld de, -16
        push hl
        or a
        sbc hl, de
        pop hl
        jr nc, .store               ; x >= -16: partly visible
        ld de, TUB_TRACK
        add hl, de
        push hl
        call tub_take_colour
        ld (ix + TUB.colour), a
        pop hl
.store:
        ld (ix + TUB.x), l
        ld (ix + TUB.x + 1), h
        ld de, TUB
        add ix, de
        pop bc
        djnz .next
        ret

tubs_draw:
        ld ix, tubs
        ld b, TUB_COUNT
.next:
        push bc
        ld l, (ix + TUB.x)
        ld h, (ix + TUB.x + 1)
        ld e, TUB_Y
        ld a, (ix + TUB.colour)
        add a, PAT_TUB
        ld d, a
        ld c, 0
        ld a, TUB_COUNT + SPR_TUB
        sub b
        call sprite_show
        ld de, TUB
        add ix, de
        pop bc
        djnz .next
        ret

; Find a tub under the bucket. In: HL = bucket x.
; Out: carry set and A = tub colour if found.
tubs_find_under:
        ld ix, tubs
        ld b, TUB_COUNT
.next:
        push bc
        push hl
        ld e, (ix + TUB.x)
        ld d, (ix + TUB.x + 1)
        bit 7, d
        jr nz, .skip                ; off the left edge
        call abs_diff16
        ld a, h
        or a
        jr nz, .skip
        ld a, l
        cp TUB_REACH
        jr nc, .skip
        pop hl
        pop bc
        ld a, (ix + TUB.colour)
        scf
        ret
.skip:
        pop hl
        ld de, TUB
        add ix, de
        pop bc
        djnz .next
        or a
        ret

tubs:               ds TUB * TUB_COUNT
tub_next_colour:    db 0
