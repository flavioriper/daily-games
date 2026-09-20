extends "res://ui/hud/panel.gd"

## Hidden Word's keyboard tray: three rows of keys under the grid, QWERTY laid
## out the way every player already knows it, with a backspace and an Enter
## flanking the bottom row. A key is a **direct action, not a brush**, the
## way Code Break's friend chips are -- tap it and it fires -- but repainted
## from the state rather than lit for a beat, because a keyboard has to keep
## telling the player what it learned about every letter.
##
## Every key stands in its own slot, a plain Control the key's Button sits
## inside: a key that pressed or bumped by writing its own position straight
## into the row's HBoxContainer would be put back on the next sort, the
## lesson Balance's weight cards paid for on 2026-09-18.
##
## Two gaps, and they are not the same number. `GAP` (10) sits between keys
## in a row; `ROW_GAP` (14) sits between the three rows. A key is
## `(1000 - 9*GAP)/10` wide with the *key* gap -- 91 -- and the arithmetic
## closes on 1000 for all three rows: the top row is ten keys and nine gaps,
## the middle row is nine keys and eight gaps centred on its own 899, and the
## bottom row spends what seven letters leave on a wider backspace and a
## wider Enter, the one key that commits a guess and so wears `Pal.GOOD`.
## Spec: docs/superpowers/specs/2026-09-19-hidden-word-flat-design.md, section 6.

## The letter tapped, lower-case.
signal key(letter: String)
## The row is committed. Named `commit` rather than the spec's own `enter`:
## `ui/hud/panel.gd` already owns a method called `enter` (the tray's
## entrance slide, which `ui/flat/flat_host.gd` calls on every tray), and a
## signal cannot share that name with an inherited method -- GDScript refuses
## to parse it. `commit` is `HiddenWordState`'s own name for the same move.
signal commit
signal erase

const HiddenWordState = preload("res://puzzles/hidden_word_state.gd")

const HEIGHT := 340.0
const KEY := Vector2(91.0, 100.0)
const GAP := 10.0
const ROW_GAP := 14.0
const WIDE_BACK := 126.0
const WIDE_ENTER := 157.0
const RADIUS := 16.0
const ROWS := ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
const FONT_SIZE := 44
## The bottom edge under every key's face, and how much a press darkens it --
## the family's own ratios (ui/menu/puzzle_card_2d.gd's chips wear the same
## pair on their own colours).
const EDGE_DARKEN := 0.28
const PRESS_DARKEN := 0.12
const BORDER_W := 6

var _keys: Dictionary = {}   # letter -> Button
var _press_tw: Dictionary = {}   # Button -> Tween
var _bump_tw: Dictionary = {}    # letter -> Tween

func _init() -> void:
	enter_from = Vector2(0, 100)

func _make_inner() -> Container:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", int(ROW_GAP))
	col.custom_minimum_size.y = HEIGHT
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return col

func _build() -> void:
	for r in ROWS.size():
		var row := HBoxContainer.new()
		row.name = "Row_%d" % r
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", int(GAP))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inner.add_child(row)
		var letters: String = ROWS[r]
		if r == 2:
			_add_special(row, "erase", WIDE_BACK)
		for i in letters.length():
			_add_letter(row, letters[i])
		if r == 2:
			_add_special(row, "commit", WIDE_ENTER)

## A plain Control holds each key so a press or a bump can move the key
## freely; the row's HBoxContainer would otherwise put it straight back on
## the next sort.
func _make_slot(row: HBoxContainer, width: float) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(width, KEY.y)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slot)
	return slot

func _add_letter(row: HBoxContainer, letter: String) -> void:
	var slot := _make_slot(row, KEY.x)
	var chip := Button.new()
	chip.name = "Key_%s" % letter.to_upper()
	chip.focus_mode = Control.FOCUS_NONE
	chip.size = Vector2(KEY.x, KEY.y)
	chip.pivot_offset = chip.size * 0.5
	chip.text = letter.to_upper()
	chip.add_theme_font_override("font", CozyTheme.display(700))
	chip.add_theme_font_size_override("font_size", FONT_SIZE)
	slot.add_child(chip)
	# Dropped after add_child, which is when CozyTheme.dress() puts the
	# shared paper wash on; a key carries its own flat face instead.
	chip.material = null
	_style(chip, Pal.KEY_FACE, Pal.TEXT)
	chip.button_down.connect(_press.bind(chip))
	chip.button_up.connect(_release.bind(chip))
	chip.pressed.connect(func() -> void: key.emit(letter))
	_keys[letter] = chip

## The backspace and Enter keys: same slot idiom, wider, and their own fixed
## look -- Enter in `Pal.GOOD` because it is the one key that commits, the
## backspace in the same face every untouched letter wears.
func _add_special(row: HBoxContainer, role: String, width: float) -> void:
	var slot := _make_slot(row, width)
	var chip := Button.new()
	chip.name = "Key_Erase" if role == "erase" else "Key_Enter"
	chip.focus_mode = Control.FOCUS_NONE
	chip.size = Vector2(width, KEY.y)
	chip.pivot_offset = chip.size * 0.5
	slot.add_child(chip)
	chip.material = null
	if role == "commit":
		chip.text = "Enter"
		chip.add_theme_font_override("font", CozyTheme.display(700))
		chip.add_theme_font_size_override("font_size", FONT_SIZE)
		_style(chip, Pal.GOOD, Pal.PAPER)
		chip.pressed.connect(func() -> void: commit.emit())
	else:
		_style(chip, Pal.KEY_FACE, Pal.TEXT)
		var icon := Control.new()
		icon.name = "Glyph"
		icon.size = Vector2(56.0, 56.0)
		icon.position = chip.size * 0.5 - icon.size * 0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.draw.connect(_draw_erase.bind(icon))
		chip.add_child(icon)
		chip.pressed.connect(func() -> void: erase.emit())
	chip.button_down.connect(_press.bind(chip))
	chip.button_up.connect(_release.bind(chip))

## The backspace glyph, drawn rather than set as text: neither of the HUD's
## two fonts carries U+232B, so a Button.text of "⌫" renders as a missing
## glyph box. An outlined arrow pointing at the letter it clears, with an X
## laid across it -- the concept tab's own icon (docs/brainstorm/concepts.html,
## the `bksp` icon), redrawn here as canvas commands.
func _draw_erase(icon: Control) -> void:
	var s: float = icon.size.x
	var w := s * 0.09
	var c := icon.size * 0.5
	var pts := PackedVector2Array([
		c + Vector2(-0.46, 0.0) * s, c + Vector2(-0.14, -0.32) * s,
		c + Vector2(0.46, -0.32) * s, c + Vector2(0.46, 0.32) * s,
		c + Vector2(-0.14, 0.32) * s, c + Vector2(-0.46, 0.0) * s,
	])
	icon.draw_polyline(pts, Pal.TEXT, w, true)
	icon.draw_line(c + Vector2(-0.02, -0.14) * s, c + Vector2(0.24, 0.14) * s, Pal.TEXT, w, true)
	icon.draw_line(c + Vector2(0.24, -0.14) * s, c + Vector2(-0.02, 0.14) * s, Pal.TEXT, w, true)

## A key's look: face, corner, a bottom edge in a darker shade of the same
## face, and lettering in `ink` for every state a key can be in.
func _style(chip: Button, fill: Color, ink: Color) -> void:
	var sb := CozyTheme.card(fill, RADIUS, fill.darkened(EDGE_DARKEN), BORDER_W, 0)
	var pressed := CozyTheme.card(fill.darkened(PRESS_DARKEN), RADIUS, fill.darkened(EDGE_DARKEN), 2, 0)
	for state in ["normal", "hover", "focus"]:
		chip.add_theme_stylebox_override(state, sb)
	chip.add_theme_stylebox_override("pressed", pressed)
	chip.add_theme_stylebox_override("disabled", sb)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		chip.add_theme_color_override(state, ink)

func _press(chip: Button) -> void:
	Motion.stop(_press_tw.get(chip))
	_press_tw[chip] = Motion.press(chip, true)

func _release(chip: Button) -> void:
	Motion.stop(_press_tw.get(chip))
	_press_tw[chip] = Motion.press(chip, false)

## Repaints every named key: `Pal.GOOD` for a `HIT`, `Pal.WORD_NEAR` for a
## `NEAR`, `Pal.WORD_MISS` for a `MISS`, lettered in `Pal.PAPER` like Enter --
## a letter absent from `marks` keeps whatever it already had. The caller
## (the board, reading `HiddenWordState.key_mark`) is the one that already
## resolves "best mark wins"; this only ever paints what it is handed.
func set_marks(marks: Dictionary) -> void:
	for letter in marks:
		var chip: Button = _keys.get(letter)
		if chip == null:
			continue
		var m := int(marks[letter])
		var fill: Color = Pal.GOOD
		if m == HiddenWordState.NEAR:
			fill = Pal.WORD_NEAR
		elif m == HiddenWordState.MISS:
			fill = Pal.WORD_MISS
		_style(chip, fill, Pal.PAPER)

## The named keys bump, the beat that says the row just landed on them.
func bump(letters: Array) -> void:
	for letter in letters:
		var chip: Button = _keys.get(letter)
		if chip == null:
			continue
		Motion.stop(_bump_tw.get(letter))
		_bump_tw[letter] = Motion.bump(chip)

## The keyboard leaves for the reveal: `_inner` slides down to `enter_from`
## while the tray fades, over `time`. Not a queue_free -- a later `enter()`
## call (Reset replaying the day) slides `_inner` straight back from the same
## `enter_from` and fades the tray back in, so nothing here needs undoing by
## hand.
func slide_out(time: float) -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	var slide: Tween = Motion.slide(_inner, "position", _inner.position, enter_from, time, 0.0, false)
	if slide != null:
		_entrance.append(slide)
	var fade: Tween = Motion.appear(self, self.modulate.a, 0.0, time)
	if fade != null:
		_entrance.append(fade)

## The three rows slide up `ENTER_STAGGER` apart on top of the panel's own
## entrance, so the keyboard reads as one hand settling rather than a slab
## dropping in at once.
func enter(delay: float) -> void:
	super(delay)
	for r in _inner.get_child_count():
		var row: Control = _inner.get_child(r)
		var slide: Tween = Motion.slide(row, "position:y", Motion.DROP, 0.0, ENTER_SLIDE, delay + r * Motion.ENTER_STAGGER)
		if slide != null:
			_entrance.append(slide)
