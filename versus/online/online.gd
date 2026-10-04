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
##     online.send(d)                    # this seat's move, as it is played
##     ... `move(d)`                     # the other seat's, in order
##     online.foul()                     # ... if that move was not legal
##     online.settle(outcome, "", moves, mine_last)   # it ended on the board
##     ... `over(outcome, why)`          # it ended some other way
##     online.settle(outcome, why, moves)
##
## and `computer` (the lobby's Play the computer: free this and play a normal
## game) and `closed` (the player backed out: close the screen).
## Spec: docs/superpowers/specs/2026-10-04-versus-online-design.md, section 3.

## A fresh look for a player has begun (open(), Find another): the board goes
## back to idle behind the lobby.
signal seeking
## A player was found and the beat that shows them is over: start the game.
signal started
## The other seat's move, each one once and in order.
signal move(d: Dictionary)
## The match has a result this screen did not write: "won", "lost" or "draw",
## and why -- "resign", "timeout", "left", or "end" when the other seat said
## the game ended on the board.
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

var game := ""
## This end's seat, the seat that opens, the number both ends share and the
## other player's uid, from `started` on.
var seat := -1
var first := -1
var match_seed := 0
var opponent := ""
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

func _init(screen: Control, the_game: String) -> void:
	name = "Online"
	_screen = screen
	game = the_game

func _ready() -> void:
	_match = (stand_in if stand_in != null else Match).new()
	_match.name = "Match"
	_match.found.connect(_on_found)
	_match.nobody.connect(_on_nobody)
	_match.offline.connect(_on_offline)
	_match.move.connect(func(d: Dictionary) -> void: move.emit(d))
	_match.ended.connect(_on_ended)
	_match.clock.connect(_on_clock)
	add_child(_match)

# --- looking ---

## Looks for a player, from nothing: the lobby goes up and the board idles.
func open() -> void:
	_run += 1
	seat = -1
	first = -1
	opponent = ""
	result = {}
	_settled = false
	_warned = false
	_keep_t = -1.0
	_close_ask()
	seeking.emit()
	_raise_lobby().show_looking()
	_sought_at = Time.get_ticks_msec()
	Analytics.track("versus_online_seek", {"game": game})
	_match.seek(game)

func _raise_lobby() -> Control:
	if not is_instance_valid(_lobby) or _lobby.state == Lobby.State.NONE:
		_lobby = Lobby.new()
		_lobby.cancel.connect(_on_cancel)
		_lobby.keep.connect(_on_keep)
		_lobby.computer.connect(_on_computer)
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

func _on_offline() -> void:
	_keep_t = -1.0
	_raise_lobby().show_offline()

## Match says `nobody` once and keeps looking; so does the card, and it asks
## again after as long a wait.
func _on_keep() -> void:
	Analytics.track("versus_online_nobody", {"game": game, "choice": "keep"})
	_keep_t = 0.0
	_lobby.show_looking()

func _on_computer() -> void:
	Analytics.track("versus_online_nobody", {"game": game,
		"choice": "computer" if _lobby.state == Lobby.State.NOBODY else "offline"})
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
	Haptics.play(Haptics.GOOD)
	Analytics.track("versus_online_found", {"game": game,
		"wait_s": int((Time.get_ticks_msec() - _sought_at) / 1000.0)})
	_raise_lobby().show_found(uid, first_line())
	var run := _run
	get_tree().create_timer(FOUND_BEAT * (0.5 if Motion.reduce else 1.0)).timeout.connect(func() -> void:
		if run != _run or not is_inside_tree():
			return
		_drop_lobby()
		# A game given up inside the beat is over before it began: `over` has
		# said so, and the screen shows its card on the idle board.
		if result.is_empty():
			started.emit())

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
	_match.send(d, seat if keeps_turn else 1 - seat)

## The other seat's move was not one the game's rules allow. Nothing on the
## server knows the rules, so this end walks away and counts it as the other
## having left.
func foul() -> void:
	if not live():
		return
	result = {"winner": seat, "why": "left"}
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
	_close_ask()
	if why.is_empty():
		if mine_last and result.is_empty():
			_match.end(seat if outcome == "won" else (1 - seat if outcome == "lost" else -1))
		why = "end"
	if outcome == "draw":
		Record.add_draw(game, Record.ONLINE)
	else:
		Record.add(game, Record.ONLINE, outcome == "won")
	Analytics.track("versus_online_end", {"game": game, "why": why, "won": outcome == "won",
		"result": outcome, "moves": moves})

func _on_ended(winner: int, why: String) -> void:
	if not result.is_empty():
		return
	result = {"winner": winner, "why": why}
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
## screen.
func again_button() -> Button:
	var b := Dialog.primary("globe", tr("VS_FIND_ANOTHER"))
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
