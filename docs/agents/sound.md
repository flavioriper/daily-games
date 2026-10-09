<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## Sound

Full rules: `docs/art/sound-direction.md`. Sounds are generated with
ElevenLabs by `tools/gen_sfx.py <puzzle_id>` into
`assets/sfx/<puzzle_id>/<cue>.ogg`, and `Fx2D.cue()` plays whichever cue has
a file -- a missing file is silence, on purpose. Soft wood, marimba, kalimba,
glockenspiel and paper; never a buzzer; up means good, down means not yet;
cues that fire on every touch (Binairo's `focus`, `blush_out`) get no file.
One take per cue; the user listens and names the ones to redo. The set is
keyed by `puzzle_id()`, not the card's name (Code Break's is `mastermind`).
Every flat board has a set, Fairy Lights included (2026-09-23). Every button clicks through `ui/ui_sound.gd`, wired by
`CozyTheme.dress()`, and keeps quiet when a board cue answered the same frame.

**Never synth (user, 2026-10-05: "we need cozy sounds, to avoid synth").**
Every file is an ElevenLabs take of real acoustic things -- kalimba, music
box, hand bells, tongue drum, close-mic foley. No prompt says retro, blip,
zap, 8-bit, synth or tape rewind, and no tool sums sines into a sound. A
tune that has to be exact is sequenced from recorded single notes
(`tools/gen_marigold_music.py`). **The one exception left is Drumbeat**: its
three songs, their lead tracks, the four drums and the calibration clicks
are still synthesised by `tools/gen_drumbeat.py` (the user: "skip drumbeat
for now"). The pass itself: `docs/art/sound-direction.md`, its last section.

**Nightlight has a set since 2026-10-06** (`HEARTH` foley and `ARCADE`
notes, fourteen cues; `docs/agents/arcade.md`). A space game gets no pad
and no laser. **Heard on 2026-10-09 and "too harsh"**: its notes are
`HEARTH_TUNE` now (kalimba and tongue drum, low and muffled, no bells, no
"bright", no "sparkle"), every cue has `warm` and the new `ease:<seconds>`
fade-in, and no note peaks above -11 (`nova` -8). When a set is asked to be
cozier, that is the order: what the game adds at play, then level and
roll-off, then the prompt's words. **A harness is heard on this Mac**: run one that plays a
game with sounds under `--audio-driver Dummy`.

**What repeats a lot is a click (user, 2026-10-05).** "It's important to
avoid bell or ring sounds for something that repeat a lot, so use something
more like a click." A chain's pebbles, a gun's shots, tiles landing: short,
dry, no note. Notes are for what happens now and then. A constant action
still gets its sound -- "a really subtle click", not silence.

**Horse Pen has a set since 2026-10-08** (`SETS["horse"]`, `MEADOW` foley,
`MEADOW_TUNE` notes and `PONY` for the `neigh`, eighteen cues): one take a
cue, unheard by the user. A bale dropped, lifted or undone is dry straw
with no note. Details: `docs/art/sound-direction.md`, its last section.

**How Big? has a set since 2026-10-08** (`SETS["how_big"]`, `BENCH` foley of
a carpenter's bench and `BENCH_TUNE` notes, sixteen cues): one take a cue,
unheard by the user. `notch` is the one that repeats (a click every 8% the
answer grows or shrinks): a ruler's joint, cut to 0.07 s at -19, and the
board pitches it down as the thing gets bigger. Details:
`docs/art/sound-direction.md`, its last section.

**Golden Acorn has a set since 2026-10-08** (`SETS["acorn"]`, `QUIZ` foley of
a card table -- index cards, a wooden tile, a pencil -- and `QUIZ_TUNE`
notes, fourteen cues): one take a cue, unheard by the user. `pick` is the
one that repeats (every tap on an answer): a wooden tile set down, cut to
0.1 s at -15, no note. The held breath after a lock is silence, not a drum
roll. Details: `docs/art/sound-direction.md`, its last section.

**Pearl Dive has a set since 2026-10-09** (`SETS["pearl"]`, `JETTY` foley of
a wooden jetty over calm water -- drops, bubbles, a wet rope, a plank -- and
`JETTY_TUNE` notes, sixteen cues): one take a cue, unheard by the user.
`tick` is the one that repeats (the clock's last five seconds): a wooden
clock's tick, cut to 0.07 s at -16, no note. `miss` can come several times
a prompt and is two dull knocks on a plank, no note either. The keyboard's
keys click through `ui/ui_sound.gd` as Hidden Word's do; the board adds no
cue a letter. Details: `docs/art/sound-direction.md`, its last section.

**Lattice has a set since 2026-10-09** (`SETS["lattice"]`, `TILES` foley of
wooden game tiles and a wooden lattice on a garden table and `TILES_TUNE`
notes, seventeen cues): one take a cue (`home` two), unheard by the user.
`pick`, `swap` and one of `miss` or `home` sound on every move, so with
`drop` and `undo` they are dry wood cut to 0.1-0.28 s with no note; the
notes are `home2` (two tiles home at once), `line`, `hint` and the day's
end. Details: `docs/art/sound-direction.md`, its last section.

**Toy Boats has a set since 2026-10-09** (`SETS["boats"]`, `JETTY` foley of
a wooden box, calm water, toy boats and pebbles, nineteen cues): one take a
cue, unheard by the user. A game is a hundred throws, so `throw`, `lob`,
`miss`, `splash`, `hit`, `knock` and above all `tick` (0.06 s at -19) are dry
and have no note; the notes (`sunk`, `glug`, `hint`, `win`, `lose`) are
`HEARTH_TUNE`'s low muffled kalimba, eased in, none above -8. Details:
`docs/art/sound-direction.md`.

**Penny Drop has a set since 2026-10-09** (`SETS["penny"]`, `HEARTH` foley of
a wooden rack and thick coins, ten cues): one take a cue, unheard by the
user. A game is up to forty-two drops, so `drop`, `land` (pitched 1.12 down
to 0.92 and -7 up to 0 dB by how far the penny fell), `tick` (0.06 s at
-19), `refused`, `lift` and `spill` are dry and have no note; the notes
(`hint`, `win`, `lose`, `draw`) are `HEARTH_TUNE`'s low muffled kalimba,
eased in, none above -8. Details: `docs/art/sound-direction.md`, its last
section.

**Dominoes has a set since 2026-10-09** (`SETS["dominoes"]`, `HEARTH` foley
of thick tiles on felt, eleven cues): one take a cue, unheard by the user. A
game is eighty-odd tiles laid, so `place` (pitched 0.94 to 1.06 at random),
`draw`, `lift`, `refused`, `knock` (a pass) and `shuffle` (once a hand) are
dry and have no note; the notes (`out`, `lost_hand`, `hint`, `win`, `lose`)
are `HEARTH_TUNE`'s low muffled kalimba, eased in, none above -8. Details:
`docs/art/sound-direction.md`, its last section.

**Reversi has a set since 2026-10-09** (`SETS["reversi"]`, `HEARTH` foley of
thick wooden discs on a painted board, ten cues): one take a cue, unheard by
the user. A game is sixty discs set down and a few hundred turned, so `place`,
`flip` (one a ring of turning discs, 0.92 to 1.2 the further out, never one a
disc), `refused`, `lift`, `sweep` and `pass` (a knuckle on the frame) are dry
and have no note; the notes (`hint`, `win`, `lose`, `draw`) are
`HEARTH_TUNE`'s low muffled kalimba, eased in, none above -8. Details:
`docs/art/sound-direction.md`, its last section.

**Beeline has a set since 2026-10-09** (`SETS["beeline"]`, nine cues): one
take a cue. `flap` (every tap, 0.1 s at -15) and `pass` (every gap, 0.14 s
at -13) never stop and are dry taps on thin wood with no note; `bump` and
`land` (-12) are `GROVE` leaf and grass, `dew` a `JETTY` water drop; the
notes (`ribbon`, `start`, `game_over`, `new_best`) are `HEARTH_TUNE`'s low
muffled kalimba, rolled off and eased in, none above -10. The screen pitches
`pass` up by at most 11% across each ten gaps.

The first `flap`, `pass` and `land` were `HEARTH_TAP`'s felt at -25, -21 and
-16 under a 2400-3200 Hz roll-off, and the user heard the rewards and
nothing in the game (2026-10-09): high-passed at 400 Hz, a stand-in for a
phone's speaker, they peaked at -40 dB and under. The lesson beside
Nightlight's: quiet and dark together is silence on a phone, so a tap that
never stops keeps a body above 400 Hz (the three now read -20, -15 and -15
there). The new takes are unheard by the user. ElevenLabs answers a hushed
prompt with a near-empty take now and then (a raw peak under -30 dB, or a
1.7 s cue with 0.2 s of sound in it): measure the raw take in
`build/sfx_raw/` and ask again with `--new`.

**No scratch: a thing is a low soft tick, a swipe is a breeze** (the user,
2026-10-09, of the menu's page turn and Dominoes' tile: "a harsh scratch
sound extremely annoying ... soft, cozy, low tics, swipes should sound more
like a light breeze blowing, or like those old mouse wheel spinning doing
those low pitch clicks, or maybe leaves being blown"). Measured, the takes
he named were bursts of noise with most of their energy between 1 and 8 kHz
(a centroid near 3 kHz): what anything slid, brushed, swept or clacked comes
back as. `tools/gen_sfx.py` has two styles for it, `HUSH` (one notch of an
old mouse wheel) and `BREEZE`, and two options, `body:<Hz>` (a high-pass, so
a low take is levelled by what a phone plays) and `steep` (four more poles
on `warm`). Redone that day: `ui/page` (a breath of breeze, steep above 1.1
kHz), Dominoes' `place`, `draw`, `lift`, `shuffle` and Reversi's `place`,
`flip`, `lift`, `sweep` (ticks with their body at 300 Hz to 1 kHz, 34 to 50
dB down above 3 kHz, where the old ones were 3 dB down). Two traps: a prompt
that says "deep" or "low-pitched" comes back under 300 Hz, and one that says
"very soft, quiet" comes back nearly silent. Unheard by the user. **Not
redone**: a scan of all 1,151 cues finds 149 short ones with most of their
energy above 2 kHz (the `place`, `lift`, `undo`, `select` and `reset` of many
boards among them, Penny Drop's four); the measure also catches bright notes
that do not scratch, so it is a list to listen through, not a verdict.
