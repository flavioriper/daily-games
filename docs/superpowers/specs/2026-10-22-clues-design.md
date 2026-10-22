# Five Clues: a words board

2026-10-22, roadmap item 9 (`docs/roadmap-next-boards.md`), built with Four
Shelves once the user allowed the functions deploy. The genre is the daily
clue-category puzzle (LinkedIn Pinpoint); that name is not used anywhere.
The board is **Five Clues**, id `clues`, locale prefix `FC_`.

## 1. The game

Five clue cards are pinned face down to a cork board on the garden shed's
wall; the first is turned. Each names a thing that belongs to one hidden
idea, the least telling first. Type the idea on Hidden Word's keyboard (the
host's `"tray": "keys"`, as Pearl Dive) and Enter:

- right: the idea is chalked on the slate, the cards hop, and every card
  turns; Enter (or a tap on the slate) goes to the next round;
- wrong: the line shakes and the next card turns;
- Enter on an empty line turns the next card without a guess;
- a line already said is refused, free;
- a wrong line with all five up loses the round ("It was: ...").

Every round done is the day (a lost round still ends; it scores nothing).
The bulb shows the idea's next letter on the slate (3/2/1/1). A typed line
is judged as the server judges it (`accepts`): folded to lower-case letters
with no accents or spaces, it is right when it is one of the round's
accepted key words or holds one of four letters or more (a last "s" may be
left off).

## 2. Bands

| | rounds | ideas | rule |
|---|---|---|---|
| Easy | 3 | everyday | |
| Medium | 3 | everyday, misleading first clues | |
| Hard | 4 | subtle | |
| Insane, **Three Tries** | 4 | subtle | a round also ends after three wrong lines |

## 3. The day, written at night

`server/functions/src/clues.ts`. Haiku writes 5-6 rounds a band in
en/pt/es, each clue a plain noun that belongs to the idea, and 3-8 key words
per language that alone tell the idea apart; a clue the key words accept is
refused (it gives the round away). Opus names every language's idea blind
from the five clues; a round stands only when the game accepts that guess in
all three, sure, no issue, and past Easy not sure from the first clue. A
band short of rounds is asked once more, then the bank fills it. Told the
last ten days' ideas. A day takes 3½-5 minutes.

The bank (`content/clues.json`, three tiers: easy, medium, hard; Hard takes
the hard tier's head and Insane its tail) is ordered by the same double FNV
hash on the server and the phone.

## 4. Sound, touch, brain

Pops from the bank (set `clues`); haptics row 28l. Words. Timed.
`skill_quality()` is the mean over rounds of the cards not needed, out of
four (a round found on the first card is 1, on the fifth 0, lost 0). Share:
🔎 and a row a round, a white square a card turned before the green one.

## 5. Decided for the user, unconfirmed

Typed answers matched by key words (the original's loose matching is a
model's); lost rounds still finish the day; the bulb as letters; Three Tries
as Insane; the shed and cork look. Typed matching is the risk: a fair guess
the key words miss reads as wrong. Unheard, unread in pt/es by a speaker,
not on a phone.
