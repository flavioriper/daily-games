# Four Shelves: a words board

2026-10-22, roadmap item 4 (`docs/roadmap-next-boards.md`), built once the
user allowed the functions deploy ("I allow you to deploy backend functions,
do it"). The genre is the daily word-grouping puzzle (NYT Connections);
that name is not used in code, comments, commits or on screen, nor its
phrases. The board is **Four Shelves**, id `shelves`, locale prefix `FS_`.

## 1. The game

Jam jars stand on an old painted dresser in a pantry, a word on each jar's
label. Every word belongs to exactly one hidden shelf of four. Tap four jars
(each rises in a sun halo) and press the tick:

- four of one shelf rise to the top free row of the dresser, where a board in
  the shelf's colour names the shelf and its words;
- anything else costs a heart (four a day); three of one shelf are said to
  be close ("Three of those go together");
- the same four twice is refused and costs nothing.

Clear puts the picks back, Shuffle stands the jars anew. Every shelf up is
the day. **Out of hearts**, the house card (`ui/hud/out_of_rows.gd`, Word
Trail's) offers one more heart for a video, once a board, or **Show the
shelves**: the rest go up by themselves and the day ends unsolved
(`finish_unsolved`, the host's `out_of_hearts` path). The bulb picks the
next word of the clearest shelf still down (3/2/1/1 a day).

## 2. Bands

| | shelves | words |
|---|---|---|
| Easy | 3 | 12, plain ideas |
| Medium | 4 | 16, the last subtler |
| Hard | 4 | 16, two subtle shelves, many red herrings |
| Insane, **Crowded Pantry** | 5 | 20 |

## 3. The day, written at night

`server/functions/src/shelves.ts`, on Golden Acorn's contract (one line in
`GAMES`). Haiku writes three puzzles a band in en/pt/es; Opus sorts every
language's shuffled words blind, and a puzzle stands only when the sorting
is the writer's in all three, sure, with no issue. A plain shelf keeps its
idea across the languages; **a subtle shelf built on a double meaning gets a
native idea in each language** (the first Insane runs were all turned down
as "translation": "things with keys" is two words in Portuguese). Told the
last ten days' shelves. A day takes about five minutes on this Mac.

The bank (`content/shelves.json`, 24 a band, grown by `node lib/cli.js bank
shelves <band> <count> [file]`) answers a band the model could not write and
a phone that never reached the day: `bankPick` / `State.bank_pick` take the
puzzle whose double FNV hash of the day and id is least, the same on both.

## 4. Sound, touch, brain

Pops from the bank (`tools/gen_sfx.py` set `shelves`); haptics row 28k.
Words. Timed. `skill_quality()` is 1 - a quarter a mistake, 0 when the
shelves were shown. Share: 🫙 and a row of squares a guess, a colour a shelf.

## 5. Decided for the user, unconfirmed

Four hearts on every band; the close line; one more heart by video; Show
the shelves ends the day unsolved (no win screen, as Word Trail); the bulb
picks words rather than naming a shelf; Crowded Pantry as Insane; the jar
look. Unheard, unread in pt/es by a speaker, not on a phone.
