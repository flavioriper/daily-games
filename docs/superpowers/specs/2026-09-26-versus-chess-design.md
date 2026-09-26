# Versus: Chess (local, against the computer)

2026-09-26. Asked for by the user, who was away while it was built, so every
call below was made without them; each is one they may overturn.

## 1. The ask

- A second Versus game: **chess**, against the computer for now (as
  snooker is).
- Keep the cozy look, but **more animated**: pieces that move in an
  animated way.
- **Skins later**: users will get custom piece sets, each with its own
  animations. So the look and the motion had to be separable from the game.
- A top-down view, with sound.

## 2. What was built

| Piece | File |
|---|---|
| Rules (pure data, make/unmake, every draw rule) | `versus/chess_rules.gd` |
| Computer player and hints | `versus/chess_ai.gd` |
| Skin interface (a working plain set) | `versus/chess_skin.gd` |
| The house set, "Garden" | `versus/chess_skin_garden.gd` |
| Board: drawing, touch, the moves as scenes | `versus/chess_board.gd` |
| The screen | `versus/chess_screen.gd` |
| Record (draws, colour, skin added) | `versus/versus_record.gd` |
| The tab (two game cards now) | `ui/menu/versus_tab.gd` |
| Sounds | `assets/sfx/chess/*.ogg` (`tools/gen_sfx.py chess`) |

Harnesses: `tests/_probe_chess.gd` (perft against the published counts on
five positions, the computer's timing, mate in one),
`tests/_probe_chess_game.gd` (a whole game through the real screen, both
sides the computer, sped up; `SEED LEVEL LEVEL_YOU COLOUR SPEED`),
`tests/_shot_chess.gd` (tab, entrance, pick-up, hop, reply, knight leap,
capture into the tray, promotion picker, mate, end card).

## 3. Rules

Everything: castling (through and out of check refused), en passant,
promotion to any of four, check, checkmate, stalemate, the fifty-move rule,
threefold repetition (Zobrist hashes since the last irreversible move) and
insufficient material (bare kings, one minor, bishops all on one colour).
Draws are automatic; there is no draw offer and no resign (Back leaves).
Perft matches all five reference positions to depth 3-4.

## 4. The computer

Negamax alpha-beta with a capture-only quiescence search, a transposition
table (move order and bounded cutoffs, mate scores never cut), killer
moves, MVV-LVA order, a check extension, iterative deepening in a time
budget. Evaluation: material and Michniewski's simplified piece-square
tables, an endgame king table, the bishop pair, and a mop-up term so a won
ending is actually won. About 44k nodes a second in GDScript on this Mac.

| Level | Depth | Blur (sd, centipawns) | Budget |
|---|---|---|---|
| Easy | 1 + captures | 110 | 0.5 s |
| Medium | 2 + captures | 35 | 0.9 s |
| Hard | to 6, reaches 4-5 | none (root shuffled for variety) | 1.6 s |

The hint (three a game) is Hard for the player on 1.1 s: a gold arrow and
ring on the board. Found in the probe and fixed: a move that failed low tied
the best on its bound, the root sort put it first, and a round cut short by
the clock trusted it -- Hard played Nxf2 into Kxf2. The proven best now
always leads the next round.

## 5. Skins

`versus/chess_skin.gd` is the whole contract. A skin answers two questions
and nothing else:

1. **Draw this piece** -- `build(builder, type, side, cell, face, look)`,
   foot at the origin, cached per (type, side, face, look) and moved by
   transform, so motion never rebuilds a mesh. Six faces: open, blink, joy,
   worry, dizzy, sleep.
2. **Where is it and how is it standing, this far into this moment** -- a
   `Pose` (foot position in cells, lift, squash, tilt, scale, alpha, look)
   for: a move (per piece type), the capture's knock into the tray, idle
   (with `selected`), the refused shiver, the check tremble, the mate
   topple, the winners' cheer, promotion, and the entrance; plus timings,
   the contact moment of a capture, the take-off and landing cues and
   whether a landing throws dust.

The board owns the rules, the clock, the order of events, the trays, the
marks and the sounds' timing. `ChessSkin.named(id)` picks a set;
`Record.skin("chess")` is where a chosen set will be read from (it returns
"garden" until there is a way to choose). A new set is one subclass file.

## 6. The Garden set

Knight's cream and rose, carved and standing, each with a face, sharing
Knight's outline and crown (`ui/faces/chess_piece.gd`). **Your pieces are
always cream and always at the bottom**; the colour they move as swaps every
game (Play again), so the computer opens every other game. How each moves:

- pawn: a hop a square, squashing at both ends;
- knight: crouches, leaps high round the corner of its L leaning into it,
  lands in dust (sound `hop`);
- bishop: glides low along the diagonal, leaning the way it goes;
- rook: trundles on the ground rocking, overshoots and settles with a thud;
- queen: rises and crosses in a pirouette;
- king: waddles, two rocking steps a square;
- castling: the king waddles, the rook leaps over him;
- a capture: at the touch the taken piece is knocked tumbling, eyes spun,
  up and over into the tray (yours below the board, the computer's above),
  where it sleeps; "+N" material beside the tray that is ahead;
- promotion: the pawn spins and comes down as its new piece, with sparkle;
- check: the king trembles, worried, on a pulsing rose square;
- mate: the king wobbles and falls over; the winners hop in a wave out from
  the mating piece; a draw puts both sides to sleep;
- at rest: breathing out of step, blinks, the queen sways; a picked-up piece
  floats and smiles, and every piece it could take looks worried.

Under reduce motion every move is a short straight slide and nothing idles.

## 7. The screen

The flat top bar (Undo, Reset, the hint and its count, settings); a
scoreboard with the sun for you and the moon for the computer (lit when it
is their turn: "Your move", "Thinking…", "In check!", else who moved first)
and the move number between them; the board in a walnut frame on the same
wooden deck as snooker, the deck cut to hug the board. Tap a piece then a
square, or drag. A piece with no move shivers and says why ("would leave
your king in check" or "nowhere to go yet"). Undo takes back your move and
the computer's answer (both walk back, a taken piece hops out of the tray).
The computer picks its piece up for a beat before it moves.

Measured with `tests/_shot_chess.gd` at `--resolution 810x1440`: **99**
draw calls on the Versus tab (91 before, with one game), **166-170** at the
board with the full set, 115-145 in the endings.

## 8. The tab

Two game cards replace snooker's big card and the "more soon" card: each a
banner (snooker's table; chess's Garden set lined up on a strip of squares),
the name and the record at the picked level, a line, and the three levels
beside Play. Each game remembers its level. The record line gains "Drawn"
once a game has been drawn.

## 9. Open for the user

- The sounds are one take each, not yet listened to.
- Whether the computer's levels are right: Easy is meant to lose pieces.
- The skin shop: nothing chooses a skin yet; the plain base set exists to
  prove the contract and is not meant to ship as a choice.
- No concept-page tab was made first (the user was away).
- Online play, as for snooker.
