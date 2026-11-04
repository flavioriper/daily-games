# Biscuit Tin

2026-11-04, the third of the five word boards in `docs/roadmap-word-boards.md`
(the user: "let's tackle the next docs/roadmap-word-boards.md item. Make sure
to wire it properly with sounds, animations, fully polished user player
experience like the others wording games ... Do it autonomous, commit to main
when done"). Built straight from the roadmap's entry, unattended, with no
concept tab first, as Cross Stitch and Padlock were.

The genre is a word-chunk tile game; its best-known version (Quartiles) is
named here once, to forbid it, and never in code, comments, commits or on
screen.

## The board

- **An open biscuit tin** on a kitchen table, full of broken biscuit pieces,
  each with two to four letters iced on it. Five long words (three on
  Easy) were each broken into four pieces, and the pieces mixed.
- **Tap a piece** and it hops out of the tin onto the plate above it, at
  the end of the row; up to four pieces lie on the plate. Tap a piece on
  the plate and it goes back to the tin with every piece after it.
- **A word**: whenever the plate spells a word the tin knows (four letters
  or more, one to four pieces), it is found at once: the pieces hop, the
  points rise off the plate, the board says it. The pieces stay, so a
  longer word can grow from it (TEA, then TEAPOT). A word found before is
  said again, quietly.
- **A whole biscuit**: four pieces that spell one of the tin's long words.
  The plate's pieces knit into one round biscuit with the word iced across
  it and it flies to its place on the tin's lid; the four pieces leave the
  tin and the rest slide together.
- **The solve**: every biscuit whole. There is no fail state.

## Words

Banks per band and language (`tools/build_biscuit.py`,
`content/insane/biscuit_<band>[.lang].json`, read through `InsaneBank`).
Honeycomb's lists cannot serve (no S, seven letters at most), so the
generator does what Padlock's does: wordfreq's words, Hunspell-checked,
rude words, rude stems and names pruned (the lists `build_padlock.py`
keeps), four to sixteen letters. Biscuits are common words of the band's
length, cut in four. Every ordered run of one to four different pieces is
looked up; a deal is kept only when the runs of four that spell a word are
exactly its biscuits, every piece is different, and no piece and no run of
two or three spells a rude word. Each tin carries its own words; no
dictionary ships.

## Points and stars

A word scores by the pieces it takes: 1, 2, 4, 8 (a biscuit, 8). The tin's
**line** is its biscuits' points and a share of what its other fair words
(zipf 2.9 up) hold (`SHARE`, 0.12-0.15): a few short words on the way. The
stars on the tools row's pill rise as the points do: 3 at the line, 2 at
three fifths of it, 1 on the solve. A biscuit the bulb lays scores nothing,
so a solve leaning on the bulb ends lower. The pill also says the points
against the line.

## Bulb, two presses

The first press (one hint) rings the first piece of a biscuit not yet
whole and says how many letters the word has; the second lays that biscuit
on the plate and bakes it whole, free (0 points). When the bulbs run out
the host offers one more for a video, as on every board: that is the way
out for a stuck player.

## Bands

| Band | Biscuits | Word | Pieces | Hints | Rule |
|---|---|---|---|---|---|
| Easy | 3 | 10-13 letters | 2-4, at most one of 2 a biscuit | 2 | |
| Medium | 5 | 9-12 | 2-4 | 2 | |
| Hard | 5 | 8-10 | 2-3, two of 2 at least | 2 | |
| Insane, *Crumbs* | 5 | 9-12 | 2-4 | 1 | four crumbs |

**Crumbs** (Insane), as the roadmap has it: the four pieces of a sixth long
word are mixed in, and the tin never takes that word whole; a crumb may
still be part of a shorter word. When the fifth biscuit is whole, the
crumbs left are swept off the table.

## Motion and sound

Enter: the pieces drop into the tin row by row (a token run). Tap: the
piece hops from the tin to the plate (token, pitch rising with the row's
length); back to the tin (lip). A fifth piece: shiver, tongue. Word: the
plate's pieces hop left to right, a gold ring, the points float up (wraps
rising with the pieces it took). Said before: one lip, the word's flag
bumps. Biscuit: the pieces close up, a crack heals, the biscuit spins to
its slot on the lid (tokens and wraps rising, the jar coin), sparkles.
Win: the lid's biscuits bounce, confetti; party when the line is reached
with no bulb. Every cue a pop from `tools/sfx_bank/` (set `biscuit` in
`tools/gen_sfx.py`); hint, solved, confetti and party are Honeycomb's raw
takes, never bought. All unheard.

## The world

A kitchen table edge to edge: a checked cloth over warm planks, the round
tin's lid leaning above with a dimple for each biscuit, the open tin
below holding the pieces, a teacup and a sugar bowl at the edges.
