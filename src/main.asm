;=============================================================================
; Sloppy Seconds: a ZX Spectrum Next game
; Entry point, main loop and NEX output.
;=============================================================================

        DEVICE ZXSPECTRUMNEXT

        INCLUDE "constants.asm"

        org $8000

start:
        di
        ld sp, stack_top
        nextreg NR_TURBO, 3         ; 28 MHz
        xor a
        out (PORT_ULA), a           ; black border

        ; Page in the 48K ROM (for its font) and bank 0 at $C000.
        ld bc, $7FFD
        ld a, %00010000
        out (c), a
        ld bc, $1FFD
        ld a, %00000100
        out (c), a

        ; Clear the ULA screen to black, so nothing shows while Layer 2 is
        ; blanked between screens.
        ld hl, $4000
        ld de, $4001
        ld bc, 6912 - 1
        ld (hl), 0
        ldir

        call l2_init
        call sprites_init
        ld a, ST_TITLE
        call change_state

main_loop:
        call wait_frame
        call input_read
        call state_update
        jr main_loop

;-----------------------------------------------------------------------------
; Frame sync: busy-wait for the raster line just below the 320x256 area.
; (Interrupts are off; there's no IM2 handler yet.)
;-----------------------------------------------------------------------------
FRAME_SYNC_LINE     equ 224

wait_frame:
.leave:                             ; first make sure we're off the line...
        call read_raster_line
        cp FRAME_SYNC_LINE
        jr z, .leave
.arrive:                            ; ...then wait for it to come round
        call read_raster_line
        cp FRAME_SYNC_LINE
        jr nz, .arrive
        ld a, h
        or a
        jr nz, .arrive
        ret

; Returns HL = current raster line, A = L.
read_raster_line:
        ld bc, PORT_NEXTREG_SEL
        ld a, NR_LINE_MSB
        out (c), a
        inc b                       ; $253B
        in a, (c)
        and 1
        ld h, a
        dec b
        ld a, NR_LINE_LSB
        out (c), a
        inc b
        in a, (c)
        ld l, a
        ret

;-----------------------------------------------------------------------------
; Modules (macros are defined in layer2/text, so those come first)
;-----------------------------------------------------------------------------
        INCLUDE "layer2.asm"
        INCLUDE "text.asm"
        INCLUDE "sprites.asm"
        INCLUDE "util.asm"
        INCLUDE "input.asm"
        INCLUDE "levels.asm"
        INCLUDE "state.asm"
        INCLUDE "joe.asm"
        INCLUDE "pipes.asm"
        INCLUDE "tubs.asm"
        INCLUDE "hud.asm"
        INCLUDE "snacks.asm"
        INCLUDE "playing.asm"
        INCLUDE "screens.asm"
        INCLUDE "title.asm"

;-----------------------------------------------------------------------------
; Stack (code, data and stack must all stay in bank 2, $8000-$BFFF, because
; $C000 is used as a paging window for Layer 2)
;-----------------------------------------------------------------------------
                ds 256
stack_top:
        ASSERT stack_top <= $C000

;-----------------------------------------------------------------------------
; Output
;-----------------------------------------------------------------------------
        SAVENEX OPEN "build/sloppy.nex", start, stack_top
        SAVENEX CORE 3, 0, 0
        SAVENEX CFG 0
        SAVENEX AUTO
        SAVENEX CLOSE
