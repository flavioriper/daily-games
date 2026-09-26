# Versus: Checkers (local, against the computer)

2026-09-26. Asked for by the user, who was away while it was built, so every
call below was made without them; each is one they may overturn.

## 1. The ask

- A third Versus game: **checkers**, against the computer for now (as
  snooker and chess are).
- Keep the cozy look, but **more animated**: pieces that move in an
  animated way.
- **Skins later**: users will get custom piece sets, each holding its own
  animations, so the look and the motion had to be separable from the game.
- A top-down view, with sound.

## 2. What was built

| Piece | File |
|---|---|
| Rules (pure data, make/unmake, two rule sets) | `versus/checkers_rules.gd` |
| Computer player and hints | `versus/checkers_ai.gd` |
| Skin interface (a working plain set) | `versus/checkers_skin.gd` |
| The house set, "Garden" | `versus/checkers_skin_garden.gd` |
| Board: drawing, touch, the moves as scenes | `versus/checkers_board.gd` |
| The screen | `versus/checkers_screen.gd` |
| The tab (three game cards, fitted to the room) | `ui/menu/versus_tab.gd` |
| Sounds | `assets/sfx/checkers/*.ogg` (`tools/gen_sfx.py checkers`) |

Harnesses: `tests/_probe_checkers.gd` (perft, the Brazilian rules on
hand-built positions, make/unmake, the computer's timing),
`tests/_probe_checkers_game.gd` (a whole game through the real screen, both
sides the computer, sped up; `SEED LEVEL LEVEL_YOU COLOUR SPEED UNDO`),
`tests/_shot_checkers.gd` (tab, deal, pick-up, hop, reply, forced capture,
routes, the flip, the squash, a chain's "x2", the tray, crowning, a king's
glide, the win, the end card, the losers turning over; `reduce` as a second
argument shoots it under reduce motion).

## 3. Rules

**Brazilian checkers** (damas brasileiras: the international rules on an 8x8
board), picked because the player is Brazilian and pt-BR is the game's
second language. Light moves first; men step forward and capture both ways;
kings fly any distance; capturing is compulsory and **the most pieces must
be taken**; captured pieces come off only when the move ends, so none is
jumped twice and a taken piece still blocks (the "Turkish" rule); a man that
crosses the far row mid-capture and has to go on stays a man. A side with no
move left (all taken or all blocked) loses. Draws: twenty moves each with
only kings and no capture, or the same position three times.

English draughts (**AMERICAN**) is in the same class as a variant flag (dark
first, men take forward only, short kings, any capture sequence, a jump that
crowns ends the move). Nothing picks it yet; it exists because its perft
counts are published and so prove the move generator: 7, 49, 302, 1469,
7361, 36768 match to depth 6. Brazilian perft reads 7, 49, 302, 1469, 7473,
37628 (no published figures to hand), and hand-built positions check what
only Brazilian has.

A move is a `PackedInt32Array` (`[from, n, landings..., captured...]`), not
chess's one int, because a chain can take up to eight pieces. Two sequences
ending on one square having taken the same pieces are one move.

## 4. The computer

Negamax alpha-beta with a transposition table (move order, bounded cutoffs,
wins never cut), killer moves, iterative deepening in a time budget, and
captures searched past the horizon: a capture is forced, so there is no
standing pat on one, and a forced move (only one legal) does not cost depth.
Evaluation: men 100, flying kings 320, men worth more as they advance, a
guarded back row, the centre, the long diagonal once the board thins,
trading down when ahead, and the stronger side closing in over a kings'
ending. About 29k nodes a second in GDScript on this Mac.

| Level | Depth | Blur (sd) | Budget |
|---|---|---|---|
| Easy | 2 | 70 | 0.4 s |
| Medium | 4 | 22 | 0.8 s |
| Hard | to 16, reaches 7 in the opening | none (root shuffled) | 1.5 s |

The hint (three a game) is Hard for the player on 1.1 s: a gold route that
draws itself along every landing, an arrow head on the last leg. The proven
best move always leads the next round, the lesson chess learned.

## 5. Skins

`versus/checkers_skin.gd` is the whole contract. The board is seen from
straight above, so a pose is: centre in cells, `lift` (drawn as the piece
growing, rising up the screen and its shadow sliding away), `squash`,
`spin` (a turn in the board's plane), `flip` (a turn over; past a quarter
the board draws the underside), `scale`, `alpha`, and `gaze`, which
overrides where the eyes look. A skin answers:

1. **Draw this piece**: `build_base` (the edge band and, for a king, the
   lower piece of the stack, drawn unturned so a twirl does not swing the
   thickness round), `build` (the top, turning with the piece, per face and
   per gaze direction), `build_under`, `build_crown` and `crown_seat`.
2. **Where is it and how is it lying**: a quiet step, one leg of a capture
   (knowing which leg of how many), when a leg passes over a point
   (`jump_contact`), the taken piece's trip to the tray, the crown's fall
   and the crowned piece under it, idle, several fidgets, the refused
   shiver, the must-capture nudge, the winners' cheer, the losers turning
   over, the deal; plus timings and the sounds each starts and lands with.

The board owns the rules' mirror, the clock, the order of events, where
every piece is looking, the marks, the trays and everything drawn round the
pieces, so every skin gets them. `CheckersSkin.named(id)` picks a set;
`Record.skin("checkers")` is where a chosen one will be read from.

## 6. The Garden set

Chess's cream and rose as round wooden draughts with a carved groove, a lit
rim and a face; a king is two stacked with a small gold crown. The
underside is a green felt pad with a stitched edge, seen whenever a piece
turns over.

- **They look at things**: every piece's eyes follow the piece that is
  moving, your finger while you drag, the piece you picked up; the pieces a
  capture will take watch it come, worried; now and then a resting piece
  glances somewhere of its own. While the computer thinks, its pieces look
  round the board.
- a man hops a square, squashing at both ends, and wobbles to rest like a
  dropped coin;
- a king glides with a full twirl, streaming speed lines;
- a capture crouches and leaps high over its victim: a **front flip** on the
  first jump (the felt underside shows mid-air), a spin on the next, and so
  on down the chain, each leg's sound a step higher, with "x2", "x3" popping
  over each piece after the first;
- the taken piece is **squashed flat** at the touch, dizzy, then **tossed
  spinning like a coin** into the tray, where it sleeps with z's;
- crowning drops a crown out of the sky onto the man, who looks up; it
  lands with a squash, a sparkle and gold rays;
- at rest they breathe and blink, and one at a time hops twice, twirls,
  wobbles or peeks left and right; a king turns slowly;
- the pieces that must capture wear a turning gold ring and a brave face;
  tapping another piece shivers it and the capturers lean toward what they
  must take;
- the game is **dealt** like coins, each piece falling and turning over
  twice before it lands;
- the winners hop and twirl in a wave out from the last move, petals fall
  when you win, and the losers **turn face down** one by one; a draw puts
  everyone to sleep.

Under reduce motion every move is a short straight slide, nothing is
dealt, nothing idles and the eyes stay still.

## 7. The screen

Chess's, with the checkers rules: the flat top bar (Undo, Reset, the hint
and its count, settings), the sun-and-moon scoreboard with the move number,
the board on the wooden terrace between two moss planters. Tap a piece then
where it lands, or drag it. A capture shows its whole route with footprints
and a rose ring round each piece it takes; where two routes share a first
landing, tapping the final square still chooses, and tapping the shared
landing narrows the choice a landing at a time. The first forced capture of
a game explains the rule in a toast. Undo takes back your move and the
computer's answer (the piece walks home along its route, what it took hops
back out of the tray, a crowned man is a man again). You always play cream
at the bottom; the colour you move as swaps every game.

Measured with `tests/_shot_checkers.gd` at `--resolution 810x1440`: **125**
draw calls on the Versus tab, **130-136** at the board with the full set,
69-97 later in a game, 90 on the end card. ANGLE agrees on every count.

## 8. The tab

A third card. Three cards are more than 1080x1920 holds with their lines,
so the tab measures the room the menu's column leaves it (the full-screen
list less its margins, the way `_fit_grid` measures) and gives up the lines
under the names, then 54 px of each picture, rather than push the bar off
the screen. At 1080x1920 the lines go; with a 180 banner up they go too and
everything still fits over the bar. Checkers' banner is a strip of the
board with a king at each end and a cream man caught mid-leap over a
worried rose one.

## 9. Open for the user

- **The rule set.** Brazilian was chosen; English draughts is one flag away
  (`Rules.new(Rules.Variant.AMERICAN)`) if the game should follow the
  player's language or offer both.
- The sounds are one take each, not yet listened to.
- Whether the computer's levels are right.
- The lines under the Versus cards are gone at every phone size now that
  there are three; a shorter blurb, or two cards a row, would bring them
  back.
- No concept-page tab was made first (the user was away).
- Online play, as for the other two.
