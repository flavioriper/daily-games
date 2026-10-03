# Drumbeat polish — four drums, Echo, hearts, a clock that matches

2026-10-01. Built unattended at the user's word: "polish the drumbeats game,
add more smooth animations, reinforce that the sfx sounds are really cozy,
add more visual rewards even if silly ... make sure the insane difficulty is
really insane, with something totally new (something only us do) ... user
can also fail on insane and hard ... redo it to have different drums instead
of using one, two fingers or something like this, like a guitar hero. Also,
make sure to be extremely polished about the rhythm, there is a lot of
players complaining right now the game has weird rhythms and not always
match the play time."

The first build is `2026-09-28-drumbeat-flat-design.md`; this replaces its
sections 1-4 (rules, board, clock, charts). Section 7 there (the crowd,
fireworks, fever tiers) carries over.

## 1. Why the rhythm felt wrong (found, 2026-10-01)

1. **The charts did not follow the music.** Hard was written by hand as
   strings of sixteenths that ran beside the tune, not on it: many notes fell
   where nothing sounded. Medium and Easy were thinned out of Hard by a
   greedy minimum gap, which left syncopated leftovers on off-beats.
2. **Android reports no output latency.** `AudioServer.get_output_latency()`
   returns 0 on Android (a known engine gap, confirmed on the Godot forum: a
   rhythm game ~165 ms off on phones), so the notes ran ~100-200 ms ahead of
   the sound, and the only fix was a ±10 ms nudge most players never found.
3. **The clock jittered.** It eased 8 % a frame toward a playback position
   that moves in mix-sized steps, so the notes shuffled back and forth and a
   snap could step them backwards.

## 2. The fixes

- **Charts come from the arrangement.** `tools/gen_drumbeat.py` describes
  each bar as events (`bar_events`), and both the music and the charts are
  made from the same events: the tune's notes go on drums 1-3 by pitch (three
  bands a section, low to high), the kick on drum 0, and on Medium/Hard the
  bass, chord stabs and koto fill the tune's rests. Easy keeps the beat grid,
  Medium the eighths, Hard the sixteenths. A note too close to the last on its
  drum steps to the next drum over (the fingers trade) or is dropped. Checked:
  the chart notes sit on an onset in the decoded audio (Easy 100 %, Hard
  77-98 %; the misses are dense gallop sixteenths where the energy test is
  blunt).
- **The tune is its own stem** (`lead_<id>.ogg`) beside the backing
  (`song_<id>.ogg`), started together; it dips (−6/−9/−12 dB) while the player
  lets notes pass and comes back on the next hit, so the player hears that the
  tune is theirs.
- **The clock** runs off the microsecond clock from the instant the music is
  heard (`_zero_us`: next mix + output latency), steered by the playback
  position at most 1 ms a frame (snapped only past 120 ms), and the time the
  notes read never goes back while a song plays.
- **The timing is measured, not nudged.** A tap-along (`calib.ogg`, twelve
  wood-block knocks 0.6 s apart): the player taps any drum with each knock;
  the median lateness from the fourth knock on is the phone's timing. On a
  phone that reports no output latency it runs before the first song (the
  start card says so), and its first guess there is 120 ms; on any phone the
  card's Tune button runs it again, and −/+ still nudge by 10 ms. Kept in
  `user://drumbeat.cfg` (`timing/offset`, `timing/tuned`). Measured with the
  harness bot tapping 90 ms late: 95 ms.
- **Windows** widened a little for glass: GOOD 70/60/50/45, OK 130/115/100/90,
  BAD 160/145/130/120 ms (Easy/Medium/Hard/Insane).

## 3. Four drums

Like a guitar-highway game. Four drums stand in a row at the foot of a path
of planks that narrows up into the stage; berries come down four lanes, each
to the drum of its colour. Left to right, low to high: **the big drum**
(lacquered barrel, coral), **the hand drum** (goblet laced with rope,
apricot), **the jingle drum** (green frame with brass jingles), **the tongue
drum** (blue box). Each has a face (happy, joy on a GOOD, worried on a miss,
sad when the hearts run out), squashes on a stroke, wobbles, nods on the beat,
and its own synthesised voice (felt boom, palm tone, thump and jingle, woody
tock), from `gen_drumbeat.py` like the songs, a voice pool each.

- **Tap**: a berry, struck once. **Two at once**: two drums together.
- **Hold**: a berry with a ribbon; kept down to the ribbon's end (20 a tick,
  200 at the end); let go early, the ribbon is lost but not the combo.
- **Drumroll**: a golden bar on the big drum or the tongue drum.
- **Balloon**: on the hand drum, that many strokes.
- A column of the board is its drum: anywhere over a lane strikes it, so the
  thumbs never hunt for the drum itself. D F J K on a keyboard.
- Notes speed up toward the drums as if coming nearer (`PERSP` 1.25), grow
  from 0.58 to full size, and are in sight `TRAVEL` 1.9/1.6/1.4/1.3 s.

## 4. Hearts (Hard and Insane)

Hard 3 hearts, Insane 2. **Three notes missed in a row** break one, and so
does **a song that ends under the line**. A heart breaks in the band (two
halves falling), the last one beats. Out of hearts the band **winds down**
(the music slows to 0.45 and fades over 1.4 s, a music box running out), dusk
falls, the drums and Tam fall asleep, and the out-of-hearts card: Try again
(the song from the top, every heart), One more heart (the rewarded video,
once a board: the band picks the song up four beats before where it stopped,
with a heart; notes from two beats on wait again) or Back. On Hard and Insane
a tap on a drum with no berry near it, while one is due on another drum, is a
**slip**: the combo breaks and the gauge dips. On Easy and Medium a stray tap
is free and a song under the line is simply played again.

## 5. Insane is Echo

Nobody else does this: **the bars come in pairs, and the second plays the
first again with its berries hidden.** Read a bar and play it; then play it
back from memory, by ear, with only the drums you just heard. The hidden bar
comes down the path under a lilac veil with moonlight twinkles; a struck
hidden note shows as a lilac ring at its drum. Tam calls each echo ("Echo!
Play it back" the first two times, a wink of notes after). A hidden bar with
every note struck is a **Perfect echo!** Insane also has the narrowest
windows and a gauge that wants 80 % GOOD. The bot (which needs no memory)
clears it; a person reading Hard's charts with half the bars blind will very
rarely do so.

## 6. Rewards, the silly ones

- **Golden berry**: the first berry into each Go-Go section; struck, a
  shower of coins, hearts from the crowd, "Golden berry!", fireworks.
- **Conga**: at 50 and 150 combo (and every hundred past), five critters
  conga across the stage, glow sticks up, kicking on the beat; again at the
  party.
- **Tam's sunglasses** drop on at 100 combo and stay for the song.
- **Drums with faces** that beam, fret and sleep; a struck berry flies up
  into the soul gauge; a berry let past tumbles off the end of the path,
  frowning.
- A held drum hums: music notes float up while its ribbon is kept.
- **The party**: the nap cat hops onto the big drum and curls up; the seal
  when the song earned it (full combo: Flawless; Insane: the night seal,
  Insane over Flawless or Echo); then the conga.
- Carried over: the crowd that gathers with the gauge, fireworks, fever
  tiers (lit rails, edge glow), streak words, the count-in, the finale.

## 7. Sounds

Every cue taken again as FESTIVAL / FESTIVAL_TUNE (`tools/gen_sfx.py`):
close-mic foley of a small garden festival at dusk (soft hand drums, wooden
beads, paper lanterns, party balloons) and every note a real kalimba, music
box, wooden tongue drum or hand bell, never synth, rolled off above 7 kHz.
26 cues, 13 new (heart_lost, out_of_hearts, heart_back, echo, echo_perfect,
golden, conga, shades, hold_done, tune_done, stamp, party, purr); the old
arcade/cartoon `start`, `new_best`, `tick`, `don`, `ka` are gone. The four
drum voices and the stems are synthesised. **Unheard by the user.**

## 8. Numbers

Notes Easy/Medium/Hard/Insane: Garden Parade 152/175/269/310, Lantern
Festival 82/142/249/284, Firefly Gallop 93/248/394/474. Draw calls 84-137 in
play, peak ~222 in Go-Go's burst (ANGLE 250); reduce motion 145 peak.

## 9. Open calls

- The sounds and both stems are unheard; the drum voices especially want a
  listen on a phone over the music.
- The tap-along's first guess on a blind phone (120 ms) is a guess.
- Whether Echo should allow a third heart; it is meant to be nearly
  impossible.

## 10. Review findings, fixed

- **A late stroke stole the next note on its drum** (the nearest note won, so
  a stroke past the midpoint of two close notes judged the second and let the
  first pass): a stroke now judges the earliest waiting note in reach.
- **A hold struck early and let go before its time finished itself** (the
  lift stopped looking at notes not yet due): a lift reaches every hold in
  reach and pays only from the hold's own time.
- **A pause left a hold held** and it completed on resume: losing focus lets
  go of every hold.
- **One more heart judged notes twice** and showed missed berries still
  coming down: it picks up the state exactly where it stopped (only notes
  never reached wait), the music lead-in plays over settled notes, a missed
  note is never drawn before its time, a hold kept when the hearts ran out is
  settled as dropped, and the tune's dip is cleared.
- **Insane had no drumrolls or balloons** (they all fell in the second bar of
  a pair): a pair whose second bar holds one is played as Hard plays it.
  **Echo's hidden notes did not sit on the tune** (the stem is shared): the
  tune steps aside (−30 dB) under every hidden bar, so the player hears the
  backing and their own drums answering. Notes now 292/267/448 on Insane.
- Resume adds the output latency like a start does; Reset and Try again stop
  the dusk tween.

## Amendment, 2026-10-03: one road

The user, with a reference screenshot: "this is what i was thinking for the
drumbeat, but instead of having one tap, double tap, we just had multiple
drums to tap to make easier"; then, on the playable mock
(`docs/brainstorm/concepts.html#drumbeat`): "all great, keep it 3 at most,
1/2/3/3" and "keep game short, around 20 to 30 seconds at most".

- The four-lane path is replaced by one road across the card: notes ride it
  right to left into one ring at its left; the drums stand in a row under it.
- A note names its drum by colour and by the drum's mark under it; the drum
  the next note wants glows. Two at once are a twin, one over the other.
- Drums by level: 1, 2, 3, 3 (big; big + tongue; big + hand + tongue).
- Songs are 21-25 s: pick-up bar, verse, Go-Go chorus, last chord. Charts are
  written per level for that level's drums.
- Unchanged: judging windows, soul gauge and its line, hearts, Echo, Go-Go,
  the clock, the tap-along, the sound set.
- Not asked, decided by me: twins stay on Hard and Insane; the glow is on at
  every level with more than one drum; fever tiers at combos of 10/25/50.
