;-----------------------------------------------------------------------------
; Sound effects on the AY (chip 1, channel C; A and B are left for music).
;
; One effect plays at a time. sfx_play starts one unless a higher-priority
; effect is still playing. sfx_update runs once a frame from main_loop.
;
; An effect is a list of segments (SFX_SEG), ended by SFX_END. Each segment
; holds a tone period and volume for a number of frames, sliding the period
; by dperiod and fading the volume by decay (in 1/16ths) every frame.
; Tone period = 109375 / Hz (the AY runs at 1.75 MHz).
;-----------------------------------------------------------------------------

PORT_AY_REG         equ $FFFD
PORT_AY_DATA        equ $BFFD

SFX_DRIP            equ 0               ; slop leaves a pipe
SFX_SPLAT           equ 1               ; slop hits the floor
SFX_BANG            equ 2               ; pipe banged
SFX_CATCH           equ 3               ; slop caught: the bucket's full
SFX_DEPOSIT         equ 4               ; right tub
SFX_WRONG           equ 5               ; wrong tub
SFX_STOMP           equ 6
SFX_KNUT            equ 7
SFX_SNACK           equ 8

; frames, period, dperiod (per frame), volume 0-15, decay (16ths per frame),
; noise period (0 = none), notone (1 = noise only)
        MACRO SFX_SEG frames, period, dperiod, vol, decay, noise, notone
        db frames
        dw period, dperiod
        db vol * 16, decay, noise | (notone << 7)
        ENDM
        MACRO SFX_END
        db 0
        ENDM

; D = AY register, E = value. Uses BC.
ay_write:
        ld bc, PORT_AY_REG
        out (c), d
        ld b, high PORT_AY_DATA
        out (c), e
        ret

sfx_init:
        ld bc, PORT_AY_REG
        ld a, $FF                   ; select AY 1, both stereo sides
        out (c), a
        xor a
        ld (sfx_frames), a
        ld de, $073F                ; mixer: everything off
        call ay_write
        ld de, $0800                ; all volumes 0
        call ay_write
        inc d
        call ay_write
        inc d
        jp ay_write

; A = SFX_* to play.
sfx_play:
        ld e, a
        ld hl, sfx_priorities
        add hl, a
        ld a, (sfx_frames)
        or a
        ld a, (hl)
        jr z, .go                   ; nothing playing
        ld hl, sfx_priority
        cp (hl)
        ret c                       ; something more important is playing
.go:
        ld (sfx_priority), a
        ld a, e
        add a, a
        ld hl, sfx_effects
        add hl, a
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        ; fall through

; Start the segment at HL (frames = 0 means the effect has ended).
sfx_load:
        ld a, (hl)
        ld (sfx_frames), a
        or a
        ret z
        inc hl
        ld de, sfx_period
        ld bc, 7
        ldir
        ld (sfx_next), hl
        ret

sfx_update:
        ld a, (sfx_frames)
        or a
        jr nz, .play
        ld de, $0A00                ; silence channel C
        call ay_write
        ld a, (mus_mixer)
        ld e, a
        ld d, 7
        jp ay_write
.play:
        ld a, (sfx_period)
        ld e, a
        ld d, 4
        call ay_write
        ld a, (sfx_period + 1)
        and $0F
        ld e, a
        inc d
        call ay_write
        ld a, (sfx_volume)
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld e, a
        ld d, 10
        call ay_write

        ld a, (mus_mixer)           ; mixer: music's A/B bits, C off
        ld l, a
        ld a, (sfx_mix)
        bit 7, a
        jr nz, 1F
        res 2, l                    ; tone C on
1:      and $1F
        jr z, 1F
        ld e, a
        ld d, 6
        call ay_write               ; noise period
        res 5, l                    ; noise C on
1:      ld e, l
        ld d, 7
        call ay_write

        ; Slide the pitch, fade the volume
        ld hl, (sfx_period)
        ld de, (sfx_dperiod)
        add hl, de
        ld (sfx_period), hl
        ld a, (sfx_decay)
        ld b, a
        ld a, (sfx_volume)
        sub b
        jr nc, 1F
        xor a
1:      ld (sfx_volume), a

        ld hl, sfx_frames
        dec (hl)
        ret nz
        ld hl, (sfx_next)
        jp sfx_load

sfx_priorities:
        db 1, 2, 2, 3, 4, 4, 3, 5, 3
sfx_effects:
        dw sfx_drip, sfx_splat, sfx_bang, sfx_catch, sfx_deposit
        dw sfx_wrong, sfx_stomp, sfx_knut, sfx_snack

sfx_drip:                                       ; a rising "plip"
        SFX_SEG 5, 220, -24, 8, $18, 0, 0
        SFX_END
sfx_splat:                                      ; a low, noisy splodge
        SFX_SEG 12, 700, 40, 13, $14, 20, 0
        SFX_END
sfx_bang:                                       ; a clank, then the pipe rings
        SFX_SEG 2, 0, 0, 15, 0, 3, 1
        SFX_SEG 16, 190, 1, 14, $0E, 0, 0
        SFX_END
sfx_catch:                                      ; a gloop, then a ding: full!
        SFX_SEG 4, 320, -45, 12, $10, 0, 0
        SFX_SEG 2, 0, 0, 0, 0, 0, 0
        SFX_SEG 12, 110, 0, 13, $14, 0, 0
        SFX_END
sfx_deposit:                                    ; C-E-G-C arpeggio
        SFX_SEG 4, 209, 0, 13, 0, 0, 0
        SFX_SEG 4, 166, 0, 13, 0, 0, 0
        SFX_SEG 4, 140, 0, 13, 0, 0, 0
        SFX_SEG 16, 104, 0, 13, $0C, 0, 0
        SFX_END
sfx_wrong:                                      ; a low double buzz
        SFX_SEG 10, 1000, 0, 14, 0, 0, 0
        SFX_SEG 4, 0, 0, 0, 0, 0, 0
        SFX_SEG 16, 1100, 0, 14, $0A, 0, 0
        SFX_END
sfx_stomp:                                      ; crunch and squish
        SFX_SEG 3, 0, 0, 15, 0, 31, 1
        SFX_SEG 10, 1200, 60, 13, $18, 24, 0
        SFX_END
sfx_knut:                                       ; "OI!": a loud, falling honk
        SFX_SEG 6, 260, 0, 15, 0, 0, 0
        SFX_SEG 18, 260, 14, 15, $0C, 0, 0
        SFX_END
sfx_snack:                                      ; the vending machine "ching"
        SFX_SEG 3, 120, 0, 12, 0, 0, 0
        SFX_SEG 12, 80, 0, 12, $10, 0, 0
        SFX_END

sfx_frames:     db 0
sfx_priority:   db 0
sfx_next:       dw 0
sfx_period:     dw 0                ; these seven are loaded from a segment
sfx_dperiod:    dw 0
sfx_volume:     db 0                ; 4.4 fixed point
sfx_decay:      db 0
sfx_mix:        db 0
