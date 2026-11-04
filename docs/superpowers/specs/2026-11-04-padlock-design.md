# Padlock

2026-11-04, the second of the five word boards in `docs/roadmap-word-boards.md`
(the user: "let's tackle the next docs/roadmap-word-boards.md item. Make sure
to wire it properly with sounds, animations, fully polished user player
experience like the others wording games ... Do it autonomous, commit to main
when done"). Built straight from the roadmap's entry, unattended, with no
concept tab first, as Cross Stitch was.

The genre is a letter-column word slider; its best-known version is named
once in the roadmap, to forbid it, and never in code, comments, commits or
on screen.

## The board

- **A brass combination padlock** hanging on a garden shed door. Its face
  holds a row of letter dials, one per letter of the band's word length;
  each dial is a strip of letters that slides up and down behind a glass
  window across the middle. The window row is the word dialled.
- **Slide a dial** by dragging it (it rides the finger, ticks a notch per
  letter that crosses the window, and settles on the nearest letter with a
  spring), or **tap a letter** to bring it to the window.
- **A word**: when the window spells a word the lock knows, its letters
  light gold on their dials (a lit letter stays lit), the word drops onto a
  brass tag on the key ring under the lock, and the board says it.
  A word that lights nothing new is still found and tagged, but plain.
- **The solve**: every letter on every dial lit. The shackle springs open.
- **No fail state**: the day cannot be lost; it can be done in fewer words.

## Words

Banks per band and language (`tools/build_padlock.py`,
`content/insane/padlock_<band>[.lang].json`, read through `InsaneBank`).
A lock is a handful of common words (the seeds) stacked letter by letter;
dial k holds their k-th letters, each once, shuffled. Every word the dials
spell is looked up in wordfreq's list for the language (zipf 1.8 and up,
pruned by the Hunspell dictionaries, the LDNOOBW lists, a house list of
rude words, stems and names); those are the words a lock credits. The fair
ones (zipf 2.9 and up) are what the bulb offers, and the fewest fair words
that light every letter (solved exactly by set cover) is the lock's **par**.
No dictionary ships: each lock carries its own words.

## Stars

A word counts when it lights at least one new letter (exploring is never
punished). Stars on the tools row's pill read what the way stands at: the
words counted plus the fewest still needed (solved live over every
credited word, so a rare word may beat par), against par: 3 within one word over par (`STAR_THREE`: dials turn one at a
time, so the window may spell a word on the way to the one meant, CHILL
before CHILI, and that word counts), 2 within three (`STAR_TWO`), 1 after. The pill also says how many
letters are still dark.

## Bulb, two presses

The first (one hint) picks the next word on a fewest path among the fair
words not found, rings its first letter and every dark letter it would
light, and says how many it lights; the second turns every dial to it,
free (not counted for the stars, counted in `quality()`).

## Bands

| Band | Letters | Seeds | Par | Hints | Rule |
|---|---|---|---|---|---|
| Easy | 4 | 4 | 3-4 | 3 | |
| Medium | 5 | 5 | 4-5 | 2 | |
| Hard | 6 | 5 | 4-5 | 2 | deeper dials |
| Insane, *Rusty Lock* | 6 | 6 | 5-6 | 1 | one dial only turns down |

**Rusty Lock**, as the roadmap has it: one dial (the deepest, rust on its
brass) slides only down. Pushed past its last letter it springs back round
to its first with a creak, so every letter can still be reached, in order;
pushed up it refuses. A tap on a letter below the window turns it down to
it; a tap above is refused and says how to come round.

## Motion and sound

Enter: the dials drop in left to right (token run), the shackle settles.
Drag: the strip rides the finger, one pebble notch per letter crossing the
window (the run rides the motion), pitch by dial. Settle: a spring
(`Motion.back_out`), the lip. Word: the window letters hop left to right,
gold rings, the tag swings onto the ring (wraps rising; higher the more
letters lit). Nothing new: one quiet wrap, the tag plain. Not a word: no
sound, nothing (dialling is free). Rusty refusal: shiver, tongue. Star
lost: the lip falling. Win: the shackle springs up, the lock swings on the
hasp, confetti; party when at par with no bulb. Every cue a pop from
`tools/sfx_bank/` (set `padlock` in `tools/gen_sfx.py`); hint, solved,
confetti and party are Honeycomb's raw takes, never bought. All unheard.

## The world

A garden shed door of painted planks edge to edge, an iron hasp and staple
bolted across it, the padlock hanging from the staple by its shackle; a
key ring hung from a nail under it carries the found words' tags; ivy at
one edge and a watering can at the foot.
