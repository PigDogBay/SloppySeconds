# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Sloppy Seconds** is a ZX Spectrum Next game written in **Z80N assembly** and assembled with **sjasmplus** into a single `.nex` file.
- `description.txt`: the full game spec (story, levels, graphics, sounds, controls, screen flow). It's the source of truth, so re-read it before designing features.
- `GameLayout.jpeg`: a hand-drawn sketch of the main game screen.

## Commands

```sh
make          # assemble src/main.asm -> build/sloppy.nex (+ .lst listing, .sld for DeZog)
make run      # build, then launch in ZEsarUX (TBBlue machine, fast boot, --snap the .nex)
make clean
make RELEASE=1   # build without the test keys
```

There are no automated tests. To verify a change, build it with zero warnings, check addresses and bytes in `build/sloppy.lst`, then launch `make run` (in the background, since the GUI stays open) and ask the user what they see. Claude can't see the emulator window. `make run` was confirmed working on 2026-10-31.

## Code architecture

- `src/main.asm` is the only file passed to sjasmplus. It `INCLUDE`s every other module and ends with the `SAVENEX` block that writes the `.nex`. Add new modules there.
- Code, data and stack all live at `$8000-$BFFF` (bank 2), and an `ASSERT` enforces that. **MMU6 (`$C000`) is used as a paging window** for drawing into Layer 2, so nothing may live there. Code that pages MMU6 must restore it to `MMU6_DEFAULT`.
- **Layer 2 is 320x256 in 16K bank 9** (8K pages 18–27). Its memory is **column-major**: byte = `x*256 + y`, and each 8K page holds 32 columns.
- Sprites are set to show over the border, so **sprite coordinates equal Layer 2 pixel coordinates** (0–319, 0–255). Colours use the default RRRGGGBB palette, where `$E3` is transparent. Blue has only 2 bits, so `$DB` comes out lavender rather than grey; use `$B6` or `$DA` for neutral or warm greys.
- Frame timing: interrupts are off (`di`). `wait_frame` polls the raster line (Next registers `$1E`/`$1F`) for line 224, just below the 320x256 area. If music or AY sound effects need a steady tick, add an IM2 handler.
- Input: `input_read` merges QAOP + Space with Kempston into one byte, `input`, using the Kempston bit layout (`INPUT_*` bit numbers).
- Levels are **data-driven**. `src/levels.asm` has a `LEVEL` struct table holding pipes, colours, quota, ooze delay, belt speed, enemy flags (`LVF_*`) and a name pointer. Gameplay should read this table and never branch on the level number. The speed values are placeholders to tune.
- **State machine** (`src/state.asm`): each `ST_*` state has an `*_enter` routine (called once by `change_state`, draws the screen) and an `*_update` routine (called every frame from `main_loop`). To switch state from an update routine, use `ld a, ST_x` / `jp change_state`. Full-screen redraws are wrapped in `screen_begin` / `screen_end`, which blank Layer 2 and hide sprites. Resuming from pause sets `game_state` directly so the level isn't reset. The title screen is in `src/title.asm`: the Sideways factory scene, loosely based on the user's `Factory.jpeg` photo of the incinerator, with Joe walking into the loading bay. The beach game-over scene (sky, sun, gulls, sea, palm and cocktail) is in `src/beach.asm`. The retirement ending (a gold clock with its 99p price tag on a plinth, with no caption, and a headstone reading R.I.P. JOE, under a dusk sky with no moon) is in `src/retire.asm`. The other screens are in `src/screens.asm`; PLAYING and PAUSED are in `src/playing.asm`.
- **Text** (`src/text.asm`): uses the 48K ROM font at `$3D00`, which `start` pages in through ports `$7FFD`/`$1FFD` (confirmed rendering in ZEsarUX on 2026-10-31). Swap `FONT_BASE` to use a custom font. `TEXT x,y,colour,scale` sets the style (scale 1 or 2). `print_centred` handles lines separated by 13. Build strings that contain numbers with `str_start` / `str_append` / `str_append_u8` into `strbuf`. The `FILL_RECT` and `HALF_DISC` macros are in `layer2.asm`. `HALF_DISC` draws a flat-bottomed half circle, optionally with a window-pane grid, for arches, trees and clouds. `HALF_DISC_DOWN` draws the flat-topped half, and `DISC` draws a full circle. **For new scenes, prefer shape lists** (`S_RECT` / `S_HALF` / `S_HALF_DOWN` / `S_DISC` / `S_END` data drawn by `draw_shapes`): about 7 bytes per shape against about 23 for a `FILL_RECT` macro. `retire.asm` uses them; converting `title.asm` and `beach.asm` would free roughly 2K. Macros must be defined before use, so keep `layer2.asm` and `text.asm` early in the include list.
- Input exposes `input` (held) and `input_new` (pressed this frame). Use `input_new` for menus and actions. BREAK is Caps Shift + Space and doesn't count as fire.
- **Gameplay modules:** `joe.asm` (movement, bucket), `pipes.asm` (each pipe cycles WAIT → OOZE → FALL → SPLAT), `tubs.asm` (5 tubs on a 400px belt loop moving right to left; the colour cycles on wrap), `hud.asm` (`add_cynicism` / `add_wages` set `hud_dirty` bits, and `hud_update` redraws only what changed) and `playing.asm` (the per-frame order, fire handling and win/lose checks). `level_load` copies the current `LEVEL` record into the `cur_*` variables, and gameplay reads those.
- **Gameplay rules** (tunable constants):
  - **One drop fills the bucket** (`BUCKET_CAPACITY` = 1, set by the user).
  - **A full bucket empties automatically when it touches a tub**, with no button (set by the user). The check runs every frame after the belt moves.
  - Fire only bangs pipes.
  - Drops that hit a full bucket fall through it.
  - Touching a wrong-colour tub loses the slop without counting.
  - Each missed drop adds `CYNICISM_MISS` = 4.
  - Wages: catch 1p, bang 1p, correct tub 10p.
  - Cynicism resets to 0 at the start of each level.
  - **Snacks** (`snacks.asm`): one at a time, every 5–10 s, on the half of the floor away from Joe. Each **lasts 5 s** (user's choice) and flashes for the last 1.5 s. Coffee −20, chocolate −30, apple −16 cynicism. **Snacks cost wages** (user's choice): coffee 5p, chocolate 8p, apple 4p, via `sub_wages`, which stops at 0. Use `sub_cynicism` to lower cynicism (it stops at 0).
  - **Cockroaches** (`roaches.asm`, on levels with `LVF_COCKROACH`, which `level_load` copies into `cur_flags`): up to 3 come in from the sides every 6–11 s and wander the floor. Each adds 1 cynicism every 2 s. Fire with one at Joe's feet stomps it for 2p. Fire handling is in `joe_fire`: stomp first, otherwise bang a pipe.
  - **Mr Knut** (`knut.asm`, `LVF_KNUT`): walks in 3 s into the level and wanders slowly. Bumping into him freezes Joe for 3 s (`joe_frozen` blocks movement and fire), adds 10 cynicism, and shows his line in the status bar through `hud_message`. After that Joe has 2 s of grace.
  - Sprite patterns can be built from compact rect lists with `pat_build_list` (5 bytes per rect); Mr Knut uses them.
- **Sound** (`src/sound.asm`): sound effects play on AY chip 1, channel C. Channels A and B, and AY chips 2 and 3, are free for music. Call `ld a, SFX_x` / `call sfx_play`. Each effect is a list of `SFX_SEG` segments (period, slide, volume, fade, noise) with a priority, and `sfx_update` runs every frame from `main_loop`. **Music** (`src/music.asm`): a two-voice player (melody on A, bass on B) that reads byte streams, one byte per note, `(duration<<5)|note`. `MUS_LOOP` jumps back to the start, `MUS_END` ends a one-shot tune, and `MUS_SEGNO` sets where `MUS_LOOP` returns to, for an intro followed by a looping section. `music_start` takes HL = a `TUNE` header (melody, bass, durations table, melody decay and floor). Note that sjasmplus macro parameters are substituted inside underscore-separated label parts, so use names like `p1` for them. `change_state` calls `music_stop`, so each screen's `*_enter` starts its own tune with `music_start`. Tunes so far: the title theme (an original 16-bar tune in C at 150 bpm) the two-bar "clocking on" jingle played on the level intro, the retirement music (a chirpy fanfare, then Chopin's funeral march at half speed, looping), and an original laid-back calypso in F at 125 bpm (`mus_durations_slow`) with a steel-pan-like quick fade for the beach game-over screen. `sfx_update` writes the shared mixer register (R7) using `mus_mixer`. Code now ends around `$BA92`, about 1.4K free, so the other tunes will need another bank.
- **Sprites:** the placeholder patterns are drawn in code (`PAT_RECT` into `pat_buf`, then `pat_upload`). `PAT_*` and `SPR_*` slot constants are in `sprites.asm`, and higher sprite slots draw on top. The bucket pattern is rebuilt whenever its contents change. Slop colour index → palette colour is in the `slop_colours` table.
- **Memory is getting tight:** everything sits in bank 2 (`$8000-$BFFF`), and as of the beach screen the code ends around `$B0xx`, leaving about 4K. Before adding large things (music, more screens), plan to move data or code into other banks.
- The `IX`/`IY` registers are used freely (interrupts are off, so the ROM never needs `IY`). The pipe loops use IX = runtime `PIPE` record and IY = static `pipe_slots` geometry.
- Test keys are on by default: **N** finishes the level and **2** maxes out cynicism (Joe quits). `make RELEASE=1` leaves them out (`IFNDEF RELEASE` in `playing_update`).

## Toolchain (macOS arm64, under `/Users/mark/work/Next/tools/`)

None of these tools are on `PATH`; the Makefile uses absolute paths (`SJASMPLUS`, `ZESARUX`, both overridable).
- **sjasmplus** v1.21: use the native build at `sjasmplus-v21/build-arm64/sjasmplus`. The `sjasmplus-v21/sjasmplus` binary there is x86_64 and won't run (no Rosetta).
- **gfx2next**: `Gfx2Next/build/gfx2next`. Converts PNG/BMP into Next sprites, Layer 2 bitmaps and palettes.
- **ZEsarUX** 13.0 (the user's preferred emulator): `/Applications/zesarux.app/Contents/MacOS/zesarux`. It has no `--smartload` flag; load files with `--snap file.nex`. `--tbblue-fast-boot-mode` disables divMMC, so the esxdos handler won't work in that mode. Check flags with `--help` / `--experthelp`.
- **CSpect** is a Windows `.exe` that needs mono, which isn't installed. The **z88dk** and **DeZog** directories are empty.

Ask the user before installing anything.

## Key design constraints (from the spec)

- Hardware: **Layer 2 at 320x256** for backgrounds and **hardware sprites** for actors. Use the **AY chips** for all sound and music.
- Sprite sizes: Joe 16x32 plus a 16x16 bucket; cockroach 16x16; Mr Knut and Chairman Fumduck 16x32 each.
- Screen layout (from the sketch): a HUD across the top with the `CYNICISM` bar (0–100, **reset to 0 at the start of every level** — user's choice) on the left and `WAGES: NNp` (the score) on the right. Rusty pipes come out of the left and right walls at two heights. A conveyor belt with tubs runs **right to left** along the bottom.
- Core loop: slop oozes from the pipes, and pressing fire next to a pipe bangs it so the slop flows faster. Joe catches slop in his bucket and drops it into the tub of the same colour. Missed slop splats and raises cynicism. Vending treats lower cynicism and score points.
- **5 levels**, one per working day ("all 8 levels" in `description.txt` is a typo). The user wants the day name shown wherever a level number would be ("MONDAY", not "LEVEL 1"); the `LEVEL.day` field and `str_append_day` handle it. The spec's names stay as subtitles:
  1. Monday: Apprenticeship
  2. Tuesday: Get on with it!
  3. Wednesday: El Stompo, which adds cockroaches that you stomp with fire.
  4. Thursday: Meet Mr Knut, a random-walking manager who stuns Joe and adds cynicism.
  5. Friday: Knackered, which adds Chairman Fumduck (more damage) and a faster belt.
- **Level quota = successful deposits** (a full bucket emptied into the tub of the matching colour), not number of colours: **5, 6, 10, 10, 15**. Wrong-tub deposits don't count; they play an error sound.
- Screen flow: Title → Level intro → Game → Level complete → (next level). From the game, cynicism at max leads to the "quit" ending (a beach), and finishing all levels leads to the "retire" ending (gold clock and grave).
- Controls: QAOP + Space, or a Kempston joystick. BREAK pauses, with options to quit or continue.
