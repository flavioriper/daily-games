extends Control

## Code Break's "Out of rows" card, over the whole screen when the last row
## is scored and the code is still under its lids: One more row (a rewarded
## video once a board, asked never pushed, left out when no video is ready --
## videos stay for buyers too and there is no free-reward path,
## docs/agents/ads-and-purchase.md) and Show the code, which is the old
## ending. There is no Try again: eight read scores make the same code free.
## Binairo's out_of_hearts.gd is the pattern; the board owns what each
## answer does, and this only asks, once, and frees itself.
## Spec: docs/superpowers/specs/2026-09-29-codebreak-polish-design.md, section 1.

signal one_more_row
signal show_code

const Dialog = preload("res://ui/hud/dialog.gd")
const Motion = preload("res://core/motion.gd")

## The rewarded placement the row's video goes through.
const PLACEMENT := "row"

var _offer := false
var _done := false
var _watching := false

## `used`: whether this board has had its one extra row already.
func _init(used: bool) -> void:
	_offer = not used and Ads.can_reward(PLACEMENT)

func _ready() -> void:
	name = "OutOfRows"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8
	add_child(Dialog.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := Dialog.card(800)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	card.add_child(col)
	col.add_child(Dialog.head("CB_OUT_TITLE", "help"))
	var line := Label.new()
	line.theme_type_variation = "SheetBody"
	line.text = "CB_OUT_BODY" if _offer else "CB_OUT_BODY_REST"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 720
	col.add_child(line)
	var first: Button
	var second: Button = null
	var show := Dialog.secondary("eye", tr("CB_SHOW_CODE")) if _offer else Dialog.primary("eye", tr("CB_SHOW_CODE"))
	show.name = "ShowCode"
	show.pressed.connect(_answer.bind(1))
	if _offer:
		var more := Dialog.primary("play", tr("CB_ONE_ROW"))
		more.name = "OneMoreRow"
		more.pressed.connect(_on_row)
		Ads.offered(PLACEMENT)
		first = more
		second = show
	else:
		first = show
	Dialog.buttons(col, first, second)
	if not Motion.reduce:
		card.pivot_offset = Vector2(400, 300)
		card.scale = Vector2.ONE * 0.86
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

func _on_row() -> void:
	if _done or _watching:
		return
	_watching = true
	# The video can outlive the card, so the answer reaches it through a
	# weakref from a static lambda, never a callback bound to a freed self.
	Ads.show_rewarded(PLACEMENT, _reply(weakref(self)))

static func _reply(me: WeakRef) -> Callable:
	return func(earned: bool) -> void:
		var card = me.get_ref()
		if card == null or not is_instance_valid(card) or card.is_queued_for_deletion():
			return
		card._watching = false
		if earned:
			card._answer(0)

func _answer(which: int) -> void:
	if _done:
		return
	_done = true
	if which == 0:
		one_more_row.emit()
	else:
		show_code.emit()
	queue_free()
