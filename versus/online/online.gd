extends Node

## Everything about a game online that is not the game: the Match, the lobby
## over the board, the found beat, the clock's line on the scoreboard and its
## warning, the dialog Back asks with, why a game ended when it did not end
## on the board, the record, the analytics and Find another. Snooker, chess
## and checkers each keep one of these when their level is Record.ONLINE and
## leave their own screen to be the game.
##
## A screen's side of it, in order:
##
##     online = Online.new(self, GAME)   # then connect, then add_child
##     online.open()                     # `seeking`: lay the board idle
##     ... `started`                     # seat, first, match_seed, opponent are set
##                                       # (nothing of the game is said before it)
##     online.send(d)                    # this seat's move, as it is played
##     ... `move(d)`                     # the other seat's, in order
##     online.foul()                     # ... if that move was not legal
##     online.settle(outcome, "", moves, mine_last)   # it ended on the board
##     ... `over(outcome, why)`          # it ended some other way
##     online.settle(outcome, why, moves)
##
## and `computer` (the lobby's Play the computer: free this and play a normal
## game) and `closed` (the player backed out: close the screen).
##
## **Against a friend** nothing of that changes for the screen. The menu sets
## `Online.with_friend` before it builds the screen; `open()` then asks that
## friend (or takes their invite) in place of looking, the lobby waits on
## their face, and a game that will not come is the lobby's own card
## (`Match.gone`), never the queue. core/social.gd is told who this is busy
## with and whether a game is on, so it knows what to do with an invite.
## Spec: docs/superpowers/specs/2026-10-04-versus-online-design.md, section 3;
## 2026-10-04-friends-design.md, section 3.

## A fresh look for a player has begun (open(), Find another): the board goes
## back to idle behind the lobby.
signal seeking
## A player was found and the beat that shows them is over: start the game.
signal started
## The other seat's move, each one once and in order, and never before
## `started`: one that lands inside the found beat is held until the screen
## has laid its board.
signal move(d: Dictionary)
## The match has a result this screen did not write: "won", "lost" or "draw",
## and why -- "resign", "timeout", "left", or "end" when the other seat said
## the game ended on the board. Never before `started` either: a match given
## up inside the found beat with no move made never began, and this goes back
## to looking without a word.
signal over(outcome: String, why: String)
## The lobby's "Play the computer".
signal computer
## The player gave up on playing online: Cancel, Back, or a resignation.
signal closed
## The clock moved: the scoreboard's line wants dressing again.
signal ticked

const Match = preload("res://versus/online/match.gd")
const Lobby = preload("res://versus/online/lobby.gd")
const Names = preload("res://versus/online/names.gd")
const Social = preload("res://core/social.gd")
const Backend = preload("res://core/backend.gd")
const Record = preload("res://versus/versus_record.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Motion = preload("res://core/motion.gd")
const Haptics = preload("res://core/haptics.gd")
const Analytics = preload("res://core/analytics.gd")
const Pal = preload("res://core/palette.gd")

## Seconds a move has (the rules' LIMIT), under which the clock warns, and at
## which the phone knocks once on your own move.
const LIMIT := 60
const WARN_AT := 15
const BUZZ_AT := 10
## How long the found card stands before the game starts.
const FOUND_BEAT := 1.6

## A harness's scripted Match (tests/_fake_match.gd): same signals and
## methods, no network.
static var stand_in: GDScript = null
## The friend the next screen at level 3 plays, set by the menu before it
## builds the screen: {uid, accept}. Read and cleared in _init.
static var with_friend := {}
## The Online that last told Social who it is busy with, so one on its way
## out does not wipe what the next has just said.
static var _teller := 0

var game := ""
## This end's seat, the seat that opens, the number both ends share and the
## other player's uid, from `started` on.
var seat := -1
var first := -1
var match_seed := 0
var opponent := ""
## The friend this game is with; "" against a stranger.
var friend := ""
## The match's result once it has one: {winner, why}.
var result := {}

var _screen: Control
var _match: Node
var _lobby: Control
var _ask: Control
var _run := 0
var _sought_at := 0
var _keep_t := -1.0
var _warned := false
var _bumped := -1
var _settled := false
## `started` has been said for this match. Until then the other seat's moves
## wait in `_held` and a result in `_held_end`.
var _begun := false
var _held: Array[Dictionary] = []
var _held_end := {}
## Moves made in this match, by either seat.
var _plies := 0
## The first open() takes the friend's invite; any after it asks them.
var _accept := false

func _init(screen: Control, the_game: String) -> void:
	name = "Online"
	_screen = screen
	game = the_game
	friend = str(with_friend.get("uid", ""))
	_accept = not friend.is_empty() and bool(with_friend.get("accept", false))
	with_friend = {}

func _ready() -> void:
	_match = (stand_in if stand_in != null else Match).new()
	_match.name = "Match"
	_match.found.connect(_on_found)
	_match.nobody.connect(_on_nobody)
	_match.offline.connect(_on_offline)
	_match.move.connect(_on_move)
	_match.ended.connect(_on_ended)
	_match.clock.connect(_on_clock)
	_match.gone.connect(_on_gone)
	add_child(_match)
	if not friend.is_empty():
		Social.hub().matched.connect(_on_matched)

func _exit_tree() -> void:
	_tell("", false)

## Social's two flags: who this is waiting on or playing, and whether a live
## game is on (a stranger's too: no invite is shown over one).
func _tell(busy: String, playing: bool) -> void:
	if busy.is_empty() and not playing and _teller != get_instance_id():
		return
	_teller = get_instance_id()
	Social.busy_with = busy
	Social.in_game = playing

# --- looking ---

## Looks for a player, from nothing: the lobby goes up and the board idles.
func open() -> void:
	_run += 1
	seat = -1
	first = -1
	opponent = ""
	result = {}
	_settled = false
	_begun = false
	_held.clear()
	_held_end = {}
	_plies = 0
	_warned = false
	_keep_t = -1.0
	_close_ask()
	_tell(friend, false)
	seeking.emit()
	_sought_at = Time.get_ticks_msec()
	if not friend.is_empty():
		_raise_lobby().show_waiting(friend)
		# Their own invite to this game is already here (asked before this
		# end did, and seen as a card, not as `matched`): it is taken, as
		# two invites that cross would only wait on each other.
		if _accept or Social.invite_from(friend) == game:
			_accept = false
			_match.accept(game, friend)
		else:
			Analytics.track("versus_friend_invite", {"game": game})
			_match.invite(game, friend)
		return
	_raise_lobby().show_looking()
	Analytics.track("versus_online_seek", {"game": game})
	_match.seek(game)

func _raise_lobby() -> Control:
	if not is_instance_valid(_lobby) or _lobby.state == Lobby.State.NONE:
		_lobby = Lobby.new()
		_lobby.cancel.connect(_on_cancel)
		_lobby.keep.connect(_on_keep)
		_lobby.computer.connect(_on_computer)
		_lobby.again.connect(open)
		_screen.add_child(_lobby)
	return _lobby

func _drop_lobby() -> void:
	if is_instance_valid(_lobby):
		_lobby.leave()
	_lobby = null

func _on_nobody() -> void:
	if is_instance_valid(_lobby) and _lobby.state == Lobby.State.LOOKING:
		_keep_t = -1.0
		_lobby.show_nobody()
	elif is_instance_valid(_lobby) and _lobby.state == Lobby.State.WAITING:
		_keep_t = -1.0
		_lobby.show_no_answer(friend)

func _on_offline() -> void:
	_keep_t = -1.0
	_raise_lobby().show_offline()

## Match says `nobody` once and keeps looking; so does the card, and it asks
## again after as long a wait.
func _on_keep() -> void:
	_keep_t = 0.0
	if not friend.is_empty():
		_lobby.show_waiting(friend)
		return
	Analytics.track("versus_online_nobody", {"game": game, "choice": "keep"})
	_lobby.show_looking()

## A game with the friend will not come of this asking (Match.gone). Nothing
## is looked for in its place: the card says why, and Ask again is open().
func _on_gone(why: String) -> void:
	if friend.is_empty():
		return
	_keep_t = -1.0
	seat = -1
	_tell(friend, false)
	if why == "expired":
		Analytics.track("versus_friend_answer", {"game": game, "choice": "expired"})
	# Removed from the friends meanwhile: there is nobody to ask again.
	if Social.started() and Social.loaded() and not Social.is_friend(friend):
		why = "unfriend"
	_raise_lobby().show_gone(friend, why)

## The friend this is waiting on has asked too (both pressed Rematch, or
## each asked the other). One invite is enough: the end with the smaller uid
## drops its own and takes theirs, the other just goes on waiting and is
## taken. Anything else -- another game, or this end not asking at all (the
## end card, the gone card) -- is an invite like any other, and is said as
## one so the menu's card comes up.
func _on_matched(from: String, their_game: String) -> void:
	if from != friend or live():
		return
	var asking: bool = _match.phase == Match.Phase.SEEKING and in_lobby() \
		and (_lobby.state == Lobby.State.WAITING or _lobby.state == Lobby.State.NO_ANSWER)
	if not asking or their_game != game:
		Social.hub().invited.emit(from, their_game)
		return
	if Backend.uid() < friend:
		_match.accept(game, friend)

func _on_computer() -> void:
	Analytics.track("versus_online_nobody", {"game": game,
		"choice": "computer" if _lobby.state == Lobby.State.NOBODY else "offline"})
	_tell("", false)
	_match.cancel()
	_drop_lobby()
	computer.emit()

func _on_cancel() -> void:
	if _lobby.state == Lobby.State.NOBODY or _lobby.state == Lobby.State.LOOKING:
		Analytics.track("versus_online_nobody", {"game": game, "choice": "cancel"})
	_match.cancel()
	closed.emit()

func _process(delta: float) -> void:
	if _keep_t >= 0.0:
		_keep_t += delta
		if _keep_t >= float(_match.wait):
			_on_nobody()

# --- found ---

func _on_found(the_seat: int, the_first: int, the_seed: int, uid: String) -> void:
	seat = the_seat
	first = the_first
	match_seed = the_seed
	opponent = uid
	_keep_t = -1.0
	_tell(friend, true)
	Haptics.play(Haptics.GOOD)
	Analytics.track("versus_online_found", {"game": game,
		"wait_s": int((Time.get_ticks_msec() - _sought_at) / 1000.0)})
	_raise_lobby().show_found(uid, first_line())
	var run := _run
	get_tree().create_timer(FOUND_BEAT * (0.5 if Motion.reduce else 1.0)).timeout.connect(func() -> void:
		if run != _run or not is_inside_tree():
			return
		_drop_lobby()
		_begin())

## The beat is over: the screen lays its board for the game, and only then
## hears what the other seat did meanwhile -- its moves in order, and after
## them a result if there is one. (A screen clears what it holds as it lays
## the board, so a move handed over sooner would be thrown away, and the
## board would wait out its clock for a move it had been given.)
func _begin() -> void:
	var run := _run
	_begun = true
	started.emit()
	while run == _run and result.is_empty() and not _held.is_empty():
		move.emit(_held.pop_front())
	_held.clear()
	if run == _run and result.is_empty() and not _held_end.is_empty():
		_on_ended(int(_held_end.winner), str(_held_end.why))
	_held_end = {}

func _on_move(d: Dictionary) -> void:
	_plies += 1
	if _begun:
		move.emit(d)
	else:
		_held.append(d)

## True when this seat makes the first move.
func opens() -> bool:
	return seat == first

## True from `found` until the match has a result: a game is being played.
func live() -> bool:
	return seat >= 0 and result.is_empty()

## True while the lobby is over the board.
func in_lobby() -> bool:
	return is_instance_valid(_lobby) and _lobby.state != Lobby.State.NONE

# --- the game ---

## This seat's move. `keeps_turn` for a move after which the same seat acts
## again (snooker's shot before its table).
func send(d: Dictionary, keeps_turn := false) -> void:
	_plies += 1
	_match.send(d, seat if keeps_turn else 1 - seat)

## The other seat's move was not one the game's rules allow -- or its word
## that the game ended on the board (`over(..., "end")`) was not true of this
## board. Nothing on the server knows the rules, so this end walks away and
## counts it as the other having left.
func foul() -> void:
	var their_end: bool = str(result.get("why", "")) == "end" and not _settled
	if not live() and not their_end:
		return
	result = {"winner": seat, "why": "left"}
	_tell(friend, false)
	_match.leave()
	_close_ask()
	over.emit("won", "left")

## The screen has ended the game and is about to show its card: `outcome` is
## "won", "lost" or "draw"; `why` is "" when the game ended on the board, else
## what `over` said. Counts the record and says so to analytics, once; and a
## game that ended on the board is reported to the match by the seat that made
## the last move (`mine_last`), which is the only seat the rules take it from.
func settle(outcome: String, why: String, moves: int, mine_last := false) -> void:
	if _settled:
		return
	_settled = true
	_tell(friend, false)
	_close_ask()
	if why.is_empty():
		if mine_last and result.is_empty():
			_match.end(seat if outcome == "won" else (1 - seat if outcome == "lost" else -1))
		why = "end"
	# A game in which nobody moved was never played: no record of it.
	if _plies == 0:
		pass
	elif outcome == "draw":
		Record.add_draw(game, Record.ONLINE)
	else:
		Record.add(game, Record.ONLINE, outcome == "won")
	Analytics.track("versus_online_end", {"game": game, "why": why, "won": outcome == "won",
		"result": outcome, "moves": moves})

func _on_ended(winner: int, why: String) -> void:
	if not result.is_empty():
		return
	if not _begun:
		if _held.is_empty() and not friend.is_empty():
			# The same with a friend, and there is no queue to go back to.
			_run += 1
			_on_gone("void")
		elif _held.is_empty():
			# Given up inside the found beat, before a move: it never began.
			# Nothing is counted and nothing is shown; back to looking.
			open()
		else:
			_held_end = {"winner": winner, "why": why}
		return
	result = {"winner": winner, "why": why}
	_tell(friend, false)
	_close_ask()
	over.emit("draw" if winner < 0 else ("won" if winner == seat else "lost"), why)

# --- the clock ---

## Whole seconds left to the side to move: this seat's when `mine`. A move
## this end has just made may not have reached the match yet, and its clock
## then still reads the old turn's; the side it has not caught up with has
## its whole minute.
func seconds(mine: bool) -> int:
	if not live() or int(_match.turn()) != (seat if mine else 1 - seat):
		return LIMIT
	return int(_match.seconds_left())

func _on_clock(the_seat: int, left: int) -> void:
	if the_seat != seat:
		_warned = false
	elif left <= BUZZ_AT and not _warned and live():
		_warned = true
		Haptics.play(Haptics.WARN)
	ticked.emit()

## The scoreboard's line for one side: `base` as the screen words it, and
## while that side is the one to move (`on`), its seconds after it -- quiet
## above WARN_AT, in the warning colour and with a nudge a second under.
func dress(label: Label, base: String, on: bool, mine: bool) -> void:
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if not on or not live():
		label.text = base
		label.remove_theme_color_override("font_color")
		return
	var s := seconds(mine)
	@warning_ignore("integer_division")
	label.text = "%s  ·  %d:%02d" % [base, s / 60, s % 60]
	if s > WARN_AT:
		label.remove_theme_color_override("font_color")
		return
	label.add_theme_color_override("font_color", Pal.BAD)
	if s != _bumped:
		_bumped = s
		label.pivot_offset = label.size * 0.5
		Motion.bump(label, 0.1, 0.22)

# --- who the other player is ---

## A new drawing of the other player, `px` square.
func face(px: float) -> Control:
	var f := Names.face_of(opponent)
	f.size = Vector2(px, px)
	return f

func rival() -> String:
	return Names.name_of(opponent)

## Who opens, as a line: the found card's, and a screen's first toast.
func first_line() -> String:
	return tr("VS_FOUND_FIRST") if opens() else tr("VS_FOUND_SECOND") % rival()

## Puts `text` on `label` and letters it smaller until it is no wider than
## `width`: a name and its number on a scoreboard plate cut for "Bot".
static func fit(label: Label, text: String, width: float) -> void:
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.remove_theme_font_size_override("font_size")
	var font := label.get_theme_font("font")
	var px := label.get_theme_font_size("font_size")
	while px > 20 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		px -= 2
	label.add_theme_font_size_override("font_size", px)

# --- the end card's words ---

func head(outcome: String) -> String:
	return tr({"won": "VS_END_WON", "lost": "VS_END_LOST", "draw": "VS_END_DRAW"}[outcome])

## Why the game ended, when it did not end on the board; "" for a `why` this
## has no words for ("end"), and the screen says it its own way.
func why_line(why: String, outcome: String) -> String:
	var won := outcome == "won"
	match why:
		"resign":
			return tr("VS_END_RESIGN") % rival() if won else tr("VS_END_RESIGN_YOU")
		"timeout":
			return tr("VS_END_TIMEOUT") % rival() if won else tr("VS_END_TIMEOUT_YOU")
		"left":
			return tr("VS_END_LEFT") % rival() if won else tr("VS_END_LEFT_YOU")
	return ""

## "Online · Won 2 · Lost 1", the end card's last line.
func record_line() -> String:
	return "%s  ·  %s" % [tr("VS_ONLINE"), Record.record_line(game, Record.ONLINE)]

## The end card's sun button online: Find another, a fresh look on the same
## screen. With a friend it reads Rematch and asks them again.
func again_button() -> Button:
	var b := Dialog.primary("globe", tr("VS_FIND_ANOTHER" if friend.is_empty() else "VS_FRIEND_REMATCH"))
	b.pressed.connect(func() -> void:
		Haptics.play(Haptics.TAP)
		open())
	return b

# --- leaving ---

## Back during a game: asks, and resigns on a yes. `moves` is the game's
## count so far, for the analytics.
func ask_leave(moves: int) -> void:
	if is_instance_valid(_ask) or not live():
		return
	if not _begun:
		# Inside the found beat there is no game to resign: this end just goes
		# (the match is told, so the other goes back to looking), uncounted.
		_run += 1
		_match.cancel()
		closed.emit()
		return
	_ask = Dialog.scrim()
	_ask.name = "Leave"
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ask.add_child(center)
	var card := Dialog.card(Lobby.WIDTH)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	col.add_child(Dialog.head("VS_RESIGN_TITLE", "run"))
	var body := Label.new()
	body.text = tr("VS_RESIGN_BODY") % rival()
	body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	body.theme_type_variation = "SheetBody"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var stay := Dialog.primary("play", tr("VS_RESIGN_STAY"))
	stay.pressed.connect(_close_ask)
	var go := Dialog.secondary("run", tr("VS_RESIGN_GO"))
	go.pressed.connect(func() -> void:
		if live():
			settle("lost", "resign", moves)
			_match.resign()
		closed.emit())
	Dialog.buttons(col, stay, go)
	_screen.add_child(_ask)
	Motion.appear(_ask, 0.0, 1.0, 0.18)

func _close_ask() -> void:
	if is_instance_valid(_ask):
		_ask.queue_free()
	_ask = null

## Android's back. True when this had something of its own to close: the
## dialog, or the lobby (which is giving up, as its Cancel is; the found
## card just waits its beat out).
func back() -> bool:
	if is_instance_valid(_ask):
		_close_ask()
		return true
	if in_lobby():
		if _lobby.state != Lobby.State.FOUND:
			_on_cancel()
		return true
	return false
