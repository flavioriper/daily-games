extends RefCounted

## Extruded lettering for the game's boards: one TextMesh line in the display
## face, toon-shaded in its colour, with a thin outline shell in that colour
## deepened rather than the shared ink line. A sign is drawn far larger than a
## piece on the stage -- a 2.27-unit board fills a card where a 0.84 tile fills
## a thumbnail -- so Toon's own line width would read several times too thick.
##
## ui/hud/sign_view.gd, ui/hud/title_view.gd and world/camp.gd all letter their
## boards through here, so the words stay data everywhere: a new puzzle or a
## new day costs a string, never an export.

const Toon = preload("res://core/toon.gd")
const CozyTheme = preload("res://ui/theme.gd")

## World units per font pixel. Font size is an integer, so an em height is
## dialled with this instead and stays exact.
const PIXEL := 0.004
## The outline shells' width, in world units, for lettering and the boards
## that carry it.
const LINE_WIDTH := 0.005
## TextMesh cannot extrude a glyph whose outline crosses itself, and the
## display face's bold digits do: at 700 the 8 and 9 come out as nothing,
## and every weight from 600 up loses at least one digit. 550 is the heaviest
## weight that extrudes all ten (measured across 300..900 in steps of 50), so
## a line that carries a digit is set at that weight instead of its own.
const DIGIT_WEIGHT := 550

## One line of lettering: `em` tall, extruded `depth`, in `colour`. The mesh is
## centred on its own origin, so it sits half in front of and half behind
## wherever it is placed; stand it off a face by depth * 0.5.
static func line(text: String, em: float, depth: float, colour: Color, weight := 700,
		align := HORIZONTAL_ALIGNMENT_CENTER, line_width := LINE_WIDTH) -> MeshInstance3D:
	var mesh := TextMesh.new()
	mesh.font = CozyTheme.display(weight)
	mesh.font_size = maxi(int(round(em / PIXEL)), 1)
	mesh.pixel_size = PIXEL
	mesh.depth = depth
	mesh.text = text
	mesh.horizontal_alignment = align
	mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_meta("weight", weight)
	_weigh(mesh, text, weight)
	mi.set_surface_override_material(0, Toon.material_for(mi, colour))
	var shell := Toon.add_outline(mi, outline(Toon.line_color(colour), line_width))
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## The face at `weight`, or at DIGIT_WEIGHT when `text` carries a digit.
static func _weigh(mesh: TextMesh, text: String, weight: int) -> void:
	var has_digit := false
	for ch in text:
		if ch.is_valid_int():
			has_digit = true
			break
	mesh.font = CozyTheme.display(DIGIT_WEIGHT if has_digit else weight)

## A fresh outline material at the thin width. Fresh rather than Toon.line():
## that caches per colour and its materials are shared with every piece on
## the stage, so setting a width on one would thin the whole game's lines.
static func outline(colour: Color, width := LINE_WIDTH) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Toon.OUTLINE_SHADER
	m.set_shader_parameter("color", colour)
	m.set_shader_parameter("width", width)
	return m

## Sets the words on `mi` at `em` and brings a long line down until it is no
## wider than `limit`. Width is linear in pixel_size, so one step lands it.
static func fit(mi: MeshInstance3D, text: String, em: float, limit: float) -> void:
	var mesh: TextMesh = mi.mesh
	_weigh(mesh, text, int(mi.get_meta("weight", 700)))
	mesh.text = text
	mesh.pixel_size = PIXEL
	mesh.font_size = maxi(int(round(em / PIXEL)), 1)
	if text == "":
		return
	var w: float = mesh.get_aabb().size.x
	if w > limit and w > 0.0:
		mesh.pixel_size = PIXEL * limit / w
