# Honeycomb: a words board

2026-10-22, built unattended (the user: "start next roadmap daily puzzle, do
everything autonomous, wire animations, sounds, everything to make it fully
playable and complete like other games"). Roadmap item 8
(`docs/roadmap-next-boards.md`); items 4 and 9 still wait on the user's
functions deploy, 12 needs new art. The mock is the roadmap page's
(`docs/brainstorm/next-daily-boards.html`), so there is no concept tab, as
with the boards built before it today.

The genre it follows is the seven-letter word comb (Spelling Bee). That name
is used nowhere in code, comments, commits or on screen, nor are its rank
names or its word for a seven-letter find: the board is **Honeycomb**, a
word using all seven letters is a **full comb**, and points are **honey**.

## 1. The game

Seven letters on a comb of wax cells, the queen bee sitting on the middle
one. Tap the cells to spell a word, then the tick key to send it:

- four letters or more, letters used as often as you like;
- every word holds the middle letter (the queen's);
- a word is one of the language's word list (below).

A word taken flies up into the honey strip at the top and pours its honey:
one for four letters, its length past that, seven more for a full comb. **The
day is done when the honey reaches the band's line**, a share of all the
honey the day's words hold. That is the win the host needs (the genre has
no end of its own); every banked hive is proven fillable.

Refusals are a toast over the count line and a shiver of the word, never
silence: too short, no middle letter, not in the list, already in the jar.
Under the comb, three round keys: take a letter back, shuffle the six outer
letters, send. The bulb spells the first half of a day's word not yet found
(never a shy one, below) and shows the rest as dots. The bin (tools row,
with its confirm) empties the jar and starts the day over. No Undo: a word
found is never taken back.

## 2. Bands

| | the day's words | words a hive holds | line | bulbs |
|---|---|---|---|---|
| Easy | tier 0 (zipf ≥ 3.3) | 16-34 | 20% | 3 |
| Medium | tier ≤ 1 (zipf ≥ 2.9) | 26-48 | 28% | 2 |
| Hard | tier ≤ 2 (zipf ≥ 2.5) | 34-58 | 36% | 1 |
| Insane, **Wandering Queen** | tier ≤ 2 | 30-52, each letter ≥ 9 | 36% | 1 |

Words of tier 3 (zipf ≥ 1.5, still in the dictionaries) are taken and
scored on every band but never counted toward the line or hinted, so a
player who knows a rare word is never told it is not one.

**Wandering Queen** (Insane's own rule): every four words found the queen
flies to another cell (`flight`, an order fixed per hive), the two letters
trade cells so hers is in the middle again, and the words after must hold
her new letter. She also flies when her letter has no day's word left, so
the day can never stick. The line is a share of the first queen's honey.

## 3. The words (`tools/build_honeycomb.py`)

Built on the Mac, per language, into `content/honeycomb.json` (`.pt`,
`.es`): wordfreq's lists (CC-BY-SA 4.0, attributed in each file's `note`,
the pt/es precedent of Hidden Word), kept only where a LibreOffice Hunspell
dictionary takes the word as written (en_US or en_GB, pt_BR, es_ES), which
drops names and places written with a capital; then folded the way Hidden
Word folds (accents off, Ñ a letter in Spanish), four letters or more, no S
(as the genre does, so plurals do not pad a day), seven different letters at
most, no Roman numerals. The dictionaries and the LDNOOBW rude-word lists
prune at build time and nothing of theirs ships. A rude word is tier 3:
taken if typed, never a day's word, never the bulb's. A **shy** word (a
day's word the same dictionary also has as a capitalised name or place:
Amanda, Argentina) is counted when found but never hinted and never a
hive's full comb. Each word ships its letter mask; `written` keeps its
accents for the jar's list.

Hives: every comb's letters come from a full-comb word of the band's tier,
a queen chosen among the letters whose count of day's words falls in the
band's window; 366 a band a language in `content/insane/honeycomb_<band>`
(`honeycomb.json` for Insane), picked through `InsaneBank`'s fixed shuffle,
so a year passes before a hive comes back. A comb's letters serve one band
each queen; on the few days two bands' shuffles meet on one comb's letters,
the higher band takes its next hive (`State.deal`). Nothing is dealt on the
phone: the board reads its hive and filters the list by mask (2 ms; the list
loads once a session in 11-21 ms).

## 4. The screen

A bleed board (`"bleed": true`, `"tray": "none"`, `"actions": false`,
`"level_card": true`): from the top of the span, the honey strip with
"honey / line" on it, the words found in rows (alphabetical, accents back,
smaller as they grow, the rest counted past what fits), the word being spelt
(the queen's letters in deep honey, a caret while empty), the comb, the
keys and the count line ("12 words", and on Insane "she flies in 3").

The world (`puzzles/honeycomb_world.gd`): a warm sky and soft sun over far
hills, a summer meadow mown paler round the comb, clover and daisies,
lavender at the sides, a straw skep on a stand at the foot. Two small worker
bees loop slowly round the comb. The cells, the queen, the keys and the
strip are `ui/faces/honeycomb_art.gd`.

Motion: the cells pop in one after another as the board enters and on the
bin; a tapped cell bumps under a sun flash and its letter pops onto the
word; a word taken flies up and shrinks into the strip, which swells, with
"+n" floating off it; a full comb rings every cell; a refused word shivers
and fades; Shuffle slides the letters to their new cells; the queen's flight
is out to the cell of her next letter on an arc, then the trade brings both
letters home; on the win the cells hop in a wave. Under reduce motion
nothing pops, shivers, slides, drifts or hops.

## 5. Sound and touch

Every action is a pop from the bank (`tools/gen_sfx.py` set `honeycomb`):
`tap` the pebble pitched up a letter at a time, `delete` the lip, `shuffle`
a run of tokens, `word` three wraps rising (pitched up with length), `full`
wraps climbing an octave, `refuse` the tongue twice falling, `found` one
quiet tongue, `fly` a flutter of small wraps, `reset` tokens falling,
`enter` a run of tokens. `hint`, `solved`, `confetti` and `party` (a full
comb found and no bulb) are Hosepipes' takes, copied. Nothing was bought.
Haptics: `docs/agents/haptics.md` row 28i.

## 6. Brain report

Words. `skill_quality()` is accuracy: words found over words found plus
entries that were no word at all (too short, no middle letter and already
found are not misses). The roadmap's "share of the day's words found" is
nearly constant when the day ends at a line, so accuracy is used. Timed as
usual (not in `Brain.UNTIMED`). Tips `BRAIN_HC_1..4`. Share line: 🐝, a
green square a word (a yellow one a full comb), a red one a miss.

## 7. Decided for the user, unconfirmed

- The win at a line (20/28/36/36% of the day's honey) rather than an open
  end; the honey rule (1, length, +7).
- Wandering Queen as Insane's rule, every four words.
- No S in any comb, in every language.
- Accuracy as the brain score.
- Tier 3 words taken and scored but never counted or hinted.
- The bulb spelling half a word with dots for the rest.
- The bin emptying the jar (with the host's confirm).

Not yet seen or heard: the sounds are unheard, pt/es unread by a speaker
(the dictionaries are generous: the English one passes clipped forms such
as "chem" and "alba", the Portuguese one inflections and a few names), reduce motion unseen, nothing played on a phone. Medium was driven
end to end through `_gui_input` by real touches (`tests/_win.gd`); Insane
and Medium were shot through `demo_tap`/`demo_key`.
