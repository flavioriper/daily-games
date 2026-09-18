extends "res://ui/hud/panel.gd"

## The flat Balance's answer row: one card per kind of fruit, sharing the
## column between them -- the fruit at the top, its weight as a big numeral
## under it, and a wide minus and plus at the bottom. The given kind's card
## is sand with a sun rim, its numeral dimmed, reads GIVEN and has no
## buttons: the same language every other board uses for a fixed cell.
##
## A weight is a numeral and never a size. The fruit are all drawn at one
## size whatever they weigh, because the puzzle is about what you cannot
## see -- a pumpkin drawn heavy would give the answer away before the scales
## did.
##
## The cards are built on the first refresh, not in _build: how many there
## are is the puzzle's difficulty, and the host has no puzzle yet when it
## lays out its rows. `friend_tray.gd`'s sibling.
##
## Which side owns what, on a press: the tray knows from `can_minus` and
## `can_plus` that a press will be refused, so it shivers the card itself;
## the board is told either way and owns the sprout's reason, since only it
## has the words. Both land on the same press.
## Spec: docs/superpowers/specs/2026-09-18-balance-flat-design.md, section 4.

## One unit onto or off kind `i`'s weight; `delta` is +1 or -1.
signal step(i: int, delta: int)

const Fruit = preload("res://ui/faces/fruit.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

const HEIGHT := 230.0
const GAP := 16.0
## The mock's own geometry, in the 1080-wide design space: the fruit's centre
## and the biggest it is ever drawn, the numeral's baseline box, the tag's,
## and the button row.
const FRUIT_Y := 62.0
const FRUIT_MAX := 120.0
const FRUIT_SHARE := 0.55
const NUM_Y := 150.0
const TAG_Y := 202.0
const BUTTON_Y := 196.0
const BUTTON_H := 56.0
const BUTTON_INSET := 24.0
const BUTTON_GAP := 14.0
const CARD_RADIUS := 32
const CARD_EDGE := 6
const BUTTON_RADIUS := 20
const BUTTON_EDGE := 5
## A weight that changed, and a press that was refused.
const HOP := -10.0
const HOP_TIME := 0.34
const BUMP := 1.25
const BUMP_TIME := 0.24
const SHIVER := 6.0
const SHIVER_TIME := 0.26
## A button whose direction has run out.
const DIM := 0.35

var cards: Array[Panel] = []
var _faces: Array[Control] = []
var _nums: Array[Label] = []
var _tags: Array[Label] = []
var _minus: Array[Button] = []
var _plus: Array[Button] = []
## The weight and the given look each card is currently drawing, so a
## refresh knows what changed and only then animates. -1 before the first.
var _shown: Array[int] = []
var _was_given: Array[bool] = []
var _hops: Array = []
var _bumps: Array = []
var _shivers: Array = []

func _init() -> void:
	enter_from = Vector2(0, 120)

func _make_inner() -> Container:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(GAP))
	row.custom_minimum_size.y = HEIGHT
	return row

## One card per kind. Each keeps its own square of the column; the fruit and
## the buttons are re-fitted whenever that width changes.
func _make_cards(count: int) -> void:
	_stop_all()
	for card in cards:
		card.queue_free()
	cards = []
	_faces = []
	_nums = []
	_tags = []
	_minus = []
	_plus = []
	_shown = []
	_was_given = []
	_hops = []
	_bumps = []
	_shivers = []
	for i in count:
		var card := Panel.new()
		card.name = "Card_%d" % i
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = HEIGHT
		# The card keeps the shared paper wash CozyTheme.dress() gives every
		# Panel, as the day card and the tip card beside it do; only the board
		# card opts out of it.
		# Dressed here as well as on change: refresh only restyles a card
		# whose given-ness *differs* from what it drew last, and a card that
		# is never given never differs, so it would keep the bare Panel look.
		card.add_theme_stylebox_override("panel", _look(false))
		_inner.add_child(card)
		cards.append(card)

		var face := Fruit.make(i, FRUIT_MAX, Vector2.ZERO)
		card.add_child(face)
		_faces.append(face)

		var num := Label.new()
		num.theme_type_variation = "WeightNumeral"
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(num)
		_nums.append(num)

		var tag := Label.new()
		tag.theme_type_variation = "GivenTag"
		tag.text = "GIVEN"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tag)
		_tags.append(tag)

		_minus.append(_make_button(card, i, -1))
		_plus.append(_make_button(card, i, 1))

		_shown.append(-1)
		_was_given.append(false)
		_hops.append(null)
		_bumps.append(null)
		_shivers.append(null)
		card.resized.connect(_fit.bind(i))
		_fit(i)
		face.set_idle(true)

## The card's paper: sand with a sun rim when the weight is given, cream with
## the ordinary line when the player still owns it.
func _look(given: bool) -> StyleBoxFlat:
	return CozyTheme.card(Pal.SURFACE_HI if given else Pal.SURFACE, CARD_RADIUS,
		Pal.SUN_DEEP if given else Pal.LINE, CARD_EDGE, 0)

func _make_button(card: Panel, i: int, delta: int) -> Button:
	var b := IconButton.new("minus" if delta < 0 else "plus")
	b.name = "Minus_%d" % i if delta < 0 else "Plus_%d" % i
	# Every state, not just `normal`: the variation's own paper is cut for a
	# 110-square top-bar button and reads too heavy on a 56-tall one.
	var rest := CozyTheme.card(Pal.SURFACE_HI, BUTTON_RADIUS, Pal.LINE, BUTTON_EDGE, 0)
	var down := CozyTheme.card(Pal.SURFACE_HI.lerp(Pal.LINE, 0.15), BUTTON_RADIUS, Pal.LINE, 2, 0)
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, rest)
	b.add_theme_stylebox_override("pressed", down)
	b.pressed.connect(_on_pressed.bind(i, delta))
	card.add_child(b)
	return b

## Lays card `i` out at whatever width the column left it: the fruit centred
## at the top, the numeral and the tag across the middle, and the two
## buttons sharing the bottom.
func _fit(i: int) -> void:
	var card: Panel = cards[i]
	var w: float = card.size.x
	if w <= 0.0:
		return
	card.pivot_offset = card.size * 0.5
	var seat: float = minf(FRUIT_MAX, w * FRUIT_SHARE)
	Fruit.resize(_faces[i], seat, Vector2(w * 0.5, FRUIT_Y))
	# A Label's height clamps up to the line height its font needs -- 76 px
	# for the 62 px numeral -- so the box is measured first and *then* hung
	# so its centre lands on the mock's y. Writing a 40-tall box instead put
	# the numeral's centre 18 px low, sitting it on top of the buttons.
	for pair in [[_nums[i], NUM_Y], [_tags[i], TAG_Y]]:
		var label: Label = pair[0]
		label.size = Vector2(w, 0.0)
		label.position = Vector2(0.0, float(pair[1]) - label.size.y * 0.5)
		label.pivot_offset = label.size * 0.5
	var bw: float = (w - 2.0 * BUTTON_INSET - BUTTON_GAP) * 0.5
	for pair in [[_minus[i], 0], [_plus[i], 1]]:
		var b: Button = pair[0]
		b.size = Vector2(bw, BUTTON_H)
		b.position = Vector2(BUTTON_INSET + int(pair[1]) * (bw + BUTTON_GAP), BUTTON_Y - BUTTON_H * 0.5)
		b.pivot_offset = b.size * 0.5

func _on_pressed(i: int, delta: int) -> void:
	var live: Button = _plus[i] if delta > 0 else _minus[i]
	if live.disabled:
		return
	# IconButton squishes itself on button_down, so a press that lands needs
	# nothing here. One that cannot is answered by the whole card shaking:
	# the button still takes the press, because the sprout has a reason to
	# give and a dead button would swallow it.
	if live.modulate.a < 1.0:
		_shiver(i)
	step.emit(i, delta)

## Card `i`'s minus and plus, so the win harness can press the real button a
## player presses rather than reaching past the input layer.
func minus_button(i: int) -> Button:
	return _minus[i]

func plus_button(i: int) -> Button:
	return _plus[i]

## Reads the board's weights: how many cards, what each says, and which
## buttons still have somewhere to go. A weight that changed since the last
## refresh hops its fruit and bumps its numeral, so minus and plus, undo,
## reset and a hint all animate through one path.
func refresh(puzzle) -> void:
	var entries: Array = []
	if puzzle != null and puzzle.has_method("weights"):
		entries = puzzle.weights()
	if entries.size() != cards.size():
		_make_cards(entries.size())
	var done: bool = puzzle != null and puzzle.is_done()
	for i in cards.size():
		var e: Dictionary = entries[i]
		var w := int(e.get("weight", 1))
		var given := bool(e.get("given", false))
		_nums[i].text = str(w)
		_nums[i].add_theme_color_override("font_color", Pal.TEXT_DIM if given else Pal.TEXT)
		_tags[i].visible = given
		_minus[i].visible = not given
		_plus[i].visible = not given
		for pair in [[_minus[i], bool(e.get("can_minus", false))], [_plus[i], bool(e.get("can_plus", false))]]:
			var b: Button = pair[0]
			b.set_enabled(not done)
			b.modulate.a = 1.0 if bool(pair[1]) else DIM
		if given != _was_given[i]:
			_was_given[i] = given
			cards[i].add_theme_stylebox_override("panel", _look(given))
		if w != _shown[i]:
			var first: bool = _shown[i] < 0
			_shown[i] = w
			if not first:
				_celebrate(i)

## The fruit hops and the numeral bumps up and back.
func _celebrate(i: int) -> void:
	Motion.stop(_hops[i])
	Motion.stop(_bumps[i])
	_hops[i] = Motion.hop(_faces[i], HOP, HOP_TIME, 0.0, _faces[i].position.y)
	_bumps[i] = Motion.bump(_nums[i], BUMP - 1.0, BUMP_TIME)

## A refused press: the whole card shakes once and settles.
func _shiver(i: int) -> void:
	Motion.stop(_shivers[i])
	var card: Panel = cards[i]
	card.position.x = 0.0
	_shivers[i] = Motion.shiver(card, SHIVER, SHIVER_TIME)
	if _shivers[i] == null:
		card.position.x = 0.0

func _stop_all() -> void:
	for group in [_hops, _bumps, _shivers]:
		for tw in group:
			Motion.stop(tw)
