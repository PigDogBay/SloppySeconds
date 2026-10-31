;-----------------------------------------------------------------------------
; Joe and his bucket
;
; Joe is 16x32 (two sprites); joe_x/joe_y is his top-left. The bucket hangs
; at his hand, BUCKET_OFFSET pixels to the side he's facing.
;-----------------------------------------------------------------------------

JOE_SPEED           equ 2
JOE_MIN_X           equ 16              ; keeps the bucket on screen
JOE_MAX_X           equ SCREEN_W - 32
JOE_MIN_Y           equ HUD_H
JOE_MAX_Y           equ BELT_Y - 32
BUCKET_OFFSET       equ 14
BUCKET_CAPACITY     equ 1               ; drops in a full bucket

joe_reset:
        ld hl, (SCREEN_W - 16) / 2
        ld (joe_x), hl
        ld a, JOE_MAX_Y
        ld (joe_y), a
        xor a
        ld (joe_facing), a
        ld (bucket_count), a
        jp bucket_rebuild

joe_update:
        ld a, (joe_frozen)          ; being told off: can't move
        or a
        jr z, 1F
        dec a
        ld (joe_frozen), a
        ret
1:
        ld a, (input)
        ld e, a

        bit INPUT_LEFT, e
        jr z, .not_left
        ld a, 1
        ld (joe_facing), a
        ld hl, (joe_x)
        ld bc, JOE_SPEED
        or a
        sbc hl, bc
        ld bc, JOE_MIN_X
        push hl
        or a
        sbc hl, bc
        pop hl
        jr nc, 1F
        ld hl, JOE_MIN_X
1:      ld (joe_x), hl
.not_left:
        bit INPUT_RIGHT, e
        jr z, .not_right
        xor a
        ld (joe_facing), a
        ld hl, (joe_x)
        ld bc, JOE_SPEED
        add hl, bc
        push hl
        ld bc, JOE_MAX_X + 1
        or a
        sbc hl, bc
        pop hl
        jr c, 1F
        ld hl, JOE_MAX_X
1:      ld (joe_x), hl
.not_right:
        bit INPUT_UP, e
        jr z, .not_up
        ld a, (joe_y)
        sub JOE_SPEED
        cp JOE_MIN_Y
        jr nc, 1F
        ld a, JOE_MIN_Y
1:      ld (joe_y), a
.not_up:
        bit INPUT_DOWN, e
        jr z, .not_down
        ld a, (joe_y)
        add a, JOE_SPEED
        cp JOE_MAX_Y + 1
        jr c, 1F
        ld a, JOE_MAX_Y
1:      ld (joe_y), a
.not_down:
        ret

; Out: HL = bucket x, A = bucket y.
joe_bucket_pos:
        ld hl, (joe_x)
        ld de, BUCKET_OFFSET
        ld a, (joe_facing)
        or a
        jr nz, .left
        add hl, de
        jr .y
.left:
        or a
        sbc hl, de
.y:
        ld a, (joe_y)
        add a, 16
        ret

joe_draw:
        ld a, (joe_facing)
        or a
        jr z, 1F
        ld a, ATTR2_MIRROR_X
1:      ld (joe_flags), a

        ld hl, (joe_x)
        ld a, (joe_y)
        ld e, a
        ld d, PAT_JOE_TOP
        ld a, (joe_flags)
        ld c, a
        ld a, SPR_JOE_TOP
        call sprite_show

        ld hl, (joe_x)
        ld a, (joe_y)
        add a, 16
        ld e, a
        ld d, PAT_JOE_BOTTOM
        ld a, (joe_flags)
        ld c, a
        ld a, SPR_JOE_BOTTOM
        call sprite_show

        call joe_bucket_pos
        ld e, a
        ld d, PAT_BUCKET
        ld c, 0
        ld a, SPR_BUCKET
        jp sprite_show

; Try to catch a drop. In: A = slop colour index.
; Out: carry set if caught (the bucket must be empty, or not full and the
; same colour).
bucket_try_catch:
        ld c, a
        ld a, (bucket_count)
        cp BUCKET_CAPACITY
        jr nc, .no                  ; full
        or a
        jr z, .take                 ; empty
        ld a, (bucket_colour)
        cp c
        jr nz, .no                  ; wrong colour
.take:
        ld a, c
        ld (bucket_colour), a
        ld hl, bucket_count
        inc (hl)
        call bucket_rebuild
        scf
        ret
.no:
        or a
        ret

bucket_empty:
        xor a
        ld (bucket_count), a
        ; fall through

; Redraw the bucket pattern: grey pail, filled to match bucket_count.
bucket_rebuild:
        call pat_clear
        PAT_RECT 4, 3, 8, 1, COL_GREY       ; handle
        PAT_RECT 3, 4, 1, 2, COL_GREY
        PAT_RECT 12, 4, 1, 2, COL_GREY
        PAT_RECT 3, 6, 10, 10, COL_GREY     ; pail
        PAT_RECT 5, 6, 6, 8, COL_FLOOR      ; empty inside
        ld a, (bucket_count)
        or a
        jr z, .upload
        ld e, a
        ld d, 0
        ld hl, bucket_fill_rows
        add hl, de
        ld a, (hl)
        ld (pr_h), a
        ld b, a
        ld a, 14
        sub b
        ld (pr_y), a
        ld a, 5
        ld (pr_x), a
        ld a, 6
        ld (pr_w), a
        ld a, (bucket_colour)
        ld e, a
        ld d, 0
        ld hl, slop_colours
        add hl, de
        ld a, (hl)
        ld (pr_colour), a
        call pat_rect
.upload:
        ld a, PAT_BUCKET
        jp pat_upload

bucket_fill_rows:
        db 0, 8                         ; rows filled, by bucket_count
        ASSERT $ - bucket_fill_rows == BUCKET_CAPACITY + 1

joe_x:          dw 0
joe_y:          db 0
joe_facing:     db 0                    ; 0 = right, 1 = left
joe_flags:      db 0
joe_frozen:     db 0                    ; frames left being told off
bucket_count:   db 0                    ; drops in the bucket
bucket_colour:  db 0                    ; slop colour index
