extends ColorRect

## The card over the board while a game online has not begun: looking for a
## player (Cancel), nobody around (Keep looking / Play the computer), no
## network (Play the computer / Back), and "found" -- the other player's face
## and name for a beat before the board wakes. It knows no game and no Match:
## it shows the state it is told and says which button was pressed
## (versus/online/online.gd is what tells it and listens).
##
## Dressed as every centred dialog is (ui/hud/dialog.gd): the sheets' scrim,
## paper and sprigs, the badge head, the sun button over a white pill.
## Spec: docs/superpowers/specs/2026-10-04-versus-online-design.md, section 3.

## Cancel while looking, Back when offline: the player gives up on a game.
signal cancel
## "Keep looking", when nobody is around.
signal keep
## "Play the computer", when nobody is around or there is no network.
signal computer

const Dialog = preload("res://ui/hud/dialog.gd")
const Names = preload("res://versus/online/names.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")

enum State { NONE, LOOKING, NOBODY, OFFLINE, FOUND }

const WIDTH := 820.0
const FACE := 170.0
## How long one face of the cast looks out of the card while looking.
const TURN := 0.9

var state: int = State.NONE
var _col: VBoxContainer
var _card: PanelContainer
var _seat: Control
var _face: Control
var _cast := 0
var _turn_t := 0.0

func _init() -> void:
	name = "Lobby"
	color = Dialog.SCRIM
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = Dialog.card(WIDTH)
	center.add_child(_card)

func _ready() -> void:
	Motion.appear(self, 0.0, 1.0, 0.2)

# --- the four states ---

func show_looking() -> void:
	_cast = randi() % Names.CAST.size()
	_lay(State.LOOKING, "VS_LOOKING", Names.CAST[_cast][1].new(), "", tr("VS_LOOKING_BODY"))
	Dialog.buttons(_col, Dialog.secondary("cross", tr("VS_CANCEL")))
	_wire(0, cancel)

func show_nobody() -> void:
	var face: Control = Names.CAST[_cast][1].new()
	face.expression = Face.Expr.SLEEPY
	_lay(State.NOBODY, "VS_NOBODY", face, "", tr("VS_NOBODY_BODY"))
	Dialog.buttons(_col, Dialog.primary("globe", tr("VS_KEEP_LOOKING")),
		Dialog.secondary("gamepad", tr("VS_PLAY_COMPUTER")))
	_wire(0, keep)
	_wire(1, computer)

func show_offline() -> void:
	var face: Control = MoonFace.new()
	face.expression = Face.Expr.SLEEPY
	_lay(State.OFFLINE, "VS_OFFLINE", face, "", tr("VS_OFFLINE_BODY"))
	Dialog.buttons(_col, Dialog.primary("gamepad", tr("VS_PLAY_COMPUTER")),
		Dialog.secondary("chevron_left", tr("SNK_BACK")))
	_wire(0, computer)
	_wire(1, cancel)

## The other player, and `line` under the name (who opens). No buttons: the
## game is about to begin, and whoever shows this takes it down.
func show_found(uid: String, line: String) -> void:
	var face := Names.face_of(uid)
	face.expression = Face.Expr.JOY
	_lay(State.FOUND, "VS_FOUND", face, Names.name_of(uid), line)
	if not Motion.reduce:
		_seat.pivot_offset = Vector2(_seat.size.x * 0.5, FACE * 0.5)
		Motion.bump(_seat, 0.18, 0.4)

## Fades out and goes.
func leave() -> void:
	state = State.NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := Motion.appear(self, modulate.a, 0.0, 0.18)
	if tw == null:
		queue_free()
	else:
		tw.finished.connect(queue_free)

# --- the card ---

## The card's contents, made again for each state: the badge head, the face
## in the middle, `big` (a name) and `body` under it. Buttons follow.
func _lay(to: int, title: String, face: Control, big: String, body: String) -> void:
	state = to
	_turn_t = 0.0
	if _col != null:
		_card.remove_child(_col)
		_col.queue_free()
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 18)
	_card.add_child(_col)
	_col.add_child(Dialog.head(title, "globe"))
	_seat = Control.new()
	# A little under the face: the moon's curve hangs below its box.
	_seat.custom_minimum_size = Vector2(0, FACE + 16.0)
	_seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(_seat)
	_put(face)
	if not big.is_empty():
		var name_l := Label.new()
		name_l.text = big
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
	Motion.appear(_col, 0.0, 1.0, 0.18)

## Seats `face` in the middle of the card, in place of the one there.
func _put(face: Control) -> void:
	if is_instance_valid(_face):
		_face.queue_free()
	_face = face
	face.size = Vector2(FACE, FACE)
	face.position = Vector2((WIDTH - 2.0 * Dialog.INSET - FACE) * 0.5, 0.0)
	_seat.add_child(face)

func _wire(i: int, sig: Signal) -> void:
	var b: Button = _col.get_node("Buttons").get_child(i)
	b.pressed.connect(func() -> void: sig.emit())

## While looking, the cast takes turns at the window: who will it be. A
## still card under reduce motion.
func _process(delta: float) -> void:
	if state != State.LOOKING or Motion.reduce:
		return
	_turn_t += delta
	if _turn_t < TURN:
		return
	_turn_t = 0.0
	_cast = (_cast + 1) % Names.CAST.size()
	_put(Names.CAST[_cast][1].new())
	_face.pivot_offset = Vector2.ONE * FACE * 0.5
	Motion.pop_in(_face)
