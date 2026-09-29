extends RefCounted

## A board's result seal: a scalloped disc with a pressed ring, gold with
## three stars, or on Insane night blue with a crescent. Binairo's Flawless
## stamp drew it first (2026-09-29); Code Break's stamp is the same seal with
## its own words. One mesh about the centre, and the words drawn over it.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The seal as one mesh, about its centre: a scalloped disc, a pressed ring
## inside it, and on Insane a crescent over the words.
static func mesh(rad: float, insane: bool) -> ArrayMesh:
	var b := Face.Builder.new()
	var body: Color = Pal.MOON_DEEP if insane else Pal.SUN
	var deep: Color = Pal.MOON_DEEP.darkened(0.25) if insane else Pal.SUN_DEEP
	var pts := PackedVector2Array()
	const BUMPS := 18
	const STEPS := 144
	for i in STEPS:
		var a := TAU * i / STEPS
		pts.append(Vector2.from_angle(a) * rad * (0.93 + 0.07 * cos(a * BUMPS)))
	b.polygon(pts, deep)
	for i in pts.size():
		pts[i] = pts[i] * 0.94
	b.polygon(pts, body)
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, rad * 0.74, 0.0, TAU), maxf(2.0, rad * 0.04), Color(Pal.SURFACE, 0.7), true)
	if insane:
		# A crescent above the words, open to the upper right like the board's moons.
		# The bite is a disc of the seal's own colour: the seal is flat there.
		var c := Vector2(0.0, -rad * 0.44)
		var cr := rad * 0.2
		b.disc(c, cr, Pal.SUN_RAY)
		b.disc(c + Vector2(cr * 0.5, -cr * 0.45), cr * 0.8, body)
	else:
		for sx in [-1.0, 1.0]:
			b.polygon(star(Vector2(sx * rad * 0.28, -rad * 0.4), rad * 0.1), Pal.SURFACE)
		b.polygon(star(Vector2(0.0, -rad * 0.46), rad * 0.13), Pal.SURFACE)
	return b.mesh()

## A five-point star's outline about `at`.
static func star(at: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * (r if i % 2 == 0 else r * 0.45))
	return pts

## The seal's words, each [text, size as a fraction of rad, drop below the
## centre as a fraction of rad], fitted across it, drawn onto `item` whose
## origin is the seal's top left corner (a 2 rad square).
static func text(item: CanvasItem, rad: float, lines: Array) -> void:
	var font: Font = CozyTheme.display(700)
	var centre := Vector2.ONE * rad
	for line in lines:
		var words: String = line[0]
		var fs := int(rad * float(line[1]))
		var w := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w > rad * 1.5:
			fs = int(fs * rad * 1.5 / w)
			w = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := centre + Vector2(-w * 0.5, rad * float(line[2]) + font.get_ascent(fs) * 0.35)
		item.draw_string(font, base + Vector2(0.0, 2.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.OUTLINE, 0.25))
		item.draw_string(font, base, words, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.SURFACE)

static func tr_static(key: String) -> String:
	return TranslationServer.translate(key)
