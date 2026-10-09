<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## Versus

**The bar has four tabs since 2026-09-26** (five since 2026-09-27, with
Arcade -- see below): Puzzles (the daily grid, which
was Home; its key is still `home`), **Versus**, Stats and Streak. Versus
holds games played against someone -- snooker, chess, checkers and air hockey; the first
is **snooker**, against the
computer only for now (spec `2026-09-26-versus-snooker-design.md`). It is not
a registry entry and not a `PuzzleBase`: `versus/snooker_screen.gd` is its own
screen, mounted by `ui/menu.gd`'s `_open_versus` the way a board host is,
closing back to the Versus tab (`_show_list("versus")`), and Android's back
reaches it through the `versus_host` group.

- **The physics is pure data** (`versus/snooker_sim.gd`, metres and
  seconds, regulation table on end, balls and pockets 1.3x): slide-then-roll
  cloth, spin as surface speed, collisions rewound to their time of impact.
  Run `tests/_probe_snooker.gd` after touching it.
- **The referee reads the table as it stood before the shot**: pots are off
  the table by the time `judge()` runs, so the colour on is
  `next_colour_before(pots)`. Reading it afterwards made every legal colour
  a foul and no frame ever ended; `tests/_probe_snooker_frame.gd` (computer
  against computer, `LEVEL`, `SEED`, `VERBOSE`) is what caught it and should
  finish a frame at every level.
- **The computer plans on a worker thread** against a copy of the table,
  inside a 1.8 s budget; the screen polls the task every frame whatever its
  state, so a hint still thinking when the turn passes never blocks the
  computer's own turn.
- **Its table sounds are foley, not the house style** (2026-09-26):
  `gen_sfx.py` appends a marimba-and-no-transients `STYLE` to every prompt,
  which turned a ball's clack into a soft boop, so a cue may name its own
  style (`FOLEY`). Clacks and cushions are as loud as the contact was hard
  (`Fx2D.cue`'s `volume_db`), and `roll` is a looping voice whose level
  follows the balls' summed speed (`_roll_sound`).
- **The pace is the cue drawn back, not a slot** (2026-09-26): press on the
  cue behind the ball and drag it back along its line; the pace is how far
  it was drawn, and letting go plays (`snooker_table.gd`'s `pulling` and
  `released`). A full draw is `REACH` 380 design px, or the room left to the
  screen's edge when the cue points at one -- a break from the D gets about
  190 -- never under `REACH_MIN` 150, and the cue follows the finger one to
  one. A ruler beside the cue fills with the pull and carries the hint's
  gold notch. The side column holds the spin pad alone.
  `tests/_tap_snooker.gd` drives it by input.
- 139 draw calls at the table since the slot went (149 with it, 146 before the polish of 2026-09-26, spec section 8), 91 on the tab (810x1440).
  The tab's picture is the real table drawn `still`, so it costs the menu
  no per-frame work.
- `tests/_shot_snooker.gd` forces a won frame for its end-card shot and puts
  `user://versus.cfg` back afterwards; a harness that finishes a frame some
  other way must do the same, or it writes a fake win into this Mac's save.

**Chess is the second Versus game** (2026-09-26, spec
`2026-09-26-versus-chess-design.md`), against the computer. The tab now holds
one card a game (banner, name and record, a line, levels beside Play), each
remembering its own level; the "more soon" card went to make room (99 draw
calls on the tab).

- **The rules are pure data** (`versus/chess_rules.gd`: every rule, draws
  included, make/unmake, Zobrist hashes). `tests/_probe_chess.gd` runs perft
  on five reference positions -- run it after touching move generation.
- **The computer** (`versus/chess_ai.gd`) is alpha-beta + quiescence in a
  time budget on a worker thread; the levels are depth and a blur on the
  scores. A move that fails low can tie the best on its bound, so an
  iterative-deepening root must keep the proven best first or a round cut
  short by the clock trusts a blunder (it played Nxf2 into Kxf2 until fixed).
- **A skin is the look and the motion, the board is everything else**:
  `versus/chess_skin.gd` is the contract (build a piece's mesh at its foot;
  answer a `Pose` for every moment: move per type, knock, idle, fidget,
  shiver, tremble, topple, cheer, promote, enter), `versus/chess_skin_garden.gd`
  the house set. Meshes are cached per type, side, face and look and moved by
  transform, never rebuilt to move. The board (`versus/chess_board.gd`) owns
  the rules' mirror (one actor a piece), the clock, the trays and the cues.
  `Skin` is a native Godot class, so the constant is `ChessSkin`.
- The player's pieces are always cream at the bottom; the colour they move
  as swaps every game. 122-129 draw calls at the board since the polish
  of 2026-09-26 (166-170 before; the terrace became one mesh), ANGLE
  agreeing. The board draws two live meshes, one under the pieces and one
  over, rebuilt a frame at a time: marks popping in, ripples, speed lines,
  the impact star, z's, the check's "!", the thought bubble and petals.
  Under reduce motion nothing idles, and two frames are pixel-identical.
- Harnesses: `tests/_shot_chess.gd` (every animation beat and the end card),
  `tests/_tap_chess.gd` (tap and drag by input), `tests/_probe_chess_game.gd`
  (a whole game through the real screen, both sides the computer; it loads
  the screen with `load()` at run time, because a `preload` compiles before
  the `Ads` autoload exists). All put `user://versus.cfg` back.

**Checkers is the third Versus game** (2026-09-26, spec
`2026-09-26-versus-checkers-design.md`), against the computer, built the way
chess is: rules, computer, skin contract, house set, board, screen.

- **Brazilian rules** (`versus/checkers_rules.gd`): flying kings, men take
  backwards, compulsory capture of the most pieces, captured pieces lifted
  at the end of the move. English draughts is the same class's AMERICAN
  flag, kept because its published perft (7 ... 36768 to depth 6) is what
  proves the move generator -- run `tests/_probe_checkers.gd` after touching
  it. A move is a `PackedInt32Array`, not chess's int: a chain can take
  eight.
- **Seen from straight above**: a pose's `lift` is drawn as growth, a rise
  up the screen and a sliding shadow; `flip` turns a piece over (the board
  draws the underside past a quarter). A piece is two meshes, `build_base`
  unturned and `build` turned by `spin`, so a twirl does not swing the
  edge band round the disc. Every piece's eyes are the board's to point
  (`_gaze_of`), quantised to eight directions and baked into the mesh key.
- A piece a move will take leaves `_at_sq` for its tray list the moment
  the move is played, but is `doomed` until the jumper is over it: it stays
  on its square watching, worried, not asleep. Anything that counts a tray
  must skip the doomed and the ones still in the air.
- 125 draw calls on the Versus tab, 130-136 at the board, ANGLE agreeing,
  unchanged by the polish of 2026-09-26 (spec section 10: a striped,
  bevelled lawn, glows in place of flat marks, heaped trays, the toast over
  the top planter, a crouch before a hop, a capture's air trail, the crown's
  sparkles, a fuller win, neighbours who chat). The tab now fits its three cards to the room (`versus_tab.gd`'s `_fit`),
  dropping the blurbs and then picture height rather than the bar.
- Harnesses: `tests/_shot_checkers.gd` (every beat; `reduce` after the
  outdir), `tests/_probe_checkers_game.gd` (a whole game, `UNDO=1` takes
  moves back). Both put `user://versus.cfg` back.

**Air hockey is the fourth Versus game** (2026-10-08, built unattended from
one line and a photograph of a table: "a new arcade multiplayer game of air
mini hockey"; no spec). Id `hockey`, title "Air Hockey" -- the game's own
plain name, as Mini Golf's is, so the renamed-genre rule does not bite. It is
on Versus and not on Arcade although the user's word was "arcade": Arcade is
played alone for a score, and this needs someone at the other end.

- **Three chips against the computer and a fourth for two people on the same
  phone** (`Record.LOCAL`, 4). **There is no game online and none against a
  friend**: the live transport is a turn's (`Match`: a move, then the other
  seat's, a minute each, the rules refusing a write out of turn) and this
  game has no turns -- two hands move at once, sixty times a second. Going
  online would need a channel each seat writes freely at ten or more a second
  (new rules, deployed by a person), someone to own the puck (each end in its
  own half is the usual answer) and a look at what 300 ms does to a rally; it
  was not half-wired. So `VersusTab.LOCAL_GAMES` holds `hockey`,
  `VersusTab.levels_of(game)` gives a card its four chips as `[key, level]`
  (the tab's `_level` is now the level itself, not the chip's index),
  `VersusTab.plays_online(game)` is what `open_friend_game` asks, and
  `ui/menu/invite_card.gd`'s own list of three is untouched. Nothing in
  `server/` changed.
- **The game is pure data** (`versus/hockey_sim.gd`, metres and seconds, a
  fixed 1/240 s): a table 1.0 by 1.6 on end, the bottom goal seat 0's. A
  mallet is led, not pushed -- `aim[p]` is where its player wants it and it
  goes there at up to `MALLET_MAX` 7.5 m/s inside its own half; its speed over
  the last `SWING` 8 steps (1/30 s) is what the puck is struck with, and it
  has no mass to lose (`MALLET_E` 0.72). **Never its speed over one step**
  (2026-10-09, the user: "a small movement makes it fly at maximum speed"):
  a finger's place is read once a frame, so the mallet crosses the whole
  frame's worth in its first 1/240 s and stands for the rest, and one step's
  speed was the hand's four times over at 60 Hz -- a puck at rest left at 6.9
  times the finger's speed where the rule says 1.72, and a finger at 0.8 m/s
  (about 5 cm/s on the glass) reached `PUCK_MAX`. Now it is 1.72 at 60 and at
  120 Hz and the cap takes a finger at 2.7 m/s
  (`tests/_probe_hockey_touch.gd`, headless). The computer strikes a little
  softer for it, its arm still gathering speed over the window: a goal every
  13 to 78 s where it was 10 to 56, each level still 12-0 over the one under. The puck is capped at `PUCK_MAX` 4.6 m/s (5.2 crossed the
  table in 0.3 s, quicker than anyone sees). A goal is the puck's middle
  `GOAL_DEPTH` past the rail inside the mouth; the mouth's corners are posts,
  struck as points. A puck squeezed against a rail pushes the mallet back,
  or the two trade places every step. **A slow puck within `EDGE` of a rail
  drifts back toward the table** (`DRIFT`): a mallet is wider than the puck
  and kept off the rails by its own radius, so a puck at rest in a corner
  could only be pushed further in, by a finger or by the computer, and a
  match stopped there (one in 108 did, computer against computer, the puck
  0.09 m from the top rail). First to `TARGET` 7; the screen serves
  to whoever was scored on. Run `tests/_probe_hockey.gd` after touching it.
- **The computer** (`versus/hockey_ai.gd`) has a person's limits, and the
  levels are those numbers (`LEVELS`): its arm's top speed (1.5 / 2.4 / 3.5
  m/s against a finger's 7.5), how late it sees the puck (0.30 / 0.19 /
  0.11 s, a queue of what it saw), how far off its aim and its block are, and
  whether it reads a bounce off the long rails. **Before the block had an
  error (`slip`), two of the same level never scored**: each met the puck
  dead on and sent it straight back, for ever. A puck that dawdles in its
  half `STALL` 2.5 s it stops lining up and goes straight at. It runs in the
  sim's own step,
  no thread. Worked out for the top mallet and turned over for the bottom
  one, so two of them play each other (the probe, the harnesses' hand, the
  tutorial's last page).
- **The table** (`versus/hockey_table.gd`): one baked mesh (frame, slots, the
  top with its air holes and lines) and one live mesh a frame (shadows, the
  puck and its trail, the mallets, a contact's spokes, a goal's glow). The
  bottom mallet is the sun's gold and the top one the moon's blue. **A finger
  leads a mallet that rides `LIFT` 0.085 m ahead of it**, so the thumb does
  not cover it; with one hand every touch is the bottom mallet's wherever it
  lands, with two a press belongs to the half it lands in, one touch index a
  mallet (`_finger`). `tests/_tap_hockey.gd` drives it with real
  `InputEventScreenTouch`es, two at once.
- **The screen** (`versus/hockey_screen.gd`) is snooker's shape without the
  bulb (`capabilities()` is empty): the sun's and the moon's plates, between
  them FIRST TO 7, two rows of pips and the match's clock. Nothing moves
  under the tutorial's card or the settings sheet. Two players are Sun and
  Moon; their matches write no record (`Record.add` is skipped, the tab's
  record line is empty) and send `versus_end` with `level: 4`.
- **Sounds** (`tools/gen_sfx.py hockey`, nine, one take each, unheard):
  `strike`, `wall`, `post` and `serve` are dry foley clicks -- they repeat --
  pitched and levelled by how hard the contact was (`_hit_db`); `glide` is a
  loop whose level follows the puck's speed; `goal`, `conceded`, `win` and
  `lose` are a real kalimba. With two players every goal is `goal` and the
  end is `win`.
- **The Versus tab holds four cards** and gave something up for it: `_fit`
  has a fourth step, `_set_side`, in which each picture leaves its own row
  and lies beside its game's name with the record under the name. At
  810x1440 that is the step it lands on (the cards need 1148 of 1300 design
  px; with three steps they needed 1284 and left the pictures 64 px strips);
  a 20:9 phone stops at the second step, pictures in their rows. 186 draw
  calls on the tab.
- 147-149 draw calls at the table, ANGLE agreeing, 161 with the end card,
  169-175 with a tutorial page up (810x1440). Most of it is the deck's
  planks and the pips, as on snooker.
- **The tutorial** (`ui/hud/hockey_tutorial_diagram.gd`, five pages): the
  whole table lying on its side, played by scripts of where each hand wants
  its mallet (`scene_of`, `want`, `advance`), so a page repeats exactly;
  the last page is two computers. The probe runs the four scripted scenes and
  fails if the swing does not score, the bank does not go in off a rail, or
  the block lets one through. Under reduce motion a page stands on one moment.
- Harnesses: `tests/_probe_hockey.gd -- [matches] [seed]` (headless: every
  pairing of levels, then the lessons), `tests/_shot_hockey.gd -- <outdir>
  [level] [rm] [lang=]` (the screen built by hand, the bottom mallet a
  level-2 computer, an end card forced; puts `user://versus.cfg` back),
  `tests/_tap_hockey.gd` (input; its "and not the far one" line already
  failed before 2026-10-09, the far mallet 0.02 m off home, not looked into),
  `tests/_probe_hockey_touch.gd` (headless: a finger read at 60 and 120 Hz
  into a puck at rest, the puck's speed for the finger's), `tests/_shot_versus_tab.gd -- <outdir>
  [banner]` (the tab alone, offline), `tests/_probe_versus_buzz.gd --
  hockey`, `tests/_shot_howto_screen.gd -- hockey <outdir>`.
- **Open** (nobody has played it with a finger): whether the puck's and the
  mallet's speeds feel right on a phone, whether `LIFT` is, whether Hard can
  be beaten and Easy cannot lose (computer against computer says only that
  each level beats the one under it 12-0), whether every wall and strike
  should knock (they echo, as every sound does), and the calls in the
  memory file.

**Haptics** (2026-10-03, `docs/agents/haptics.md` rows 30-32): the cues ring
for both players, so only `hint`, `win`, `lose` (and chess's and checkers'
`draw`) are mapped; everything else is `_fx.buzz` where the hand's side is
to move. `tests/_probe_versus_buzz.gd -- snooker|chess|checkers [rm]` reads the trace through
the real screen (headless; `LEVEL`, `YOU`, `SHOTS`, `SPEED`) and puts
`user://versus.cfg` back.

**Tutorials** (2026-10-04, `docs/agents/checkup.md`, the last section): each
screen has `tutor` (`ui/hud/screen_tutor.gd`) and `tutorial_pages()`, the
pages played by the real table or board (`ui/hud/snooker_tutorial_diagram.gd`,
`chess_`, `checkers_`). The computer's answer waits while the card is up
(`_held`). A harness that opens a screen through the menu sets
`ScreenTutor.no_first_play`.

**Online** (2026-10-04, spec `2026-10-04-versus-online-design.md`; where the
spec and the code differ the code is right -- snooker's shot is not the
spec's dictionary, `versus_online_end` carries more). **Level 3 is Online**
(`Record.ONLINE`): a fourth chip on every card of the tab, and Play then
looks for a stranger who is looking at the same moment; the two play one
live game with 60 s a move. No friends, no rating, no chat, no typed name.
The transport (the Realtime Database over REST, rules only, `core/live.gd`)
and what is not yet done on the live project are in
`docs/agents/turns-and-backend.md`; read that before touching `Live`, the
rules or `Match`'s clocks.

- **Three layers, and a screen talks only to the top one.**
  `versus/online/match.gd` (`Match`: the queue, the claim, streams, clocks;
  knows no game), `versus/online/lobby.gd` (the card over the board: knows
  no game and no Match), `versus/online/online.gd` (`Online`: everything
  about a game online that is not the game, one per screen), and
  `versus/online/names.gd` (a face and a name from `uid.hash()`: one of nine
  `ui/faces/` characters, `VS_NAME_*` and a number 100-999, "Hedgehog 482";
  `CAST`'s order is the deal, so adding one renames players and is done
  between versions).
- **`Online`'s API.** `Online.new(self, GAME)`, connect, `add_child`, then
  `open()`. Signals: `seeking` (a fresh look began -- `open()` and Find
  another -- lay the board idle), `started` (found and the 1.6 s found beat
  is over, 0.8 s under reduce motion; `seat`, `first`, `match_seed`,
  `opponent` are set), `move(d)`, `over(outcome, why)` (a result this screen
  did not write: outcome `won`/`lost`/`draw`, why `resign`/`timeout`/`left`/
  `end`), `computer` (the lobby's Play the computer), `closed` (Cancel, Back
  on the offline card, or a resignation: close the screen), `ticked` (the
  clock moved: dress the scoreboard again). Calls: `send(d, keeps_turn :=
  false)`, `foul()`, `settle(outcome, why, moves, mine_last := false)`,
  `opens()`, `live()` (from found until there is a result), `in_lobby()`,
  `seconds(mine)`, `dress(label, base, on, mine)` (the scoreboard line with
  `  ·  0:42` after it, quiet above `WARN_AT` 15, `Pal.BAD` and a bump a
  second under), `face(px)`, `rival()`, `first_line()`, `Online.fit(label,
  text, width)` (letters a name down to fit a plate cut for "Bot"),
  `head(outcome)`, `why_line(why, outcome)` ("" for `end`), `record_line()`,
  `again_button()` (Find another: `open()` on the same screen),
  `ask_leave(moves)` (the house dialog; a yes settles `lost`/`resign`,
  resigns and emits `closed`), `back()` (Android's back: true when it closed
  the dialog or gave up from the lobby; the found card just waits).
- **Nothing of the game is said before `started`** (review fix, 2026-10-04).
  `Match` hands a move over the moment the match is PLAYING, which is 1.6 s
  before a screen lays its board, and a screen clears its inbox as it lays
  it (`_lay`): a move that reached it inside the found beat was thrown away
  and the board lost on time waiting for it. So `Online` holds the other
  seat's moves (`_held`) and a result (`_held_end`) until `_begin()` has
  emitted `started`, then emits them in order, the result last. Do not
  connect a screen to `Match.move` directly.
- **A game that never began is not a game.** A result that arrives inside
  the found beat with no move held (the other end pressed Back, or its
  screen went) is not said at all: `Online` calls `open()` and looks again,
  no card, no `settle`. Back inside the beat at this end (`ask_leave` before
  `started`) asks nothing: `Match.cancel()` (which tells the match) and
  `closed`. And `settle` counts no record for a match in which neither seat
  moved (`_plies == 0`: `send` and every move heard add one) -- two ends
  with beats of different length (reduce motion halves it) would otherwise
  disagree on whether a walk-out in the first second was a game. It still
  sends `versus_online_end`.
- **`settle` is the only place the online record and `versus_online_end`
  are written**, once (`_settled`), and it is the screen that calls it, from
  `_conclude`. With `why == ""` the game ended on the board: `settle` writes
  the match's result (`Match.end`) only when `mine_last`, because the rules
  take `end` from the seat that made the last move and nobody else, and the
  other end hears it as `over(..., "end")`.
- **The pattern a screen follows** (all three; grep `# --- online (level
  3)`): `var online: Node`, null against the computer; `_init` clamps the
  level to `Record.ONLINE`; `_ready` calls `_go_online()` in place of the
  first `_new_game()`; a state for the board idle under the lobby (chess and
  checkers `State.WAIT`, snooker `State.LOBBY`) laid by `_lay`; on `started`
  the seat that opens is white / the light pieces / the break, the player
  stays cream at the bottom, and `_seat_rival(uid)` puts the other player's
  face and fitted name on the moon's plate ("…" and no face while looking);
  where the computer's turn called `_think("ai")` it calls `_take_online()`,
  which plays the next message in `_inbox` only when the board is ready
  (`State.THINK`) -- a move can land while this seat's own is still in the
  air; the player's own move is `online.send` as it is played; `can_undo`,
  `hints_left` and `can_reset` answer no, so undo, the bulb and Reset stay
  on the bar greyed; `_finish` is split into `_conclude(outcome, ..., why)`
  so a game can end off the board; **chess and checkers do not take the other
  seat's `end` on trust** (the rules let whoever moved last write it with
  any winner): `_online_end` only notes that it was said, the board finishes
  on its own `rules.status()` once the last move has been played (the two
  can arrive in either order), and an `end` this board does not reach with
  nothing left to play is `online.foul()` -- from `_on_online_over` when the
  board is already waiting (`YOURS`, or `THINK` with an empty inbox), else
  from `_start_turn`. Snooker is different by design: the shooter's table
  says the frame is over and the watcher takes it (`_take_online` concludes
  on `_online_end` only when no table is coming). The end card's head is `online.head`, its
  line `online.why_line`, a loss shows the other player's face, its button
  is `online.again_button()`; Back asks through `online.ask_leave` and sends
  no `versus_abandon`; `go_back()` (Android's back) tries `online.back()`
  first. `_play_computer` frees `online`, sets it null, takes
  `Record.last_bot_level(GAME)`, gives the bar its own motto back
  (`FlatTopBar.set_motto`; online it reads `VS_ONLINE_MOTTO`, A MINUTE A
  MOVE, because the game's own names the moon), sends a `versus_start` and
  opens `tutor.first_play()`. `ui/menu.gd` opens no first-play card over a
  screen whose `online` is set, and the tutorial card (the `?`) holds
  nothing online, since a stranger's clock is running: snooker's `_hold`
  returns at once, and chess's and checkers' `_held` only ever paused the
  computer's poll.
- **`Match`'s API**: `seek(game)`, `cancel()`, `send(d, next_turn)`,
  `end(winner, why := "end")`, `resign()`, `leave()`, `seconds_left()`,
  `turn()`; `wait` (25 s before `nobody`; a var so a probe shortens it),
  `phase` (`IDLE, SEEKING, JOINING, PLAYING, OVER`), `id`, `seat`,
  `opponent`; signals `found(seat, first, seed, opponent_uid)`, `nobody`,
  `move(d)`, `ended(winner, why)`, `clock(seat, seconds_left)`, `offline`.
  What it does that a caller must know:
  - **`nobody` is said once a seek** and the looking goes on behind it. Keep
    looking does not seek again: `Online` runs its own timer (`_keep_t`) and
    raises the card again after another `wait`. A void match's silent
    re-seek keeps the time already looked and whether `nobody` was said.
  - **`found` only after both seats have written `seen`**, never on the
    claim: a claimed ticket whose owner is gone is voided after 10 s and the
    seeker goes back to looking without a word (`_reseek`).
  - **`leave()` resigns** a game that has no result (JOINING too), takes a
    ticket out of the queue, shuts both streams and emits nothing.
    `cancel()` is `leave()`, `seek()` begins with one, and so does
    `_exit_tree`: freeing a live Match is a resignation. In JOINING the seat
    is known before the document says so (`_sits`: the claimed ticket's
    owner is p0, the claimer p1), so walking away in that gap resigns too.
  - **A seek cancelled while its claim is on the way** (`_scan`): if the
    claim landed all the same, the match it made is resigned at once
    (`winner: 0`, the claimer is p1; the rules allow a resignation to either
    player at any time), so the player claimed re-seeks in about a second
    instead of waiting 11.5 s for void. Not when the ticket stream already
    said so and this is the match joined (`id == mid`). On one Mac the
    ticket's delete usually overtakes the claim and the rules refuse the
    claim; both ways are right.
  - **It is a follower of state**: it keeps the match document (`_m`),
    applies each stream event by path (`_apply`; arrays turned back into
    keyed objects, `_keyed`, because the database hands `moves` and `seen`
    back as arrays), and hands out the other seat's moves from `_handed` up
    to `n`. A reopened stream sends the whole document again, so
    reconnecting has no code of its own. Do not add a "reconnected" path.
  - **Moves go out one at a time and in order** (`_outbox`, `_pump`). **A
    move keeps the `n` it was first sent at** (`item.n`), and anything but a
    yes -- no answer, or a 401 -- is settled by reading `moves/{n}`: if it
    is this seat's with this `d` the move was sent (the PATCH landed and its
    answer was lost) and what is queued behind goes out at `n + 1`; a 401
    with the move not there is final (the game is over, or this end is out
    of step and the clock settles it); a read that does not answer means try
    again. Before this a lost answer followed by a lost read sent the move
    again at an `n` counted afresh: twice when the stream had caught up (a
    snooker shot twice is a foul at the other end), or refused and dropped
    with the message behind it when it had not. **The PATCH's echo is applied
    only when the copy is not already past it** (`_m.n <= n`): the stream may
    have brought the move and the reply first, and a late echo rolled `n`,
    `turn` and `turnAt` back.
  - **Claim margins.** The rules' clocks are 10 s (a ticket's heartbeat, and
    void), 20 s (left) and 60 s (a move). This end claims on its estimate of
    the server's clock (`Live.server_now()`) `GRACE_MS` 1.5 s late, asks
    again no sooner than `CLAIM_GAP` 3 s, and a refusal costs nothing. It
    only claims a ticket whose heartbeat is under `FRESH_MS` 8.5 s old.
    Timeout is claimed by the seat that is not to move; left by either.
    Heartbeats: the ticket's `at` every 4 s, `seen` every 5 s, the queue
    read every 3 s. Up to four tickets 61 s stale are swept per read.
  - **Stream watchdog.** The other seat's heartbeat reaches the match
    stream every 5 s, so one quiet for `QUIET_MAX` 12 s is cut
    (`Stream.drop()`) and reopens; `Live.Stream`'s own limit is 40 s (the
    server's keep-alive is 30 s). A match whose document never arrives says
    `offline` after `JOIN_MAX` 20 s.
- **The wire** (`moves/{i}.d`, a JSON string the game owns, at most 20,000
  characters by the rules):
  - chess `{m: int}` -- the rules' own move int, so a promotion's piece, a
    castle and an en passant travel in it;
  - checkers `{m: [int...]}` -- the rules' own `PackedInt32Array` (from, the
    count, the landings, the pieces taken), so a whole chain and a crowning
    travel in it;
  - **snooker is not done the way chess is**, because two phones cannot be
    trusted to roll a shot alike: **the shooter is the authority**. Letting
    go sends `{shot: <base64>}` -- seven float32s (`Sim.pack`): the line x,
    y, the pace, the tip x, y, where the cue ball stood x, y (a placement in
    the D travels in that) -- with `keeps_turn`, and the shooter then plays
    the pace as it reads back out of the packing, to the bit. The watcher
    shows the cue play it (`_swing`, as the computer's is shown; at `HURRY`
    0.4 of the time when the next message is already waiting) and rolls it
    on its own table. When the shooter's table has stopped and its referee
    has judged it sends `{table: {p, on}, rules: {...}}` with the next turn:
    `p` is every ball's place as base64 float32s, `on` a bit a ball
    (`Sim.snapshot`), `rules` the referee's whole state
    (`snooker_rules.to_dict`). About 620 characters. **Floats never travel
    as JSON numbers.** **The watcher never judges**: after its own roll it
    waits in `State.SETTLE` for that message, takes table and state as sent
    (`Sim.read`/`restore`, `from_dict(sent, true)`), reads the points, the
    foul and the faces off the sent `last` (`_call`), and slides any ball
    that stopped elsewhere to its place in `SLIDE` 0.15 s
    (`snooker_table.slide`; snapped under reduce motion). The shooter also
    restores its own table from its own snapshot, so both start the next
    shot the same to the bit. **A cue ball in hand is seated before the
    snapshot** (`_judge` calls `_seat_cue_ball()` when `rules.in_hand`): the
    referee puts it on one spot in the D whatever stands there, and a table
    sent with it on top of another ball is one `Sim.read` refuses -- a foul
    on a legal frame.
  - **Each end is player 0.** `to_dict` writes the state as its owner sees
    it and the receiver reads it with `flip` (`turn`, `scores`, `breaks`,
    `high`, `winner`, `breaker`, `last.player` swap). The same holds one
    layer up: a screen thinks in "mine" and "theirs" and only `Online` and
    `Match` know seats.
  - Snooker's clock is on the name of whoever is aiming and only while they
    aim (`_dress_clocks`); the shot message stamps `turnAt` afresh, so the
    roll and the table message have their own 60 s.
- **A foul** is a message this end's rules could not have produced; nothing
  on the server knows the games. `online.foul()` sets the result to a win
  with why `left`, calls `Match.leave()` and emits `over("won", "left")`.
  `foul()` also works on a result of `end` not yet settled, which is how a
  forged ending is refused. Chess: `m` not a number, or not in
  `rules.legal_moves()`. Checkers: `m` not an array of numbers, or not equal
  to a listed move whole (so the most pieces are taken). Both: an `end` from
  the other seat that this board's own rules do not reach. Snooker's shot: more than the one key, not seven finite
  floats, a line not of length 1, a pace of 0 or over `Sim.MAX_SPEED`, a tip
  past `Sim.MAX_TIP`, a cue ball that is not where this table has it (or,
  in hand, not in the D or on another ball). Snooker's table: more than the
  two keys, `Sim.read` refusing it (the wrong count of balls, a place off
  the table, no cue ball, two balls in one place), `from_dict` refusing the
  state, or `_possible` -- a shot not played by the other seat, a score gone
  down, one up by more than 7 (mine) or 16 (theirs), both up, a frame over
  with its winner not ahead, a red on the table that was not before the
  shot. A message out of place (a table where a shot belongs) fails the same
  checks.
- **`Record.last_bot_level(game)`** (`versus/versus_record.gd`): the level
  last picked against the computer, 0-2, kept under `[last_bot]` because
  `last_level` now answers 3 after Online was picked. It is what Play the
  computer starts. `set_last_level(3)` on a save from before Online carries
  the old `last` over. The online record is the same kind of key as the
  others (`chess_3`: won, lost, drawn) and is sent nowhere.
- **Draw calls** (810x1440): the tab 150 with four chips (125 with three);
  online boards chess 129, checkers 138-140 (130-136 against the computer),
  snooker 143-144 (139); the lobby over a board up to 167, an end card up to
  174.
- **Probes and harnesses.** The three probes want the emulators and nothing
  windowed; start them once:
  `cd server && PATH="/opt/homebrew/opt/openjdk/bin:$PATH" firebase
  emulators:start --only auth,database --project demo-peeplet`.
  - `tests/_probe_live_rules.sh` (`QUICK=1` skips the 20 s and 60 s cases;
    about 65 s whole): 59 cases with curl -- the ticket, the claim and every
    way to cheat it, a move in and out of turn, each result allowed and
    refused, the four clocks waited out for real. Run it after touching
    `server/database.rules.json`.
  - `FIREBASE_EMULATOR=127.0.0.1 FIREBASE_PROJECT=demo-peeplet godot
    --headless --path . --script res://tests/_probe_match.gd` (add `--
    clocks` for another 65 s): unstarted means `offline` and no network; a
    lone seeker hears `nobody` and leaves no ticket; two processes trade ten
    bare moves to one result, one of them cutting its own stream so a move
    is made while it is not listening; with `clocks`, void, left and timeout
    are claimed for real. Run it after touching `Match` or `Live`. Also:
    **lost answers** (`Live.lose = 2` -- a seam like `Stream.drop()`: the
    next two requests land and their answers are thrown away) on a move of
    two messages, the first keeping the turn, and on a move whose reply
    arrives before it is settled: the first goes in once, the one behind it
    goes, the count never steps back; and **a seek cancelled mid-claim**
    (`Match._claim_mid` names the claim in flight), once as it falls and
    once with the ticket's delete held back so the claim lands: the match is
    resigned at once and the one claimed is looking again in 1.3 s. Every
    mode, the children's too, refuses to run without `FIREBASE_EMULATOR`.
  - `... --script res://tests/_probe_online.gd -- chess|checkers|snooker`:
    two processes, the real screen at level 3, each seat played by the
    game's computer (level 1 against level 0) as if tapped. Four cases: a
    whole game to one result and one final position at both ends (chess
    opens on a line with an en passant, an underpromotion and a castle a
    side; checkers on seven plies with a capture each way and a man that
    takes two and is crowned where it lands); a SIGKILL mid-game (the other
    ends `left`, about 22 s); a resignation through Back and the dialog; a
    move no rule allows (a foul). **Snooker's whole frame is the one that
    matters**: both ends hash table and referee's state after every shot and
    must agree on all of them, and it prints the watcher's drift before it
    took the shooter's table -- **0 mm over 106 shots on this Mac**, which
    proves the sim is deterministic on one machine and nothing about two
    phones. That is what **the nudge** case is for: one end moves a ball on
    its copy (`NUDGE`, metres, 0.004) before every roll it watches, its
    rolls end up to half a metre off, and the hashes must still agree.
    Snooker's foul is tried twice (a shot that is not one, a table one ball
    short). `SPEED` (4; snooker 8), `SEED`. Four more since the review:
    **a forged end** (chess, checkers: a move, then `end` written won with
    the game on; the other ends `left`, a win, no loss counted); **a move
    inside the found beat** (all three: the opener starts with no beat and
    moves at once, the other holds the message until its board is laid and
    the game goes on to a resignation); **Back inside the found beat** (all
    three: one closes, the other looks again with no card, no record
    moves); **an in-off with a ball on the cue ball's spot** (snooker: a
    shot stopped mid-roll with the cue ball potted and a red on the spot;
    the cue ball is seated clear, every hash agrees, no foul). Every mode
    refuses to run without `FIREBASE_EMULATOR`.
  - `tests/_probe_snooker_frame.gd` also checks, after every shot, that
    `{table, rules}` comes back through JSON exactly, flipped and not, and
    prints the longest message.
  - `caffeinate -d -i -u godot --path . --resolution 810x1440
    --always-on-top --script res://tests/_shot_online.gd -- <outdir>
    [lang=pt|es] [rm] [tab] [checkers] [snooker]`: windowed, no network, the
    Match is `tests/_fake_match.gd` (`say_found`, `say_move`, `say_clock`,
    `say_ended`, `say_nobody`, `say_offline`; `sent` holds what the screen
    sent). The tab, the lobby's four states, the clock quiet and warning,
    the dialog, the end cards, Play the computer, Cancel; `checkers` or
    `snooker` alone skips what comes before it. Prints draw calls a shot.
- **Harness hygiene, online's own.**
  - **A harness that instantiates `world/main.tscn` puts
    `tests/_offline_main.gd` on it before it enters the tree**
    (`main.set_script(load(...))`): `world/main.gd` without its `_ready`,
    which is what starts `Analytics`, `Backend` and `Ads` -- against the
    live project, since nothing names an emulator. `_shot_online.gd` does,
    prints `first frame: backend started false, analytics started false,
    ads started false`, and quits if one is true. What it did before
    (stopping both at the top of its first `_process`) was measured: by
    that frame both were started, `game_open` had been handed to an
    HTTPRequest and a sign-in begun, and only the frame's end took them
    back. `Ads.start()` does nothing off a phone.
  - `Online.stand_in` (a static `GDScript`) is what `Online._ready` builds
    in place of `Match`; set it before the screen opens and reach the fake
    as `screen.online._match`. A stand-in must have `wait`, `seek`,
    `cancel`, `send`, `end`, `resign`, `leave`, `turn`, `seconds_left` and
    the six signals.
  - **Two processes share `user://versus.cfg`**, so in `_probe_online.gd`
    only the conductor saves and restores it and the players leave it
    alone. Each player is its own identity through `BACKEND_PLAYER`
    (`user://probe_player_<who>.cfg`).
  - **A killed harness leaves a fake level-3 record** (and `last = 3`) in
    this Mac's save: every finished game writes `chess_3` and the like, and
    the restore is on the way out.
  - A harness that opens a screen at level 3 with `Backend` unstarted gets
    the offline card, not a game: that is the design, not a bug.

**Online: open** (2026-10-04)

- **Every other harness that builds `world/main.tscn` starts `Backend` (and
  `Analytics`, when `res://analytics_secret.cfg` or `GA_API_SECRET` is
  there) against the live project and never stops it**: fifty-odd
  `tests/_shot_*.gd`, `_tap*.gd`, `_probe_*.gd` (`grep -L "stop()" $(grep -l
  world/main.tscn tests/*.gd)`); the few that call `stop()` do it after the
  start. `tests/_offline_main.gd` is the fix and only `_shot_online.gd`
  uses it yet. `CLAUDE.md`'s "tests and harnesses stay offline" is true of
  the ones that build a screen themselves.
- The lost-answer and mid-claim fixes were seen with the stream up (one Mac,
  the emulator). A PATCH that lands with its answer lost *and* the stream
  down was not staged; the same read of `moves/{n}` settles it.
- A foul on a forged `end` is a win by `left` at the honest end; the forger's
  own device shows what it wrote.

- Never run on two devices, and never against the real project: the
  database instance exists since 2026-10-04 but the rules are not deployed
  (`turns-and-backend.md`). Everything above was seen against the emulator,
  two processes on one Mac.
- No sweep: finished matches stay in `/matches` for good; stale tickets go
  only when another seeker reads the queue.
- After a foul the honest end walks away through `Match.leave()`, which
  writes a resignation, so the cheater's end reads "won by resign" and
  counts a win on its own device.
- Not exercised through a screen: a draw online (chess, checkers; the rules
  probe covers `end` with winner -1), and a real 60 s timeout (`_probe_match
  -- clocks` waits one out with bare moves; the shots fake the card).
- An online screen sends `versus_start` with `level: 3` as it opens, before
  anyone is found (`docs/agents/analytics.md`).
- The pt and es names and strings (`VS_NAME_*`, the 28 `VS_` keys,
  `SNK_RIVAL_TURN`) are machine-fluent and want a native eye.
