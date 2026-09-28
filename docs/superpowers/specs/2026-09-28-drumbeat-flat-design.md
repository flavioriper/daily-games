# Drumbeat — flat design

2026-09-28. Built unattended at the user's word ("a drum rhythm game like
[the drum-festival arcade game], wire sfx sound as well ... do everything"),
from a screenshot of image results for the reference. No concept tab. The
reference is Bandai Namco's *Taiko no Tatsujin* (*Taiko: Drum Master*); this
line is the only place its name is written, in order to forbid it. **It is
called Drumbeat and nothing else**, in code, in a comment or on screen.

It is a **puzzle-grid board**, not an Arcade game: the user said so
mid-build ("it's a puzzle game not arcade"). Clearing the day's song is the
solve.

## 1. The rules (checked against the reference, 2026-09-28)

- Notes ride a lane right to left into a hit ring, in time with the song.
- **Don** (red): strike the drum's face. **Ka** (blue): strike its rim.
- **Big** don / ka: a second stroke of the same side within 70 ms scores the
  note again (the arcade asks for both sticks).
- **Drumroll** (yellow bar): any stroke, as many as you can, 100 points each
  (200 on a big roll).
- **Balloon**: that many dons before it passes; 100 a stroke, 1000 on the pop.
- Judgement **GOOD / OK / BAD** by distance from the note's time. The web port
  uses 25 / 75 / 108 ms; a phone's glass and audio are slower than a drum, so
  ours are wider: GOOD 65/50/45/36, OK 120/105/95/80, BAD 150/135/125/110 ms
  (Easy/Medium/Hard/Insane). A wrong side inside the OK window is a BAD; a
  stroke with no note near it costs nothing.
- **Soul gauge**: GOOD fills it, OK half, BAD drains twice a GOOD's worth. It
  is full after 55/65/75/85 % of the notes hit GOOD. **Cleared** = the song
  ends with the gauge at or over 80 %.
- **Go-Go time** (each song's chorus): everything scores ×1.2; the lanterns
  light and the lane warms.
- Score: GOOD 300, OK 150, +10 for every 10 of combo up to +100.
- Crowns on the win: Cleared, Full combo (no BAD), All GOOD.

Nothing ends a song early. A song that ends under the line is played again
(tap the drum), never lost -- Marigold's "a try, never a loss".

## 2. The board

`puzzles/drumbeat2d.gd`; rules in `puzzles/drumbeat_state.gd` (pure data,
no clock); drawings in `ui/faces/drumbeat_parts.gd` (shared with the menu
card). Registry: `"tray": "none"`, `"actions": false`, four levels, each its
own daily (`pick_difficulty`), the day's song dealt from the seed. Top to
bottom inside the card: the score and the soul gauge; a dusk festival stage
(lanterns on a cord swinging to the beat, two stalls, the moon) with **Tam**,
a frog in a festival headband, drumming on the right; the wooden lane with
the hit ring on the left, bar lines and the notes (berries with faces); and
the drum -- a cream skin with a painted leaf in a lacquered rim with brass
tacks. **A stroke on the skin is a don; anywhere else on the board is a ka.**
Every finger counts, so a big note is two thumbs on the skin. F/J and D/K on
a keyboard.

Before the song, a card over the stage names the song and level, shows the
four kinds of note, and carries the **timing nudge** (−/+ 10 ms, ±300 ms,
kept in `user://drumbeat.cfg`), which moves the notes and the judge against
the music for a phone whose audio arrives late (a Bluetooth headset).

## 3. The clock

The song's time is the music's playback position plus
`AudioServer.get_time_since_last_mix()` less `get_output_latency()`; between
mixes the microsecond clock carries it, a drift under 60 ms is eased out at
8 % a frame, a bigger one snapped to. Every stroke reads the clock at the
moment it is handled. Focus lost pauses the music; a stroke resumes.

## 4. The songs

`tools/gen_drumbeat.py` writes both the music and the charts from one
description, against one bar grid, so they cannot drift: three original
tunes in the house instruments (marimba, glockenspiel, kalimba, a bamboo
flute, a koto pluck, a plucked bass, a soft kick, shaker and claps in Go-Go),
a bar of wood-block count-in first.

| id | title | BPM | key | notes E/M/H |
|---|---|---|---|---|
| parade | Garden Parade | 112 | F major, oom-pah | 169 / 242 / 257 |
| festival | Lantern Festival | 132 | D major pentatonic, flute | 73 / 244 / 273 |
| gallop | Firefly Gallop | 168 | A minor gallop | 86 / 288 / 337 |

A chart is written once, at Hard, sixteen characters a bar, following the
melody. Medium keeps notes at least half a beat apart and Easy a beat (two
when a beat is under half a second), a big note winning its slot; Insane is
Hard's chart with the narrow windows. Balloon counts scale with the level.

`tests/_probe_drumbeat.gd -- <jitter ms> <slips %>`: a perfect bot is All GOOD
on all twelve charts; at ±60 ms it clears Easy to Hard on every song and
misses Insane's line; at ±90 ms with 8 % wrong strokes it clears Easy only.

## 5. Sound

`tools/gen_sfx.py drumbeat`: don and ka are FOLEY and dead short (the first
ka take was four clicks smeared over 300 ms and sounded late; take 1 of three
retakes is one knock). They play from the board's own six-voice pools, not
`Fx2D.cue`, whose 60 ms same-cue gap would swallow sixteenths. Also balloon,
pop, balloon_gone, gogo, soul, combo, break, select, start, clear,
full_combo, fail, new_best, tick. One take a cue, awaiting the user's listen.
The songs are synthesised, not ElevenLabs, because they have to be exact.

## 6. Measured (810x1440, this Mac)

73-76 draw calls on the start card, 63-73 in play, 118-124 in Go-Go with a
sticker up, 68 on the win; ANGLE agrees (73 / 120) and differs only by the
pulsing prompt and the wordmark's glint. Idle 3.8-6.1 ms. Menu last page 150.

## 7. Polish and loud rewards (2026-09-28)

At the user's word ("polish and improve design and animation ... the
rewards even if silly should be way more visual to keep users playing").
Screen and art only; the state class is untouched.

- **The crowd gathers.** A row of garden critters (bunny, mouse, bear cub,
  chick, hedgehog; `Parts.critter`) stands at the foot of the stage, three
  at the start and one more for every seventh of the soul gauge, up to ten,
  each popping in with hearts; the tenth says *Full house!*. They never
  leave within a run. They bob on the beat (higher on a hot run), jump with
  their paws up on a cheer, wave glow sticks through Go-Go and the finale,
  fret after a broken combo and droop on the retry card. The crowd is the
  gauge made visible: playing well fills the stage.
- **Fireworks** over the dusk sky: a rocket's climb, then a burst of
  trails, a beat apart. One on a balloon's pop, two on the clear line,
  three on Go-Go, one to five on a combo call by its size, and a volley of
  6-12 (more for a full combo and All GOOD) in two waves at the finish.
- **Fever tiers** off the combo (25 / 50 / 100): the lane's rails light
  gold, then hot, then a turning rainbow; the drum takes an aura in the
  same colours; from 50 the card's edges glow (always in Go-Go).
- **The combo lives on the drum's skin** in big numerals, kicked on every
  hit and coloured by tier (ink, gold, red, a rainbow a digit at a time).
  The judgement moved up to where the combo was, over the ring, and is
  stamped in with a pop.
- **The beat is shown**: the ring breathes on it, the lanterns swell, the
  drum breathes, and the drum's brass tacks run a marquee chase (every
  other one flashing in Go-Go, all of them in the finale).
- **Every hit pays**: juice drops in the berry's colour and a glint off
  the ring, a music-note bit (`Rewards` gained a `note` kind) floating up
  off the drum, the score rolling up with a kick.
- **Streak words** on the combo calls: Nice!, Great!, On fire!, Drum
  master!, Legendary! with the count under it; stars, then coins from 100.
- **The count-in** letters 3, 2, 1 on the last beats before the first note
  and a Go! over a sunburst.
- **The soul gauge**: notches every tenth, a glint riding the fill, a heart
  at its end (grey, red past the line, beating when full), a rainbow when
  full and a *Soul full!* the first time.
- **The finale** is 3.2 s (was 1.6): the crown sticker, fireworks, the
  crowd and Tam jumping, coins and a rain of confetti, stars and notes.

## 8. Open

- Nobody has heard the songs or the cues yet. Listen for the melodies (all
  original, hand-written in scale degrees) and the don/ka feel.
- The judgement windows and the default offset want a phone: Android's
  reported output latency is untested here.
- Per-song bests and crowns are not kept beyond the daily's completion record.
