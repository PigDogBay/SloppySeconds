;-----------------------------------------------------------------------------
; Vending machine snacks
;
; Every cur_snack_gap + 0..255 frames (set per level) a snack (coffee,
; chocolate or an apple) appears on the half of the floor away from Joe, if
; fewer than cur_snacks are out. Each lasts SNACK_LIFE frames, flashing for
; the last SNACK_WARN. Walking into one lowers cynicism, but Joe has to pay
; for it out of his wages (which never go below 0).
;-----------------------------------------------------------------------------

MAX_SNACKS          equ 3
SNACK_TYPES         equ 3
SNACK_LIFE          equ 250             ; 5 s at 50 Hz
SNACK_WARN          equ 75              ; flash for the last 1.5 s
SNACK_MIN_Y         equ JOE_MIN_Y + 16
SNACK_Y_RANGE       equ TUB_Y - 24 - SNACK_MIN_Y
SNACK_HALF_W        equ 136             ; x range within each half
        ASSERT SNACK_Y_RANGE > 0 && SNACK_Y_RANGE < 256

        STRUCT SNACK
active      BYTE 0
type        BYTE 0
x           WORD 0
y           BYTE 0
timer       BYTE 0
        ENDS

; Per snack type: cynicism removed, price (pence, taken from wages)
snack_relief:       db 20, 30, 16       ; coffee, chocolate, apple
snack_price:        db 5, 8, 4

snacks_reset:
        ld ix, snacks
        ld b, MAX_SNACKS
        ld a, SPR_SNACK
.next:
        ld (ix + SNACK.active), 0
        push af
        push bc
        call sprite_hide
        pop bc
        pop af
        inc a
        ld de, SNACK
        add ix, de
        djnz .next
        ; fall through

snack_start_gap:
        ld e, 255
        call rand_below
        ld hl, (cur_snack_gap)
        add hl, a
        ld (snack_gap), hl
        ret

snacks_update:
        ld hl, (snack_gap)
        dec hl
        ld (snack_gap), hl
        ld a, h
        or l
        call z, snack_spawn

        ld ix, snacks
        xor a
        ld (snack_index), a
.next:
        call snack_step
        ld de, SNACK
        add ix, de
        ld hl, snack_index
        inc (hl)
        ld a, (hl)
        cp MAX_SNACKS
        jr c, .next
        ret

; Put out a new snack if one of the first cur_snacks slots is free:
; random type, random spot on the far side from Joe.
snack_spawn:
        call snack_start_gap
        ld ix, snacks
        ld a, (cur_snacks)
        ld b, a
.find:
        ld a, (ix + SNACK.active)
        or a
        jr z, .found
        ld de, SNACK
        add ix, de
        djnz .find
        ret                         ; enough out already
.found:
        ld e, SNACK_TYPES
        call rand_below
        ld (ix + SNACK.type), a
        ld e, SNACK_Y_RANGE
        call rand_below
        add a, SNACK_MIN_Y
        ld (ix + SNACK.y), a
        ld e, SNACK_HALF_W
        call rand_below
        add a, 16
        ld l, a
        ld h, 0
        push hl
        ld hl, (joe_x)
        ld de, SCREEN_W / 2 - 16
        or a
        sbc hl, de
        pop hl
        jr nc, 1F                   ; Joe on the right: snack on the left
        ld de, SCREEN_W / 2 - 8
        add hl, de
1:      ld (ix + SNACK.x), l
        ld (ix + SNACK.x + 1), h
        ld (ix + SNACK.timer), SNACK_LIFE
        ld (ix + SNACK.active), 1
        ret

; One frame for the snack at IX (slot snack_index).
snack_step:
        ld a, (ix + SNACK.active)
        or a
        ret z
        dec (ix + SNACK.timer)
        jr z, snack_finish          ; time's up

        ; Draw, blinking when nearly gone
        ld a, (ix + SNACK.timer)
        cp SNACK_WARN
        jr nc, .show
        and 4
        jr z, .show
        ld a, (snack_index)
        add a, SPR_SNACK
        call sprite_hide
        jr .collide
.show:
        ld l, (ix + SNACK.x)
        ld h, (ix + SNACK.x + 1)
        ld e, (ix + SNACK.y)
        ld a, (ix + SNACK.type)
        add a, PAT_SNACK
        ld d, a
        ld c, 0
        ld a, (snack_index)
        add a, SPR_SNACK
        call sprite_show

.collide:
        ld hl, (joe_x)
        ld e, (ix + SNACK.x)
        ld d, (ix + SNACK.x + 1)
        call abs_diff16
        ld a, h
        or a
        ret nz
        ld a, l
        cp 14
        ret nc
        ld a, (joe_y)               ; snack y within joe_y-12 .. joe_y+28
        ld b, a
        ld a, (ix + SNACK.y)
        sub b
        add a, 12
        cp 41
        ret nc

        ; Collected
        ld a, (ix + SNACK.type)
        ld hl, snack_relief
        add hl, a
        ld a, (hl)
        call sub_cynicism
        ld a, (ix + SNACK.type)
        ld hl, snack_price
        add hl, a
        ld a, (hl)
        call sub_wages
        ld a, SFX_SNACK
        call sfx_play
        ; fall through

snack_finish:
        ld (ix + SNACK.active), 0
        ld a, (snack_index)
        add a, SPR_SNACK
        jp sprite_hide

snacks:         ds SNACK * MAX_SNACKS
snack_gap:      dw 0
snack_index:    db 0
