extends Control

## Binairo's "Out of hearts" card, over the whole screen when the last heart
## of a Hard or Insane board is gone: Try again (the same board, hearts full,
## clock and moves from zero), One more heart (a rewarded video once a board,
## asked never pushed; left out when no video is ready -- a remove-ads
## player watches it too, since videos stay for buyers and there is no
## free-reward path, docs/agents/ads-and-purchase.md), and Back to camp. Dressed like every centred
## dialog (ui/hud/dialog.gd), built like ui/ads/reward_prompt.gd. The board
## owns what each answer does; this only asks, once, and frees itself.
## Spec: docs/superpowers/specs/2026-09-29-binairo-insane-polish-design.md, section 1.

signal try_again
signal one_more_heart
signal leave

const Dialog = preload("res://ui/hud/dialog.gd")
const Motion = preload("res://core/motion.gd")

## The rewarded placement the heart's video goes through.
const PLACEMENT := "heart"

var _offer := false
var _done := false
var _watching := false

## `used`: whether this board has had its one heart already. One more heart
## is on the card when it has not and a video is ready.
func _init(used: bool) -> void:
	_offer = not used and Ads.can_reward(PLACEMENT)

func _ready() -> void:
	name = "OutOfHearts"
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
	col.add_child(Dialog.head("BN_OUT_TITLE", "heart_line"))
	var line := Label.new()
	line.theme_type_variation = "SheetBody"
	line.text = "BN_OUT_BODY" if _offer else "BN_OUT_BODY_REST"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 720
	col.add_child(line)
	var again := Dialog.primary("reset", tr("BN_TRY_AGAIN"))
	again.name = "TryAgain"
	again.pressed.connect(_answer.bind(0))
	var heart: Button = null
	if _offer:
		heart = Dialog.secondary("play", tr("BN_ONE_HEART"))
		heart.name = "OneMoreHeart"
		heart.pressed.connect(_on_heart)
		Ads.offered(PLACEMENT)
	var back := Dialog.secondary("chevron_left", tr("WIN_BACK"))
	back.name = "Leave"
	back.pressed.connect(_answer.bind(2))
	var stack := Dialog.buttons(col, again, heart)
	back.size_flags_horizontal = Control.SIZE_FILL
	stack.add_child(back)
	if not Motion.reduce:
		card.pivot_offset = Vector2(400, 300)
		card.scale = Vector2.ONE * 0.86
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

func _on_heart() -> void:
	if _done or _watching:
		return
	_watching = true
	# The video can outlive the card (Back, or the board torn down behind
	# it), so the answer reaches it through a weakref from a static lambda,
	# never a callback bound to a freed self.
	Ads.show_rewarded(PLACEMENT, _reply(weakref(self)))

static func _reply(me: WeakRef) -> Callable:
	return func(earned: bool) -> void:
		var card = me.get_ref()
		if card == null or not is_instance_valid(card) or card.is_queued_for_deletion():
			return
		card._watching = false
		if earned:
			card._answer(1)

func _answer(which: int) -> void:
	if _done:
		return
	_done = true
	match which:
		0: try_again.emit()
		1: one_more_heart.emit()
		_: leave.emit()
	queue_free()
