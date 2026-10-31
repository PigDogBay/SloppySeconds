;-----------------------------------------------------------------------------
; The bosses: Mr Knut the manager (LVF_KNUT, Thursday onwards) and Chairman
; Fumduck (LVF_FUMDUCK, Friday). Both run the same code on a BOSS record (IX).
;
; Each arrives from a side `arrive` frames into the level and wanders the
; floor slowly at random. If Joe bumps into one, Joe gets a telling-off:
; frozen for BOSS_TELL_OFF frames, +`damage` cynicism, and the boss's words
; replace the status line. Afterwards Joe has BOSS_GRACE frames to get away
; from that boss. A boss can't catch Joe while he's already being told off.
;-----------------------------------------------------------------------------

BOSS_STEP_FRAMES    equ 2               ; frames per pixel walked
BOSS_TELL_OFF       equ 150             ; 3 s frozen
BOSS_GRACE          equ 100             ; 2 s before he can catch Joe again
BOSS_MESSAGES       equ 3

KS_AWAY             equ 0
KS_WALKING          equ 1
KS_TELLING_OFF      equ 2

        STRUCT BOSS
state       BYTE 0
x           WORD 0
y           BYTE 0
dx          BYTE 0
dy          BYTE 0
turn        BYTE 0
step        BYTE 0
timer       BYTE 0
grace       BYTE 0
; Fixed per boss
lvflag      BYTE 0      ; LVF_* bit that brings him in
arrive      BYTE 0      ; frames into the level
damage      BYTE 0      ; cynicism per telling-off
spr         BYTE 0      ; top sprite slot (bottom is the next one)
pat         BYTE 0      ; top pattern (bottom is the next one)
sfx         BYTE 0
msgs        WORD 0      ; table of BOSS_MESSAGES string pointers
        ENDS

knut:
        BOSS { 0, 0, 0, 0, 0, 0, 0, 0, 0, LVF_KNUT, 150, 10, SPR_KNUT_TOP, PAT_KNUT_TOP, SFX_KNUT, knut_messages }
fumduck:
        BOSS { 0, 0, 0, 0, 0, 0, 0, 0, 0, LVF_FUMDUCK, 250, 20, SPR_FUM_TOP, PAT_FUM_TOP, SFX_FUMDUCK, fumduck_messages }

bosses_reset:
        xor a
        ld (joe_frozen), a
        ld hl, 0
        ld (hud_message), hl
        ld ix, knut
        call boss_reset
        ld ix, fumduck
boss_reset:
        ld (ix + BOSS.state), KS_AWAY
        ld (ix + BOSS.grace), 0
        ld a, (ix + BOSS.arrive)
        ld (ix + BOSS.timer), a
        ret

bosses_update:
        ld ix, knut
        call boss_update
        ld ix, fumduck
        ; fall through

boss_update:
        ld a, (cur_flags)
        and (ix + BOSS.lvflag)
        ret z

        ld a, (ix + BOSS.state)
        cp KS_WALKING
        jr z, .walking
        cp KS_TELLING_OFF
        jr z, .telling_off

        ; Away: count down, then walk in from a random side
        dec (ix + BOSS.timer)
        ret nz
        ld e, JOE_MAX_Y - JOE_MIN_Y
        call rand_below
        add a, JOE_MIN_Y
        ld (ix + BOSS.y), a
        ld (ix + BOSS.dy), 0
        call rand
        and 1
        ld hl, 0
        ld a, 1
        jr nz, 1F
        ld hl, JOE_MAX_X + 16
        ld a, -1
1:      ld (ix + BOSS.x), l
        ld (ix + BOSS.x + 1), h
        ld (ix + BOSS.dx), a
        call boss_turn_time
        ld (ix + BOSS.step), BOSS_STEP_FRAMES
        ld (ix + BOSS.state), KS_WALKING
        jp boss_draw

.telling_off:
        dec (ix + BOSS.timer)
        jp nz, boss_draw
        ld (ix + BOSS.state), KS_WALKING
        ld (ix + BOSS.grace), BOSS_GRACE
        ld hl, 0                    ; back to the normal status line
        ld (hud_message), hl
        ld hl, hud_dirty
        set HUD_STATUS, (hl)
        call boss_face_away
        jp boss_draw

.walking:
        ld a, (ix + BOSS.grace)
        or a
        jr z, 1F
        dec (ix + BOSS.grace)
1:
        dec (ix + BOSS.turn)
        call z, boss_new_direction

        dec (ix + BOSS.step)
        jr nz, .collide
        ld (ix + BOSS.step), BOSS_STEP_FRAMES
        call boss_move

.collide:
        ld a, (ix + BOSS.grace)
        ld hl, joe_frozen           ; not while Joe's already in trouble
        or (hl)
        jr nz, boss_draw
        ld hl, (joe_x)
        ld e, (ix + BOSS.x)
        ld d, (ix + BOSS.x + 1)
        call abs_diff16
        ld a, h
        or a
        jr nz, boss_draw
        ld a, l
        cp 12
        jr nc, boss_draw
        ld a, (joe_y)
        sub (ix + BOSS.y)
        jr nc, 1F
        neg
1:      cp 24
        jr nc, boss_draw

        ; Caught! Freeze Joe, add cynicism, say something
        ld (ix + BOSS.state), KS_TELLING_OFF
        ld a, BOSS_TELL_OFF
        ld (ix + BOSS.timer), a
        ld (joe_frozen), a
        ld a, (ix + BOSS.damage)
        call add_cynicism
        ld a, (ix + BOSS.sfx)
        call sfx_play
        ld e, BOSS_MESSAGES
        call rand_below
        add a, a
        ld l, (ix + BOSS.msgs)
        ld h, (ix + BOSS.msgs + 1)
        add hl, a
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        ld (hud_message), hl
        ld hl, hud_dirty
        set HUD_STATUS, (hl)
        call boss_face_joe
        ; fall through

boss_draw:
        ld c, 0                     ; face the way he's heading
        bit 7, (ix + BOSS.dx)
        jr z, 1F
        ld c, ATTR2_MIRROR_X
1:      ld l, (ix + BOSS.x)
        ld h, (ix + BOSS.x + 1)
        ld e, (ix + BOSS.y)
        ld d, (ix + BOSS.pat)
        ld a, (ix + BOSS.spr)
        push bc
        push hl
        call sprite_show
        pop hl
        pop bc
        ld a, (ix + BOSS.y)
        add a, 16
        ld e, a
        ld d, (ix + BOSS.pat)
        inc d
        ld a, (ix + BOSS.spr)
        inc a
        jp sprite_show

; One pixel along (dx, dy), bouncing off the edges of the floor.
boss_move:
        ld l, (ix + BOSS.x)
        ld h, (ix + BOSS.x + 1)
        ld a, (ix + BOSS.dx)
        ld e, a
        add a, a
        sbc a, a
        ld d, a
        add hl, de
        bit 7, h
        jr z, 1F
        ld hl, 0
        ld (ix + BOSS.dx), 1
1:      push hl
        ld de, JOE_MAX_X + 16 + 1
        or a
        sbc hl, de
        pop hl
        jr c, 1F
        ld hl, JOE_MAX_X + 16
        ld (ix + BOSS.dx), -1
1:      ld (ix + BOSS.x), l
        ld (ix + BOSS.x + 1), h
        ld a, (ix + BOSS.y)
        add a, (ix + BOSS.dy)
        cp JOE_MIN_Y
        jr nc, 1F
        ld (ix + BOSS.dy), 1
        ld a, JOE_MIN_Y
1:      cp JOE_MAX_Y + 1
        jr c, 1F
        ld (ix + BOSS.dy), -1
        ld a, JOE_MAX_Y
1:      ld (ix + BOSS.y), a
        ret

boss_new_direction:
        ld e, 3
        call rand_below
        dec a
        ld (ix + BOSS.dx), a
        ld e, 3
        call rand_below
        dec a
        ld (ix + BOSS.dy), a
        or (ix + BOSS.dx)
        jr nz, boss_turn_time
        ld (ix + BOSS.dx), 1
boss_turn_time:
        ld e, 64
        call rand_below
        add a, 40
        ld (ix + BOSS.turn), a
        ret

; Point dx at Joe (while telling off) or away from him (afterwards).
boss_face_joe:
        ld b, 1
        jr boss_face
boss_face_away:
        ld b, -1
boss_face:
        ld hl, (joe_x)
        ld e, (ix + BOSS.x)
        ld d, (ix + BOSS.x + 1)
        or a
        sbc hl, de                  ; carry: Joe is to the left
        ld a, b
        jr nc, 1F
        neg
1:      ld (ix + BOSS.dx), a
        ld (ix + BOSS.dy), 0
        jp boss_turn_time

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

; Chairman Fumduck facing right: big bushy silver hair, sunglasses, a
; million-dollar smile, pinstriped navy suit, red tie, a well-fed belly.
fum_top_rects:
        db 4, 3, 9, 11, COL_SKIN        ; head
        db 3, 0, 10, 4, COL_FUM_HAIR    ; bushy hair
        db 2, 1, 12, 3, COL_FUM_HAIR
        db 1, 3, 4, 7, COL_FUM_HAIR     ; and round the back
        db 12, 4, 2, 1, COL_FUM_HAIR
        db 8, 6, 6, 2, COL_BLACK        ; sunglasses
        db 5, 6, 3, 1, COL_BLACK
        db 13, 8, 1, 2, COL_SKIN        ; nose
        db 7, 10, 7, 3, COL_BLACK       ; the grin...
        db 8, 10, 5, 2, COL_WHITE       ; ...all teeth
        db 6, 14, 4, 1, COL_SKIN        ; neck
        db 3, 15, 10, 1, COL_FUM_SUIT   ; shoulders
        db 6, 15, 4, 1, COL_WHITE
        db 7, 15, 2, 1, COL_FUM_TIE
        db $FF
fum_bottom_rects:
        db 2, 0, 12, 10, COL_FUM_SUIT   ; jacket
        db 1, 2, 14, 6, COL_FUM_SUIT    ; belly
        db 5, 0, 1, 10, COL_FUM_STRIPE  ; pinstripes
        db 10, 0, 1, 10, COL_FUM_STRIPE
        db 6, 0, 4, 5, COL_WHITE        ; shirt
        db 7, 0, 2, 7, COL_FUM_TIE      ; tie
        db 0, 9, 2, 2, COL_SKIN         ; hands
        db 14, 9, 2, 2, COL_SKIN
        db 3, 10, 10, 4, COL_FUM_SUIT   ; trousers
        db 3, 14, 4, 2, COL_BLACK       ; shoes
        db 9, 14, 4, 2, COL_BLACK
        db $FF

knut_messages:
        dw knut_msg1, knut_msg2, knut_msg3
knut_msg1:  db "MR KNUT: OI! GET BACK TO WORK!", 0
knut_msg2:  db "MR KNUT: IS THIS WHAT I PAY YOU FOR?", 0
knut_msg3:  db "MR KNUT: YOU'RE ON THIN ICE, LAD!", 0

fumduck_messages:
        dw fum_msg1, fum_msg2, fum_msg3
fum_msg1:   db "FUMDUCK: MY YACHT WON'T PAY FOR ITSELF!", 0
fum_msg2:   db "FUMDUCK: LESS SLOUCHING, MORE SLOPPING!", 0
fum_msg3:   db "FUMDUCK: SMILE, JOE! WE'RE A FAMILY!", 0
