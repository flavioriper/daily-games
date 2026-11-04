# Stepping Stones

2026-11-04, the fourth of the five word boards in `docs/roadmap-word-boards.md`
(the user: "let's tackle the next docs/roadmap-word-boards.md item. Make sure
to wire it properly with sounds, animations, fully polished user player
experience like the others wording games ... Do it autonomous, commit to main
when done"). Built straight from the roadmap's entry, unattended, with no
concept tab first, as Cross Stitch, Padlock and Biscuit Tin were.

The genre is the word ladder; its best-known daily versions (Weaver,
Crossclimb) are named here once, to forbid them, and never in code,
comments, commits or on screen.

## The board

- **A brook** runs across the screen between two grassy banks. On the near
  bank (top) a flat slab bears the start word; on the far bank (bottom)
  another bears the word to reach.
- **A stone is a word one letter from the one before** (same length, one
  letter changed in place). Type it on the phone's own keyboard (Five
  Clues' unseen `LineEdit`, `"tray": "none"`): the letters appear on the
  wet stone waiting under the last one, and the moment the line holds the
  band's length it is judged (Enter judges sooner). Laid, the stone drops
  into the brook with a splash ring, under the one before.
- **Crossing**: a stone one letter from the far bank's word ends the
  crossing by itself (the player steps onto the bank); typing the far
  bank's word when the last stone is one letter from it does the same.
- **Letters that already match the far bank** in place stand on a patch of
  moss, on every stone and the near bank, so the way reads at a glance.
  The letter a stone changed is inked darker gold.
- **Refusals**, each a shiver of the waiting stone, a tongue and a line
  said under it: not a word the brook knows; not one letter from the last
  stone (the line says how many letters differ, since a phone keyboard
  can autocorrect); already a stone (or a bank) on this way.
- **Undo** lifts the last stone out (lip), **the bin** (asks) lifts them
  all. Stones lifted cost nothing: the count is the stones on the way when
  the crossing is made.
- **A dead end**: a laid stone with no way on over the fair words says so
  ("hard to go on from X: Undo takes it back"); the bulb knows it too.

## Words

`tools/build_stones.py` reads Biscuit Tin's pruned wordfreq list (Hunspell
checked, rude words, stems and names out; the build's cache dir) and writes
`content/stones_<4|5>[.lang].json`: `fair` (zipf 2.9 up, commonest first:
the par, the bulb and the dead-end check walk on these), `more` (zipf 1.8 to
2.9: a stone may be one), `shown` (accents). Five-letter bands also accept
Hidden Word's accept list (`content/hidden_word_accept*.txt`), so a real
word a player knows is never refused there (the roadmap's call). Typed
words fold as Hidden Word folds (accents off, Ñ kept in Spanish).

Banks: `content/insane/stones_<band>[.lang].json`, 365 a band a language,
read through `InsaneBank`. A crossing is two common words (zipf 3.5 up)
whose fewest stones over the fair words is in the band's range, all their
letters different (Easy and Medium; Hard and Insane one may match), with
two shortest ways at least. Each carries `par`, `route` (one shortest way
through the commonest words), `ways` and Easy's `given`.

## Stars and quality (Market Sums' metric, one stone kinder)

The stars on the tools row's pill read the way as it stands: the stones
laid and the fewest still to go from the last. 3 up to par + 1, 2 up to
par + 3, 1 after. The pill says "Par N" and the stones laid. The brain
score is par over the stones (a stone the bulb laid counted twice); a party
on the solve at par with no bulb.

## Bulb, two presses

The first press (one hint) rings the letter of the last stone to change on
a fewest way and says which (from a dead end: the stone to go back to). The
second lays that stone (from a dead end, after lifting the stones past the
one named). When the bulbs run out the host offers one more for a video.

## Bands

| Band | Letters | Par stones | Hints | Rule |
|---|---|---|---|---|
| Easy | 4 | 3 | 3 | the middle stone given |
| Medium | 4 | 4-5 | 2 | |
| Hard | 5 | 4-5 | 2 | |
| Insane, *Slippery* | 5 | 4-5 | 2 | a swap of two letters side by side is a stone too |

**Given** (Easy): the middle stone of a shortest way sits mossy at the
brook's side; a stone one letter from it calls it into the way, where it
slides into place. Undo lifts it back with the stone that called it.

**Slippery** (Insane): a stone may also be the one before with two letters
side by side swapped (TRIAL, then TRAIL). The par counts
swaps, and a shortest way takes one.

## Motion and sound

Enter: the banks' slabs and the far bank pop in, the waiting stone ripples
(a token run). Type: a token, pitch wobbling; erase: a lip. Lay: the stone
drops in, a splash ring and a puff (token low and a wrap). The given stone
joining: tokens rising. Refused: shiver, tongue twice falling. Again: lip
twice. Undo: the stone lifts and fades (lip falling); clear: lips falling.
A star lost: a low lip. Crossing: the stones hop near to far in a wave
(wraps rising a step a stone), the far bank's slab hops, a gold ring,
sparkles, confetti; party at par with no bulb. Every cue a pop from
`tools/sfx_bank/` (set `stones` in `tools/gen_sfx.py`); hint, solved,
confetti and party Honeycomb's raw takes, never bought. All unheard.

## The world

The brook edge to edge: a pale meadow bank under the host's rows (the
wordmark reads as ink on it), water with a lighter current streaked across
and reeds and pebbles at its edges, the far bank's grass at the foot (above
the phone's keyboard when it is up). The current's streaks drift on the
board's own clock (`_process`, so a resting game keeps them still).
