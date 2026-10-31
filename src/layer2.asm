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
