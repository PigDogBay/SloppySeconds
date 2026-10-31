;-----------------------------------------------------------------------------
; Hardware sprites and placeholder patterns
;
; Sprites are shown over the border, so sprite (0,0) is the top-left of the
; 320x256 Layer 2 screen and both use the same coordinates. Sprite X is
; 9 bits and wraps: 496-511 shows partly off the left edge, 320+ is hidden.
;
; Placeholder patterns are drawn at start-up into pat_buf with PAT_RECT and
; uploaded. Replace them with gfx2next art later (keep the slot numbers).
; Higher sprite slots draw on top of lower ones.
;-----------------------------------------------------------------------------

; --- Pattern slots ---
SLOP_COLOURS        equ 7
PAT_JOE_TOP         equ 0
PAT_JOE_BOTTOM      equ 1
PAT_BUCKET          equ 2               ; rebuilt whenever the bucket changes
PAT_DROP            equ 3               ; + colour index
PAT_SPLAT           equ PAT_DROP + SLOP_COLOURS
PAT_TUB             equ PAT_SPLAT + SLOP_COLOURS
PAT_SNACK           equ PAT_TUB + SLOP_COLOURS  ; coffee, chocolate, apple

; --- Sprite slots (draw order: later = on top) ---
SPR_JOE_TOP         equ 0
SPR_JOE_BOTTOM      equ 1
SPR_TUB             equ 2               ; 5 tubs
SPR_DROP            equ 7               ; 6 drops, one per pipe
SPR_BUCKET          equ 13
SPR_SNACK           equ 14

ATTR2_MIRROR_X      equ %00001000

; Slop colour index -> palette colour. Level 1 uses the first two.
slop_colours:
        db $E0                      ; 0 red
        db $27                      ; 1 blue
        db $1C                      ; 2 green
        db $FC                      ; 3 yellow
        db $E7                      ; 4 magenta (not $E3: that's transparent)
        db $1F                      ; 5 cyan
        db $F4                      ; 6 orange
        ASSERT $ - slop_colours == SLOP_COLOURS

sprites_init:
        nextreg NR_SPRITE_LAYERS, %00000011 ; visible, over border, order SLU
        call sprites_hide_all
        call build_joe_patterns
        call build_snack_patterns
        jp build_slop_patterns

; In: A = sprite slot, HL = x (9 bits), E = y, D = pattern,
;     C = attr2 flags (e.g. ATTR2_MIRROR_X). Trashes A, BC.
sprite_show:
        ld b, c                     ; keep flags in B
        push bc
        ld bc, PORT_SPRITE_SLOT
        out (c), a
        pop bc
        ld c, PORT_SPRITE_ATTR      ; only the low byte is decoded
        out (c), l                  ; attr 0: X bits 7-0
        out (c), e                  ; attr 1: Y
        ld a, h
        and 1
        or b
        out (c), a                  ; attr 2: flags, X bit 8
        ld a, d
        or %10000000
        out (c), a                  ; attr 3: visible, pattern, 4-byte
        ret

; In: A = sprite slot.
sprite_hide:
        ld bc, PORT_SPRITE_SLOT
        out (c), a
        ld c, PORT_SPRITE_ATTR
        xor a
        out (c), a
        out (c), a
        out (c), a
        out (c), a                  ; attr 3 bit 7 clear = invisible
        ret

sprites_hide_all:
        ld bc, PORT_SPRITE_SLOT
        xor a
        out (c), a
        ld c, PORT_SPRITE_ATTR
        ld e, 64
.next:
        out (c), a
        out (c), a
        out (c), a
        out (c), a
        dec e
        jr nz, .next
        ret

;-----------------------------------------------------------------------------
; Pattern building
;-----------------------------------------------------------------------------
        MACRO PAT_RECT px, py, pw, ph, pcol
        ld a, px
        ld (pr_x), a
        ld a, py
        ld (pr_y), a
        ld a, pw
        ld (pr_w), a
        ld a, ph
        ld (pr_h), a
        ld a, pcol
        ld (pr_colour), a
        call pat_rect
        ENDM

pat_clear:
        ld hl, pat_buf
        ld (hl), COL_TRANSPARENT
        ld de, pat_buf + 1
        ld bc, 255
        ldir
        ret

; Fill a rectangle in pat_buf from pr_x/y/w/h/colour (all within 16x16).
pat_rect:
        ld a, (pr_y)
        add a, a
        add a, a
        add a, a
        add a, a
        ld e, a
        ld a, (pr_x)
        add a, e
        ld e, a
        ld d, 0
        ld hl, pat_buf
        add hl, de
        ld a, (pr_h)
        ld b, a
.row:
        push bc
        push hl
        ld a, (pr_w)
        ld b, a
        ld a, (pr_colour)
.column:
        ld (hl), a
        inc hl
        djnz .column
        pop hl
        ld de, 16
        add hl, de
        pop bc
        djnz .row
        ret

; Upload pat_buf to pattern slot A.
pat_upload:
        ld bc, PORT_SPRITE_SLOT
        out (c), a
        ld hl, pat_buf
        ld b, 0                     ; 256 bytes
        ld c, PORT_SPRITE_PATTERN
        otir
        ret

; Joe, facing right (mirror X for left). Top: cap, face, fag. Bottom: overalls.
build_joe_patterns:
        call pat_clear
        PAT_RECT 3, 1, 10, 4, COL_CAP
        PAT_RECT 10, 4, 5, 1, COL_CAP       ; peak
        PAT_RECT 4, 5, 9, 10, COL_SKIN
        PAT_RECT 10, 7, 1, 2, COL_BLACK     ; eye
        PAT_RECT 11, 12, 4, 1, COL_WHITE    ; fag end
        PAT_RECT 15, 12, 1, 1, COL_RED_HOT
        PAT_RECT 6, 15, 5, 1, COL_SKIN      ; neck
        ld a, PAT_JOE_TOP
        call pat_upload

        call pat_clear
        PAT_RECT 3, 0, 10, 9, COL_OVERALLS
        PAT_RECT 12, 1, 3, 6, COL_OVERALLS  ; arm
        PAT_RECT 13, 7, 3, 2, COL_SKIN      ; hand (holds the bucket)
        PAT_RECT 4, 9, 3, 5, COL_OVERALLS
        PAT_RECT 9, 9, 3, 5, COL_OVERALLS
        PAT_RECT 3, 14, 5, 2, COL_BLACK     ; boots
        PAT_RECT 9, 14, 5, 2, COL_BLACK
        ld a, PAT_JOE_BOTTOM
        jp pat_upload

; Vending machine snacks: coffee, chocolate bar, apple.
build_snack_patterns:
        call pat_clear                      ; mug of coffee
        PAT_RECT 6, 1, 1, 3, COL_GREY       ; steam
        PAT_RECT 9, 2, 1, 2, COL_GREY
        PAT_RECT 3, 5, 9, 10, COL_WHITE     ; mug
        PAT_RECT 12, 7, 3, 1, COL_WHITE     ; handle
        PAT_RECT 14, 7, 1, 5, COL_WHITE
        PAT_RECT 12, 11, 3, 1, COL_WHITE
        PAT_RECT 4, 5, 7, 2, COL_COFFEE
        ld a, PAT_SNACK + 0
        call pat_upload

        call pat_clear                      ; chocolate bar
        PAT_RECT 1, 5, 14, 7, COL_WRAPPER
        PAT_RECT 1, 5, 3, 7, COL_COFFEE     ; bitten end
        PAT_RECT 12, 5, 3, 7, COL_GREY      ; foil
        PAT_RECT 5, 7, 6, 3, COL_YELLOW     ; label
        ld a, PAT_SNACK + 1
        call pat_upload

        call pat_clear                      ; apple
        PAT_RECT 8, 1, 1, 4, COL_COFFEE     ; stalk
        PAT_RECT 9, 2, 3, 2, $1C            ; leaf
        PAT_RECT 4, 5, 8, 10, $E0
        PAT_RECT 3, 7, 10, 6, $E0
        PAT_RECT 5, 7, 2, 2, COL_WHITE      ; shine
        ld a, PAT_SNACK + 2
        jp pat_upload

; Drop, splat and tub patterns for every slop colour.
build_slop_patterns:
        xor a
        ld (build_index), a
.next:
        ld e, a
        ld d, 0
        ld hl, slop_colours
        add hl, de
        ld a, (hl)
        ld (build_colour), a

        call pat_clear                      ; drop
        PAT_RECT 6, 2, 4, 2, (build_colour)
        PAT_RECT 5, 4, 6, 9, (build_colour)
        PAT_RECT 4, 6, 8, 6, (build_colour)
        PAT_RECT 6, 6, 1, 2, COL_WHITE
        ld a, (build_index)
        add a, PAT_DROP
        call pat_upload

        call pat_clear                      ; splat
        PAT_RECT 4, 11, 8, 2, (build_colour)
        PAT_RECT 1, 13, 14, 3, (build_colour)
        ld a, (build_index)
        add a, PAT_SPLAT
        call pat_upload

        call pat_clear                      ; tub
        PAT_RECT 0, 3, 16, 13, COL_GREY
        PAT_RECT 2, 5, 12, 9, (build_colour)
        PAT_RECT 0, 3, 16, 1, COL_WHITE
        ld a, (build_index)
        add a, PAT_TUB
        call pat_upload

        ld a, (build_index)
        inc a
        ld (build_index), a
        cp SLOP_COLOURS
        jp c, .next
        ret

pat_buf:        ds 256
pr_x:           db 0
pr_y:           db 0
pr_w:           db 0
pr_h:           db 0
pr_colour:      db 0
build_index:    db 0
build_colour:   db 0
