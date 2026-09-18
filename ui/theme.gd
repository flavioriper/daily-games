extends RefCounted

## One warm theme for every Control: the display and body fonts, the card
## styles and the button variants the HUD uses, built in code so it stays in
## step with the palette. One Theme instance is built and shared.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 4.

const Pal = preload("res://core/palette.gd")

const DISPLAY_PATH := "res://assets/fonts/Fredoka-Variable.ttf"
const BODY_PATH := "res://assets/fonts/Nunito-Variable.ttf"
## The OpenType 'wght' axis tag: the four ASCII bytes packed big-endian.
const WGHT := 0x77676874

const GRAIN_SHADER := preload("res://shaders/wood_grain_2d.gdshader")
const PAPER_SHADER := preload("res://shaders/paper_2d.gdshader")

static var _theme: Theme
static var _fonts: Dictionary = {}
static var _grain: Dictionary = {}
static var _paper: ShaderMaterial

## The shared theme, built once.
static func make() -> Theme:
	if _theme != null:
		return _theme
	var theme := Theme.new()
	# Plain labels and buttons: the body face, today's paper button look.
	theme.set_font("font", "Label", body(500))
	theme.set_color("font_color", "Label", Pal.TEXT)
	theme.set_font("font", "Button", body(700))
	_button(theme, "Button", Pal.SURFACE_HI, Pal.LINE, 6, 28, Pal.TEXT)
	# Label variations.
	# The title itself is ui/hud/sign_view.gd: a modelled board, not a Control.
	_label(theme, "Motto", body(700, 2), 24, Pal.SURFACE)
	theme.set_color("font_shadow_color", "Motto", Color(Pal.OUTLINE, 0.45))
	theme.set_constant("shadow_offset_x", "Motto", 1)
	theme.set_constant("shadow_offset_y", "Motto", 2)
	_label(theme, "CardTitle", display(600), 40, Pal.TEXT)
	# The menu's puzzle cards: a chunky name and a quiet one-line blurb, sized
	# for three cards across a 1080 screen.
	_label(theme, "CardName", display(700), 32, Pal.TEXT)
	_label(theme, "CardBlurb", body(500), 22, Pal.TEXT_DIM)
	# The motto under the menu's title letters: the Motto face, larger, on
	# two lines over the sky.
	_label(theme, "TitleMotto", body(800, 2), 30, Pal.SURFACE)
	# Cream over a lit campsite needs an edge to read: a wood-dark outline, the
	# way the concept banner letters it, and a soft shadow under that.
	theme.set_color("font_outline_color", "TitleMotto", Pal.PLAQUE_DEEP)
	theme.set_constant("outline_size", "TitleMotto", 8)
	theme.set_color("font_shadow_color", "TitleMotto", Color(Pal.OUTLINE, 0.35))
	theme.set_constant("shadow_offset_x", "TitleMotto", 2)
	theme.set_constant("shadow_offset_y", "TitleMotto", 4)
	_label(theme, "CardBody", body(500), 30, Pal.TEXT)
	_label(theme, "OnSlateTitle", display(600), 40, Pal.MOON)
	_label(theme, "OnSlateBody", body(500), 30, Pal.MOON)
	_label(theme, "Badge", display(700), 26, Pal.SURFACE)
	# The flat Binairo's lettering (docs/superpowers/specs/2026-09-18-binairo-flat-design.md):
	# the wordmark in ink where the other boards carry a carved sign, its
	# motto under it, and the win screen's headline.
	_label(theme, "Wordmark2D", display(700, 2), 84, Pal.TEXT)
	_label(theme, "FlatMotto", body(700, 2), 24, Pal.TEXT_DIM)
	_label(theme, "WellDone", display(700), 96, Pal.TEXT)
	_label(theme, "CardBodyDim", body(500), 30, Pal.TEXT_DIM)
	_label(theme, "TipBody", body(500), 32, Pal.TEXT)
	# The flat Balance's weight cards
	# (docs/superpowers/specs/2026-09-18-balance-flat-design.md, section 4):
	# the weight as a big numeral, and the tag a given card wears in place of
	# its minus and plus. The win screen reuses the numeral at a smaller size.
	_label(theme, "WeightNumeral", display(700), 62, Pal.TEXT)
	_label(theme, "GivenTag", body(700, 2), 22, Pal.TEXT_DIM)
	# The flat Nonogram's tray (docs/superpowers/specs/2026-09-18-nonogram-flat-design.md,
	# section 6): the two chips are wide enough to name what they paint, so
	# each carries its word beside its picture.
	_label(theme, "ChipLabel", display(700), 40, Pal.TEXT)
	# Button variations.
	_variant(theme, "IconButton", body(700), 34, Pal.SURFACE_HI, Pal.LINE, 6, 28, Pal.TEXT)
	_variant(theme, "PrimaryButton", display(700), 40, Pal.SUN, Pal.SUN_DEEP, 8, 32, Pal.TEXT)
	_variant(theme, "DarkButton", display(700), 40, Pal.SLATE, Pal.SLATE_GIVEN, 8, 32, Pal.MOON)
	# The flat screen's sun button: PrimaryButton with its label in white, as
	# the reference letters it.
	_variant(theme, "SunButton", display(700), 40, Pal.SUN, Pal.SUN_DEEP, 8, 32, Pal.SURFACE)
	_theme = theme
	return theme

## The rounded display face at a weight (Fredoka), optionally letter-spaced
## by `spacing` pixels between glyphs.
static func display(weight: int, spacing := 0) -> FontVariation:
	return _font(DISPLAY_PATH, weight, spacing)

## The body face at a weight (Nunito), optionally letter-spaced by `spacing`
## pixels between glyphs.
static func body(weight: int, spacing := 0) -> FontVariation:
	return _font(BODY_PATH, weight, spacing)

## A cached FontVariation over the file at `path` with the wght axis set. A
## missing file (a stripped test project) falls back to the engine font.
static func _font(path: String, weight: int, spacing := 0) -> FontVariation:
	var key := "%s|%d|%d" % [path, weight, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	var base: Font = null
	if ResourceLoader.exists(path):
		base = load(path) as Font
	fv.base_font = base if base != null else ThemeDB.fallback_font
	fv.variation_opentype = {WGHT: weight}
	fv.spacing_glyph = spacing
	_fonts[key] = fv
	return fv

static func _label(theme: Theme, name: String, font: Font, size: int, colour: Color) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, colour)

static func _variant(theme: Theme, name: String, font: Font, size: int, fill: Color, border: Color, border_w: int, radius: int, text: Color) -> void:
	theme.set_type_variation(name, "Button")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	_button(theme, name, fill, border, border_w, radius, text)

## The four button states for a type: normal and hover alike (touch has no
## hover), pressed sinks onto a 2 px edge and darkens toward LINE, disabled
## fades to 55 percent.
static func _button(theme: Theme, type: String, fill: Color, border: Color, border_w: int, radius: int, text: Color) -> void:
	theme.set_stylebox("normal", type, card(fill, radius, border, border_w, 24))
	theme.set_stylebox("hover", type, card(fill, radius, border, border_w, 24))
	theme.set_stylebox("pressed", type, card(fill.lerp(Pal.LINE, 0.15), radius, border, 2, 24))
	theme.set_stylebox("disabled", type, card(Color(fill, 0.55), radius, Color(border, 0.55), border_w, 24))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, type, text)
	theme.set_color("font_disabled_color", type, Color(text, 0.45))

## A rounded card with a thick bottom edge, the HUD's paper.
static func card(fill: Color, radius: int, border: Color, border_w: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.border_width_bottom = border_w
	sb.border_color = border
	return sb

static func paper_card() -> StyleBoxFlat:
	return card(Color(Pal.PAPER, 0.94), 28, Pal.LINE, 6, 24)

static func slate_card() -> StyleBoxFlat:
	return card(Color(Pal.SLATE, 0.92), 24, Pal.SLATE_GIVEN, 0, 20)

static func parchment_card() -> StyleBoxFlat:
	var sb := card(Color(Pal.PARCHMENT, 0.96), 12, Pal.LINE, 0, 24)
	sb.set_border_width_all(3)
	return sb

## The painterly wash every paper face wears, as a Control `material`
## (shaders/paper_2d.gdshader): the same slow warm-to-cool drift the 3D
## pieces carry, over whatever colour the stylebox drew. One shared material,
## since it is measured in screen space and every panel shows the patch it
## sits over. Applied by dress() to every face that enters the tree; a widget
## that wants another surface (the wood trays, the plank) sets its own
## material and keeps it.
static func paper() -> ShaderMaterial:
	if _paper == null:
		_paper = ShaderMaterial.new()
		_paper.shader = PAPER_SHADER
	return _paper

## Hands the paper wash to every Button, Panel and PanelContainer that enters
## `tree` without a material of its own. Installed once, by world/main.gd
## before any screen builds, the way the theme is one Theme for the whole HUD:
## a stylebox cannot carry a material, and the alternative was every widget
## remembering to ask. The check runs for every node that enters the tree,
## 3D included; it is a type test and costs nothing worth measuring.
static func dress(tree: SceneTree) -> void:
	tree.node_added.connect(_dress_node)

static func _dress_node(node: Node) -> void:
	if node is Button or node is Panel or node is PanelContainer:
		var c := node as CanvasItem
		if c.material == null:
			c.material = paper()

## The grain the wood panels wear, as a Control `material`. It darkens
## whatever the stylebox drew rather than painting a colour of its own, so a
## tray, its trough and the plaque each keep their own wood. `seed` picks the
## log: one material per seed, cached, so panels that would otherwise show
## the same corner of the same figure do not. Put it on the panel, never on a
## panel with children that draw themselves -- the material catches those too.
static func wood_grain(seed := 0.0) -> ShaderMaterial:
	if not _grain.has(seed):
		_grain[seed] = _make_grain(seed)
	return _grain[seed]

## One grain material, uncached. Only plank() wants this: a panel that carves
## its own silhouette hands the shader its size, and that size is a plain
## uniform, so two panels of different sizes cannot share one material.
static func _make_grain(seed: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GRAIN_SHADER
	m.set_shader_parameter("grain_seed", seed)
	# The plank's rim, should one be asked for (it is off by default), as
	# the multiply that takes the face to PLAQUE_DEEP.
	var face := plank_face()
	m.set_shader_parameter("rim_tint", Vector3(
		Pal.PLAQUE_DEEP.r / face.r, Pal.PLAQUE_DEEP.g / face.g, Pal.PLAQUE_DEEP.b / face.b))
	return m

static func wood_card() -> StyleBoxFlat:
	return card(Pal.WOOD, 28, Pal.WOOD_DEEP, 8, 16)

## The plank's face: a third of the way from PLAQUE toward the trays' WOOD, a
## warmer tan with room for the grain to darken.
static func plank_face() -> Color:
	return Pal.PLAQUE.lerp(Pal.WOOD, 0.35)

## The face colour over the whole rect, and nothing else: the board the day
## card hangs from is cut by the grain shader, which
## draws the hewn edge and its lit lip itself, with no rim. Use through plank().
static func plank_card() -> StyleBoxFlat:
	return card(plank_face(), 0, Pal.PLAQUE_DEEP, 0, 22)

## Dress `panel` as a hewn board: the face as its stylebox, the grain as its
## material, and its size handed to the shader on every resize so the shader
## can cut the silhouette (shaders/wood_grain_2d.gdshader, `plank_size`).
## `seed` picks the board, as for wood_grain(). The material is this panel's
## own rather than the shared cached one, because the size is a plain uniform:
## an instance uniform is read out of the global shader buffer, and
## gl_compatibility shaders address only sixteen instances of it before a
## mobile driver starts handing back garbage.
static func plank(panel: Control, seed: float) -> void:
	panel.add_theme_stylebox_override("panel", plank_card())
	var m := _make_grain(seed)
	panel.material = m
	var fit := func() -> void: m.set_shader_parameter("plank_size", panel.size)
	panel.resized.connect(fit)
	fit.call()

## The trough carved into the colour tray, holding the buttons.
static func wood_channel() -> StyleBoxFlat:
	return card(Pal.WOOD_DEEP, 20, Pal.WOOD_DEEP.darkened(0.25), 4, 10)
