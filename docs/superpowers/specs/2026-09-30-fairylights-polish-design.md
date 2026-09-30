# Fairy Lights polish: fuses, Wish Tags, rewards, motion and sound

2026-09-30, built unattended on `feat/fairylights-polish` (worktree
`../daily-fairy`, because sibling polish sessions were committing to the main
checkout the same hour) at the user's word ("let's polish the fairy lights
game, add more smooth animations, reinforce that the sfx sounds are really
cozy, add more visual rewards even if silly to the user to keep engagement,
and make sure the insane difficulty is really insane, with something totally
new (something only us do) that make the game nearly impossible, user can
also fail on insane and hard ... don't worry if you need to redo something
on the logic or design, as long as it keep the cozy vibe").

Quilt's, Mushroom Patch's and Bridges' passes the same day are the pattern:
the hearts, the dusk and the card, the streak, the gags, the party and the
seal. No concept tab: polish of a built screen with the user away. The flat
spec (`2026-09-20-fairy-lights-flat-design.md`, with its section 13) stands
except where this says otherwise. The calls at the end are for the user to
judge on the phone.

## 1. Hard and Insane can be failed: fuses

A rotation board has no "placement" to judge the way Quilt and Mushroom
Patch do: a piece passes through wrong turns on the way to its right one, so
judging where a piece *lands* would punish every honest tap. What a player
who deduces never does is **turn a piece that is already right**. Every
board on Easy to Hard is proved guess-free by the propagate-only solver, and
every Wish Tags board by its own solver (section 2), so the answer is unique
and a deducing player never needs to touch a right piece. That is the one
mistake, and it is the one that blows a fuse.

| band | garden | hints | hearts |
|---|---|---|---|
| Easy (0) | 5x5 | 3 | - |
| Medium (1) | 6x6 | 3 | - |
| Hard (2) | 7x7 | **1** | **3** |
| Insane (3) | **8x8, Wish Tags** | **0** | **2** |

- **A tap on a right piece** (on Hard and Insane, on a proved board only --
  the rare unproved fallback plays safe, Quilt's `ok`): the piece starts its
  quarter turn, **sparks** fly off it, the whole live run **flickers** twice
  like a brown-out (`fuse`), a heart splits (`heart_lost`), and the piece
  **swings back** to where it was right and a **brass clip** snaps onto it
  (`clip`). The clip is for good: the heart bought the knowledge, as
  Mushroom Patch's pebble and Quilt's chalk cross do. A tap on a clipped
  piece is refused for free ("A fuse showed that one was already right.").
  The grid never actually changes, so there is nothing in the undo log.
- Input, undo, hint and reset wait while the fuse plays (`busy()` holds the
  host's hint video).
- **Undo** stays on every band: it only turns the last tap back, and a turn
  that blew no fuse took nothing right away. Undo is not judged.
- **Out of hearts**: the garden **goes dark** -- the light is pulled back
  down every branch to the post, far end first, the lanterns go plain and
  doze, dusk falls on the card (`out_of_hearts`), and
  `ui/hud/out_of_hearts.gd` comes up with `FL_OUT_BODY`/`FL_OUT_REST`. Try
  again deals the same garden back in Reset's wave with every heart back and
  every clip gone (hints spent stay spent, a hint's pin stays); One more
  heart brings the light back where it was.
- The hearts sit on the family's paper pill in a strip over the card; the
  card gives up the room.
- Rules add `FL_RULES_HEARTS` ("only turn a piece you know is wrong");
  Easy and Medium say `FL_RULES_SAFE`.

## 2. Insane: Wish Tags

**Some lanterns wear a paper wish tag with a number on it: how many lengths
of wire lie between that lantern and the post.** Nothing else changes -- the
same tap, the same wash, the same win -- but the garden is 8x8 and it is
*not* one the ordinary rules can pin down: without the tags it has more than
one answer, or needs a guess. The tags are the only way in.

- **Why it is ours**: the genre (named once in the flat spec, not here) has
  wrapping edges, hidden junctions, several sources and colour-matched
  networks. A search on 2026-09-30 found no telling where an endpoint
  carries its **distance along the wire** from the source. It asks a new
  kind of thought -- counting a route you have not built yet -- and it gives
  a quiet sub-rule for free (a tag's number always has the parity of the
  lantern's grid distance from the post).
- **Why it is nearly impossible**: 64 pieces, about 22 lanterns, only the
  tags the proof needs (the rest are stripped greedily until the answer
  would stop being unique), a garden that ordinary propagation cannot
  finish, two hearts, no hints, and a fuse for every right piece touched.
- **The deal** (`Gen.generate_tags`, mined off the phone): grow an 8x8
  Prim tree around a middle post; tag every lantern with its depth; require
  that the tag solver (below) finishes it **without a guess**; then strip
  tags one at a time in a seeded order, keeping each removal only while the
  solver still finishes; require that the **propagate-only solver without
  tags cannot** finish it (Hard's solver fails, the ladder's `HARD_RUNG`).
  Scramble as every band does.
- **The tag solver**: the propagate-only solver plus three rules a player
  uses -- no closed loop of proven-open edges; no island (a group of cells
  whose edges are all proven and which does not hold the post); and each
  tag is a distance (a lantern proven joined to the post must sit at its
  tag's depth; a lantern whose proven run leaves it at a cell `k` steps
  down the wire can still reach the post only if `k` plus the grid distance
  from there is at most its tag, with the same parity). When those stall,
  **one supposition** at a time: try a candidate, propagate, and strike it
  on a contradiction. A board is graded by suppositions needed (the rung)
  and candidates tried (the work), and the miner keeps the hardest.
- **Banked** (`content/insane/fairylights.json`,
  `tools/insane/fairylights_ladder.gd`, run through `tools/mine_insane.gd`).
  The phone checks a banked garden is a spanning tree over 8x8 rooted at its
  post, every tag equals its lantern's depth, and the deal is the tree's own
  pieces turned; it trusts the miner's proof. An empty or broken bank deals
  a live 8x8 propagate-proved garden with every lantern tagged.
- **How it looks**: a tag is a little paper label on a thread under its
  lantern, the number inked in brown. When the lantern is lit, the tag reads
  what the wire says: its depth equals the tag -> a gold tick and the paper
  warms; unequal -> the number goes rose. (It is read off the player's own
  wire, never the answer.) At the party every tag flutters and turns gold
  (`tags`).
- Tips lead with `FL_TIP_TAGS`, `FL_TIP_TAGS_2`, `FL_TIP_HEARTS`.
  `FL_LVL_2` "7 × 7 garden, three hearts", `FL_LVL_3` "Wish Tags: 8 × 8, two
  hearts". A Wish Tags solve shares as 🏷️.

## 3. Rewards, even silly

- **The streak**: turns in a row that wake at least one lantern (read off
  the wash, so it reveals nothing the garden does not show). A turn that
  wakes nothing is neutral; a turn that puts a lantern out, a fuse, an undo
  or a reset ends it. `combo` up the pentatonic from the second, the "x3"
  bubble over the lantern, confetti at 4 and 7.
- **Every new join** a turn makes (two stubs meeting) gives off a tiny spark
  where they meet (`join`, a soft click).
- **A lantern waking** plays, three times in five by its cell's hash, a
  gag: **a moth** flutters in, circles the lantern twice and wanders off
  (`moth`); the lantern **hums** and three little notes float up (`hum`);
  or **hearts** float up (`love`).
- **The party**, after the chase: the lanterns **sway** on the beat,
  neighbours half a beat apart (`dance`); **fireflies** rise out of the
  garden (`fireflies`); confetti twice (`party`); **the nap cat** hops onto
  the frame's foot and curls up (`purr`); on Wish Tags the tags flutter
  gold; and the sprout shares **a bit of lantern wisdom**, one of twelve
  (`FL_CHEER_0..11`).
- **The seal**: Flawless (no hint, and no fuse on Hard and Insane, or no
  undo on Easy and Medium) stamps the gold seal; any Insane solve the night
  seal, "Insane" over "Flawless" or "Wish Tags". `completion_record()` keeps
  `flawless`, `hearts` and the clips. `share_glyphs()` adds `🏅 Flawless` or
  `🏷️ Wish Tags[ · Flawless]`.
- `win_delay()` adds the party.

## 4. Motion

New: a **press dip** (the piece sinks and shades under the finger, and
springs as it turns); an idle **sway** on every lit lantern, each on its own
phase; the join spark; the fuse's sparks, flicker, swing back and the clip
snapping on; the heart pill and its split; the dark pulled back to the post
and the dusk; the streak bubble; the moth, notes and hearts; the tags'
gold; the dance, the fireflies, the cat and the seal's drop. Under reduce
motion: no gags, confetti, sway, fireflies, dance or cat walk-in; the fuse
has no spin (the heart splits and the clip is simply there), the dusk and
the seal stand at once.

## 5. Sound

Re-prompted toward glass chimes, soft felt taps, a music box and kalimba:
`place`, `refuse`, `undo`, `hint`, `reset`, `enter`, `solved`, `wake`. New:
`join`, `combo`, `confetti`, `moth`, `hum`, `love`, `heart_lost`, `fuse`,
`clip`, `out_of_hearts`, `heart_back`, `stamp`, `party`, `dance`,
`fireflies`, `purr`, `tags`. Rendered on ElevenLabs (the fallback key when
the first is out); **unheard** by a person.

## 6. Numbers

Filled in by the build (bank, generation, draw calls, suite, win harness).

**The board side (sections 1, 2 and 4), 2026-09-30.** Peak draw calls from
`tests/_shot_fairylights.gd` at 810x1440, windowed one at a time: rest 102
(Easy), 118 (Hard), 125 (Insane); press 115 (Medium); fuse 124 (Hard), 133
(Insane), 122 (Hard, reduce motion); out, dark, card and Try again 139 (Hard),
138 (reduce motion); tags lit and read 144 (Insane); restore 134 -- every one
far under the 855 budget. The sparks are a layer of their own over the
lanterns (a lantern is a Control and hid its own fuse); the tag numbers are
one draw_string a tag. Suite passed=123054 failed=0; `tests/_win.gd --
fairylights` winnable 1/1 (Medium; it now taps every piece round where a band
has no hints).

**The rewards (section 3), 2026-09-30.** Peak draw calls from
`tests/_shot_fairylights.gd` at 810x1440, windowed one at a time, the second
of two readings: `right` (six lanterns woken in a row: join sparks, x2 to x6,
confetti at 4, moth, notes and love, then an undo deflating the bubble) 115
(Easy), 137 (Insane), 109 (Easy, reduce motion: no sparks, gags or confetti,
the bubble still counts); `solve` (three lanterns tapped home: chase, dance,
fireflies, confetti twice, the cat hopping along the frame's foot and curling
up, the seal) 139 (Easy, gold seal), 173 (Insane: night seal, tags fluttering
gold), 173 on `--rendering-driver opengl3_angle`, 152 (Insane, reduce motion,
over the win screen); `restore` with a flawless record 152 (Insane: cat
asleep, gold tags, night seal, a clip, a heart gone); `tags` 144 and `fuse`
124 (Hard) with the bigger paper and clip. Every one far under 855: each
floating thing is one cached mesh (moth, note, heart, firefly, the twinkle's
star for a join) under a transform, the bubble is rebuilt once a count, and
the seal is one mesh and two strings. The tags are 1.7 times the first pass's
(0.46 by 0.5 of a cell, the number 0.36 of a cell: 42 px at Insane's 118 px
cell, overhanging the stone's lower right a little), the clip 1.5 times (0.45
by 0.225). Suite passed=123054 failed=0; `tests/_win.gd -- fairylights`
winnable 1/1 (6x6, 33 turns). Screenshots read: the moth, notes, love, x3,
x4's confetti, the party frames, the night and gold seals, the cat avoiding
the bottom row's lanterns, rose and gold tags.

## 7. Calls for the user

1. **The fuse rule**: only turning a right piece costs, so exploring by
   cycling a piece is dangerous on Hard -- that is the point, but it is new
   to this genre.
2. **Wish Tags on the phone**: whether the tags read at 8x8's cell, and
   whether counting a route is fun or just hard.
3. **Two hearts on Insane, three on Hard** are guesses.
4. **Twelve bits of lantern wisdom**: silly on purpose.
5. **Sounds are unheard.**
6. **The seal** hangs off the frame's lower right corner (a stamp on a
   parcel) and on 8x8 still covers the corner lantern; the cat picks the
   stretch of the bottom row that hides the fewest lanterns. Both are the
   party's leavings over a finished garden, so nothing is hidden that the
   player still needs.
7. **Review findings, fixed**: a slide from one piece to the next turned the
   second, a second finger turned a second piece, and a cancelled touch or a
   release with no press still turned whatever was under it -- on Hard and
   Insane any of those can be a fuse (one finger now, and only a release on
   the piece that went down turns it); an undo or Reset inside the wash still
   rang a lantern awake and played its gag as it went dark; Reset stayed lit
   through a fuse and out of hearts. Notes in `docs/agents/boards/fairy-lights.md`.
