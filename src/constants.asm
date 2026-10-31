;-----------------------------------------------------------------------------
; Hardware constants: Next registers, I/O ports, colours
;-----------------------------------------------------------------------------

; --- Next registers (written with NEXTREG) ---
NR_TURBO            equ $07     ; CPU speed: 0=3.5 1=7 2=14 3=28 MHz
NR_L2_BANK          equ $12     ; Layer 2 first 16K bank
NR_GLOBAL_TRANS     equ $14     ; global transparency colour
NR_SPRITE_LAYERS    equ $15     ; sprite enable / layer order
NR_CLIP_L2          equ $18     ; Layer 2 clip window (4 writes)
NR_CLIP_SPRITES     equ $19     ; sprite clip window (4 writes)
NR_CLIP_CTRL        equ $1C     ; reset clip window indexes
NR_LINE_MSB         equ $1E     ; active video line (bit 0)
NR_LINE_LSB         equ $1F     ; active video line (bits 7-0)
NR_MMU6             equ $56     ; 8K page at $C000
NR_MMU7             equ $57     ; 8K page at $E000
NR_DISPLAY_CTRL1    equ $69     ; bit 7 = Layer 2 enable
NR_L2_CONTROL       equ $70     ; Layer 2 resolution / palette offset

; --- I/O ports ---
PORT_NEXTREG_SEL    equ $243B
PORT_NEXTREG_DATA   equ $253B
PORT_ULA            equ $FE     ; border (out), keyboard (in)
PORT_KEMPSTON       equ $1F
PORT_SPRITE_SLOT    equ $303B   ; select sprite / pattern index
PORT_SPRITE_ATTR    equ $57     ; sprite attribute upload (low byte only)
PORT_SPRITE_PATTERN equ $5B     ; sprite pattern upload (low byte only)

; --- Default 8-bit palette colours (RRRGGGBB) ---
; $E3 is the default transparent colour, so never use it for solid pixels.
COL_BLACK           equ $00
COL_WHITE           equ $FF
COL_YELLOW          equ $FC
COL_FLOOR           equ $49     ; dull factory grey-blue
COL_BELT_EDGE       equ $24
COL_BELT            equ $6D
COL_TRANSPARENT     equ $E3
COL_GREY            equ $92
COL_SKIN            equ $F6
COL_CAP             equ $8C
COL_OVERALLS        equ $0E
COL_RED_HOT         equ $E0
COL_PIPE_DARK       equ $64     ; rusty steel
COL_PIPE_LIGHT      equ $A8
COL_BAR_BG          equ $24
COL_CYNICISM        equ $E0

; --- Screen geometry (Layer 2 320x256, sprite coords match 1:1) ---
SCREEN_W            equ 320
SCREEN_H            equ 256
HUD_H               equ 16      ; cynicism bar + wages
BELT_Y              equ 216     ; top of conveyor belt area
