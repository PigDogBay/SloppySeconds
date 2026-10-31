;-----------------------------------------------------------------------------
; Small helpers: random numbers, distances
;-----------------------------------------------------------------------------

; 16-bit xorshift. Out: A = random byte. Trashes HL.
rand:
        ld hl, (rand_seed)
        ld a, h
        rra
        ld a, l
        rra
        xor h
        ld h, a
        ld a, l
        rra
        ld a, h
        rra
        xor l
        ld l, a
        xor h
        ld h, a
        ld (rand_seed), hl
        ret

; Out: A = random number 0..E-1. Trashes D, HL.
rand_below:
        call rand
        ld d, a
        mul d, e
        ld a, d
        ret

; Mix the R register into the seed (call on a key press).
rand_mix:
        ld a, r
        ld hl, (rand_seed)
        xor l
        ld l, a
        ld a, h
        or l
        jr nz, 1F
        inc hl                      ; the seed must never be 0
1:      ld (rand_seed), hl
        ret

; HL = |HL - DE|, for values 0..32767.
abs_diff16:
        or a
        sbc hl, de
        ret nc
        ex de, hl
        ld hl, 0
        or a
        sbc hl, de
        ret

rand_seed:      dw $ACE1
