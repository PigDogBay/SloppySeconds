;-----------------------------------------------------------------------------
; Mr Knut, the manager (levels with LVF_KNUT: Thursday onwards)
;
; Arrives from a side KNUT_ARRIVE frames into the level and wanders the floor
; slowly at random. If Joe bumps into him, Joe gets a telling-off: frozen for
; KNUT_TELL_OFF frames, +KNUT_DAMAGE cynicism, and Knut's words replace the
; status line. Afterwards Joe has KNUT_GRACE frames to get away.
;-----------------------------------------------------------------------------

KNUT_ARRIVE         equ 150             ; 3 s
KNUT_STEP_FRAMES    equ 2               ; frames per pixel walked
KNUT_TELL_OFF       equ 150             ; 3 s frozen
KNUT_GRACE          equ 100             ; 2 s before he can catch Joe again
KNUT_DAMAGE         equ 10
KNUT_MESSAGES       equ 3

KS_AWAY             equ 0
KS_WALKING          equ 1
KS_TELLING_OFF      equ 2

knut_reset:
        xor a
        ld (knut_state), a
        ld (knut_grace), a
        ld (joe_frozen), a
        ld hl, 0
        ld (hud_message), hl
        ld a, KNUT_ARRIVE
        ld (knut_timer), a
        ret

knut_update:
        ld a, (cur_flags)
        and LVF_KNUT
        ret z

        ld a, (knut_state)
        cp KS_WALKING
        jr z, .walking
        cp KS_TELLING_OFF
        jr z, .telling_off

        ; Away: count down, then walk in from a random side
        ld hl, knut_timer
        dec (hl)
        ret nz
        ld e, JOE_MAX_Y - JOE_MIN_Y
        call rand_below
        add a, JOE_MIN_Y
        ld (knut_y), a
        xor a
        ld (knut_dy), a
        call rand
        and 1
        ld hl, 0
        ld a, 1
        jr nz, 1F
        ld hl, JOE_MAX_X + 16
        ld a, -1
1:      ld (knut_x), hl
        ld (knut_dx), a
        call knut_turn_time
        ld a, KNUT_STEP_FRAMES
        ld (knut_step), a
        ld a, KS_WALKING
        ld (knut_state), a
        jp knut_draw

.telling_off:
        ld hl, knut_timer
        dec (hl)
        jp nz, knut_draw
        ld a, KS_WALKING
        ld (knut_state), a
        ld a, KNUT_GRACE
        ld (knut_grace), a
        ld hl, 0                    ; back to the normal status line
        ld (hud_message), hl
        ld hl, hud_dirty
        set HUD_STATUS, (hl)
        call knut_face_away
        jp knut_draw

.walking:
        ld a, (knut_grace)
        or a
        jr z, 1F
        dec a
        ld (knut_grace), a
1:
        ld hl, knut_turn
        dec (hl)
        call z, knut_new_direction

        ld hl, knut_step
        dec (hl)
        jr nz, .collide
        ld (hl), KNUT_STEP_FRAMES
        call knut_move

.collide:
        ld a, (knut_grace)
        or a
        jr nz, knut_draw
        ld hl, (joe_x)
        ld de, (knut_x)
        call abs_diff16
        ld a, h
        or a
        jr nz, knut_draw
        ld a, l
        cp 12
        jr nc, knut_draw
        ld a, (knut_y)
        ld b, a
        ld a, (joe_y)
        sub b
        jr nc, 1F
        neg
1:      cp 24
        jr nc, knut_draw

        ; Caught! Freeze Joe, add cynicism, say something
        ld a, KS_TELLING_OFF
        ld (knut_state), a
        ld a, KNUT_TELL_OFF
        ld (knut_timer), a
        ld (joe_frozen), a
        ld a, KNUT_DAMAGE
        call add_cynicism
        ld a, SFX_KNUT
        call sfx_play
        ld e, KNUT_MESSAGES
        call rand_below
        add a, a
        ld hl, knut_messages
        add hl, a
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        ld (hud_message), hl
        ld hl, hud_dirty
        set HUD_STATUS, (hl)
        call knut_face_joe
        ; fall through

knut_draw:
        ld a, (knut_dx)             ; face the way he's heading
        bit 7, a
        ld a, 0
        jr z, 1F
        ld a, ATTR2_MIRROR_X
1:      ld (knut_flags), a
        ld hl, (knut_x)
        ld a, (knut_y)
        ld e, a
        ld d, PAT_KNUT_TOP
        ld a, (knut_flags)
        ld c, a
        ld a, SPR_KNUT_TOP
        call sprite_show
        ld hl, (knut_x)
        ld a, (knut_y)
        add a, 16
        ld e, a
        ld d, PAT_KNUT_BOTTOM
        ld a, (knut_flags)
        ld c, a
        ld a, SPR_KNUT_BOTTOM
        jp sprite_show

; One pixel along (dx, dy), bouncing off the edges of the floor.
knut_move:
        ld hl, (knut_x)
        ld a, (knut_dx)
        ld e, a
        add a, a
        sbc a, a
        ld d, a
        add hl, de
        bit 7, h
        jr z, 1F
        ld hl, 0
        ld a, 1
        ld (knut_dx), a
1:      push hl
        ld de, JOE_MAX_X + 16 + 1
        or a
        sbc hl, de
        pop hl
        jr c, 1F
        ld hl, JOE_MAX_X + 16
        ld a, -1
        ld (knut_dx), a
1:      ld (knut_x), hl
        ld a, (knut_dy)
        ld b, a
        ld a, (knut_y)
        add a, b
        cp JOE_MIN_Y
        jr nc, 1F
        ld a, 1
        ld (knut_dy), a
        ld a, JOE_MIN_Y
1:      cp JOE_MAX_Y + 1
        jr c, 1F
        ld a, -1
        ld (knut_dy), a
        ld a, JOE_MAX_Y
1:      ld (knut_y), a
        ret

knut_new_direction:
        ld e, 3
        call rand_below
        dec a
        ld (knut_dx), a
        ld b, a
        push bc
        ld e, 3
        call rand_below
        dec a
        ld (knut_dy), a
        pop bc
        or b
        jr nz, knut_turn_time
        ld a, 1
        ld (knut_dx), a
knut_turn_time:
        ld e, 64
        call rand_below
        add a, 40
        ld (knut_turn), a
        ret

; Point dx at Joe (while telling off) or away from him (afterwards).
knut_face_joe:
        ld a, 1
        jr knut_face
knut_face_away:
        ld a, -1
knut_face:
        ld b, a
        ld hl, (joe_x)
        ld de, (knut_x)
        or a
        sbc hl, de                  ; carry: Joe is to the left
        ld a, b
        jr nc, 1F
        neg
1:      ld (knut_dx), a
        xor a
        ld (knut_dy), a
        jp knut_turn_time

; Mr Knut facing right: bald dome, hair round the back, angry brow,
; white shirt, blue tie, grey trousers. Rect lists for pat_build_list.
knut_top_rects:
        db 4, 1, 8, 11, COL_SKIN        ; head
        db 5, 0, 6, 1, COL_SKIN
        db 3, 4, 2, 6, COL_KNUT_HAIR    ; hair round the back
        db 4, 3, 1, 2, COL_KNUT_HAIR
        db 12, 6, 1, 3, COL_SKIN        ; nose
        db 9, 5, 3, 1, COL_BLACK        ; angry brow
        db 10, 6, 1, 2, COL_BLACK       ; eye
        db 9, 10, 3, 1, COL_BLACK       ; scowl
        db 6, 12, 4, 1, COL_SKIN        ; neck
        db 3, 13, 10, 3, COL_WHITE      ; collar
        db 7, 13, 2, 3, COL_KNUT_TIE
        db $FF
knut_bottom_rects:
        db 3, 0, 10, 9, COL_WHITE       ; shirt
        db 1, 1, 2, 7, COL_WHITE        ; arms
        db 13, 1, 2, 7, COL_WHITE
        db 1, 8, 2, 2, COL_SKIN         ; hands
        db 13, 8, 2, 2, COL_SKIN
        db 7, 0, 2, 7, COL_KNUT_TIE     ; tie
        db 7, 7, 1, 1, COL_KNUT_TIE
        db 3, 9, 10, 5, COL_KNUT_SUIT   ; trousers
        db 3, 14, 4, 2, COL_BLACK       ; shoes
        db 9, 14, 4, 2, COL_BLACK
        db $FF

knut_messages:
        dw knut_msg1, knut_msg2, knut_msg3
knut_msg1:  db "MR KNUT: OI! GET BACK TO WORK!", 0
knut_msg2:  db "MR KNUT: IS THIS WHAT I PAY YOU FOR?", 0
knut_msg3:  db "MR KNUT: YOU'RE ON THIN ICE, LAD!", 0

knut_state:     db 0
knut_x:         dw 0
knut_y:         db 0
knut_dx:        db 0
knut_dy:        db 0
knut_turn:      db 0
knut_step:      db 0
knut_timer:     db 0
knut_grace:     db 0
knut_flags:     db 0
