;-----------------------------------------------------------------------------
; Layer 2, 320x256 8bpp
;
; Memory is column-major: byte offset = x * 256 + y. The 80K screen is
; 10 consecutive 8K pages; each page holds 32 columns. To draw, page the
; relevant 8K into MMU6 ($C000-$DFFF), then restore MMU6 afterwards.
;-----------------------------------------------------------------------------

L2_BANK             equ 9               ; 16K bank 9 = 8K pages 18..27
L2_FIRST_PAGE       equ L2_BANK * 2
L2_PAGES            equ 10
MMU6_DEFAULT        equ 0               ; NEX default: bank 0 at $C000

l2_init:
        nextreg NR_L2_BANK, L2_BANK
        nextreg NR_L2_CONTROL, %00010000    ; 320x256, palette offset 0
        nextreg NR_CLIP_CTRL, %00000001     ; reset L2 clip index
        nextreg NR_CLIP_L2, 0               ; X1 (x/2)
        nextreg NR_CLIP_L2, 159             ; X2 (x/2)
        nextreg NR_CLIP_L2, 0               ; Y1
        nextreg NR_CLIP_L2, 255             ; Y2
        nextreg NR_DISPLAY_CTRL1, %10000000 ; Layer 2 on
        ret

; Page the column containing pixel x into MMU6.
; In: HL = x (0..319). Out: A = high byte of the column's address
; ($C0..$DF); the low byte is y. Leaves MMU6 paged; caller restores it.
l2_page_column:
        ld a, l
        rlca
        rlca
        rlca
        and 7                       ; (x & 255) >> 5
        bit 0, h
        jr z, 1F
        or 8                        ; + 256 >> 5
1:      add a, L2_FIRST_PAGE
        nextreg NR_MMU6, a
        ld a, l
        and 31
        or $C0
        ret

; Fill the whole screen. In: A = colour.
l2_clear:
        ld (rect_colour), a
        ld b, L2_PAGES
        ld c, L2_FIRST_PAGE
.page:
        push bc
        ld a, c
        nextreg NR_MMU6, a
        ld a, (rect_colour)
        ld hl, $C000
        ld (hl), a
        ld de, $C001
        ld bc, $1FFF
        ldir
        pop bc
        inc c
        djnz .page
        nextreg NR_MMU6, MMU6_DEFAULT
        ret

; Fill a rectangle. Parameters in rect_x/y/w/h/colour (use FILL_RECT).
; y + h must not pass 256. A width or height of 0 draws nothing.
l2_fill_rect:
        ld a, (rect_h)
        or a
        ret z
        ld bc, (rect_w)
        ld a, b
        or c
        ret z
        ld hl, (rect_x)
.column:
        push bc
        push hl
        call l2_page_column
        ld h, a
        ld a, (rect_y)
        ld l, a
        ld a, (rect_h)
        ld b, a
        ld a, (rect_colour)
.fill:
        ld (hl), a
        inc l
        djnz .fill
        pop hl
        inc hl
        pop bc
        dec bc
        ld a, b
        or c
        jr nz, .column
        nextreg NR_MMU6, MMU6_DEFAULT
        ret

        MACRO FILL_RECT px, py, pw, ph, pcol
        ld hl, px
        ld (rect_x), hl
        ld hl, pw
        ld (rect_w), hl
        ld a, py
        ld (rect_y), a
        ld a, ph
        ld (rect_h), a
        ld a, pcol
        ld (rect_colour), a
        call l2_fill_rect
        ENDM

rect_x:         dw 0
rect_w:         dw 0
rect_y:         db 0
rect_h:         db 0
rect_colour:    db 0

;-----------------------------------------------------------------------------
; Half disc with a flat bottom (arched windows, tree canopies, cloud puffs).
; Parameters in disc_* (use HALF_DISC). If disc_grid is non-zero, the rim and
; a grid every GRID_MASK+1 pixels are drawn in that colour (window panes).
; Columns off the screen are skipped. r must be 1..127.
;-----------------------------------------------------------------------------
GRID_MASK           equ 3               ; panes every 4 pixels

l2_half_disc:
        ld a, (disc_r)
        ld d, a
        ld e, a
        mul d, e
        ld (disc_r2), de
        ld a, (disc_r)
        neg
        ld (disc_dx), a
.column:
        ld a, (disc_dx)             ; HL = cx + dx (sign-extended)
        ld l, a
        add a, a
        sbc a, a
        ld h, a
        ld de, (disc_cx)
        add hl, de
        bit 7, h
        jr nz, .next                ; x < 0
        push hl
        ld de, SCREEN_W
        or a
        sbc hl, de
        pop hl
        jr nc, .next                ; x >= 320
        call l2_page_column
        ld (disc_col_hi), a

        ld a, (disc_dx)             ; |dx| and dx^2
        bit 7, a
        jr z, 1F
        neg
1:      ld (disc_adx), a
        ld d, a
        ld e, a
        mul d, e
        ld (disc_dx2), de

        ld b, 0                     ; B = column height: largest h with
.grow:                              ; dx^2 + h^2 <= r^2
        ld a, b
        inc a
        ld d, a
        ld e, a
        mul d, e
        ld hl, (disc_dx2)
        add hl, de
        ex de, hl
        ld hl, (disc_r2)
        or a
        sbc hl, de
        jr c, .grown
        inc b
        jr .grow
.grown:
        ld a, b
        or a
        jr z, .next
        ld d, b                     ; D = rows left
        ld c, 1                     ; C = row number from the bottom
        ld a, (disc_col_hi)
        ld h, a
        ld a, (disc_base)
        ld l, a
.row:
        dec l
        ld a, (disc_grid)
        or a
        jr z, .solid
        ld a, c
        cp b
        jr z, .grid                 ; rim
        ld a, (disc_adx)
        or a
        jr z, .grid                 ; centre bar
        and GRID_MASK
        jr z, .grid
        ld a, c
        and GRID_MASK
        jr z, .grid
.solid:
        ld a, (disc_colour)
        jr .plot
.grid:
        ld a, (disc_grid)
.plot:
        ld (hl), a
        inc c
        dec d
        jr nz, .row
.next:
        ld a, (disc_r)
        ld b, a
        ld a, (disc_dx)
        cp b
        jr z, .done
        inc a
        ld (disc_dx), a
        jp .column
.done:
        nextreg NR_MMU6, MMU6_DEFAULT
        ret

        MACRO HALF_DISC pcx, pbase, pr, pcol, pgrid
        ld hl, pcx
        ld (disc_cx), hl
        ld a, pbase
        ld (disc_base), a
        ld a, pr
        ld (disc_r), a
        ld a, pcol
        ld (disc_colour), a
        ld a, pgrid
        ld (disc_grid), a
        call l2_half_disc
        ENDM

disc_cx:        dw 0
disc_base:      db 0
disc_r:         db 0
disc_colour:    db 0
disc_grid:      db 0
disc_dx:        db 0
disc_adx:       db 0
disc_col_hi:    db 0
disc_r2:        dw 0
disc_dx2:       dw 0
