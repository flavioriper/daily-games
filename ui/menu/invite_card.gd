extends ColorRect

## The friends' centred cards, all one drawing: a friend's face and name over
## a line and two buttons. Four of them --
##
## - `invite(uid, game)`: a friend asks for a game. Play / Not now.
## - `friend(uid)`: someone opened this player's link (or this player theirs).
##   Play / Close; Play turns the card into the picker.
## - `pick(uid)`: which game to ask them to. Three buttons and Cancel.
## - `remove(uid)`: the question before a friend is removed. Remove / Keep.
##
## It knows no Social and no menu: it says which button was pressed and
## whoever raised it does the rest (ui/menu.gd for the first two, over
## anything; ui/menu/friends_sheet.gd for the last two, over the sheet).
## `is_open()` and `close()` are the pair ui/menu.gd's go_back looks for, so
## Android's back answers a card as its quiet button does.
##
## Dressed as the lobby is (versus/online/lobby.gd, ui/hud/dialog.gd): the
## sheets' scrim, paper and sprigs, the badge head, the sun button over a
## white pill.
## Spec: docs/superpowers/specs/2026-10-04-friends-design.md, section 4.

## Play on an invite (its own game), or the game picked.
signal play(game: String)
## Remove, on the question.
signal confirmed
## The quiet button, or Android's back: Not now, Close, Cancel, Keep.
signal dismissed

const Dialog = preload("res://ui/hud/dialog.gd")
const Names = preload("res://versus/online/names.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

enum Kind { INVITE, FRIEND, PICK, REMOVE }

const WIDTH := 820.0
const FACE := 170.0
## Over a sheet (ui/hud/sheet.gd's OVER_BOARD), whichever it is raised over.
const OVER_SHEET := 12
const GAMES := ["snooker", "chess", "checkers", "boats", "penny", "dominoes", "reversi"]
## Titles stay English (ui/menu/versus_tab.gd's NAMES).
const TITLES := {"snooker": "Snooker", "chess": "Chess", "checkers": "Checkers", "boats": "Toy Boats",
	"penny": "Penny Drop", "dominoes": "Dominoes", "reversi": "Reversi"}

var kind: int = Kind.INVITE
var uid := ""
var game := ""
## A new friend's card without its Play (the menu clears it while a live game
## online is on: Play would mean walking out of that game).
var can_play := true
var _card: PanelContainer
var _col: VBoxContainer
var _seat: Control
var _gone := false

static func invite(from: String, game_: String) -> Control:
	var c: Control = new()
	c.uid = from
	c.game = game_
	c.kind = Kind.INVITE
	return c

static func friend(who: String) -> Control:
	var c: Control = new()
	c.uid = who
	c.kind = Kind.FRIEND
	return c

static func pick(who: String) -> Control:
	var c: Control = new()
	c.uid = who
	c.kind = Kind.PICK
	return c

static func remove(who: String) -> Control:
	var c: Control = new()
	c.uid = who
	c.kind = Kind.REMOVE
	return c

func _init() -> void:
	name = "FriendCard"
	color = Dialog.SCRIM
	z_index = OVER_SHEET
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = Dialog.card(WIDTH)
	center.add_child(_card)

func _ready() -> void:
	_lay()
	Motion.appear(self, 0.0, 1.0, 0.2)
	if not Motion.reduce and (kind == Kind.INVITE or kind == Kind.FRIEND):
		_seat.pivot_offset = Vector2((WIDTH - 2.0 * Dialog.INSET) * 0.5, FACE * 0.5)
		Motion.bump(_seat, 0.18, 0.4)

## Up and answerable: Android's back closes a card that is_open().
func is_open() -> bool:
	return not _gone

## The quiet way out.
func close() -> void:
	if _gone:
		return
	dismissed.emit()
	leave()

## Fades out and goes, with nothing said: the invite was taken back.
func leave() -> void:
	if _gone:
		return
	_gone = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := Motion.appear(self, modulate.a, 0.0, 0.18)
	if tw == null:
		queue_free()
	else:
		tw.finished.connect(queue_free)

# --- the card ---

func _lay() -> void:
	if _col != null:
		_card.remove_child(_col)
		_col.queue_free()
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 18)
	_card.add_child(_col)
	var who := Names.name_of(uid)
	var face := Names.face_of(uid)
	match kind:
		Kind.INVITE:
			face.expression = Face.Expr.JOY
			_head("FRIENDS_INVITED_TITLE", face, who, tr("FRIENDS_INVITED_BODY") % TITLES.get(game, game))
			Dialog.buttons(_col, Dialog.primary("play", tr("VS_PLAY")), Dialog.secondary("cross", tr("FRIENDS_NOT_NOW")))
			_wire(0, func() -> void: _say(play, game))
			_wire(1, close)
		Kind.FRIEND:
			face.expression = Face.Expr.JOY
			_head("FRIENDS_NEW_TITLE", face, who, tr("FRIENDS_NEW_BODY"))
			if not can_play:
				Dialog.buttons(_col, Dialog.secondary("check", tr("BTN_CLOSE")))
				_wire(0, close)
				return
			Dialog.buttons(_col, Dialog.primary("play", tr("VS_PLAY")), Dialog.secondary("check", tr("BTN_CLOSE")))
			_wire(0, func() -> void:
				kind = Kind.PICK
				_lay())
			_wire(1, close)
		Kind.PICK:
			_head("FRIENDS_PICK_TITLE", face, who, tr("FRIENDS_PICK_BODY") % who)
			var stack := Dialog.buttons(_col, null)
			for g: String in GAMES:
				var b := Dialog.primary("play", TITLES[g])
				b.name = "Pick_" + g
				b.custom_minimum_size.y = Dialog.SECONDARY_H
				b.size_flags_horizontal = Control.SIZE_FILL
				b.pressed.connect(func() -> void: _say(play, g))
				stack.add_child(b)
			var no := Dialog.secondary("cross", tr("VS_CANCEL"))
			no.size_flags_horizontal = Control.SIZE_FILL
			no.pressed.connect(close)
			stack.add_child(no)
		Kind.REMOVE:
			face.expression = Face.Expr.WORRIED
			_head("FRIENDS_REMOVE_TITLE", face, who, tr("FRIENDS_REMOVE_BODY") % who)
			Dialog.buttons(_col, Dialog.primary("check", tr("FRIENDS_KEEP")), Dialog.secondary("cross", tr("FRIENDS_REMOVE")))
			_wire(0, close)
			_wire(1, func() -> void: _say(confirmed))
	Motion.appear(_col, 0.0, 1.0, 0.18)

## The badge head, the face in the middle, the name and `body` under it.
func _head(title: String, face: Control, who: String, body: String) -> void:
	_col.add_child(Dialog.head(title, "friends"))
	_seat = Control.new()
	# A little under the face: a curve may hang below its box.
	_seat.custom_minimum_size = Vector2(0, FACE + 16.0)
	_seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(_seat)
	face.size = Vector2(FACE, FACE)
	face.position = Vector2((WIDTH - 2.0 * Dialog.INSET - FACE) * 0.5, 0.0)
	_seat.add_child(face)
	var name_l := Label.new()
	name_l.text = who
	name_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_l.theme_type_variation = "DayBig"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(name_l)
	var body_l := Label.new()
	body_l.text = body
	body_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	body_l.theme_type_variation = "SheetBody"
	body_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(body_l)

func _wire(i: int, then: Callable) -> void:
	var b: Button = _col.get_node("Buttons").get_child(i)
	b.pressed.connect(then)

## Says `sig` once and goes: a second tap while the card fades says nothing.
func _say(sig: Signal, arg: Variant = null) -> void:
	if _gone:
		return
	if arg == null:
		sig.emit()
	else:
		sig.emit(arg)
	leave()
