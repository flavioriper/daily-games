# Sound direction

How a board gets its sounds. The first set is Binairo's (2026-09-23,
`assets/sfx/binairo/`), the second Code Break's (the same day,
`assets/sfx/mastermind/`), then Balance, Untangle, Shikaku and Tents the
same afternoon, then Light Up, One Line and Nonogram, then Queens, Hidden
Word and Word Trail, then Mushroom Patch, Sudoku and Bridges, then Quilt, Paper Planes and
Pinwheel -- all eighteen boards; none had
been judged by ear when this was
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
- **A board's main move gets a file even when it is chatty.** Balance's
  `step` fires on every +/- tap and Untangle's `pick` on every grab; they are
  the move itself, not a cue riding on another, so they get a file, kept
  quiet (-9 and -12).
- **A drag that grows something can tick as it grows.** Shikaku's `select`
  fires on the press and again each time the bed's area changes, played
  through `cue(name, pitch)` a little higher per cell (4% a cell, capped at
  1.6), so the size of the bed can be heard. Asked for by the user
  2026-09-23. `CUE_GAP` keeps a fast drag from machine-gunning it.
- **A board with no cue calls gets them written at its real moments.**
  Hidden Word shipped cueing only `enter` and `reset`; its set added
  `type`, `erase`, `refused` (an Enter the rules turn down), `hint`, and a
  `flip` per tile timed to the turn through the board's own `_cue_due`
  queue (`FLIP_STEP` apart, 4% higher each), with `solved` or `lost` played
  when the deciding row has *landed*, not when Enter was pressed -- the same
  rule the board already keeps for its sprout. `lost` is a calm descending
  phrase, never a fail sting: running out of rows is "maybe tomorrow".
- **Bridges was the second board with no cue calls** (only `enter` and
  `solved`), and got `place`/`remove` on a drag (the plank cycle runs back
  to 0, so which one is read off the plank count), `met` when an islet's
  number is satisfied and `over` when it is pushed past it (both in its
  `_settle`, so undo and hint sound the same), `locked` on a refused drag,
  and the usual undo, hint, check and reset. Sudoku's set added `pencil`
  for a note, `line` when a move finishes a row, column or region (checked
  outside the wave, so reduce motion still hears it), and `locked` on a
  refused tap.
- **Pinwheel's `place` is levelled at -11**, not a tap's usual -6/-7: the
  whirr is dense (RMS -14 at -7 peak, against about -22 for the other taps)
  and it plays on every turn.
- A cue that fires per cell in one frame (Binairo's `blush_in`, `line`) is
  fine: `cue()` plays a repeat inside `CUE_GAP` (60 ms) once.
- Reuse cue names across boards where the moment is the same (`place`,
  `undo`, `hint`, `check`, `check_ok`, `reset`, `solved`, `enter` are common
  to most boards), and phrase their prompts like Binairo's so the game stays
  one family. Do not point one board at another's folder; copy or
  regenerate, so each set can be tuned alone.

## The interface click

Every button in the game clicks (`ui/ui_sound.gd`, `assets/sfx/ui/click.ogg`,
`tools/gen_sfx.py ui`): `CozyTheme.dress()` wires it to every `BaseButton` that
enters the tree, so a new button needs nothing. The click waits for the end of
the frame and **stays quiet if a board played a cue in that frame** (Fx2D
stamps `UiSound.board_frame`): a tray chip that places, Undo, Hint and Check
are answered by the board's own sound, and a button on a board with no set
yet (Hidden Word's keys, Sudoku's pad) still clicks. A button with the meta
`silent` never clicks. The tip card is not a button, so it calls
`UiSound.click(self)` itself; anything else tappable that is not a
`BaseButton` must do the same. Harnesses that skip `main.tscn` never install
`dress()` and stay quiet.

## Levels and lengths

- **Chatty cues quiet, rare cues loud.** The third number in each `SETS`
  entry is the peak in dBFS. Binairo: `solved` -3, `hint`/`check_ok` -5,
  `place`/`check`/`line` -6, `reset` -8, `clear`/`undo`/`enter` -9,
  `blush_in` -10, `brush` -12. Start a new board from those.
- **Short.** A tap is 0.5 s requested, a UI action 0.6-0.7, a flourish 1.0,
  the win 2.0. The API's minimum is 0.5 s; ask for that and describe the
  sound as "very short".
- Peaks land within about a decibel of the target after Vorbis encoding;
  a file several dB off is a bug (see the mono fold under Traps).

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

- **Measure the peak on the mono file, not the stereo take.** Until
  2026-09-23 the script levelled the stereo take and folded it to mono
  afterwards (`-ac 1`), and the fold moved the peak: about +3 dB when the
  two channels were alike, and as much as -5 dB when they differed
  (Pinwheel's `hint` landed at -10.9 against -5). 93 of 146 files were
  more than 2 dB off their target. The chain now folds to mono first
  (`aformat=channel_layouts=mono`), and every set was re-levelled from its
  cached take -- the same sounds, only the gain changed.
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
  A short file is not a dud on its own: Balance's `step`, Untangle's `drop`
  and Shikaku's `plot` trimmed to 0.23-0.29 s but carry -25 to -30 dB RMS,
  which is a real tap. Only a near-silent take (around -45) needs redoing.
- **The key** is read from `$ELEVENLABS_API_KEY` or
  `~/.config/elevenlabs/api_key` (mode 600) and must never be written into
  the repo or pasted into chat. If it is missing, ask the user to run
  `! mkdir -p ~/.config/elevenlabs && pbpaste > ~/.config/elevenlabs/api_key`.
- Harnesses and headless tests run through the same `cue()`; with the dummy
  audio driver that is harmless, and the suite stayed green.
