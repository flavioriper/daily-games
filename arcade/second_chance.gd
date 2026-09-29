extends Control

## At game over, once a run: the Second chance (arcade/boosters.gd) -- what
## it does in this game, Use (one held) or Buy and use at its price, and No
## thanks. No timer: the run waits. Laid over an Arcade screen by the screen,
## which takes the answer from `taken` or `declined`.
## Spec docs/superpowers/specs/2026-09-28-gold-gifts-design.md, section 4.

signal taken
signal declined

const Boosters = preload("res://arcade/boosters.gd")
const BoosterIcon = preload("res://arcade/booster_icon.gd")
const GoldPill = preload("res://ui/menu/gold_pill.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")

var game := ""
var _done := false
var _watching := false   # a video is up; a second tap must not start another

## Whether to ask: one held, the gold for one, or a video for it.
static func wanted() -> bool:
	return Wallet.can_have(Boosters.CHANCE) or Ads.can_reward("continue")

func _init(g: String) -> void:
	game = g

func _ready() -> void:
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
	var icon := BoosterIcon.new(Boosters.CHANCE, 150)
	icon.count = Wallet.count(Boosters.CHANCE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var title := Label.new()
	title.theme_type_variation = "WellDone"
	title.text = "CHANCE_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var line := Label.new()
	line.theme_type_variation = "SheetBody"
	line.text = Boosters.chance_key(game)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 720
	col.add_child(line)
	var held := Wallet.count(Boosters.CHANCE)
	var gold_ok := Wallet.can_have(Boosters.CHANCE)
	var video_ok := Ads.can_reward("continue")
	var watch: Button = null
	if video_ok:
		var glyph := "play"
		var text := tr("CHANCE_WATCH")
		watch = Dialog.secondary(glyph, text) if gold_ok else Dialog.primary(glyph, text)
		watch.name = "Watch"
		watch.pressed.connect(_on_watch)
		Ads.offered("continue")
	var use: Button = null
	var pill: Control = null
	if gold_ok:
		if held > 0:
			use = Dialog.primary("reset", tr("CHANCE_USE") % held)
		else:
			use = Dialog.primary("coin", tr("CHANCE_BUY") % Locale.number(Boosters.price(Boosters.CHANCE)))
			pill = GoldPill.new()
			pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		use.name = "Use"
		use.pressed.connect(_on_use)
	var no := Dialog.secondary("chevron_right", tr("CHANCE_NO"))
	no.name = "No"
	no.pressed.connect(_on_no)
	if gold_ok and video_ok:
		var stack := Dialog.buttons(col, use, watch, pill)
		no.size_flags_horizontal = Control.SIZE_FILL
		stack.add_child(no)
	elif video_ok:
		Dialog.buttons(col, watch, no)
	else:
		Dialog.buttons(col, use, no, pill)
	if not Motion.reduce:
		card.pivot_offset = Vector2(400, 300)
		card.scale = Vector2.ONE * 0.86
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

func _on_use() -> void:
	if _done:
		return
	if not Wallet.use(Boosters.CHANCE, game, true):
		Motion.shiver(get_node("Card") if has_node("Card") else self)
		return
	_done = true
	taken.emit()
	queue_free()

func _on_no() -> void:
	if _done:
		return
	_done = true
	declined.emit()
	queue_free()

func _on_watch() -> void:
	if _done or _watching:
		return
	_watching = true
	Ads.show_rewarded("continue", func(earned: bool) -> void:
		_watching = false
		if _done or not earned:
			return
		_done = true
		taken.emit()
		queue_free())
