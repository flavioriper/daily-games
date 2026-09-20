extends "res://ui/hud/panel.gd"

## The flat screen's top row: back, the wordmark lettered in ink with the
## leaf sprouting from it and the motto under, then undo, hint with its
## bouncing count and settings. The same signals as ui/hud/top_bar.gd, the
## same buttons; only the title differs, a Label where the other boards
## carry the carved sign. Every puzzle keeps its title case and wears the
## shared golden sun over each i. Binairo keeps its supplied mixed-case
## `BINAiRO` lockup and roots the sprout in the A.
##
## One board asks for a fifth button: the flat Balance is its own continuous
## check, so it has nothing to put in an actions row and drops the row
## entirely, which leaves Reset homeless. It rides up here instead, between
## undo and hint. Nothing else sets `with_reset`, so the other two screens
## keep their four.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 3,
## and docs/superpowers/specs/2026-09-18-balance-flat-design.md, section 5.

signal back
signal undo
signal reset
signal hint
signal settings

const IconButton = preload("res://ui/hud/icon_button.gd")
const Icons = preload("res://ui/icons.gd")
const SunDot = preload("res://ui/sun_dot.gd")

const HEIGHT := 180.0
const BUTTON := Vector2(110, 110)
const BADGE_HOP := -6.0
const BADGE_HOP_TIME := 0.3
const BADGE_CYCLE := 2.4
## The leaf stands over the gap before the wordmark's last letter: this far
## right of the title's centre, as a fraction of its width.
const LEAF_AT := 0.2
const LEAF := 40.0
const BRAND_TITLE := "BINAiRO"
## The width the title's block gets: the row less the back button, the three
## icon buttons and the four separations (1000 - 110 - 3 x 110 - 4 x 16 =
## 496). A title wider than this is shrunk to fit rather than clipped --
## Mushroom Patch measures 635 in Fredoka 700 at the theme's 84 (2026-09-20),
## where Hidden Word's 482 is the longest that fits as it stands.
const BLOCK := 496.0
## No title shrinks below this; past it the name is too long for the screen
## and the answer is a shorter name.
const TITLE_MIN := 56

var title_text := ""
var motto_text := ""
var brand_binairo := false
## Whether this bar carries Reset (a board with no actions row).
var with_reset := false
var back_button: Button
var undo_button: Button
var reset_button: Button
var hint_button: Button
var settings_button: Button
var _title: Label
var _motto: Label
var _block: Control
var _bounce: Tween

func _init(title := "", motto := "", carry_reset := false, branded := false) -> void:
	brand_binairo = branded
	title_text = BRAND_TITLE if brand_binairo else title
	motto_text = motto if brand_binairo else motto.to_upper()
	with_reset = carry_reset
	enter_from = Vector2(0, -80)

func _make_inner() -> Container:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	return row

func _build() -> void:
	back_button = _button("chevron_left", back)
	_block = Control.new()
	_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_block.custom_minimum_size.y = HEIGHT
	_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_block)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.add_child(col)
	_title = Label.new()
	_title.theme_type_variation = "GameWordmark"
	_title.text = title_text
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_fit_title()
	_title.add_child(SunDot.new(_title))
	_motto = Label.new()
	_motto.theme_type_variation = "BinairoMotto" if brand_binairo else "FlatMotto"
	_motto.text = motto_text
	_motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_motto.visible = motto_text != ""
	col.add_child(_motto)
	# The leaf draws over the block once the title has a size to hang from.
	var leaf := Control.new()
	leaf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaf.draw.connect(_draw_leaf.bind(leaf))
	_block.add_child(leaf)
	_title.resized.connect(leaf.queue_redraw)
	undo_button = _button("undo", undo)
	reset_button = _button("reset", reset)
	reset_button.visible = with_reset
	hint_button = _button("bulb", hint)
	settings_button = _button("gear", settings)

## `_title` fires this once itself, synchronously, the moment it enters the
## already-themed tree inside _build(); the notification hook below covers
## the case that add_child does not resolve it in time or a theme is
## installed after the fact. Always clears any prior override first, so a
## repeat call always measures the theme's true size and not a size this
## function set on an earlier pass -- without that, a shrunk title would
## shrink again on every re-entry.
func _fit_title() -> void:
	if _title == null:
		return
	_title.remove_theme_font_size_override("font_size")
	var font := _title.get_theme_font("font")
	var size := _title.get_theme_font_size("font_size")
	# A harness that never installs ui/theme.gd's theme (nothing up the tree
	# knows the GameWordmark variation) hands back a null font or a zero
	# size here; leave the label exactly as it fell back rather than fit it
	# to garbage.
	if font == null or size <= 0:
		return
	var width: float = font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if width <= 0.0 or width <= BLOCK:
		return
	var fitted := floori(float(size) * BLOCK / width)
	_title.add_theme_font_size_override("font_size", maxi(fitted, TITLE_MIN))

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_fit_title()

## A button keeps its own square and sits centred on the row, as the other
## top bar's do.
func _button(icon: String, sig: Signal) -> Button:
	var b := IconButton.new(icon)
	b.custom_minimum_size = BUTTON
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: sig.emit())
	_inner.add_child(b)
	return b

## A stem rising from the title's top edge with two leaves, over the gap
## before the last letter. Drawn in the block's space from the title's own
## rect, so it follows the lettering wherever the row puts it.
func _draw_leaf(ci: Control) -> void:
	if _title == null or _title.size.x <= 0.0:
		return
	var text_w: float = _title.get_minimum_size().x
	var font := _title.get_theme_font("font")
	var font_size := _title.get_theme_font_size("font_size")
	var text_left := _title.position.x + (_title.size.x - text_w) * 0.5
	var root_x := _title.position.x + _title.size.x * 0.5 + text_w * LEAF_AT
	if brand_binairo:
		var before_a := font.get_string_size("BIN", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var a_w := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		root_x = text_left + before_a + a_w * 0.52
	var top := Vector2(root_x, _title.position.y + _title.size.y * 0.16)
	var tip := top + Vector2(2.0, -30.0)
	ci.draw_polyline(PackedVector2Array([top, top + Vector2(4.0, -16.0), tip]), Pal.LEAF, 7.0, true)
	# The leaf icon's base is at (0.15, 0.85) of its rect and its tip at the
	# opposite corner, so it points to the upper right from a base at the
	# lower left; a mirrored rect (negative width) points it to the upper
	# left. Each rect is placed so that base lands on the stem's tip and the
	# leaf grows up and outward, as the sprout's do. (Until 2026-09-18 the
	# rects stood on the wrong sides and the leaves hung with their stalks
	# outboard and their tips turned in.)
	var right := LEAF
	var left := LEAF * 0.85
	Icons.paint(ci, "leaf", Rect2(tip + Vector2(-0.15 * right, 2.0 - 0.85 * right), Vector2(right, right)), Pal.LEAF)
	Icons.paint(ci, "leaf", Rect2(tip + Vector2(0.15 * left, 2.0 - 0.85 * left), Vector2(-left, left)), Pal.LEAF)

func refresh(puzzle) -> void:
	var caps: Array = puzzle.capabilities() if puzzle != null else []
	var done: bool = puzzle != null and puzzle.is_done()
	undo_button.visible = caps.has("undo")
	hint_button.visible = caps.has("hint")
	undo_button.set_enabled(puzzle != null and puzzle.can_undo() and not done)
	# A finished board has nothing left to reset -- except the one that can
	# finish without being solved. Hidden Word's sixth wrong row stops the
	# clock and greys this bar exactly as a solve does (spec
	# 2026-09-19-hidden-word-flat-design.md, section 8), but the day is still
	# there to replay and Reset is the only way back to it: the win screen
	# never comes, so there is no Back to camp button under it either. Every
	# other board that is done is also solved, so nothing else moves.
	reset_button.set_enabled(not done or (puzzle != null and not puzzle.is_solved()))
	var left: int = puzzle.hints_left() if puzzle != null else 0
	hint_button.set_enabled(left > 0 and not done)
	hint_button.badge = left
	_set_bounce(hint_button.visible and left > 0 and not done)

## The badge hops every BADGE_CYCLE seconds while hints remain, as on the
## island's bar. Under reduce-motion hop returns null and the badge stays put.
func _set_bounce(on: bool) -> void:
	if not on:
		Motion.stop(_bounce)
		_bounce = null
		return
	if Motion.running(_bounce):
		return
	var badge: Control = hint_button.badge_node()
	_bounce = hint_button.create_tween().set_loops()
	_bounce.tween_callback(func() -> void: Motion.hop(badge, BADGE_HOP, BADGE_HOP_TIME, 0.0, hint_button.badge_rest.y))
	_bounce.tween_interval(BADGE_CYCLE)
