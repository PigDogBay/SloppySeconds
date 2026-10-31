;-----------------------------------------------------------------------------
; Vending machine snacks
;
; Every SNACK_GAP_MIN + 0..255 frames a snack (coffee, chocolate or an apple)
; appears on the half of the floor away from Joe. It lasts SNACK_LIFE frames,
; flashing for the last SNACK_WARN. Walking into it lowers cynicism, but Joe
; has to pay for it out of his wages (which never go below 0).
; Only one snack is out at a time.
;-----------------------------------------------------------------------------

SNACK_TYPES         equ 3
SNACK_LIFE          equ 250             ; 5 s at 50 Hz
SNACK_WARN          equ 75              ; flash for the last 1.5 s
SNACK_GAP_MIN       equ 500             ; 10 s; plus up to ~5 s random
SNACK_MIN_Y         equ JOE_MIN_Y + 16
SNACK_Y_RANGE       equ TUB_Y - 24 - SNACK_MIN_Y
SNACK_HALF_W        equ 136             ; x range within each half
        ASSERT SNACK_Y_RANGE > 0 && SNACK_Y_RANGE < 256

; Per snack type: cynicism removed, price (pence, taken from wages)
snack_relief:       db 10, 15, 8        ; coffee, chocolate, apple
snack_price:        db 5, 8, 4

snacks_reset:
        xor a
        ld (snack_active), a
        ld a, SPR_SNACK
        call sprite_hide
        ; fall through

snack_start_gap:
        ld e, 255
        call rand_below
        ld hl, SNACK_GAP_MIN
        add hl, a
        ld (snack_gap), hl
        ret

snacks_update:
        ld a, (snack_active)
        or a
        jr nz, .active
        ld hl, (snack_gap)
        dec hl
        ld (snack_gap), hl
        ld a, h
        or l
        ret nz

        ; Spawn: random type, random spot on the far side from Joe
        ld e, SNACK_TYPES
        call rand_below
        ld (snack_type), a
        ld e, SNACK_Y_RANGE
        call rand_below
        add a, SNACK_MIN_Y
        ld (snack_y), a
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
1:      ld (snack_x), hl
        ld a, SNACK_LIFE
        ld (snack_timer), a
        ld a, 1
        ld (snack_active), a
        ret

.active:
        ld hl, snack_timer
        dec (hl)
        jr z, snack_finish          ; time's up

        ; Draw, blinking when nearly gone
        ld a, (hl)
        cp SNACK_WARN
        jr nc, .show
        and 4
        jr z, .show
        ld a, SPR_SNACK
        call sprite_hide
        jr .collide
.show:
        ld hl, (snack_x)
        ld a, (snack_y)
        ld e, a
        ld a, (snack_type)
        add a, PAT_SNACK
        ld d, a
        ld c, 0
        ld a, SPR_SNACK
        call sprite_show

.collide:
        ld hl, (joe_x)
        ld de, (snack_x)
        call abs_diff16
        ld a, h
        or a
        ret nz
        ld a, l
        cp 14
        ret nc
        ld a, (joe_y)               ; snack y within joe_y-12 .. joe_y+28
        ld b, a
        ld a, (snack_y)
        sub b
        add a, 12
        cp 41
        ret nc

        ; Collected
        ld a, (snack_type)
        ld e, a
        ld d, 0
        ld hl, snack_relief
        add hl, de
        ld a, (hl)
        call sub_cynicism
        ld a, (snack_type)
        ld e, a
        ld d, 0
        ld hl, snack_price
        add hl, de
        ld a, (hl)
        call sub_wages
        ; fall through

snack_finish:
        xor a
        ld (snack_active), a
        ld a, SPR_SNACK
        call sprite_hide
        jp snack_start_gap

snack_active:   db 0
snack_type:     db 0
snack_x:        dw 0
snack_y:        db 0
snack_timer:    db 0
snack_gap:      dw 0
