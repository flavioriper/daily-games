# Sound direction

How a board gets its sounds. The first set is Binairo's (2026-09-23,
`assets/sfx/binairo/`), the second Code Break's (the same day,
`assets/sfx/mastermind/`), and neither had been judged by ear when this was
written: the rules below are how it was made, not proof it is right. When the
user corrects a sound, record the correction here.

## The look, in sound

The same brief as `shading-direction.md`: soft, warm, rounded, never harsh.

- **Instruments:** soft wood (taps, pops), marimba, kalimba, glockenspiel,
  and paper for small UI clicks. One family, so a board sounds like one toy.
- **No buzzers, no alarms, no harsh transients.** A mistake is a kind "not
  quite" -- two soft notes going down -- never an error beep. That is the
  sound form of the tip card that names a broken rule instead of scolding.
- **Up means good, down means not yet.** Confirmations rise (`check_ok`,
  `line`, `hint`, `solved`), refusals and mistakes dip (`check`, `blush_in`).
- **Dry, no music bed, no voice.** Every prompt ends with the shared `STYLE`
  string in `tools/gen_sfx.py` saying so; keep it on every cue.

## Which cues get a sound

Every board already names its moments through `fx.cue("<name>")`
(`ui/fx2d.gd`), and `cue()` plays `assets/sfx/<puzzle_id>/<cue>.ogg` if that
file exists. **A missing file is silence, on purpose** -- so choosing a board's
set is choosing which cues get a file.

- `grep -n 'cue(' puzzles/<board>2d.gd` first, and read each call in context:
  how often does it fire, and does it fire per cell?
- **Leave out the cues that fire on almost every touch alongside another.**
  Binairo's `focus` fires on every tap with `place`, and `blush_out` fires on
  every cell that recovers; both were left without a file, because they
  would only muddy the sound they ride with.
- A cue that fires per cell in one frame (Binairo's `blush_in`, `line`) is
  fine: `cue()` plays a repeat inside `CUE_GAP` (60 ms) once.
- Reuse cue names across boards where the moment is the same (`place`,
  `undo`, `hint`, `check`, `check_ok`, `reset`, `solved`, `enter` are common
  to most boards), and phrase their prompts like Binairo's so the game stays
  one family. Do not point one board at another's folder; copy or
  regenerate, so each set can be tuned alone.

## Levels and lengths

- **Chatty cues quiet, rare cues loud.** The third number in each `SETS`
  entry is the peak in dBFS. Binairo: `solved` -3, `hint`/`check_ok` -5,
  `place`/`check`/`line` -6, `reset` -8, `clear`/`undo`/`enter` -9,
  `blush_in` -10, `brush` -12. Start a new board from those.
- **Short.** A tap is 0.5 s requested, a UI action 0.6-0.7, a flourish 1.0,
  the win 2.0. The API's minimum is 0.5 s; ask for that and describe the
  sound as "very short".
- Peaks land within about 3 dB of the target after Vorbis encoding; that is
  expected, not a bug.

## How to generate

1. Add a `"<puzzle_id>": {cue: (prompt, seconds, peak)}` block to `SETS` in
   `tools/gen_sfx.py`. The key must be the board's `puzzle_id()`, since
   that is the folder `cue()` looks in.
2. `python3 tools/gen_sfx.py <puzzle_id>` -- one take per cue (the user
   asked for one take, not a choice of three; they test and say which to
   redo).
3. `godot --headless --path . --import`.
4. Check it plays: a throwaway probe that builds the board and taps it, then
   reads `fx._players` and `fx._streams` (the file loaded, the right folder).
5. Report durations and peaks and say plainly that nobody has listened yet.

To redo one: edit its prompt and run `... <puzzle_id> <cue> --new` (a fresh
take). To change only its level or trim, edit the peak and run without
`--new` -- the raw take is cached in `build/sfx_raw/` (ignored) and is
reprocessed for free.

## Traps already hit

- **`loudnorm` does not work on sub-second clips**: it pushed several to
  0 dBFS and left one at -18. The script levels on peak instead
  (`volumedetect`, then `volume=`).
- **A -50 dB silence trim ate a whole sound**: `reset` (a ripple of soft
  pops) came out 30 ms long. The trim is at -60 dB with 10 ms kept; check
  every duration after a run for anything far under what was asked.
- **The folder is the `puzzle_id()`, not the card's name.** Code Break's
  board answers `"mastermind"`, so its set is `SETS["mastermind"]` and
  `assets/sfx/mastermind/`; a `codebreak` folder would be silently never
  played. Read `puzzle_id()` off the board before naming the set.
- **A take can come back nearly empty.** Code Break's first `reset` was a
  quarter second of sound at about -45 dB RMS followed by silence, so the
  trimmed file was 0.25 s against 1.0 asked. That was the take, not the
  trim (check the raw mp3's RMS over time with `astats`); `--new` fixed it.
- **The key** is read from `$ELEVENLABS_API_KEY` or
  `~/.config/elevenlabs/api_key` (mode 600) and must never be written into
  the repo or pasted into chat. If it is missing, ask the user to run
  `! mkdir -p ~/.config/elevenlabs && pbpaste > ~/.config/elevenlabs/api_key`.
- Harnesses and headless tests run through the same `cue()`; with the dummy
  audio driver that is harmless, and the suite stayed green.
