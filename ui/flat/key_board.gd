extends "res://ui/hud/panel.gd"

## Hidden Word's keyboard tray: three rows of keys under the grid, QWERTY laid
## out the way every player already knows it, with Enter and a backspace
## flanking the bottom row -- the backspace on the right, where every phone
## keyboard keeps it (swapped 2026-09-30 at the user's request; it stood on
## the left before). A key is a **direct action, not a brush**, the
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
## bottom row spends what seven letters leave on a wider Enter and a
## wider backspace; Enter is the one key that commits a guess and so wears
## `Pal.GOOD`.
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
const Face = preload("res://ui/faces/face.gd")

const HEIGHT := 340.0
const KEY := Vector2(91.0, 100.0)
const GAP := 10.0
const ROW_GAP := 14.0
const WIDE_BACK := 126.0
const WIDE_ENTER := 157.0
const RADIUS := 16.0
const ROWS := ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
## Spanish types Ñ, and its keyboards put it at the end of the middle row,
## which makes that row ten keys -- the top row's width exactly.
const ROWS_ES := ["qwertyuiop", "asdfghjklñ", "zxcvbnm"]
const FONT_SIZE := 44

## True while the keyboard has been slid out of the way. The board asks,
## because a Reset or a new word has to bring it back and the board that
## sent it away may not be the one that needs it again -- the settings
## sheet's New puzzle spawns a fresh board against this same tray.
var gone := false
var _keys: Dictionary = {}   # letter -> Button
var _chips: Array[Button] = []   # every key, letters and the two specials
var _press_tw: Dictionary = {}   # Button -> Tween
var _bump_tw: Dictionary = {}    # letter -> Tween
## One slot per row, and the row it holds. A row is *not* a direct child of
## `_inner`: a `VBoxContainer` re-sorts its children on
## `NOTIFICATION_SORT_CHILDREN` (a resize, a child change, a theme change),
## and any such sort mid-tween snapped every row's `position:y` tween back to
## wherever the sort last put it -- the three rows landed stacked on top of
## each other at (0, 0). The slot is the VBox's child at a fixed height; the
## row moves freely inside it, the way `ui/flat/weight_tray.gd`'s cards move
## inside slots the row container owns. `docs/art/flat-motion.md` rule 6 and
## CLAUDE.md's own "a card that moves inside a container needs a slot."
var _row_slots: Array[Control] = []
var _rows: Array[HBoxContainer] = []
var _row_tw: Array = [null, null, null]
## The language the keys were laid out for. The tray outlives the board, and
## the settings sheet that spawns a New puzzle also carries the language
## picker, so a board asks match_locale() before it deals a word.
var _lang := ""
## The keys' paint (the board checkup, 2026-10-02). A Button with its own
## StyleBoxFlat and its own text cost two draw calls (the box is a polygon,
## the letter a glyph batch), 56 of Hidden Word's 125 at rest. The Buttons
## still take the taps and carry the press and bump tweens and the rows'
## slides, but draw nothing; `_paint`, over them, draws every key's face as
## one mesh and every letter after it, read off each Button's transform, so
## the keyboard is two draw calls whatever it is doing. A look (size, face,
## pressed, the backspace's glyph) is made once as a flat triangle list and
## copied natively under the key's transform; the mesh is made again only on
## a frame where some key moved, was pressed or was repainted (`_sig`).
var _paint: Control
var _look: Dictionary = {}    # Button -> [fill, ink, label, role]
var _flats: Dictionary = {}   # look key -> [verts, cols]
var _faces: ArrayMesh
var _sig := PackedFloat32Array()
var _font: Font

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
	if _paint == null:
		_font = CozyTheme.display(700)
		_paint = Control.new()
		_paint.name = "Paint"
		_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_paint.draw.connect(_draw_keys)
		add_child(_paint)
	_lang = Locale.current()
	var rows: Array = ROWS_ES if Locale.current() == "es" else ROWS
	for r in rows.size():
		var slot := Control.new()
		slot.name = "RowSlot_%d" % r
		slot.custom_minimum_size = Vector2(0.0, KEY.y)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inner.add_child(slot)
		_row_slots.append(slot)

		var row := HBoxContainer.new()
		row.name = "Row_%d" % r
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", int(GAP))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(row)
		_rows.append(row)
		slot.resized.connect(_fit_row.bind(r))
		_fit_row(r)

		var letters: String = rows[r]
		if r == 2:
			_add_special(row, "commit", WIDE_ENTER)
		for i in letters.length():
			_add_letter(row, letters[i])
		if r == 2:
			_add_special(row, "erase", WIDE_BACK)

## Lays the keys out again when the language has changed since they were
## laid: Spanish has an Ñ the others do not. Nothing to do otherwise.
func match_locale() -> void:
	if _lang == Locale.current():
		return
	for r in _row_tw.size():
		Motion.stop(_row_tw[r])
	for slot in _row_slots:
		_inner.remove_child(slot)
		slot.queue_free()
	_row_slots = []
	_rows = []
	_row_tw = [null, null, null]
	_keys = {}
	_chips = []
	_look = {}
	_sig = PackedFloat32Array()
	_press_tw = {}
	_bump_tw = {}
	_build()

## Keeps row `r` filling its slot's whole width -- the slot's width is
## whatever the VBox leaves it, which is the tray's own width and not a
## constant. A row mid-slide owns its own `position.y` until the tween ends.
func _fit_row(r: int) -> void:
	var slot: Control = _row_slots[r]
	var row: HBoxContainer = _rows[r]
	if slot.size.x <= 0.0:
		return
	row.size = slot.size
	if not Motion.running(_row_tw[r]):
		row.position = Vector2.ZERO

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
	slot.add_child(chip)
	# Dropped after add_child, which is when CozyTheme.dress() puts the
	# shared paper wash on; a key carries its own flat face instead.
	chip.material = null
	_blank(chip)
	_look[chip] = [Pal.KEY_FACE, Pal.TEXT, letter.to_upper(), "letter"]
	chip.button_down.connect(_press.bind(chip))
	chip.button_up.connect(_release.bind(chip))
	chip.pressed.connect(func() -> void: key.emit(letter))
	_keys[letter] = chip
	_chips.append(chip)

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
	_blank(chip)
	if role == "commit":
		_look[chip] = [Pal.GOOD, Pal.PAPER, "KEY_ENTER", role]
		chip.pressed.connect(func() -> void: commit.emit())
	else:
		_look[chip] = [Pal.KEY_FACE, Pal.TEXT, "", role]
		chip.pressed.connect(func() -> void: erase.emit())
	chip.button_down.connect(_press.bind(chip))
	chip.button_up.connect(_release.bind(chip))
	_chips.append(chip)

## The backspace glyph, drawn rather than set as text: neither of the HUD's
## two fonts carries U+232B, so a Button.text of "⌫" renders as a missing
## glyph box. An outlined arrow pointing at the letter it clears, with an X
## laid across it -- the concept tab's own icon (docs/brainstorm/concepts.html,
## the `bksp` icon), stroked into the key's look about the key's centre `c`.
static func _erase_glyph(b, c: Vector2) -> void:
	var s := 56.0
	var w := s * 0.09
	var pts := PackedVector2Array([
		c + Vector2(-0.46, 0.0) * s, c + Vector2(-0.14, -0.32) * s,
		c + Vector2(0.46, -0.32) * s, c + Vector2(0.46, 0.32) * s,
		c + Vector2(-0.14, 0.32) * s,
	])
	b.stroke(pts, w, Pal.TEXT, true)
	b.stroke(PackedVector2Array([c + Vector2(-0.02, -0.14) * s, c + Vector2(0.24, 0.14) * s]), w, Pal.TEXT)
	b.stroke(PackedVector2Array([c + Vector2(0.24, -0.14) * s, c + Vector2(-0.02, 0.14) * s]), w, Pal.TEXT)

## A key's look: the theme's soft button in the key's face (UI polish,
## 2026-09-28; a thick bottom edge before), lettered in `ink` for every
## state a key can be in -- painted by `_paint`, never by the Button.
func _style(chip: Button, fill: Color, ink: Color) -> void:
	var look: Array = _look.get(chip, [])
	if look.is_empty():
		return
	look[0] = fill
	look[1] = ink
	_sig = PackedFloat32Array()

## A Button that takes input and moves but paints nothing of its own.
static func _blank(chip: Button) -> void:
	var none := StyleBoxEmpty.new()
	for state in ["normal", "hover", "focus", "pressed", "disabled", "hover_pressed"]:
		chip.add_theme_stylebox_override(state, none)

func _process(_delta: float) -> void:
	if _paint == null or not is_visible_in_tree():
		return
	# Every key's place, scale and press, in the paint's space; a frame that
	# matches the last one draws the mesh it already has.
	var inv := _paint.get_global_transform().affine_inverse()
	var sig := PackedFloat32Array()
	sig.resize(_chips.size() * 7)
	var k := 0
	for chip in _chips:
		var xf := inv * chip.get_global_transform()
		sig[k] = xf.x.x
		sig[k + 1] = xf.x.y
		sig[k + 2] = xf.y.x
		sig[k + 3] = xf.y.y
		sig[k + 4] = xf.origin.x
		sig[k + 5] = xf.origin.y
		sig[k + 6] = 1.0 if _held(chip) else 0.0
		k += 7
	if sig == _sig:
		return
	_sig = sig
	_faces = null
	_paint.queue_redraw()

static func _held(chip: Button) -> bool:
	var mode := chip.get_draw_mode()
	return mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED

## Every key's face as one mesh, then every key's letter: two draw calls.
func _draw_keys() -> void:
	if _chips.is_empty():
		return
	var inv := _paint.get_global_transform().affine_inverse()
	if _faces == null:
		var b := Face.FlatBuilder.new()
		for chip in _chips:
			var f := _flat_for(chip)
			var xf := inv * chip.get_global_transform()
			b.verts.append_array(xf * (f[0] as PackedVector2Array))
			b.cols.append_array(f[1])
		_faces = b.mesh()
	if _faces != null:
		_paint.draw_mesh(_faces, null)
	var asc := _font.get_ascent(FONT_SIZE)
	for chip in _chips:
		var look: Array = _look[chip]
		if String(look[2]) == "":
			continue
		var text := tr(String(look[2]))
		var ts := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var at := Vector2((chip.size.x - ts.x) * 0.5, (chip.size.y - ts.y) * 0.5 + asc)
		_paint.draw_set_transform_matrix(inv * chip.get_global_transform())
		_paint.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, look[1])
	_paint.draw_set_transform_matrix(Transform2D.IDENTITY)

## A key's face as a flat triangle list about its own top-left corner, made
## once per size, face, press and glyph: CozyTheme.soft_button's look (a
## soft shadow below, a two-pixel border a shade darker, the face) laid out
## as triangles.
func _flat_for(chip: Button) -> Array:
	var look: Array = _look[chip]
	var held := _held(chip)
	var key := "%d|%d|%s|%s|%s" % [int(chip.size.x), int(chip.size.y), look[0].to_html(), held, look[3]]
	var f: Array = _flats.get(key, [])
	if not f.is_empty():
		return f
	var fill: Color = look[0]
	var b := Face.Builder.new()
	var sz := chip.size
	var tint := fill.darkened(0.55).lerp(Color(0.35, 0.23, 0.12), 0.5)
	var spread := 3.0 if held else 10.0
	var drop := Vector2(0.0, 1.0 if held else 4.0)
	_shadow(b, drop, sz, RADIUS, spread, Color(tint, 0.10 if held else 0.2))
	b.fan(_rounded(Vector2.ZERO, sz, RADIUS), Color(fill.darkened(0.16), fill.a))
	b.fan(_rounded(Vector2(2.0, 2.0), sz - Vector2(4.0, 4.0), RADIUS - 2.0),
		fill.darkened(0.07) if held else fill)
	if look[3] == "erase":
		_erase_glyph(b, sz * 0.5)
	f = Face.FlatBuilder.flat_of(b)
	_flats[key] = f
	return f

## A rounded rectangle's outline with a fixed count of points a corner, so
## two of them of different radii can be joined point to point.
static func _rounded(at: Vector2, sz: Vector2, r: float) -> PackedVector2Array:
	const N := 8
	var rr := minf(r, minf(sz.x, sz.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[at + Vector2(sz.x - rr, rr), -PI * 0.5],
		[at + Vector2(sz.x - rr, sz.y - rr), 0.0],
		[at + Vector2(rr, sz.y - rr), PI * 0.5],
		[at + Vector2(rr, rr), PI],
	]
	for c in corners:
		for i in N + 1:
			pts.append(c[0] + Vector2.from_angle(c[1] + PI * 0.5 * i / N) * rr)
	return pts

## StyleBoxFlat's shadow: the rect in `colour`, fading to nothing `spread`
## further out, moved by `drop`.
static func _shadow(b, drop: Vector2, sz: Vector2, r: float, spread: float, colour: Color) -> void:
	var inner := _rounded(drop, sz, r)
	var outer := _rounded(drop - Vector2.ONE * spread, sz + Vector2.ONE * spread * 2.0, r + spread)
	var n := inner.size()
	var first: int = b.verts.size()
	for p in inner:
		b.vertex(p, colour)
	for p in outer:
		b.vertex(p, Color(colour, 0.0))
	var c: int = b.vertex(drop + sz * 0.5, colour)
	for i in n:
		var j := (i + 1) % n
		b.tri(c, first + i, first + j)
		b.tri(first + i, first + n + i, first + n + j)
		b.tri(first + i, first + n + j, first + j)

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
## resolves "best mark wins"; this only ever paints what it is handed. The
## mark is matched explicitly rather than defaulted to a hit, so a value that
## is none of the three (a caller's bug) paints nothing rather than lying
## green.
func set_marks(marks: Dictionary) -> void:
	for letter in marks:
		var chip: Button = _keys.get(String(letter).to_lower())
		if chip == null:
			continue
		var fill: Color
		match int(marks[letter]):
			HiddenWordState.HIT:
				fill = Pal.GOOD
			HiddenWordState.NEAR:
				fill = Pal.WORD_NEAR
			HiddenWordState.MISS:
				fill = Pal.WORD_MISS
			_:
				continue
		_style(chip, fill, Pal.PAPER)

## Every letter key back to its untouched face. `set_marks` alone can never
## get there: it only ever paints what it is handed and a letter absent from
## its dictionary keeps whatever it already had, which is right for a guess
## and wrong for a Reset -- the board's rows are gone and the keyboard would
## still be coloured by them. Enter keeps its own `Pal.GOOD` and the
## backspace its own face; neither is ever a mark.
func clear_marks() -> void:
	for letter in _keys:
		_style(_keys[letter], Pal.KEY_FACE, Pal.TEXT)

## The named keys bump, the beat that says the row just landed on them.
func bump(letters: Array) -> void:
	for letter in letters:
		var lower := String(letter).to_lower()
		var chip: Button = _keys.get(lower)
		if chip == null:
			continue
		Motion.stop(_bump_tw.get(lower))
		_bump_tw[lower] = Motion.bump(chip)

## The keyboard leaves for the reveal: `_inner` slides down to `enter_from`
## while the tray fades, over `time`, and every key is disabled so a tap on
## the now-faded paper cannot still fire `key`/`commit`/`erase`. Not a
## queue_free -- a later `enter()` call (Reset replaying the day) slides
## `_inner` straight back from the same `enter_from`, fades the tray back in
## and re-enables every key, so nothing here needs undoing by hand.
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
	for chip in _chips:
		chip.disabled = true
	gone = true

## The three rows slide up `ENTER_STAGGER` apart on top of the panel's own
## entrance, so the keyboard reads as one hand settling rather than a slab
## dropping in at once, and every key takes input again (undoing a prior
## `slide_out`).
func enter(delay: float) -> void:
	super(delay)
	gone = false
	for chip in _chips:
		chip.disabled = false
	for r in _rows.size():
		Motion.stop(_row_tw[r])
		var row: HBoxContainer = _rows[r]
		var slide: Tween = Motion.slide(row, "position:y", Motion.DROP, 0.0, ENTER_SLIDE, delay + r * Motion.ENTER_STAGGER)
		_row_tw[r] = slide
		if slide != null:
			_entrance.append(slide)
