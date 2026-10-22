# Birdsong: a Memory board

2026-10-22, built unattended (the user: "start next roadmap daily puzzle, do
everything autonomous, wire animations, sounds, everything to make it fully
playable and complete like other games"). Roadmap item 2
(`docs/roadmap-next-boards.md`); the mock is the roadmap page's
(`docs/brainstorm/next-daily-boards.html`), so there is no concept tab, as
with Glimpse.

The genre it follows is the electronic colour-and-tone memory toy (Simon).
That name is never used in code, comments, commits or on screen: the board
is **Birdsong**.

## 1. The game

A little bird sits on the old tree's branch over a row of Drumbeat's drums
on the lawn. It sings a tune on the drums; when it stops, the player taps
the drums in the same order. Each round the tune is one note longer. The
day's whole tune played back is the solve.

- A **slip** (a wrong drum) costs nothing but the round: the bird is
  puzzled, sings the round again, and the player starts it over. Nothing
  can be lost on any band (house rule: only Insane can be lost, and Insane
  counts nothing).
- **The bulb** has the bird sing the round again, all of it.
- **No Undo** (a note heard cannot be unheard), **no Check** (nothing on the
  board is ever wrong). The bin starts the day from its first round.
- A tap while the bird sings is a soft shush and plays nothing.

## 2. Bands (`puzzles/birdsong_state.gd`)

| | drums | tune | first round | seconds a note | bulbs |
|---|---|---|---|---|---|
| Easy | 3 (big, hand, tongue) | 5 | 1 note | 0.62 | 3 |
| Medium | 4 (+ jingle) | 7 | 2 notes | 0.55 | 2 |
| Hard | 4 | 9 | 3 notes | 0.46 | 1 |
| Insane, **Whisper** | 4 | 9 | 3 notes | 0.50 | 1 |

**Whisper** (Insane's own rule, harder by memory, not by a limit): after the
first round the bird sings only the round's new note; the rest of the tune
is the player's to hold. A slip or the bulb has it sing the whole round.

The tune is dealt from the host's rng (the day's seed, per band), never one
drum three times running.

## 3. The screen

A bleed board (`"bleed": true`, `"tray": "none"`, `"actions": false`,
`"level_card": true`). From the top of the span: the branch and the bird;
the words (Listen… / Your turn! / Lovely! / Once more…); the song's row (a
ring for each note of the round, a berry in it for each note played back, a
faint dot for each note the day still holds; the sung note's slot lights
with its berry while it rings); "Round n of N"; the drums on the lawn.

The world (`puzzles/birdsong_world.gd`): a spring morning, cream sky over
the rows clearing to a pale blue at the hills, a low sun, the old tree's
trunk at the left edge with its leaves over the top, daisies on the lawn.

The bird is new (`ui/faces/songbird.gd`: it is the mechanic, as Queens'
bee); the drums, their marks and the berries are Drumbeat's. A lit drum is
a ring of its light shade and a bump, never a darker or lighter drum (the
coloured-by-index rule). Each drum also has its mark on its skin.

## 4. Sound and touch

Notes are Drumbeat's four drum voices (one felt skin at four pitches), as
`note_k` (sung, unmapped haptics) and `drum_k` (struck, a tap). The rest are
Glimpse's takes copied, none bought: `slip` and `hush` the tongue, `round`
the plate flourish, `grow` the bubble, `hint` the puff, `reset`, `enter`,
`solved`, `confetti`, `party` (a day with no slip), `purr`.

## 5. Brain report

Memory. `skill_quality()` = rounds played back with no slip / rounds. The
board is in `Brain.UNTIMED`: its time is the bird's pace. Tips
`BRAIN_BS_1..4`. Share line: 🐦 and a square a round (green clean, yellow
after a slip).

## 6. Decided for the user, unconfirmed

- The bands' numbers above, Whisper as Insane's rule.
- Easy starts at one note; Hard and Insane start at three.
- The words over the row; "Round n of N" under it.
- The world's morning garden and the tree at the left.
- Struck and sung notes are the same voice (two file names).

## 7. Amendment, 2026-10-22 evening: the woodpecker

The user: "redesign the bird game, instead of using drums, let's change the
bird to a woodpecker, and the minigame can be just a single drum that has
to follow the same pattern from the woodpecker on hitting the wood". The
reference was another game's tree mini-game (a tree hums a rhythm in one
four-beat bar, the player repeats it on one button in the next); it is
named nowhere. Concept tab `docs/brainstorm/concepts.html#woodpecker`; the
user's verdict on it: "all great, build it fully", which took every
recommendation on the page. Sections 1 to 6 above are history where they
disagree with this one.

- **The game.** A woodpecker clings to the old tree's trunk and knocks a
  rhythm inside one bar of four beats, a quiet pebble on each beat under
  it. The player knocks the same rhythm back on one drum, the big drum.
  The day is one rhythm: each round adds one knock somewhere in the bar
  (the day "fills up"), and the whole rhythm knocked back is the solve.
- **Judged between the player's taps.** The first knock starts the bar;
  the rest are held to their places from it (good within 90 ms, fine within
  170 ms). A missed place, an extra knock or one too far off is a slip:
  nothing lost, the woodpecker knocks the round again. No per-phone timing
  is needed, as a phone's sound delay is the same on every tap.
- **Bands** (`puzzles/birdsong_state.gd`):

  | | bpm | slots | knocks | first round | rounds | holes on the card | bulbs |
  |---|---|---|---|---|---|---|---|
  | Easy | 88 | 8 | 5 | 2 | 4 | while it knocks and on your turn | 3 |
  | Medium | 96 | 8 | 6 | 3 | 4 | while it knocks | 2 |
  | Hard | 104 | 16 | 7 | 3 | 5 | never | 1 |
  | Insane, **Feints** | 100 | 16 | 7 | 3 | 5 | never; twice a bar it draws back without striking | 1 |

  On sixteen slots one or two quick knocks sit on the "and" of an eighth
  already knocked (a pair, or a triple), never added before that eighth.
  Whisper is gone.
- **The screen.** The trunk at the left (`World.trunk_edge`), the
  woodpecker on its right side (`ui/faces/woodpecker.gd`, a body and a head
  mesh so a peck is a transform), the words beside it, the knock card (the
  woodpecker's lane in bark with its holes, the player's lane with a red
  berry for each knock where it landed, ringed green good / gold fine; a
  playhead through each bar; dashed rings where knocks were missed after a
  slip), "Round n of N", and the drum on the lawn: anywhere under the card
  knocks it.
- **Sound.** `peck` the bank's token a step up, `tick` the pebble quiet,
  `feint` the lip, `drum` Drumbeat's `drum_0`; the rest as before. `note_*`,
  `drum_1..3` and `grow` are gone.
- **Title** stays Birdsong; the id, saved progress, Memory and
  `Brain.UNTIMED` are unchanged. Share line: 🪵 and a square a round.
- **Unconfirmed:** the windows, the tempos, the feints, the look, the
  sounds heard, a phone.
