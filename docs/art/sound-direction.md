# Sound direction

How a board gets its sounds. The first set is Binairo's (2026-09-23,
`assets/sfx/binairo/`), the second Code Break's (the same day,
`assets/sfx/mastermind/`), then Balance, Untangle, Shikaku and Tents the
same afternoon, then Light Up, One Line and Nonogram, then Queens, Hidden
Word and Word Trail, then Mushroom Patch, Sudoku and Bridges, then Quilt, Paper Planes and
Pinwheel, then Fairy Lights -- every flat board; none had
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
- **Fairy Lights' lanterns chime as the wash reaches them.** Its set adds
  `wake`, queued in the board's `_settle` at each lantern's own wake moment
  (`_wake_cues`, delivered in `_process`) and 3% higher per step of depth
  from the post, capped at 1.5, so a long run is heard travelling out. It
  is quiet (-12) because a move can wake several; lanterns closer together
  than `CUE_GAP` chime once.
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
  2026-09-23 the script levelled the stereo take with `volumedetect` and
  folded it to mono afterwards (`-ac 1`), and the files came out anything
  from 3 dB hot (the fold sums two alike channels) to 5 dB short (it cancels
  two unlike ones; Pinwheel's `hint` landed at -10.9 against -5): 93 of 146
  were more than 2 dB off. Three things had to change, and each was found
  by the one before it failing: `volumedetect` measures in 16-bit and reads
  a fold past full scale as exactly 0 dB, so the peak is read with
  `astats`; trimming the folded mono cut audible ring-outs (Binairo's
  `line` lost a tail at -23 dB), so the trim stays on the stereo take; and
  inside one filter chain ffmpeg chooses where the fold happens, so
  `to_ogg` now runs each stage as its own file -- trim, fold to float mono,
  measure, gain and encode. Every set was re-levelled from its cached take
  (the same sounds, only the gain changed) and all 168 files now land
  within about a decibel.
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

## Code Break's second set (2026-09-29)

`full`, `locked`, `check` and `score` were re-prompted toward felt and
kalimba, the same fix Binairo's `check` and `blush_in` got: a wooden bonk
reads as a scold. A filling row plays a tune -- `note`, a kalimba pluck
layered under `place` at -4 dB and pitched up the major pentatonic by the
seat -- and each score pip lands with its own `pip` a step higher, in the
pile's order (never the seats'), so a score can be heard counting. The
rest (`warmer`, `so_close`, `all_here`, `cool`, `shuffle`, `peek`, `stamp`,
`party`, `confetti`, `out_of_rows`, `row_back`) are one take each, not yet
heard by the user. Details: `docs/agents/boards/code-break.md`.

## Shikaku's polish (2026-09-30)

`clear`, `locked`, `undo` and `check` re-prompted toward felt and kalimba,
for the same reason as Binairo's and Code Break's: the bonk, the tape rewind
and the wooden boops read as a scold or a toy. New cues `sprout`, `combo`
(layered and pitched up the pentatonic like Binairo's), `confetti` and `worm`
were generated with the rest. The main ElevenLabs key ran out of credits
mid-run; `tools/gen_sfx.py` now retries a request once on a fallback key
(`$ELEVENLABS_API_KEY_FALLBACK` or `~/.config/elevenlabs/api_key_fallback`)
when the first answers `quota_exceeded`, and the last seven cues came from
it. Not yet judged by ear.

## Tents' polish (2026-09-30)

`place`, `locked`, `undo` and `check` re-prompted toward felt, canvas and
kalimba, like Shikaku's; `place` and the new `strike`, `cairn` and `clear`
take the COZY style (real canvas, pebbles and grass rather than marimba). A
sweep ticks `cairn` (laying) or `clear` (rubbing out) once per square it
will change, 4% higher each, capped at 1.6. New: `combo`, `confetti`,
`peek`, `cool`, `bunny`, `oak`, `heart_lost`, `out_of_hearts`,
`heart_back`, `stamp`, `party`. All 18 came from the fallback key; none
judged by ear. Details: `docs/agents/boards/tents.md`.

## Light Up's polish (2026-09-30)

`place`, `locked`, `undo` and `check` re-prompted toward paper, felt and
kalimba, like Shikaku's and Tents': the bonk, the tape rewind and the wooden
boops read as a scold or a toy. `place` (a paper lantern set down on stone,
a warm glow) and the new `strike` (a lamp blown out), `chip` and `clear`
(one tick per stone of a sweep, 4% higher each, capped at 1.6), `moth`,
`purr` and `wake` (a cross little mew, never a hiss) take the COZY style.
Also new: `combo`, `confetti`, `cool`, `puff`, `snail`, `heart_lost`,
`out_of_hearts`, `heart_back`, `stamp`, `party` and `lanterns` (the sky
lanterns rising). All 21 came from the fallback key; none judged by ear.
Spec: `docs/superpowers/specs/2026-09-30-lightup-polish-design.md`.

## No synth (2026-10-05)

The user, after an audit of where every file comes from: **"we need cozy
sounds, to avoid synth (not usually cozy)"**, Drumbeat set aside for now.
Two things in the game were synth, and both went:

- **The Arcade tab's `ARCADE` style asked ElevenLabs for a "soft warm 8-bit
  chiptune synth"** -- all 22 of Firefly's cues and the jingles of the other
  five (86 files). The constant keeps its name and now reads like the
  polished boards' `*_TUNE` strings (a real kalimba, music box, tongue drum
  and hand bells, "no synth, no electronic tones, no beeps"), and every
  prompt under it was rewritten: a retro jingle is a tune on a kalimba and a
  music box, a blip is a note, a low "bonk" blip is one damped tongue-drum
  note, a horn is two music box notes. Firefly's four sounds that are not
  notes (`shoot`, `pop`, `dive`, the looped `beam`) take a new foley style,
  `NIGHT`: a puff and a glass tink, a paper fan's swoop, a singing glass rim
  under tiny bells where the tractor beam hummed. Seconds and peaks are the
  old ones, so nothing in the screens moved.
- **Marigold's `music.ogg` was summed sines** (`tools/gen_marigold_music.py`).
  It is still sequenced, because the tune has to be exact, but from three
  recorded notes; see `docs/agents/boards/marigold.md`.

Swept up with them: the four house-set `undo` cues still prompted as
"rewinding a tiny tape" (Binairo, Code Break, Balance, Untangle -- the sound
every polish since Shikaku's has thrown out) are a felt brush and a kalimba
note gliding down, and Peapod's `rot` lost its "blip" (the
rotten gift and `rot.ogg` were removed on 2026-10-05).

Left alone: the `CARTOON` cues (mallets, blocks, pebbles, crates -- comic,
but things, not synth; Peapod's and Lucky Thirteen's went the same morning,
next section) and **Drumbeat's songs, leads, drums and calibration
clicks, which are still synthesised** by `tools/gen_drumbeat.py`.

One take each on the main key (592 credits), none judged by ear; two came
back near-empty and were taken again (Untangle's `undo`, 0.21 s at -42 dB
RMS, and Binairo's, -36). Marigold's tune was measured instead of heard:
its 62 melody notes sit a median 3 cents off the score.

## Peapod and Lucky Thirteen, hated (2026-10-05)

Minutes after the pass above the user: **"i really really hate peapod and
lucky 13 sounds so much, it's annoying"**. Both sets were redone whole, in
two goes, and the second go is the rule to keep:

> "it's important to avoid bell or ring sounds for something that repeat a
> lot, so use something more like a 'click', previous selection sound were
> in the right direction. Also, on peapod, we need a really subtle click
> sound for every shoot"

**A sound that repeats a lot is a click: short, dry, no note, no ring.**
Kalimba, music box and bells are for what happens now and then (a reward,
a wave, a win). And a constant action still wants its sound -- a faint
click, not silence. The first go got both wrong: it made Lucky Thirteen's
`select` a kalimba note climbing the pentatonic, and took Peapod's `shot`
away altogether.

Where the two games stand:

- **Peapod.** `shot` is one click cut to its first 50 ms at -24 dBFS, the
  quietest file in the game, on every volley (it had been an airy
  half-second "pft" centred at 5.5 kHz, five to ten a second). `hit` and
  `clank`, the peas landing, are heard at most once in `HIT_GAP` (0.07 s:
  a volley's peas as one, every volley of the quickest gun; `CUE_GAP`
  alone let sixteen a second through). **A hit sounds by the number left
  on the crate** (the user's third note that morning: "add a subtle sound
  as the block on peapod is hitted based on the number on it"): 1.4x on
  its last pea, 0.12 lower each time the number trebles, no lower than
  0.7 (`_hit_pitch`), so a big crate is a dull knock that rises as it is
  worn down. The sim's `hit` event carries `hp` for it.
  Levels by the user's ear, heard in play: "the block break is too loud,
  and the block shoot hit is too low" at `pop` -8 and `hit` -18; they are
  -14 and -10 now (`pop_gold` -9, `clank` -11), the same takes.
  **Then "more cozy, to make user feel good when hitting multiple
  different sizing blocks. Check on web how they do it."** What the web
  says, and what was taken from it: Peggle plays every peg hit as the next
  note of a scale in key with its music, so a run of hits is a phrase
  (Audiokinetic's write-up of Peggle Blast); a pentatonic scale is the
  usual choice because any of its notes sit together in any order;
  Unpacking recorded real materials and kept its pick-ups "tight so it
  felt responsive and tactile"; Dorfromantik gives the one thing the
  player does most a soft pop and lets nothing else disturb it; every
  guide on repeated sounds says small random pitch and level so no two
  are the same. So `hit` is a damped wooden tock (a felt mallet on a
  block: a note's worth of pitch, no ring, 40 ms of body), **each of the
  eight paints has its note** (`HIT_NOTES` by `Art.tier_of`, down the
  major pentatonic as the number trebles: 9, 7, 4, 2, 0, -3, -5, -8
  semitones), with 1.2% of pitch and 2 dB of level at random. A crate
  steps up a note as it is worn down a colour, and a wall of mixed
  crates plays a handful of notes that agree. The take landed 60 ms
  behind a breath of room noise, hence `tools/gen_sfx.py`'s `"tight"`
  flag. The tap the user had said "I like it" to is kept at
  `build/sfx_raw/peapod/hit_liked_0859.mp3` (ignored by git).
  `pop` climbs 1.25% a kill to 1.25x, where it went 2.5% to 1.5x and
  stayed. The other `CARTOON` cues are `PEAPATCH` foley: no boing, slide
  whistle, 'blegh' or firecracker bang.
- **Lucky Thirteen.** `select` is the first take of all again (a 0.07 s
  pebble click), 5% higher a pebble up to 1.5x where it went 7% to 1.9x.
  `merge`, every move's, is three pebbles clacking with no chime. `land`
  is heard once in `LAND_GAP` (0.09 s), `merge` climbs 0.9 to 1.3 where it
  reached 1.6, the end card counts on `unselect`. The rest is `RIVERBED`
  foley.
- **The same rule, applied to that morning's own takes**: Firefly's
  `shoot` (several a second) and `pop` had been given a glass tink and
  Posy's `collect` a music box note; all three are dry clicks now, cut to
  60-150 ms.

**Low is not cozy on a phone.** Takes prompted "low and muffled" came back
as 80 Hz thumps: measured above 400 Hz, where a phone's speaker starts,
Peapod's `knock` sat at -58 dB. Ask for wood (a knuckle on a crate), not a
thump, and check a new set with a high-pass in mind, not only its peak.

None of it heard by anyone but for the user's verdict on the first go.

## Horse Pen (2026-10-08)

`SETS["horse"]`, eighteen cues, every one the board fires. Three styles:
`MEADOW` (close-mic foley of straw bales, short grass and a wooden gate),
`MEADOW_TUNE` (the garden family's kalimba, music box and hand bells) and
`PONY`, for `neigh` alone -- the other styles end "no voice", which would
ask the animal to keep quiet. **`place` fires on every move, and `lift` and
`undo` nearly as often, so all three are dry straw cut to 0.22-0.28 s with
no note in them** (-9, -12, -14). `locked` is a knuckle on a fence post,
asked for as wood and not as a thump (the phone trap above); `closed` and
`open` are the gate's latch. Notes are kept for what happens now and then:
`ready` two kalimba notes up, `best` three with a hand bell, `not_yet` two
down (the `fall` trick, as Tents' `check`), and `hint`, `solved`, `party`,
`stamp`, `out_of_hearts` and `heart_back` phrased as Mini Golf's. One take a
cue on the first run, no retakes, unheard by the user. Measured, not heard:
every peak within a decibel of its target, nothing near-empty, and the foley
holds its level above 400 Hz. `out_of_hearts` came back 0.95 s against 1.8
asked and `stamp`'s thump sits 0.1 s behind a breath; both are like their
siblings in other sets and were left.

## How Big? (2026-10-08)

`SETS["how_big"]`, sixteen cues, every one the board fires. Two styles:
`BENCH` (close-mic foley of a carpenter's bench: a wooden folding ruler, a
small clamp, thick paper, a tape measure) and `BENCH_TUNE` (the garden
family's kalimba, music box, tongue drum and hand bells). **`notch` is the
only cue that repeats** -- one click every time the answer has grown or
shrunk by 8% under the finger, so a long pull is a run of them -- and it is
a ruler's joint with no note, cut to 0.07 s and the quietest file of the set
(-19); the board plays it between 1.35 and 0.75 of its pitch, lower the
bigger the thing has become, and 6 dB under its file. `lock` is the clamp
snapping shut, `next` a sheet of paper slid aside, `reset` the tape drawn
back. The reveal is a note by its grade, up for good and down for not yet:
`spot` three kalimba notes and a hand bell, `close` two, `fair` one, `off`
two falling (the `fall` trick, as Tents' `check`); `heart_lost` is a low
tongue drum over a dull knock. `hint`, `solved`, `party`, `stamp`,
`out_of_hearts` and `heart_back` are phrased as Horse Pen's. One take a cue
on the first run, no retakes, unheard by the user and not measured.

## Golden Acorn (2026-10-08)

`SETS["acorn"]`, fourteen cues, every one the board fires. Two styles:
`QUIZ` (close-mic foley of a card table: stiff index cards, a small wooden
tile, a pencil) and `QUIZ_TUNE` (the garden family's kalimba, music box,
tongue drum and hand bells). **`pick` is the only cue that repeats** -- a
player in doubt taps several answers -- and it is a wooden tile set down
with no note, cut to 0.1 s at -15. `lock` is a card pressed flat under a
knuckle, `next` a card slid off the stack and turned, `refuse` a pencil
tapped twice (Lock with nothing picked, a bulb on a question already cut),
`enter` the stack squared up. **Between `lock` and the answer there is 0.6 s
of nothing**: a quiz show's drum roll or sting was left out on purpose, and
the answer is a note, up for right and down for not quite -- `right` three
kalimba notes and a hand bell, `wrong` two falling (the `fall` trick, as
Tents' `check`), never a buzzer; `heart_lost` is a low tongue drum over a
dull knock. `hint`, `solved`, `party`, `stamp`, `out_of_hearts` and
`heart_back` are phrased as How Big?'s. One take a cue on the first run, no
retakes, unheard by the user and not measured.
