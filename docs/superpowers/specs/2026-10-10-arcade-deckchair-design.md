# Deckchair, the Arcade tab's ninth game

2026-10-10. Built in one sitting while the user was away, from their brief
over a screenshot of an image search: "is the next arcade game to be
created, check rules on web, wire everything even sound, do autonomous, no
questions". No concept tab came first: nobody was there to judge one, so it
went spec to Godot as the other unattended builds have, and every call
below that the brief did not make is listed in section 7 as mine.

## 1. Where it lives

On the **Arcade tab**, the ninth card, after Beeline
(`ui/menu/arcade_tab.gd`, `ui/menu.gd`'s `_open_arcade`). A deal played
alone for a score, with the Arcade's boosters, Second chance, gold and end
card.

## 2. The game

**It is called Deckchair and nothing else**, in code, in a comment, in a
sound prompt, in a commit or on screen. The reference is the patience game
*Klondike*, which the world calls *Solitaire* since Microsoft shipped it
with Windows in 1990; both are named here once, to forbid them. The search's
other pictures (the eight-column spider game, the peg board) are not this
game. What was taken, checked on the web (the GNOME card games' manual,
two rule sites and the write-ups of the Windows scoring):

- 52 cards. **Seven columns** of one to seven cards, only the last of each
  face up; the other 24 are the **stock**.
- A column is **built downward in alternating colours** (a red six on a
  black seven). Any face-up card moves with everything lying on it.
- A face-down card left on top of its column is turned up.
- **Only a king** (with what lies on it) may start an empty column.
- Four **homes**, one a suit, built upward from the ace to the king. A
  home's top card may be brought back down onto a column.
- The stock is turned onto the waste, whose top card is in play. The
  sources differ on how many at a time and how often: here it is **one
  card at a time, gone through as often as wanted**, the kindest of the
  rule sets found.
- All 52 home wins the deal.
- **The score** is the Windows one: 10 for a card home, 5 for a card
  turned face up, 5 for a card played off the waste onto a column, 15 lost
  for a card brought back down, never under nothing; a deal won pays
  700,000 over its seconds (never fewer than 30). Left out on purpose: the
  2 points lost every ten seconds and the 100 lost for each pass of the
  stock.

`arcade/deckchair_sim.gd` holds it as pure data: a card is 0 to 51, the
homes are counts, a move resolves at once and leaves events.

## 3. What is its own

- **Tap or carry.** A tap sends a card where it may go, its home first,
  then a column that is not empty, then an empty one. Or the card is
  carried, with what lies on it; the places it may go wear a ring and it
  is set down on whichever of them it covers most.
- **Undo** takes back any move and its points (400 deep). **Three hints**
  a deal: the bulb rings a move that gets somewhere.
- **The dead end is called.** Random deals of this game cannot all be won,
  and a deal that can be won is lost by a wrong turn. Measured 2026-10-10
  with a solver that sees every card, on seeds 1 to 1000: 854 can be won,
  54 cannot whatever is done, 92 not settled at four million positions. The
  bot here, which takes the nearest card turned up or sent home, wins 493
  of them, so most dead ends are a winnable deal played into a corner.
  After every move the sim looks for a way on: a card turned up, a card
  home past where the homes stand, or a card played off the stock (every
  one of which is within reach, the stock being turned one at a time for
  ever). It looks twice (`_replan`): the columns rearranged among
  themselves; then with the homes' top cards brought down as well, to 600
  positions. With nothing found a card comes up at the
  table's foot: **Undo**, or **Finish** and keep the score. The table above
  it stays the player's, and a move that finds a way on puts it away.
  A search given up at 600 says stuck too (`unsure`): of 300 deals 31 end
  so, and looked at to 100,000 positions every one of them but one was
  stuck indeed.
- **The sweep.** With no card left face down the deal is won (the lowest
  card not yet home is always on top of its pile or in the stock), so the
  cards go home by themselves, one every 0.085 s, each scoring its 10.
- **No mascot.** The cards are marks, so nobody sits on the table or the
  end card, whose seat is a fan of the four homes' top cards.
- The back is a deckchair's striped canvas. A red card and a black card are
  told apart by their marks' colour, so nothing else is said by a tint of
  the card: a place is a gold ring, a refusal a shake.

## 4. The Arcade's kit

- Boosters (`arcade/boosters.gd`): **Aces home** (`dc_aces`: the same
  shuffle dealt with the four aces already on their piles, worth nothing)
  and **More hints** (`dc_hints`: three more).
- **Second chance**, offered when a dead end is finished with points made:
  every card still face down and the whole stock are shuffled and laid
  back in the same places, again until there is a way on.
- The record is the score; its "furthest" is the most cards sent home in
  a deal.

## 5. Sound and feel

`SETS["deckchair"]` in `tools/gen_sfx.py`, fifteen cues made against the
cozy rules. Everything a card does is one tick, a single take (a flat
wooden tile laid on felt, 523 Hz) cut short and moved a step or two:
`place`, `lift`, `draw`, `flip`, `home`, `undo`, `nope`, with `recycle` and
`deal` the wheel spun. The moments (`hint`, `suit`, `stuck`, `win`,
`game_over`, `new_best`) are Beeline's muffled kalimba note written into
phrases, none above -8 and no two with one contour. Haptics: a card lifted,
set down or drawn is its sound's echo; a card home a tap, a card turned up
a tick, a refusal a warn, the bulb and a suit home good, the dead end bad,
the win and a new best the win; the sweep's cards are heard and one in four
is felt (`docs/agents/haptics.md` row 53).

## 6. Checked

- `tests/_probe_deckchair.gd` (headless): 300 deals, the bot wins 151,
  118 end stuck and 31 stuck past the search's reach; after every move 52
  cards each once, every run built down in turn, no column all face down;
  undo walks back to the deal; a hand-made dead end, a way on two moves
  deep, the aces-home deal, twelve Second chances, the points. 0 failed.
  The slowest single move of 60 deals is 70 ms on this Mac (the second
  look, at a near dead end).
- `tests/_shot_deckchair.gd` through the real menu at 810x1440, on the
  desktop driver (two readings), on `opengl3_angle`, under reduce motion
  and in pt and es: a ScreenTouch on the stock turns a card, a ScreenDrag
  carries a card to a column and it is laid, a ScreenTouch on a card sends
  it. 103 draw calls dealt, 119 with a card carried, 133 mid deal, 162
  with the dead end's card, 196 on its end card, 119 in the sweep, 92 at
  the win, 130 on the win's end card, 302 on the tab with nine cards.
- `tests/_shot_howto_screen.gd -- deckchair`: eight pages, 162-167 draw
  calls, the longest body 188 px of 230 in pt.
- `tests/_probe_chance.gd` and `tests/_probe_wallet.gd` with Deckchair
  added; the suite 249800/0.

## 7. Calls that are mine, unconfirmed

1. The name, and that the name of the original is used nowhere.
2. One card turned at a time and the stock gone through for ever (not
   three at a time, no limit of passes).
3. The Windows score without its two penalties for time and for passes;
   the time bonus kept, so a quicker win scores more.
4. Deals are shuffled, not picked: at least 85 in 100 can be won and at
   least 5 in 100 cannot (section 3; an earlier line here said "about
   half", which was the bot's losses, not the deals'). A bank of proved
   deals (as Lattice and Horse Pen have) would make every deal winnable
   and was not built. The bulb follows the bot, so a hint can lead into a
   dead end of a deal that could be won.
5. The dead end is called by the game, with Undo and Finish; there is no
   way to finish a deal that still has a move.
6. Undo without limit or price; three hints.
7. The two boosters and what the Second chance does; no chance on a deal
   that scored nothing, none on a deal won.
8. Homes on the left, the waste and the stock on the right.
9. Plain court cards: a letter and the suit's mark, no pictures.
10. The sweep starts by itself.

## 8. Not done

Nothing run on a phone (the carry under a thumb least of all, and the
second look's 70 ms there); no sound heard by a person; pt and es written
by me and read by nobody; `tests/_probe_arcade_buzz.gd` has no Deckchair
bot, so the knocks are read from the code, not traced. A column of twelve
or more closes its fan up to stay on the cloth and was not shot. The tab
holds nine cards, the ninth alone on a fifth row: it fits at 810x1440 with
nothing to spare.
