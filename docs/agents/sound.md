<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## The cozy rules

The user, 2026-10-09: "Sounds should always aim for cozy low, low clicks,
ticks, slides should always aim for something gentle sliding on wood never
on steel, old mouse center button wheel scroll fast clicks, for sounds like
the button click overall, never high pitch sounds, always some low pitched
or bass sound. Lofi inspired". These rules come first; where a note further
down this file or in `docs/art/sound-direction.md` disagrees, it is history
and these win. Every new cue and every redone one is held to them.

**1. Every sound is one of three things.** Decide which before writing a
prompt.

| The cue | What it is | Style and options | Level |
|---|---|---|---|
| A thing set down, lifted, turned, pressed, counted; a button; anything that repeats | one low soft tick, the notch of an old mouse wheel; several in a row are a wheel spun | `HUSH`, `cut:0.06`-`0.28`, `warm:1000`-`1600`, `body:320` | -13 to -19 |
| A swipe, a page, a sweep, anything that travels | a breath of breeze, or a thing slid gently on wood (rule 4) | `BREEZE`, `warm:1100`, `steep`, `ease`, `body:320` | -16 |
| A moment: a hint, a line, a hand won, the day's end | a few muffled notes at 400 to 700 Hz, kalimba or tongue drum played with felt | `COZY_TUNE`, `warm:2000`-`2600`, `ease`, `body:300`, `notes` (rule 8) | none above -8 |

**2. Low, and never high.** No cue has its weight above 1 kHz. The measure,
taken on every take before it is kept: the body between 300 Hz and 1 kHz,
30 dB or more down above 3 kHz (the takes the user hated had a centroid
near 3 kHz and were 3 dB down there). No pitch climb at play goes past
five semitones, and a tick that repeats varies by 0.94 to 1.06 at random so
it is never the same sound twice. Good news still rises and "not yet" still
falls, but on the low notes: a rise is two or three steps of a kalimba, not
a sparkle.

**3. "Bass" stops at 300 Hz.** A phone's speaker plays next to nothing
under about 250 Hz (measured here on 2026-10-09: Beeline's taps, dark and
quiet, peaked at -40 dB high-passed at 400 Hz and the user heard nothing).
So low means a round body at 300 Hz to 1 kHz with the top taken off, not a
thump or a rumble. Each tick names `body:320`, and a take is checked
high-passed at 400 Hz: it still reads -20 dB or better there. A prompt that
says "deep", "bass" or "low-pitched" comes back under 300 Hz, and one that
says "very soft, quiet" comes back near silent: ask for a plain soft hollow
tick and let the level and the roll-off make it low and quiet.

**4. Wood, never steel.** What a sound is made of: wood, felt, cork, wool,
paper, leaves, air, calm water. Never steel, metal, coins that ring, glass,
ceramic, bells, chimes, a glockenspiel, a music box's bright comb, anything
that rings on. Of two things that touch, the softer is the one heard (a
wooden tile on felt is felt), so a prompt always names the soft thing it
lands on. **A slide is gentle and on wood**, and it is the hardest to get:
the same morning, everything asked for as slid, brushed, swept, scraped,
rustled or clacked came back as a burst of noise from 1 to 8 kHz, the
"harsh scratch" the user named. So a page or a swipe of the finger stays a
breeze; a piece that travels over the board may be wood on wood, asked for
as a low hollow wooden glide or a wheel turning, with none of those six
words in the prompt, `warm` at 1600 or under, and the measure of rule 2
deciding whether it is kept. A slide that does not pass is a row of ticks.

**5. A button is a mouse wheel's click.** Every button, tab, key and chip:
one notch of an old mouse's wheel, low and dull, 0.06 to 0.15 s, no note
and no paper in it. A list that scrolls or a count that runs is the wheel
spun: the same tick, quickly, throttled so it never machine-guns
(`CUE_GAP`). A constant action still gets its tick -- "a really subtle
click", never silence, and never a note.

**6. Lofi is a treatment, not a noise.** What is taken from it: the top
rolled off gently (`warm`, and `steep` for air), an onset that is rounded
and never snaps (`ease`, 4 ms at least), levels kept low, a close dry room.
What is not: vinyl crackle, tape hiss, wow, a bit-crusher or any noise laid
over a take -- crackle and hiss are the scratch the user hates -- and the
"never synth" rule below stands: every file is a take of a real thing.

**7. The prompt proposes, the measure decides.** One take a cue; measure
the raw take in `build/sfx_raw/` and the finished file (rules 2 and 3); ask
again with `--new` when it fails rather than filtering a bad take harder.
Then `godot --headless --path . --import`, or the game still plays the old
file. Say in the commit which cues the user has not heard.

**8. A take is one note; the phrase is written.** Asked for "five notes
rising", the API returns one kalimba hit ringing out, every time (nine
takes of nine, Binairo, 2026-10-09), and at 250 to 350 Hz as often as not:
a pure tone a phone does not play (-35 dB high-passed at 400 Hz). So a note
cue's take is its one note, and `"notes:<gap>:<semitones>,..."` writes the
phrase from it: `"notes:0.14:0,2,4,7,9"` is five rising, `"notes:0.3:9,5,2"`
three falling slowly, and the steps are chosen so every note lands between
400 and 700 Hz (the measure prints the raw take's centroid). Rising is
good, falling is not yet, and two cues of one board never share a contour.

**The measure is `tools/measure_sfx.py <puzzle_id> [cue ...] [--raw]`.** A
line a file and a word for the rule it breaks: `high` (under 30 dB down
above 3 kHz, or a centroid over 1 kHz), `rumble` (more under 300 Hz than
from 300 Hz to 1 kHz), `faint` (under -24 dB high-passed at 400 Hz), and on
raw takes `empty` and `scratch` (a quarter of it above 3 kHz: ask again, do
not filter). A set is done at "0 flagged". It measures and does not hear:
a single tone at 450 Hz passes whatever it sounds like. What a tick prompt
comes back as, from Binairo's thirty-odd takes: "set down gently on thick
felt, a single soft tock, round and hollow" lands most often; "one notch of
an old mouse wheel" alone came back scratched three times in five and
"lifted off" or "picked up" as a thump at 110 Hz or a hiss at 7 kHz, so a
lift is a lighter thing set down. A tick that will not come is another
tick's take a step or two up (`"notes:0:2"`). **A cut tick is `tight`**
(Code Break, 2026-10-10): a take's tock sits up to 0.18 s into room noise
the default trim keeps, so `cut` ended three ticks before their sound and
the measure passed them; `heard` far shorter than the file is the sign.
`notes` trims the take's lead-in itself since Balance (the same day): moved
with the pitch, it put a second tock at 0.07 s where 0.13 was written. So
after a set, draw each tick's envelope in 10 ms steps and read where the
tocks fall: a tick under a finger starts inside 30 ms or is taken again.

**Copy these, not those.** A new set is built from `HUSH`, `BREEZE`,
`HEARTH`, `HEARTH_TAP` and `COZY_TUNE` (`HEARTH_TUNE` says "low" and "very
softly" and is what came back under 300 Hz at -26 dB; the sets that use it
have not been measured on the phone's side). Not models, though boards still
use them: `STYLE` (glockenspiel, bubbly pops), `ARCADE` and every `*_TUNE`
that says "small hand bells" or "music box", `DUSK` and `GLASSHOUSE` (glass
chimes), `NIGHT` (glass jars and bells), `CARTOON`. **Owed against these
rules, none started**: `ui/click` (still "paper and wood", `STYLE`, -12,
never measured); the 149 short cues listed at the foot of this file; the
bell and chime notes of the sets above. They are redone when the user names
them.

**The redo, a set at a time** (the user, 2026-10-09: "let's start to redo
all games sfx"). In `SETS` order; the next is the first row not done. Done
means every file of the set reads "0 flagged", the board's own pitch climbs
are inside five semitones, and the sounds are imported; it does not mean
heard.

| Set | State |
|---|---|
| `ui` | `page` and `opening` pass; `click` passes the measure but is still the paper-and-wood take, not a wheel's notch: not done |
| `binairo` | done 2026-10-09, unheard: 15 new takes (7 ticks, 2 breezes, 7 phrases with `brush` the lift's take), 6 kept; the streak's climb 14 semitones down to 5 |
| `mastermind` (Code Break) | done 2026-10-10, unheard: 19 new takes (10 ticks, 2 breezes, 7 phrases), 6 kept; `note` and `pip` are ticks and their climb is 16 semitones down to 5 (`CLIMB`) |
| `balance` | done 2026-10-10, unheard: 17 new takes (9 ticks, 2 breezes, 6 phrases), 5 kept; `land` and `tock` pitched inside five semitones |
| `untangle` | done 2026-10-10, unheard: 14 new takes (7 ticks, 1 breeze, 5 phrases and the kitten's chirrup), `pick` and `unwind` the drop's take, `confetti` Binairo's, 9 kept; nothing is rope any more (creak, rustle and zip are scratch); `put` and `stitch` play 6 and 10 dB up at the board now that they are low. `hover` is called by the board and has never had a file: still silent, the user's call |
| `shikaku` | done 2026-10-10, unheard: 11 new takes (5 ticks, 2 breezes, 4 phrases), `enter` select's take five in a row, `twirl` sprout's, `check` Code Break's, 8 kept; `select` climbs 5 semitones (it was 8) and the streak's `combo` is a tick climbing 5 (a pluck climbing 14) |
| `tents` | done 2026-10-10, unheard: 14 new takes (5 ticks with the `bunny` three hops, 3 breezes with the `oak` a breath through its leaves, 5 phrases and the camper's `peek`), `enter` place's take five in a row, `clear` cairn's three steps down, `undo` strike's, `check` Code Break's, 5 kept; nothing is canvas any more (a whump was a thump at 18 Hz); the sweep climbs 5 semitones (it was 8) and the streak's `combo` is a tick climbing 5 (a pluck climbing 14) |
| `lightup` | done 2026-10-10, unheard: 17 new takes (5 ticks with the `snail` three slow notches, 4 breezes with the lantern's `puff` and the sky `lanterns`, 5 phrases, the `moth`'s two notes and the cat's chirrup and mew), `enter` place's take five in a row, `clear` chip's three steps down, `undo` strike's, 6 kept; nothing is paper or stone any more; the sweep climbs 5 semitones (it was 8) and the streak's `combo` is a tick climbing 5 (a pluck climbing 14) |
| `oneline` | done 2026-10-10, unheard: 14 new takes (4 ticks with the `mushroom` two tocks a third apart, 2 breezes with the `petals` a long breath, 5 phrases, and `dew`, `bloom` and the `ladybug` two, one and three quiet notes), `enter` lay's take five in a row, `undo` slip's, `start` mushroom's, `check` Code Break's, `sun` Light Up's puff, `confetti` Binairo's, 6 kept; nothing is a plank's creak, a drop's plink or a wing any more; `lay` already climbed under 5 semitones and the streak's `combo` is a tick climbing 5 (a pluck climbing 14) |
| `nonogram` | done 2026-10-10, unheard: 14 new takes (4 ticks with the `pebbles` a wheel's four notches, 3 breezes with the `petals` and the `leaves` a long breath each, 5 phrases, and the `bee` and `bloom` two quiet notes and one), `enter` place's take five in a row, `mushroom` One Line's, `confetti` Binairo's, 8 kept; nothing is ceramic any more (`place` and `undo` had come out 20 and 90 ms long); the streak's `combo` is a tick climbing 5 (a pluck climbing 14) |
| `queens` | done 2026-10-10, unheard: 15 new takes (4 ticks, 3 breezes with the `mist` and its lifting a long breath each, 5 phrases, and the `drone`, `bloom` and `buzz_off` two quiet notes up, one, and two down), `enter` place's take five in a row, `confetti` Binairo's, `check` Code Break's, `heart_lost` Nonogram's, 6 kept (`locked` six steps up with its rumble off); nothing is a wing or a buzz any more; the sweep already climbed under 5 semitones and the streak's `combo` is a tick climbing 5 (a pluck climbing 14) |
| `hiddenword` | done 2026-10-10, unheard: 11 new takes (4 ticks, 1 breeze, 5 phrases and the `sprout` one quiet note), `post` flip's take, `enter` type's take five in a row, the `snail` three slow notches and `snail_hurry` four quick ones of the same take, `confetti` Binairo's, 12 kept; nothing is paper any more (a key, a card's flick, an envelope and a brush sat above 3 kHz) and the snail is never a slide; `flip` already climbed under 5 semitones and a green letter's `combo` is a tick climbing 4 (a pluck climbing 9) |
| `wordtrail` | done 2026-10-10, unheard: 16 new takes (3 ticks, 3 breezes with `quick` and the `wish` a small puff each, 6 phrases with `place` four quick notes up, `bloom` four quiet notes, and `flutter`, `wish_low` and the `lantern` two quiet notes up, two down and one), `enter` select's take five in a row, `confetti` Binairo's, 12 kept (`conga` five steps up and `miss` six with their rumble off, `dance` and `reveal` rolled off); nothing is paper, a ribbon or a glockenspiel any more; `select` climbs 5 semitones (it was 8), a word's `combo` is a tick climbing 5 across the game (a pluck climbing two octaves) and `reveal` stops falling at 5. `combo` is cut at 0.055 s: two takes each held a second tock 60 ms behind |
| `mushroom` | done 2026-10-10, unheard: 16 new takes (5 ticks with `reach` the quietest at -18, 3 breezes with the `rings` a long breath and the `sneeze` a small puff, 5 phrases, `meadow` four quiet notes, `bloom` one and `rings_glow` three slow ones that rise and settle), `enter` place's take five in a row, `undo` remove's twice and falling, `wilt` remove's three notches down, `confetti` Binairo's, 8 kept (`twirl` rolled off); nothing is moss, a glockenspiel, a celesta or a slide whistle any more; the streak's `combo` is a tick climbing 5 (a pluck climbing 14), cut at 0.07 s ahead of a second tock. The `sneeze` is no longer a sneeze (`CARTOON` is not a model): the user's call |
| `sudoku` | done 2026-10-10, unheard: 13 new takes (3 ticks with `pencil` a lighter thing at -17, 2 breezes with the `hills` a long breath, 5 phrases, `all_home` four quick notes, `bloom` one and `hills_glow` three slow ones that rise and settle), `enter` place's take five in a row and `boing` three (up and back a step), `undo` pencil's twice and falling, `tumble` pencil's three notches down, `check` Code Break's, `confetti` Binairo's, 9 kept (`check_ok` and `heart_lost` rolled off, `ruled` six steps up with its rumble off); nothing is a pencil, paper, an eraser, a glockenspiel, a music box, a celesta, a rubbery boing or a slide whistle any more; the streak's `combo` is a tick climbing 5 (a pluck climbing 14), cut at 0.07 s ahead of a second tock. `pencil` took five takes for one tock from 0 ms |
| `bridges` | done 2026-10-10, unheard: 13 new takes (3 ticks, 3 breezes with the `lanterns` a long breath and the `fish` a small puff, 5 phrases, `join` two quiet notes alike and a third up, and `lanterns_glow` three slow ones that rise and settle), `enter` place's take five in a row, `undo` remove's twice and falling, `sink` remove's three notches down, `ruled` join's take as one quiet note (it was a bell), `check` Code Break's, `confetti` Binairo's, 11 kept (`met`, `twirl` and `heart_lost` rolled off, `met` 2 dB down; the `boat` passed as it was); nothing is a plank's creak, a drip, a bloop, a bell, a glockenspiel, a music box or a celesta any more; the streak's `combo` is a tick climbing 5 (a pluck climbing 14). The `fish` is no longer a splash (`CARTOON` is not a model): the user's call |
| `quilt` | done 2026-10-10, unheard: 12 new takes (4 ticks with the `button` a bead pressed home, 2 breezes with the `flutter` a small puff, 5 phrases and the `row` four quick quiet notes up), `enter` place's take five in a row and `boing` three (up and back), `undo` lift's twice and falling, `wiggle` lift's two notches and `snip` lift's one, four steps up, `ruled` row's take as one quiet note (it was a chalk scratch), `love` row's as two notes alike and a third up (the bubbly pops sat at 1 kHz however they were rolled off), `confetti` Binairo's, the cat Untangle's kitten, 6 kept (`heart_back` and the `bunting` rolled off; the bunting keeps its first prompt, cloth flags and all, and passes the measure); nothing new is cloth, thread, a needle, scissors, chalk, a glockenspiel or a music box; the streak's `combo` is a tick climbing 5 (a pluck climbing 14). `place` is one tock and no longer a pat and its stitches; the wrong patch goes home on a puff of air, not a flap: the user's call |
| `planes` (Paper Planes) | done 2026-10-10, unheard: 13 new takes (2 ticks, 6 breezes with `place` a small puff on every launch, `enter` a long breath, the `gust`, `drift` the quietest at -19 and `stuck` the breeze settling, 4 phrases and the `loop` four quiet notes up and over), `whoosh` place's take, `flutter` crash's three notches down, `tweet` and `love` loop's as two quiet notes up and two alike and a third up, `confetti` Binairo's, the cat Untangle's kitten, 7 kept (`flock` rolled off, from its finished file: the first set's takes were not kept; `undo`, `hint` and the `clouds` keep their first prompts, a paper rustle and a music box in them, and pass the measure); nothing new is paper, a music box or a bird (the chirp sat whole above 3 kHz; the first `place` was a breath at 19 Hz a phone did not play); the streak's `combo` is a tick climbing 5 (a pluck climbing 14). `place`, `drift` and the `gust` took two to four takes each for one that was not a scratch or a rumble. The bird is two notes and the crash a tock: the user's call |
| `pinwheel` | done 2026-10-10, unheard: 12 new takes (3 ticks with `place` one notch a quarter turn and `snag` a light one, 4 breezes with the `whirl` a gust, the `kite` a long breath and the `ribbons` the breeze easing, 4 phrases and the `flutter` two quiet notes up), `enter` place's take five in a row, `undo` snag's twice and falling, `tack` snag's two notches and `tug` snag's one, two steps down, `love` flutter's as two notes alike and a third up, `confetti` Binairo's, the cat Untangle's kitten, 4 kept (`refused`, `hint`, `heart_lost` and `heart_back` as they were; `hint` keeps its first prompt, a music box in it, and passes the measure); nothing new is paper, linen, thread, a needle, a ribbon, a music box or a whistle; the streak's `combo` is a tick climbing 5 (a pluck climbing 14). The first `place` and `snag` each held a second knock and were taken again, `combo` took three takes, and the first `whirl` and `kite` came back a scratch and a rumble. The pinwheel's turn is one tock and no longer a whirr; the wrong turn's snag and its stitch are notches: the user's call |
| `caterpillar` | done 2026-10-10, unheard: 13 new takes (4 ticks with `munch` two low notches on every leaf, 1 breeze, the butterflies' `flutter` a small puff, 5 phrases, the `row` four quick quiet notes up and the `ladybug` three, up and back a step), `enter` place's take five in a row, `slip` undo's one notch, two steps down, `love` and `burp` row's as two notes alike and a third up and one quiet note, `fill` and `hungry` the ladybug's as two quiet notes up and two low ones alike, `reset` Pinwheel's take (four here each came back a scratch), `confetti` Binairo's, the cat Untangle's kitten, 4 kept (`refuse`, `strand`, `heart_lost` and `heart_back` as they were); nothing new is a leaf, a crunch, a bubble, a buzz, a wing, a music box or a party blower; the streak's `combo` is a tick climbing 5 (a pluck climbing 14), cut at 0.055 s ahead of a second tock (three takes). `hint`'s take came back at 247 Hz, so its notes are 9 to 16 steps up. The nibble is two tocks, the burp one note and the tummy's rumble two (`CARTOON` is not a model): the user's call |
| `sunbeam` | done 2026-10-10, unheard: 12 new takes (3 ticks with `slide` one tock as the piece is let go, 3 breezes with the `sizzle` a small puff and `slip` the breeze easing, 5 phrases and the `dew` one quiet note), `step`, `undo` and `stir` lift's take (one notch at -19 on every peg, twice and falling, one three steps down), `drop` and `enter` slide's (two steps down, and five in a row), `rainbow`, `love`, `flutter` and the `chorus` the dew's (four quick notes up and over, two alike and a third up, two up, three all but together), `confetti` Binairo's, the cat Untangle's kitten, 6 kept (`dry`, `refuse`, `shy`, `wake`, `heart_lost` and `heart_back` as they were; `shy` keeps its first prompt, a glass twinkle in it, and passes the measure); nothing new is brass, glass, a chime, a music box, steam or a wing; the streak's `combo` is a tick climbing 5 (a pluck climbing 14) and the `dew` climbs a semitone a drop lit, 5 at most (it was 0.08 a drop with no end, 5.8 on six drops). `slide` took five takes for one tock (four held a second knock or came back high), the `sizzle` four and `reset` two; the dew's take came back at 295 Hz, so its notes are 6 to 13 steps up. `step` has a file again, the quietest there is (the set's comment said it got none while the old file, 98% above 3 kHz, played on every peg); the piece let go is a tock and no longer a glide, a drop dried a puff and no longer steam: the user's call |
| `knight` | next |
| `snooker`, `hockey`, `chess`, `checkers`, `hedgehogs`, `slider`, `marigold`, `pixelgarden`, `fairylights`, `firefly`, `molehill`, `stackwood`, `thirteen`, `posy`, `peapod`, `rings`, `drumbeat`, `trestle`, `minigolf`, `horse`, `lattice`, `how_big`, `acorn`, `pearl`, `boats`, `penny`, `dominoes`, `reversi`, `wallet`, `grove`, `nightlight`, `beeline` | not started, in this order |

**What other games do** (looked up 2026-10-09; little is written down, and
none of it outranks the user's ear). Unpacking's foley, the genre's
reference: real things recorded, never one thing standing in for another;
pick-ups short and immediate so the hand never feels late; when two
materials meet the softest decides the sound; several takes a sound so a
repeat is never identical. UI sound guides: a tap is 30 to 150 ms, with no
peak that tires an ear over hundreds of presses and nothing piercing on a
small speaker. Lofi production guides: the top rolled off somewhere from 5
to 10 kHz on a gentle slope (ours is far lower, by the user's word).

## Sound

Sounds are generated with ElevenLabs by `tools/gen_sfx.py <puzzle_id>` into
`assets/sfx/<puzzle_id>/<cue>.ogg`, and `Fx2D.cue()` plays whichever cue has
a file -- a missing file is silence, on purpose. How a board's set is chosen
and generated: `docs/art/sound-direction.md`. Never a buzzer; up means good,
down means not yet;
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
