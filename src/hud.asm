;-----------------------------------------------------------------------------
; HUD: cynicism bar and wages (top strip), level progress (on the belt)
;
; Change values with add_cynicism / add_wages (or set hud_dirty bits);
; hud_update redraws only the parts that changed, once per frame.
;-----------------------------------------------------------------------------

HUD_CYNICISM        equ 0               ; hud_dirty bits
HUD_WAGES           equ 1
HUD_STATUS          equ 2
HUD_ALL             equ %00000111

CYN_BAR_X           equ 76
CYN_BAR_Y           equ 4
CYN_BAR_H           equ 8               ; bar width = CYNICISM_MAX pixels
STATUS_Y            equ BELT_Y + 20

; In: A = amount. Caps at CYNICISM_MAX.
add_cynicism:
        ld b, a
        ld a, (cynicism)
        add a, b
        cp CYNICISM_MAX + 1
        jr c, 1F
        ld a, CYNICISM_MAX
1:      ld (cynicism), a
        ld hl, hud_dirty
        set HUD_CYNICISM, (hl)
        ret

; In: A = amount. Stops at 0.
sub_cynicism:
        ld b, a
        ld a, (cynicism)
        sub b
        jr nc, 1F
        xor a
1:      ld (cynicism), a
        ld hl, hud_dirty
        set HUD_CYNICISM, (hl)
        ret

; In: A = pence. Stops at 0.
sub_wages:
        ld e, a
        ld d, 0
        ld hl, (wages)
        or a
        sbc hl, de
        jr nc, 1F
        ld hl, 0
1:      ld (wages), hl
        ld hl, hud_dirty
        set HUD_WAGES, (hl)
        ret

; In: A = pence.
add_wages:
        ld hl, (wages)
        add hl, a
        ld (wages), hl
        ld hl, hud_dirty
        set HUD_WAGES, (hl)
        ret

hud_update:
        ld a, (hud_dirty)
        or a
        ret z
        bit HUD_CYNICISM, a
        call nz, hud_draw_cynicism
        ld a, (hud_dirty)
        bit HUD_WAGES, a
        call nz, hud_draw_wages
        ld a, (hud_dirty)
        bit HUD_STATUS, a
        call nz, hud_draw_status
        xor a
        ld (hud_dirty), a
        ret

hud_draw_labels:
        TEXT 4, 4, COL_WHITE, 1
        ld hl, str_hud_cynicism
        jp print_string

hud_draw_cynicism:
        FILL_RECT CYN_BAR_X, CYN_BAR_Y, CYNICISM_MAX, CYN_BAR_H, COL_BAR_BG
        ld a, (cynicism)
        ld l, a
        ld h, 0
        ld (rect_w), hl             ; 0 width draws nothing
        ld a, COL_CYNICISM
        ld (rect_colour), a
        jp l2_fill_rect             ; x/y/h still set from above

hud_draw_wages:
        FILL_RECT 192, 0, SCREEN_W - 192, HUD_H, COL_BLACK
        call str_start
        ld hl, str_hud_wages
        call str_append
        ld hl, (wages)
        call str_append_u16
        ld hl, str_hud_pence
        call str_append
        TEXT 0, 4, COL_WHITE, 1
        ; right-align: x = SCREEN_W - 4 - length * 8
        ld hl, (str_ptr)
        ld de, strbuf
        or a
        sbc hl, de
        ld a, l
        add a, a
        add a, a
        add a, a
        ld e, a
        ld d, 0
        ld hl, SCREEN_W - 4
        or a
        sbc hl, de
        ld (text_x), hl
        ld hl, strbuf
        jp print_string

hud_draw_status:
        FILL_RECT 0, STATUS_Y - 2, SCREEN_W, 12, COL_BELT
        call str_start
        call str_append_day
        ld hl, str_hud_buckets
        call str_append
        ld a, (deposits)
        call str_append_u8
        ld hl, str_hud_slash
        call str_append
        ld a, (cur_quota)
        call str_append_u8
        TEXT 0, STATUS_Y, COL_BLACK, 1
        ld hl, strbuf
        jp print_centred

hud_dirty:          db 0

str_hud_cynicism:   db "CYNICISM", 0
str_hud_wages:      db "WAGES: ", 0
str_hud_pence:      db "P", 0
str_hud_buckets:    db "     BUCKETS ", 0
str_hud_slash:      db "/", 0
