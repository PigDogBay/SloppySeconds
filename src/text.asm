;-----------------------------------------------------------------------------
; Text on Layer 2
;
; Uses the 8x8 character set in the 48K ROM ($3D00, chars 32-127), which
; main.asm pages in at start-up. To use a custom font, point FONT_BASE at
; your own 96-character, 8-bytes-per-char table, minus 32*8.
;
; Text is drawn with a transparent background (only set pixels are written),
; at scale 1 (8x8) or 2 (16x16). Strings end with 0; 13 starts a new line
; (in print_centred only).
;-----------------------------------------------------------------------------

FONT_BASE           equ $3D00 - 32 * 8
LINE_GAP            equ 4               ; extra pixels between lines

; Set the text cursor/style. Pass px = 0 when using print_centred.
        MACRO TEXT px, py, pcol, pscale
        ld hl, px
        ld (text_x), hl
        ld a, py
        ld (text_y), a
        ld a, pcol
        ld (text_colour), a
        ld a, pscale
        ld (text_scale), a
        ENDM

; Draw one character at (text_x, text_y) and advance text_x.
; In: A = ASCII code (32-127).
print_char:
        ld l, a
        ld h, 0
        add hl, hl
        add hl, hl
        add hl, hl
        ld de, FONT_BASE
        add hl, de
        ld (glyph_ptr), hl

        ld hl, (text_x)
        ld c, $80                   ; mask for the current font column
.column:
        ld a, (text_scale)
        ld b, a                     ; horizontal repeat
.column_repeat:
        push bc
        push hl
        call l2_page_column
        ld d, a
        ld a, (text_y)
        ld e, a                     ; DE = screen address of (x, text_y)
        ld hl, (glyph_ptr)
        ld b, 8                     ; font rows
.row:
        ld a, (hl)
        and c
        ld a, (text_scale)          ; (flags still from AND)
        jr z, .skip
        push bc
        ld b, a
        ld a, (text_colour)
.write:
        ld (de), a
        inc e
        djnz .write
        pop bc
        jr .next_row
.skip:
        add a, e
        ld e, a
.next_row:
        inc hl
        djnz .row
        pop hl
        inc hl                      ; next screen column
        pop bc
        djnz .column_repeat
        srl c
        jr nz, .column
        ld (text_x), hl
        nextreg NR_MMU6, MMU6_DEFAULT
        ret

; Print from HL until 0 or 13. Out: HL points at the terminator.
print_string:
        ld a, (hl)
        or a
        ret z
        cp 13
        ret z
        push hl
        call print_char
        pop hl
        inc hl
        jr print_string

; Print a string with each line centred horizontally, starting at text_y.
; In: HL = string (lines separated by 13).
print_centred:
.line:
        push hl
        ld b, 0                     ; B = characters in this line
.count:
        ld a, (hl)
        or a
        jr z, .counted
        cp 13
        jr z, .counted
        inc b
        inc hl
        jr .count
.counted:
        ld l, b
        ld h, 0
        add hl, hl
        add hl, hl
        add hl, hl                  ; width at scale 1
        ld a, (text_scale)
        cp 2
        jr nz, 1F
        add hl, hl
1:      ex de, hl
        ld hl, SCREEN_W
        or a
        sbc hl, de
        srl h
        rr l
        ld (text_x), hl
        pop hl
        call print_string
        ld a, (hl)
        or a
        ret z
        inc hl                      ; skip the 13
        ld a, (text_scale)
        add a, a
        add a, a
        add a, a
        add a, LINE_GAP
        ld b, a
        ld a, (text_y)
        add a, b
        ld (text_y), a
        jr .line

;-----------------------------------------------------------------------------
; String builder (for text with numbers in it)
;-----------------------------------------------------------------------------
STRBUF_SIZE         equ 48

; Start a new string in strbuf.
str_start:
        ld hl, strbuf
        ld (str_ptr), hl
        ld (hl), 0
        ret

; Append the string at HL.
str_append:
        ld de, (str_ptr)
.copy:
        ld a, (hl)
        ld (de), a
        or a
        jr z, .done
        inc hl
        inc de
        jr .copy
.done:
        ld (str_ptr), de
        ret

; Append A (0-255) in decimal, without leading zeros.
str_append_u8:
        ld l, a
        ld h, 0
        ; fall through

; Append HL (0-65535) in decimal, without leading zeros.
str_append_u16:
        xor a
        ld (num_started), a
        ld bc, 10000
        call .digit
        ld bc, 1000
        call .digit
        ld bc, 100
        call .digit
        ld bc, 10
        call .digit
        ld a, l
        add a, '0'
        call .emit                  ; units are always written
        ld de, (str_ptr)
        xor a
        ld (de), a
        ret
.digit:
        ld a, '0' - 1
.subtract:
        inc a
        or a                        ; clear carry (A unchanged)
        sbc hl, bc
        jr nc, .subtract
        add hl, bc
        cp '0'
        jr nz, .emit
        push af
        ld a, (num_started)
        or a
        jr nz, .zero
        pop af
        ret                         ; leading zero: skip
.zero:
        pop af
.emit:
        ld de, (str_ptr)
        ld (de), a
        inc de
        ld (str_ptr), de
        ld a, 1
        ld (num_started), a
        ret

text_x:         dw 0
text_y:         db 0
text_colour:    db COL_WHITE
text_scale:     db 1
glyph_ptr:      dw 0
num_started:    db 0
str_ptr:        dw strbuf
strbuf:         ds STRBUF_SIZE
