# Birdsong

- **Birdsong is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  second and the second Memory board. **Redesigned the same evening** at
  the user's word: a woodpecker knocks a rhythm on the old tree's trunk,
  one bar of four beats, and the player knocks it back on one drum; each
  round adds a knock. The songbird, its four drums and Whisper are history.
  Spec `docs/superpowers/specs/2026-10-22-birdsong-design.md` section 7;
  concept tab `docs/brainstorm/concepts.html#woodpecker`.
- Files: `puzzles/birdsong2d.gd` (the board, extends `core/puzzle_base.gd`),
  `puzzles/birdsong_state.gd` (bands, the day's knocks and their order,
  judging), `puzzles/birdsong_world.gd` (the garden; `trunk_edge`),
  `ui/faces/woodpecker.gd` (body and head meshes),
  `ui/hud/birdsong_tutorial_diagram.gd`, `ui/menu/cards/birdsong.gd`
  (extends Drumbeat's card for its go drum).
- **Judged between the player's taps** (`State.heard(t)`): the first knock
  anchors the bar, the rest are held to their places from it; `missed(t)`
  finds a place passed. The user picked this over judging on a running
  beat, so no per-phone timing (Drumbeat's tap-along) is needed. Keep it.
- **The board runs on its own clock** (`_t`, stood still while
  `clock_held`) and a queue of timed jobs (`_after`): the pecks, the beats,
  the turn. A knock is timed between two steps by `_now()` (the real time
  since the last step, at most 50 ms). A harness steps it by calling
  `_process(delta)` and knocks when `clock() >= knock_due(state.landed)`.
- **The board is its own tutorial**: `demo` set before it enters the tree
  makes it silent, deaf and laid in its own rect; the diagram knocks with
  `demo_knock()`. Lessons LISTEN, PLAY, SLIP, FEINT (Insane), HINT. The
  lanes size with the card's height so the short page still reads.
- Sounds: `tools/gen_sfx.py` set `birdsong`: `peck` (bank token, +1),
  `tick` (bank pebble, quiet), `feint` (bank lip), `knock` (the player's,
  bank token three semitones under the peck; the drum's copy of
  `assets/sfx/drumbeat/drum_0.ogg` went on 2026-10-29); the rest Glimpse's takes. Unheard.
- Harness: `tests/_win.gd -- birdsong` (real touches on each knock's place,
  round two's last knock left out, one bulb);
  `tests/_shot_birdsong.gd -- <dir> d=<0..3> [tut|card]` shoots a peck
  mid-bar, two knocks landed, a slip, the win, a reopened day, a tutorial
  page or the card, with draw calls.
- Seen windowed at 810x1440, desktop GL and ANGLE: every band plays
  through, the win and its brain report, a solved day reopened, the first
  tutorial page, the card. 89-132 draw calls in play, up to ~167 with a
  tutorial page. `tests/_probe_insane_hints.gd -- id=birdsong`: 0 failures.
  Not seen: a phone, reduce motion, the sounds heard, pt/es read by a
  speaker.

### Made fun (2026-10-29)

The user: "make birdsong experience way better to play, and game itself
way funnier to play, right now nobody likes it", autonomous, push when
done; mid-pass: "players really really hate the drums sounds, maybe we can
change it to knock sounds similar to what the bird does". References from
the web: Rhythm Heaven (call and response as the hook; encouraging words;
the game pokes fun at a goof, a character reacting), Patapon (the drum
answered, Good/Great/Perfect, combos that build), rhythm-game design notes
(say early, late or perfect so the player learns).

**Measured first** (`tests/_probe_bs_fun.gd`, 60 days a band, a tapper who
forgets a knock now and then (4% a knock past the first) and whose timing
drifts with the time since the first knock, as a person's does with no
beat): 0.34/0.38/0.44/0.47 slips a round Easy to Insane, only 17/11/4/3 of
60 days clean, and on Easy about 70% of slips are timing drift, not
memory (Hard and Insane about 60%). The same tapper with flat timing slips
0.11-0.20 a round. A slip only ever said "Once more…" with dashed rings.

**What changed**:

- **The player's knock is wood** (`knock`, bank token at -3 semitones, the
  peck at +1): kin to the woodpecker's and told apart. The drum's sound is
  gone; the drum stays as the thing tapped.
- **A slip says why** on the shared `ui/flat/toast_card.gd` under the card:
  too early or too late for a knock (within `State.NEAR` 0.34 s of its
  place), a knock where there is none, or a knock missed, with where in
  counting words (`BS_WHY_*`, `BS_AT_*`: on beat n, half way between n and
  n+1, just after or before n). `State.LATE_GRACE` 0.16 s: a place is
  given up that long after `OK`, so a late knock is told it was late, not
  that one was missed; what is a slip is unchanged.
- **The round's new knock is marked**: its peck higher (`NEW_PITCH`) and
  louder, its chips gold, its hole glinting in sun while the holes show.
  On Hard and Insane (no holes) it is heard and seen in the chips.
- **The player's beat is seen, never heard**: once their first knock
  lands, the beat numbers light on the beats from it and the woodpecker
  nods on each. No tick: a sound would come late by the phone's delay and
  undo judging between taps.
- **The woodpecker beams at a good knock**, a green ring off the berry.
- **The bulb keeps the holes**: it knocks the round again and its holes
  stay on the card through the turns until the round is knocked back, on
  every band (`_peek`), so on Hard it really shows the rhythm.
- **Live stars** (`star_line.gd`) beside "Round n of N", by slips and
  bulbs (`STARS_CUT` [1, 3]); the party's toots need three stars.
- **Runs**: clean rounds in a row climb the round's flourish; a round
  with every knock good says "Perfect!", three or more clean in a row say
  "n in a row!" with sparkles; the win names the best run when it was not
  a clean day (`BS_WIN_RUN`).
- **The encore**: the day's whole rhythm knocked once more by the
  woodpecker at twice the pace, each berry hopping to its knock, then the
  flourish and the confetti. The win waits for it (about 2.2-2.6 s).
- Bands, deals, windows (`GOOD`/`OK`) unchanged. en/pt/es.
- Harnesses: `_win.gd -- birdsong` checks the bulb keeps the holes and the
  slip's toast and stars (PASS); `opengl3_angle` 810x1440: Medium 95
  listening, 90 playing, 132 on a slip's toast, 148 win; Insane 94/90/132/145.
  `_probe_insane_hints.gd -- id=birdsong`: 0 failures (as before, the bulb
  never ends a day). Suite 303252/0. Unseen on a phone; the knock unheard.
