;-----------------------------------------------------------------------------
; Input: keyboard QAOP + Space, merged with a Kempston joystick.
;
; `input`     = buttons held this frame (1 = held)
; `input_new` = buttons that went down this frame (use for menus/actions)
;
; Bits 0-4 match the Kempston layout. BREAK is Caps Shift + Space, and
; pressing it does not also count as fire.
;-----------------------------------------------------------------------------

INPUT_RIGHT         equ 0
INPUT_LEFT          equ 1
INPUT_DOWN          equ 2
INPUT_UP            equ 3
INPUT_FIRE          equ 4
INPUT_BREAK         equ 5
INPUT_DEBUG1        equ 6               ; key 1 (temporary debug)
INPUT_DEBUG2        equ 7               ; key 2 (temporary debug)

input_read:
        ld e, 0

        ld a, $FB                   ; Q W E R T
        in a, (PORT_ULA)
        bit 0, a                    ; Q
        jr nz, 1F
        set INPUT_UP, e
1:
        ld a, $FD                   ; A S D F G
        in a, (PORT_ULA)
        bit 0, a                    ; A
        jr nz, 1F
        set INPUT_DOWN, e
1:
        ld a, $DF                   ; P O I U Y
        in a, (PORT_ULA)
        bit 1, a                    ; O
        jr nz, 1F
        set INPUT_LEFT, e
1:
        bit 0, a                    ; P
        jr nz, 1F
        set INPUT_RIGHT, e
1:
        ld a, $7F                   ; SPACE SYM M N B
        in a, (PORT_ULA)
        bit 0, a                    ; SPACE
        jr nz, .no_space
        ld a, $FE                   ; CAPS Z X C V
        in a, (PORT_ULA)
        bit 0, a                    ; CAPS SHIFT
        jr nz, .fire
        set INPUT_BREAK, e
        jr .no_space
.fire:
        set INPUT_FIRE, e
.no_space:
        ld a, $F7                   ; 1 2 3 4 5
        in a, (PORT_ULA)
        bit 0, a
        jr nz, 1F
        set INPUT_DEBUG1, e
1:
        bit 1, a
        jr nz, 1F
        set INPUT_DEBUG2, e
1:
        in a, (PORT_KEMPSTON)
        ld d, a
        and %11100000               ; floating bus / no joystick: ignore
        jr nz, 1F
        ld a, d
        or e
        ld e, a
1:
        ld a, (input)               ; previous frame
        cpl
        and e
        ld (input_new), a
        ld a, e
        ld (input), a
        ret

input:          db 0
input_new:      db 0
