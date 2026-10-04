extends RefCounted

## Insane's move counter: "N moves left" on a paper pill, where a judged
## board's hearts used to sit. Since 2026-10-04 an Insane board judges
## nothing as it lands (a heart was the answer with a price on it); it hands
## out a budget of moves instead, every piece put down or taken off spending
## one, and the board is lost when the budget is gone with the puzzle
## unsolved (docs/agents/flat-screens.md, "Insane counts moves").
##
## One per board, kept in a var: the mesh a draw handed over stays alive
## until the next replaces it. One draw_mesh and one draw_string.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The strip a board leaves for the pill over its field.
const ROW := 64.0
const FONT := 30
const HEIGHT := 46.0
const PAD := 24.0
const RIM := 2.0
## The count turns rose from here down.
const LOW := 3

var _shown: ArrayMesh
var _wide := -1.0
var _bump_at := -INF
var _last := -1

## Call when the count changed, so the pill bumps.
func bump(now: float) -> void:
	_bump_at = now

## Whether the bump is still playing (a board that only redraws while it
## moves asks this).
func animating(now: float) -> bool:
	return not Motion.reduce and now - _bump_at < Motion.BUMP_TIME

## The line the pill reads.
static func line(on: Control, left: int) -> String:
	return on.tr("MOVES_LEFT_ONE") if left == 1 else on.tr("MOVES_LEFT_N") % left

## Draws the pill centred on `centre` of `layer`.
func draw(layer: Control, centre: Vector2, left: int, now: float) -> void:
	var font: Font = CozyTheme.display(700)
	var text := line(layer, left)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT).x
	var wide := tw + 2.0 * PAD
	if _shown == null or not is_equal_approx(wide, _wide):
		_wide = wide
		var box := Vector2(wide, HEIGHT)
		var b := Face.Builder.new()
		b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2.ONE * RIM, box + Vector2.ONE * 2.0 * RIM,
			HEIGHT * 0.5 + RIM), Pal.LINE)
		b.polygon(Face.Builder.round_rect(-box * 0.5, box, HEIGHT * 0.5), Pal.SURFACE)
		_shown = b.mesh()
	_last = left
	var k := 1.0
	if not Motion.reduce and now - _bump_at < Motion.BUMP_TIME:
		k = Motion.bump_scale(now - _bump_at)
	layer.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	layer.draw_mesh(_shown, null)
	var rise := (font.get_ascent(FONT) - font.get_descent(FONT)) * 0.5
	layer.draw_string(font, Vector2(-tw * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT,
		Pal.BAD if left <= LOW else Pal.TEXT)
	layer.draw_set_transform(Vector2.ZERO)
