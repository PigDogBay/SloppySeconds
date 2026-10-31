;-----------------------------------------------------------------------------
; Music player: two voices on AY chip 1, melody on channel A and bass on
; channel B. Channel C is left for sound effects, and sfx_update writes the
; shared mixer register (it reads mus_mixer for the A/B bits).
;
; A tune is one byte stream per voice. Each byte is (duration << 5) | note.
; Note 0 is a rest, notes 1-30 are semitones from F4 (see mus_periods), and
; note 31 jumps back to the start (MUS_LOOP) or, with the longest
; duration, ends the tune and goes quiet (MUS_END). MUS_SEGNO marks where
; MUS_LOOP goes back to (by default, the start). Each voice has a pitch shift
; (in octaves) and a simple pluck envelope: start loud, fade to a floor.
; Every note goes quiet for its last frames so repeated notes don't blur.
;-----------------------------------------------------------------------------

        STRUCT VOICE
ptr         WORD 0
start       WORD 0
timer       BYTE 0
volume      BYTE 0      ; 4.4 fixed point
attack      BYTE 0      ; volume at the start of a note
decay       BYTE 0      ; 16ths per frame
floor       BYTE 0
shift       BYTE 0      ; octaves down
tone_reg    BYTE 0
vol_reg     BYTE 0
        ENDS

MUS_LOOP            equ 31
MUS_END             equ $FF
MUS_SEGNO           equ (1 << 5) | 31
MUS_GAP             equ 2               ; silent frames at the end of a note

; Durations at 150 bpm (frames)
D16                 equ 0 << 5          ; 5
D8                  equ 1 << 5          ; 10
D8D                 equ 2 << 5          ; 15 (dotted eighth)
D4                  equ 3 << 5          ; 20
D4D                 equ 4 << 5          ; 30
D2                  equ 5 << 5          ; 40
D2D                 equ 6 << 5          ; 60
D1                  equ 7 << 5          ; 80

mus_durations:      db 5, 10, 15, 20, 30, 40, 60, 80
mus_durations_slow: db 6, 12, 18, 24, 36, 48, 72, 96     ; 125 bpm

; Notes: semitones from F4 (index 1). Shift down two octaves for the bass.
R                   equ 0
F4  equ 1
FS4 equ 2
G4  equ 3
GS4 equ 4
A4  equ 5
AS4 equ 6
B4  equ 7
C5  equ 8
CS5 equ 9
D5  equ 10
DS5 equ 11
E5  equ 12
F5  equ 13
FS5 equ 14
G5  equ 15
GS5 equ 16
A5  equ 17
AS5 equ 18
B5  equ 19
C6  equ 20
CS6 equ 21
D6  equ 22
DS6 equ 23
E6  equ 24
F6  equ 25
FS6 equ 26
G6  equ 27
GS6 equ 28
A6  equ 29
AS6 equ 30
; Bass names (played two octaves down)
F2  equ F4
FS2 equ FS4
G2  equ G4
A2  equ A4
AS2 equ AS4
B2  equ B4
C3  equ C5
CS3 equ CS5
D3  equ D5
E3  equ E5
F3  equ F5
FS3 equ FS5
G3  equ G5
A3  equ A5

; AY tone periods for F4..AS6 (109375 / Hz)
mus_periods:
        dw 313, 296, 279, 263, 249, 235, 222, 209, 197, 186
        dw 176, 166, 157, 148, 140, 132, 124, 117, 111, 105
        dw 99, 93, 88, 83, 78, 74, 70, 66, 62, 59

; A tune header: melody stream, bass stream, durations table, then the
; melody's decay and floor (its "instrument").
        MACRO TUNE p1, p2, p3, p4, p5     ; melody, bass, durations, decay, floor
        dw p1, p2, p3
        db p4, p5
        ENDM

; HL = tune header.
music_start:
        ld de, mus_tune
        ld bc, 8
        ldir
        ld ix, mus_voices
        ld hl, (mus_tune)
        ld de, $0008                ; tone reg 0, volume reg 8
        ld a, (mus_tune + 6)
        ld c, a
        ld b, $D0                   ; attack
        call .voice
        ld a, (mus_tune + 7)
        ld (ix + VOICE.floor), a
        ld ix, mus_voices + VOICE
        ld hl, (mus_tune + 2)
        ld de, $0209                ; tone reg 2, volume reg 9
        ld bc, $C00C                ; plucky
        call .voice
        ld (ix + VOICE.shift), 2    ; two octaves down
        ld a, $3C                   ; tone A and B on
        ld (mus_mixer), a
        ld a, 1
        ld (mus_playing), a
        ret
; IX = voice, HL = stream, D/E = tone/volume registers, B/C = attack/decay.
.voice:
        ld (ix + VOICE.ptr), l
        ld (ix + VOICE.ptr + 1), h
        ld (ix + VOICE.start), l
        ld (ix + VOICE.start + 1), h
        ld (ix + VOICE.tone_reg), d
        ld (ix + VOICE.vol_reg), e
        ld (ix + VOICE.attack), b
        ld (ix + VOICE.decay), c
        ld (ix + VOICE.floor), 0
        ld (ix + VOICE.shift), 0
        ld (ix + VOICE.volume), 0
        ld (ix + VOICE.timer), 1
        ret

music_stop:
        xor a
        ld (mus_playing), a
        ld a, $3F
        ld (mus_mixer), a
        ld de, $0800
        call ay_write
        inc d
        jp ay_write

music_update:
        ld a, (mus_playing)
        or a
        ret z
        ld ix, mus_voices
        call mus_voice
        ld ix, mus_voices + VOICE
        ; fall through

; One frame for the voice at IX.
mus_voice:
        dec (ix + VOICE.timer)
        jr nz, .sustain

        ; Next note
        ld l, (ix + VOICE.ptr)
        ld h, (ix + VOICE.ptr + 1)
        ld a, (hl)
        cp MUS_END
        jr z, .ended
        cp MUS_SEGNO
        jr nz, 2F
        inc hl                      ; loop back to just after here
        ld (ix + VOICE.start), l
        ld (ix + VOICE.start + 1), h
        jr 1F
2:      cp MUS_LOOP
        jr nz, 1F
        ld l, (ix + VOICE.start)
        ld h, (ix + VOICE.start + 1)
1:      ld a, (hl)
        inc hl
        ld (ix + VOICE.ptr), l
        ld (ix + VOICE.ptr + 1), h
        ld c, a
        rlca                        ; duration = top 3 bits
        rlca
        rlca
        and 7
        ld hl, (mus_tune + 4)       ; this tune's durations
        add hl, a
        ld a, (hl)
        ld (ix + VOICE.timer), a
        ld a, c
        and $1F
        ld (ix + VOICE.volume), a   ; 0 for a rest
        jr z, .output
        dec a                       ; HL = period << shift
        add a, a
        ld hl, mus_periods
        add hl, a
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        ld b, (ix + VOICE.shift)
        inc b
        jr .shift_test
.shift:
        add hl, hl
.shift_test:
        djnz .shift
        ld d, (ix + VOICE.tone_reg)
        ld e, l
        call ay_write
        inc d
        ld e, h
        call ay_write
        ld a, (ix + VOICE.attack)
        ld (ix + VOICE.volume), a
        jr .output

.ended:                             ; stay on MUS_END, silent
        ld (ix + VOICE.timer), 1
        xor a
        ld (ix + VOICE.volume), a
        jr .output

.sustain:
        ld a, (ix + VOICE.volume)
        or a
        jr z, .output               ; a rest
        sub (ix + VOICE.decay)
        jr c, 1F
        cp (ix + VOICE.floor)
        jr nc, 2F
1:      ld a, (ix + VOICE.floor)
2:      ld (ix + VOICE.volume), a

.output:
        ld a, (ix + VOICE.timer)
        cp MUS_GAP + 1
        ld a, 0
        jr c, 1F                    ; the gap at the end of the note
        ld a, (ix + VOICE.volume)
        rrca
        rrca
        rrca
        rrca
        and $0F
1:      ld e, a
        ld d, (ix + VOICE.vol_reg)
        jp ay_write

;-----------------------------------------------------------------------------
; "Sloppy Seconds" theme: a bouncy 16-bar tune in C, 150 bpm, with an
; oom-pah bass. Chords: C C F C | D7 G7 C G7 | F F C A7 | Dm G7 C C
;-----------------------------------------------------------------------------
theme_melody:
        db D8D|G4, D16|C5, D8|E5, D8|G5, D4|E5, D8|C5, D8|E5            ; C
        db D4|G5, D8|A5, D8|G5, D4|E5, D4|C5                            ; C
        db D8|F5, D8|A5, D8|C6, D8|A5, D4|F5, D4|A5                     ; F
        db D4D|G5, D8|E5, D4|C5, D4|R                                   ; C
        db D8D|FS5, D16|G5, D8|A5, D8|FS5, D4|D5, D8|A5, D8|C6          ; D7
        db D4|B5, D8|A5, D8|G5, D8|F5, D8|D5, D4|B4                     ; G7
        db D8|C5, D8|E5, D8|G5, D8|C6, D4|E6, D4|C6                     ; C
        db D8|B5, D8|A5, D8|G5, D8|F5, D2|D5                            ; G7
        db D4|A5, D8|A5, D8|AS5, D4|C6, D4|A5                           ; F
        db D8D|C6, D16|AS5, D8|A5, D8|G5, D2|F5                         ; F
        db D4|G5, D8|G5, D8|A5, D4|G5, D4|E5                            ; C
        db D8|A5, D8|CS6, D8|E6, D8|CS6, D4|A5, D4|G5                   ; A7
        db D4|F5, D8|E5, D8|F5, D4|A5, D4|D6                            ; Dm
        db D8D|B5, D16|A5, D8|G5, D8|F5, D4|G5, D4|B5                   ; G7
        db D8|C6, D8|G5, D8|E5, D8|C5, D8|D5, D8|E5, D8|F5, D8|FS5      ; C
        db D4|G5, D8|R, D8|G5, D4|C6, D4|R                              ; C
        db MUS_LOOP

theme_bass:
        db D4|C3, D4|G3, D4|G2, D4|G3                                   ; C
        db D4|C3, D4|G3, D4|G2, D4|G3                                   ; C
        db D4|F2, D4|C3, D4|A2, D4|C3                                   ; F
        db D4|C3, D4|G3, D4|G2, D4|G3                                   ; C
        db D4|D3, D4|A3, D4|A2, D4|FS3                                  ; D7
        db D4|G2, D4|D3, D4|B2, D4|F3                                   ; G7
        db D4|C3, D4|G3, D4|E3, D4|G3                                   ; C
        db D4|G2, D4|D3, D4|B2, D4|D3                                   ; G7
        db D4|F2, D4|C3, D4|A2, D4|C3                                   ; F
        db D4|F2, D4|C3, D4|A2, D4|C3                                   ; F
        db D4|C3, D4|G3, D4|G2, D4|G3                                   ; C
        db D4|A2, D4|E3, D4|CS3, D4|G3                                  ; A7
        db D4|D3, D4|A3, D4|F3, D4|A3                                   ; Dm
        db D4|G2, D4|D3, D4|B2, D4|F3                                   ; G7
        db D4|C3, D4|G3, D4|E3, D4|G3                                   ; C
        db D4|C3, D4|G2, D4|C3, D4|R                                    ; C
        db MUS_LOOP

;-----------------------------------------------------------------------------
; "Clocking on" jingle for the start of each day: up the C chord, then
; F - G - C. Plays once.
;-----------------------------------------------------------------------------
jingle_melody:
        db D8|G4, D8|C5, D8|E5, D8|G5, D4|E5, D4|G5
        db D8|F5, D8|A5, D8|B5, D8|D6, D2|C6
        db MUS_END
jingle_bass:
        db D4|C3, D4|G3, D4|E3, D4|G3
        db D4|F2, D4|G2, D2|C3
        db MUS_END

;-----------------------------------------------------------------------------
; Retirement: a chirpy fanfare, a pause, then Chopin's funeral march (in
; B flat minor, at half speed: every note value is doubled), looping.
;-----------------------------------------------------------------------------
retire_melody:
        db D16|C6, D16|D6, D16|E6, D16|G6, D8|E6, D8|C6, D8|D6, D8|E6, D4|C6
        db D8|G5, D8|A5, D8|B5, D8|D6, D4|C6, D4|R
        db D2|R
        db MUS_SEGNO
        db D2|AS4, D4D|AS4, D8|AS4, D1|AS4
        db D4D|CS5, D8|C5, D4D|C5, D8|AS4, D4D|AS4, D8|A4, D2|AS4
        db D2|AS4, D4D|AS4, D8|AS4, D1|AS4
        db D4D|CS5, D8|C5, D4D|C5, D8|AS4, D4D|AS4, D8|A4, D2|AS4
        db MUS_LOOP
retire_bass:
        db D8|C3, D8|G3, D8|E3, D8|G3, D8|C3, D8|G3, D8|E3, D8|G3
        db D4|F3, D4|G3, D4|C3, D4|R
        db D2|R
        db MUS_SEGNO
        db D2|AS2, D2|FS2, D2|AS2, D2|FS2
        db D2|AS2, D2|FS2, D2|AS2, D2|FS2
        db D2|AS2, D2|FS2, D2|AS2, D2|FS2
        db D2|AS2, D2|FS2, D2|AS2, D2|FS2
        db MUS_LOOP

;-----------------------------------------------------------------------------
; Beach: a laid-back calypso in F at 125 bpm. Steel-pan melody (quick fade)
; over a 3-3-2 bass. Chords: F C7 C7 F | Bb F C7 F
;-----------------------------------------------------------------------------
beach_melody:
        db D8|C6, D4|A5, D8|F5, D8|R, D8|A5, D8|C6, D8|D6               ; F
        db D4D|C6, D4D|AS5, D4|G5                                       ; C7
        db D8|E5, D4|G5, D8|AS5, D8|R, D8|AS5, D8|A5, D8|G5             ; C7
        db D4D|A5, D4D|F5, D4|R                                         ; F
        db D8|D6, D4|D6, D8|D6, D8|R, D8|C6, D8|AS5, D8|A5              ; Bb
        db D4D|C6, D4D|A5, D4|F5                                        ; F
        db D8|G5, D4|AS5, D8|A5, D8|G5, D8|E5, D4|G5                    ; C7
        db D4D|F5, D8|C5, D2|F5                                         ; F
        db MUS_LOOP
beach_bass:
        db D4D|F2, D4D|C3, D4|F3                                        ; F
        db D4D|C3, D4D|G3, D4|AS2                                       ; C7
        db D4D|C3, D4D|G2, D4|E3                                        ; C7
        db D4D|F2, D4D|C3, D4|A2                                        ; F
        db D4D|AS2, D4D|F3, D4|D3                                       ; Bb
        db D4D|F2, D4D|C3, D4|F3                                        ; F
        db D4D|C3, D4D|G3, D4|E3                                        ; C7
        db D4D|F2, D4D|C3, D4|F2                                        ; F
        db MUS_LOOP

tune_theme:     TUNE theme_melody, theme_bass, mus_durations, $05, $80
tune_jingle:    TUNE jingle_melody, jingle_bass, mus_durations, $05, $80
tune_retire:    TUNE retire_melody, retire_bass, mus_durations, $05, $80
tune_beach:     TUNE beach_melody, beach_bass, mus_durations_slow, $0A, $30

mus_tune:       ds 8                ; the current tune's header
mus_voices:     ds VOICE * 2
mus_playing:    db 0
mus_mixer:      db $3F              ; mixer bits for A/B (C added by sfx)
