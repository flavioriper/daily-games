# Caterpillar, made fun to play

2026-10-26. The user: "make catterpillar experience way better to play, and
game itself way funnier to play, right now nobody likes it. Use web for
reference on how good games does it. Do it autonomous, push to main when
done". Every call below is mine and the user's to overturn. The board's
history is `docs/agents/boards/caterpillar.md`.

## 1. Why nobody likes it

1. **A day is guessed, not read.** The generator kept the fewest leaves that
   still prove one walk. A careful player (one who sees a square a step
   strands) guessing at turns crawled ~2x the garden in wasted squares on
   Easy, ~3x on Medium, ~5x on Hard (`tests/_probe_cat_fun.gd`). The genre's
   hit on a networking site is loved for being learned in seconds and solved
   in a minute, a flowing drag with a few real turns -- not backtracking.
2. **A dead end is silent until much later.** Stranding a square was priced
   with hearts once; since hearts went (2026-10-04) nothing says it at all,
   so the player finds out squares later, at a wall.
3. **The drag is mute.** `step` had no file: forty to sixty squares crawled
   in silence. Path-drawing games sell "silky" drawing with soft audio on
   every cell and a satisfying pop at each connection.
4. **Where to?** Nothing points at the leaf due next.

## 2. Intent

A day reads like a flow: drag, see a turn, think a moment, drag on. The
caterpillar reacts to all of it.

## 3. What changes

- Gardens dealt readable at a band's look-ahead (3, 4, 6 squares); leaves
  stripped only while readable. Insane's bank untouched.
- Easy and Medium show a stranded square at once, rose, free, until freed.
- The leaf due next ripples gold.
- Each square crawled pops (the wrap, climbing to the next leaf); a cut pops
  the lip.
- A fast crawl grins and kicks up dust.

## 4. Non-goals

No hearts, move counts or clocks (the user's 2026-10-04 and 2026-10-12
calls). No change to Insane's Peckish rules or bank. No new tutorial page.

## 5. Measured

| | Easy | Medium | Hard |
|---|---|---|---|
| wasted squares before | 49 | 99 | 254 |
| wasted squares after | 3.2 | 7.2 | 17.3 |
| leaves before / after | 7.2 / 9.2 | 8.0 / 9.8 | 9.8 / 12.8 |
| deal worst | 14 ms | 43 ms | 77 ms |
