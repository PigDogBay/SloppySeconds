;-----------------------------------------------------------------------------
; Level table: one record per level. Gameplay code should read these
; values, not test the level number.
;
; Quota = number of full buckets deposited into the matching-colour tub.
; Speeds are placeholders (frames between ooze steps / pixels per frame);
; tune them during play-testing.
;-----------------------------------------------------------------------------

LVF_COCKROACH       equ %00000001
LVF_KNUT            equ %00000010
LVF_FUMDUCK         equ %00000100

        STRUCT LEVEL
pipes       BYTE 0
colours     BYTE 0      ; also the number of tub types
quota       BYTE 0
ooze_delay  BYTE 0      ; frames per ooze step (lower = faster)
belt_speed  BYTE 0      ; pixels per frame, right to left
flags       BYTE 0      ; LVF_*
day         WORD 0      ; day of the week, shown instead of "level N"
name        WORD 0      ; 0-terminated name
desc        WORD 0      ; intro text, lines separated by 13
        ENDS

LEVEL_COUNT         equ 5

levels:
        LEVEL { 2, 2,  5, 12, 1, 0,                                  day_mon, lvl1_name, lvl1_desc }
        LEVEL { 4, 3,  6, 11, 1, 0,                                  day_tue, lvl2_name, lvl2_desc }
        LEVEL { 4, 4, 10, 10, 1, LVF_COCKROACH,                      day_wed, lvl3_name, lvl3_desc }
        LEVEL { 4, 5, 10, 9, 1, LVF_COCKROACH|LVF_KNUT,             day_thu, lvl4_name, lvl4_desc }
        LEVEL { 6, 7, 15, 8, 2, LVF_COCKROACH|LVF_KNUT|LVF_FUMDUCK, day_fri, lvl5_name, lvl5_desc }
        ASSERT $ - levels == LEVEL_COUNT * LEVEL

day_mon:    db "MONDAY", 0
day_tue:    db "TUESDAY", 0
day_wed:    db "WEDNESDAY", 0
day_thu:    db "THURSDAY", 0
day_fri:    db "FRIDAY", 0

lvl1_name:  db "APPRENTICESHIP", 0
lvl1_desc:  db "TWO PIPES. RED AND BLUE SLOP.", 13
            db "TAKE IT EASY, LAD.", 0
lvl2_name:  db "GET ON WITH IT!", 0
lvl2_desc:  db "FOUR PIPES, THREE COLOURS.", 13
            db "THE SLOP'S COMING FASTER.", 0
lvl3_name:  db "EL STOMPO", 0
lvl3_desc:  db "FOUR COLOURS - AND COCKROACHES!", 13
            db "WALK UP TO THEM AND STOMP WITH FIRE.", 0
lvl4_name:  db "MEET MR KNUT", 0
lvl4_desc:  db "FIVE COLOURS. THE MANAGER IS ABOUT.", 13
            db "DON'T BUMP INTO MR KNUT.", 0
lvl5_name:  db "KNACKERED", 0
lvl5_desc:  db "SIX PIPES, SEVEN COLOURS, FAST BELT.", 13
            db "CHAIRMAN FUMDUCK IS ON THE FLOOR.", 0

; Append the current level's day name to strbuf.
str_append_day:
        call get_level_ptr
        ld l, (ix + LEVEL.day)
        ld h, (ix + LEVEL.day + 1)
        jp str_append
