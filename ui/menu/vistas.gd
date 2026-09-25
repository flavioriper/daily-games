extends RefCounted

## Every painted surface on the first screen, and the one place the art is
## named. Six vistas (assets/art/menu/vista_<name>.png, supplied by the user
## on 2026-09-24) are cropped for the header, the day card and all twenty
## card banners; a plate is a ColorRect with shaders/painted_plate_2d.gdshader,
## one draw call. Crops are fractions of the picture, never pixels, so a
## full-size original can replace a file with no change here.
##
## A vista that is not on disk, or a card this table does not name, draws a
## sky-over-ground gradient in the card's colour instead -- never an error,
## the way Fx2D.cue() plays silence for a missing sound.
## Spec: docs/superpowers/specs/2026-09-24-painted-menu-design.md, section 4.

const Pal = preload("res://core/palette.gd")
const SHADER = preload("res://shaders/painted_plate_2d.gdshader")

const DIR := "res://assets/art/menu/vista_%s.png"

## [vista, zoom, focus]: zoom 1.0 is cover, and focus is where the crop sits
## in the room the zoom leaves (CSS background-position). Copied from the
## concept page's table.
const HEADER := ["dusk", 1.1, Vector2(0.88, 0.70)]
const HEADER_SCRIM := Vector3(0.78, 0.0, 0.62)
const HEADER_FADE := Vector2(0.62, 0.96)
const CARD_RADIUS := 28.0
const CARD_WASH := 0.62
const DAY_RADIUS := 36.0
const DAY_SCRIM := Vector3(0.94, 0.25, 0.66)

const CARDS := {
	"binairo": ["sky", 1.5, Vector2(0.30, 0.30)],
	"mastermind": ["meadow", 1.6, Vector2(0.70, 0.55)],
	"balance": ["sky", 1.4, Vector2(0.80, 0.45)],
	"untangle": ["night", 1.5, Vector2(0.60, 0.40)],
	"shikaku": ["meadow", 1.5, Vector2(0.20, 0.70)],
	"tents": ["autumn", 1.5, Vector2(0.70, 0.40)],
	"lightup": ["night", 1.7, Vector2(0.85, 0.60)],
	"oneline": ["meadow", 1.4, Vector2(0.45, 0.80)],
	"nonogram": ["dusk", 1.5, Vector2(0.20, 0.35)],
	"queens": ["meadow", 1.8, Vector2(0.90, 0.85)],
	"hiddenword": ["dusk", 1.5, Vector2(0.55, 0.55)],
	"wordtrail": ["autumn", 1.6, Vector2(0.40, 0.20)],
	"mushroom": ["autumn", 1.7, Vector2(0.15, 0.80)],
	"sudoku": ["dusk", 1.7, Vector2(0.85, 0.75)],
	"bridges": ["beach", 1.5, Vector2(0.70, 0.65)],
	"quilt": ["dusk", 1.8, Vector2(0.92, 0.70)],
	"fairylights": ["night", 1.6, Vector2(0.20, 0.70)],
	"planes": ["sky", 1.4, Vector2(0.50, 0.20)],
	"pinwheel": ["beach", 1.6, Vector2(0.20, 0.55)],
	"rings": ["meadow", 1.5, Vector2(0.40, 0.30)],
	"caterpillar": ["meadow", 1.7, Vector2(0.65, 0.75)],
}

## The Streak tab's two pictures (ui/menu/streak_tab.gd): the run's card and
## today's, each washed to the card's paper on its left edge.
const STREAK := ["meadow", 1.4, Vector2(0.85, 0.75)]
const TODAY := ["meadow", 1.8, Vector2(0.25, 0.85)]
const SIDE_SCRIM := Vector3(1.0, 0.0, 0.45)

## Island key (core/progress.gd's ISLANDS) to the vista its name suggests.
## Keyed on the key, never the translated name, so every language sees the
## same picture.
const DAY := {
	"ISLAND_0": "beach", "ISLAND_1": "meadow", "ISLAND_2": "night",
	"ISLAND_3": "beach", "ISLAND_4": "dusk", "ISLAND_5": "autumn",
	"ISLAND_6": "beach", "ISLAND_7": "meadow", "ISLAND_8": "beach",
	"ISLAND_9": "night", "ISLAND_10": "autumn", "ISLAND_11": "meadow",
	"ISLAND_12": "sky", "ISLAND_13": "dusk", "ISLAND_14": "meadow",
	"ISLAND_15": "autumn", "ISLAND_16": "dusk", "ISLAND_17": "autumn",
	"ISLAND_18": "dusk", "ISLAND_19": "autumn", "ISLAND_20": "sky",
	"ISLAND_21": "beach", "ISLAND_22": "night", "ISLAND_23": "sky",
}
## Where each vista's day-card crop looks (zoom 1.0, cover).
const DAY_FOCUS := {
	"beach": Vector2(0.50, 0.62), "dusk": Vector2(0.30, 0.55),
	"meadow": Vector2(0.50, 0.60), "night": Vector2(0.55, 0.60),
	"autumn": Vector2(0.50, 0.55), "sky": Vector2(0.50, 0.45),
}

static var _cache := {}

## The vista's texture, or null when the file is not there. ResourceLoader
## .exists is asked first so a missing file prints nothing.
static func texture(vista: String) -> Texture2D:
	if _cache.has(vista):
		return _cache[vista]
	var path := DIR % vista
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[vista] = tex
	return tex

## The crop, as a UV rect: cover the plate, zoom past cover, then slide to
## `focus` within the room the zoom leaves.
static func crop(plate: Vector2, tex: Vector2, zoom: float, focus: Vector2) -> Rect2:
	if plate.x <= 0.0 or plate.y <= 0.0 or tex.x <= 0.0 or tex.y <= 0.0:
		return Rect2(0.0, 0.0, 1.0, 1.0)
	var s := maxf(plate.x / tex.x, plate.y / tex.y) * maxf(zoom, 1.0)
	var frac := (plate / s) / tex
	return Rect2((Vector2.ONE - frac) * focus, frac)

static func _plate(radius: float) -> ColorRect:
	var plate := ColorRect.new()
	plate.color = Color.WHITE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("paper", Pal.PAPER)
	mat.set_shader_parameter("surface", Pal.SURFACE)
	plate.material = mat
	plate.resized.connect(func() -> void: _refit(plate))
	return plate

## Points `plate` at a vista (or the fallback in `tint`) and re-crops it.
static func point_at(plate: ColorRect, vista: String, zoom: float, focus: Vector2, tint: Color) -> void:
	var mat := plate.material as ShaderMaterial
	var tex := texture(vista)
	mat.set_shader_parameter("fallback", tex == null)
	mat.set_shader_parameter("vista", tex)
	mat.set_shader_parameter("tint", tint)
	plate.set_meta("zoom", zoom)
	plate.set_meta("focus", focus)
	_refit(plate)

## F1 (final fix wave, 2026-09-24): a plate's top pad, in px -- the header
## plate is asked to grow by exactly the top safe-area inset
## (ui/menu.gd's `_build_list`, `MenuHeader.HEIGHT`'s own budget is fixed),
## and this crop is `cover`, sized off the plate's own height, so growing the
## plate without accounting for the pad rescales and slides the whole
## painting rather than opening a band at the top -- the sun and moon seated
## on the deck (`menu_header.gd`'s `PAIR_TOP`) walked down the picture with
## it. `set_top_pad` records the pad so `_refit` can cover the plate at its
## *pre-pad* height and extend the UV rect upward by the pad's own share of
## that crop, leaving the picture below the pad pixel-identical to the
## pad-0 case, shifted down by the pad.
static func set_top_pad(plate: ColorRect, px: float) -> void:
	plate.set_meta("top_pad", maxf(px, 0.0))
	_refit(plate)

static func _refit(plate: ColorRect) -> void:
	var mat := plate.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", plate.size)
	var tex: Texture2D = mat.get_shader_parameter("vista")
	if tex == null:
		return
	var top_pad := float(plate.get_meta("top_pad", 0.0))
	var crop_size := Vector2(plate.size.x, maxf(plate.size.y - top_pad, 1.0))
	var r := crop(crop_size, tex.get_size(), float(plate.get_meta("zoom", 1.0)), plate.get_meta("focus", Vector2(0.5, 0.5)))
	if top_pad > 0.0:
		# The pad's own share of the crop, in UV: r.size.y is the crop's UV
		# height for crop_size.y px, so top_pad px of it is
		# r.size.y * (top_pad / crop_size.y). Extending the rect upward by
		# that (rather than resizing the whole crop) is what keeps the image
		# below the pad identical to the pad-0 case -- a negative uv.y is
		# left for the sampler's edge clamp (repeat_disable) to fill.
		var pad_uv := r.size.y * (top_pad / crop_size.y)
		r.position.y -= pad_uv
		r.size.y += pad_uv
	mat.set_shader_parameter("uv_rect", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))

static func card_plate(id: String, tint: Color) -> ColorRect:
	var plate := _plate(CARD_RADIUS)
	(plate.material as ShaderMaterial).set_shader_parameter("wash", CARD_WASH)
	var row: Array = CARDS.get(id, ["", 1.0, Vector2(0.5, 0.5)])
	point_at(plate, row[0], row[1], row[2], tint)
	return plate

static func day_plate() -> ColorRect:
	var plate := _plate(DAY_RADIUS)
	(plate.material as ShaderMaterial).set_shader_parameter("scrim", DAY_SCRIM)
	return plate

static func set_day_vista(plate: ColorRect, island_key: String, tint: Color) -> void:
	var vista: String = DAY.get(island_key, "beach")
	point_at(plate, vista, 1.0, DAY_FOCUS.get(vista, Vector2(0.5, 0.5)), tint)

static func header_plate() -> ColorRect:
	var plate := _plate(0.0)
	var mat := plate.material as ShaderMaterial
	mat.set_shader_parameter("scrim", HEADER_SCRIM)
	mat.set_shader_parameter("fade", HEADER_FADE)
	point_at(plate, HEADER[0], HEADER[1], HEADER[2], Pal.ACCENT)
	return plate

## A picture set into the side of a Streak card: `row` is [vista, zoom,
## focus], washed into `paper` (the card's own fill) along its left edge.
static func side_plate(row: Array, radius: float, paper: Color) -> ColorRect:
	var plate := _plate(radius)
	var mat := plate.material as ShaderMaterial
	mat.set_shader_parameter("scrim", SIDE_SCRIM)
	mat.set_shader_parameter("paper", paper)
	point_at(plate, row[0], row[1], row[2], Pal.LEAF)
	return plate
