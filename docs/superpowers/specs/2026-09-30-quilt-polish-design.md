# Quilt polish: clarity, hearts, Scrap Basket, rewards, motion and sound

2026-09-30, built unattended on `feat/quilt-polish` at the user's word
("let's polish the quilts game, add more smooth animations, reinforce that
the sfx sounds are really cozy, add more visual rewards even if silly to the
user to keep engagement, and make sure the insane difficulty is really
insane, with something totally new (something only us do) that make the game
nearly impossible, user can also fail on insane and hard ... Players are
complaining they can't understand the game quite well, seems to be poorly
done").

Bridges', Sudoku's, Mushroom Patch's and Queens' passes the same day are the
pattern: the hearts, the dusk and the card, the streak, the gags, the party
and the seal. Section 1 comes first because the board was hard to
understand. No concept tab: polish of a built screen with the user away. The
flat spec (`2026-09-20-quilt-flat-design.md`) stands except where this says
otherwise. The calls at the end are for the user to judge on the phone.

## 1. Why players could not understand it, and what changed

Read against how block-fit puzzles are taught elsewhere (drag a piece, a
shadow shows where it lands, cover the whole shape, pieces never turn):

| problem | now |
|---|---|
| **The How-to-play diagram was wrong.** Four coloured squares in a row and a green box, captioned "Join matching patches into the shown shape": nothing is joined or matched in this game, and no patch is dragged. | Its own little quilt: a pale 3x2 backing with two L-shaped patches on a felt rack under it; a finger drags one up, its landing outline shows, it snaps and sews, then the other; the backing is covered and glows green. Caption: "Drag every patch on until the quilt is covered". |
| **Nothing said patches never turn.** Players used to other block games look for a rotate. | A tip of its own (`QL_TIP_TURN`), in the rules' second sentence, and in the line when a rack patch is tapped. |
| **A tap on a rack patch did nothing visible** (it grew and flew straight back). | A tap (press and release within 14 px and 0.3 s) **wiggles** the patch where it lies and the line says "Drag it up onto the quilt. Patches never turn." |
| **Sloppy fingers were refused.** The drop snapped to the rounded cell only, so a patch half a cell off a fit blushed and flew home. | **Sticky snap**: when the rounded origin does not fit, the nearest fitting origin within 0.75 cell of the held corner is taken instead (the ghost outline shows exactly that spot before the finger lifts, so it is never a surprise). |
| **A dead end was silent.** On Easy and Medium you could leave a pocket no remaining patch fits and carry on for minutes. | After each drop on Easy and Medium the board asks the state whether the patches left can still cover the bare cells (`finishable()`, exact cover on what is left). When they cannot, the line says "Hmm, what's left can't cover that gap any more. Take a patch back." and every bare cell no remaining patch can reach **pulses rose** (three pulses). |
| **Progress was hard to read** on the bigger quilts. | A **sewn-in label** on the backing's corner (a little cloth tag with a stitched edge) counts the bare squares still to cover, and bumps as it changes. On Scrap Basket it is the one number that tells you how many squares the scraps are not. |
| **Nothing showed the gesture.** | A **ghost finger** on Easy and Medium drags the patch with the fewest legal spots from the rack to its place (the answer's), after 1.6 s of rest, looping until the first patch lands. |

The rules text was rewritten in plain words, with a band's own closing
paragraph (safe, hearts, scraps). The tips cycle every 7 s like Bridges'.

## 2. Hard and Insane can be failed: hearts

| band | box | patches | hints | hearts |
|---|---|---|---|---|
| Easy (0) | 5x5 | 5 | 3 | - |
| Medium (1) | 6x6 | 6 | 3 | - |
| Hard (2) | 7x7 | 8 | **1** | **3** |
| Insane (3) | 7x7, **Scrap Basket** | 9 on the quilt **+ 3 scraps** | **0** | **2** |

- **Every drop on the quilt is judged as it lands.** The tiling is proved
  unique, so a patch sewn anywhere but its answer place is wrong by proof. A
  drop is right when the cells it covers are exactly the cells of an answer
  placement of the same shape (so two identical patches are interchangeable).
  Only a board whose proof said unique is judged (`ok`); the rare fallback
  board plays safe.
- A right patch **stays for good** on Hard and Insane: it cannot be dragged
  off again (a press on it shivers it: "That one's right, it stays."), and it
  wears no extra glow -- the sewn stitch is enough.
- **The wrong patch** lands and its needle starts the quilting stitch, then
  the thread **snaps** (`snip`), the stitch unravels backward, the patch
  **peels up** by a corner and **flutters home** to the rack with a wobble
  (`flutter`); a heart splits (`heart_lost`). Where it was tried is **ruled
  for good** (`state.ruled[patch]` holds origins): while that patch is held
  over a ruled spot the ghost is a chalk cross instead of an outline and a
  drop there is refused for free ("You already tried that one there.").
- Input, undo, hint and reset wait while a wrong patch peels; `busy()` holds
  the host's hint video.
- **Out of hearts**: dusk, "The quilters have nodded off", and
  `ui/hud/out_of_hearts.gd` with `QL_OUT_BODY`/`QL_OUT_REST`. Try again takes
  every patch home in Reset's wave with every heart back and the ruled marks
  gone; One more heart brings the light back.
- The hearts sit on the family's paper pill in a strip over the field; the
  field gives up the 64 px.
- Easy and Medium stay safe: drops are not judged, a patch can be taken off.
  Undo on Hard/Insane has nothing to take back except a scrap-free lift, so
  `can_undo()` is false there (the history only holds right patches).

## 3. Insane: Scrap Basket

**The basket holds three scraps too many.** Nine patches make the quilt and
three do not belong to it; they look exactly like the others. You have to
work out which nine cover the quilt *and* where -- and on Insane a scrap sewn
anywhere is a wrong drop and costs one of your two hearts.

- **Why it is nearly impossible**: every other telling of this genre deals
  exactly the pieces the shape needs, so the first step of every solve is
  free -- the sizes add up by construction. Here the set is a question too:
  the squares tell you the scraps' total, the shapes have to tell you which,
  and a region tiled by non-turning patches that is rigid with the right nine
  must also refuse every other choice of nine. A search on 2026-09-30 found
  decoy pieces in physical packing puzzles and a same-colour rule in the
  territory game, but no daily fill-the-shape board that deals pieces it does
  not use.
- **The deal** (`Gen.generate_scraps`): grow nine patches (sizes 3 to 6) in
  the 7x7 box as today, then draw three scrap shapes (sizes 3 to 6, span at
  most MAX_SPAN, none identical to a quilt patch or to each other), shuffle
  all twelve into the basket order, and prove **exactly one** subset tiles
  the quilt exactly once (`count_covers`, an exact cover where a patch may be
  left out). Scraps have `answer = -1`.
- **Graded** by the search's own cost (`nodes`), as the other bands; the
  miner keeps the hardest. **Banked** (`content/insane/quilt.json`,
  `tools/insane/quilt_ladder.gd`); the phone checks a banked board is
  well-formed and that its answer covers the region exactly, and trusts the
  miner's proof. An empty or broken bank deals a live one.
- How it looks: the rack's felt mat becomes a **wicker basket** (a woven
  band and a rim), and the backing's corner label counts bare squares.
- At the solve the three scraps **hop out of the basket and are strung into
  a bunting** across the top of the card, swinging (`bunting`).
- Rules add `QL_RULES_SCRAPS`; tips lead with `QL_TIP_SCRAPS`,
  `QL_TIP_SCRAPS_2`, `QL_TIP_HEARTS`. `QL_LVL_3` "Scrap Basket: 12 patches,
  3 don't belong".

## 4. Rewards, even silly

- **The streak**: good drops in a row -- on Hard and Insane a right one, on
  Easy and Medium any drop that leaves the quilt finishable. `combo` up the
  pentatonic from the second, the "x3" bubble over the patch, confetti at 4
  and 7 (quilts are small). A refusal, a wrong patch, a dead end, a take-off,
  an undo or a reset ends it.
- **A patch sewn** plays, three times in five by its hash, a gag: **hearts
  float up** (`love`), **a button is sewn on** its middle with a pop and stays
  there (`button`), or the patch **boings** -- a squash-hop in place
  (`boing`).
- **A row or column of the quilt finished** (every backing cell in it
  covered): a sparkle runs along it (`row`).
- **The party**, after the gold wave: the patches **dance** on the beat,
  neighbours half a beat apart (`dance`), confetti twice (`party`), **the nap
  cat** (`ui/faces/nap_cat.gd`) hops onto the finished quilt and curls up
  (`purr`), on Scrap Basket the scraps become bunting, and the line shares
  **a bit of quilt wisdom**, one of twelve (`QL_CHEER_0..11`).
- **The seal**: Flawless (no hint, and no heart lost on Hard and Insane, or
  never a dead end on Easy and Medium) stamps the gold seal; any Insane solve
  the night seal, "Insane" over "Flawless" or "Scraps". `completion_record()`
  keeps `flawless` and `hearts`. `share_glyphs()` adds `🏅 Flawless` or
  `🧺 Scraps[ · Flawless]`.
- `win_delay()` adds `PARTY_AT` + `PARTY_EXTRA`.

## 5. Motion

New: sticky snap's glide; the tap wiggle; the label's bump; the coach
finger; the dead-end pulse; the heart pill and its split; the wrong patch's
snip, unravel, peel and flutter; the chalk cross; the dusk; the streak
bubble; love hearts, the button's pop and the boing; the row sparkle; the
dance; the cat; the bunting; the seal's drop. Under reduce motion: no gags,
confetti, coach, dance, cat walk-in or bunting swing; the peel is instant,
the button and the seal stand at once, the cat is simply there.

## 6. Sound

Re-prompted toward felt, cotton, a wooden spool, soft pins and kalimba (the
tape-rewind undo and the "bonk" read as a toy or a scold): `lift`, `place`,
`refused`, `undo`, `hint`, `reset`, `enter`, `solved`. New: `wiggle`,
`stuck`, `combo`, `confetti`, `love`, `button`, `boing`, `row`,
`heart_lost`, `snip`, `flutter`, `ruled`, `out_of_hearts`, `heart_back`,
`stamp`, `party`, `dance`, `purr`, `bunting`. Rendered on the fallback key;
**unheard**.

## 7. Numbers

Filled in after the build: the bank, band timings, draw-call peaks from
`tests/_shot_quilt.gd`, the suite and `tests/_win.gd -- quilt`.

## 8. Calls for the user

1. **Hard and Insane are judged**: a right patch stays for good, so Hard
   loses the take-off gesture.
2. **Scrap Basket on the phone**: whether twelve patches on the basket stay
   legible, and whether the label's count reads as the clue it is.
3. **The dead end is named** on Easy and Medium, and the ghost finger shows
   one answer patch -- small gifts of information on the easy bands.
4. **Sticky snap** takes the nearest fit within 0.75 cell.
5. **Twelve bits of quilt wisdom**: silly on purpose.
6. **Sounds are unheard.**
