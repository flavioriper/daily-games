extends RefCounted

## The piece pill: a paper capsule of round buttons with a caption under
## each and a title over them, standing by a piece of a board. Tally's
## paper (arcade/tally_board.gd) and the Factory's land (factory/screen.gd)
## both draw theirs with it (the user, 2026-10-20: the Factory's belts get
## "some helpers ... based on the tally convey"). The owner keeps what the
## pill is for, which buttons it has and what they do; this lays the pill
## out by the piece, draws it and says which button a point is on.

const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")

## Round buttons this wide, their captions under, in a paper capsule OFF
## pixels off the piece, popping in over POP.
const BTN := 84.0
const PAD := 16.0
const GAP := 14.0
const CAP_FS := 20
const TITLE_FS := 24
const OFF := 14.0
const POP := 0.18
const INK := Color("4a3626")
const SUN := Color("f2b53a")
const PAPER := Color("fcf7ef")
const ICON := {"copy": "copy", "dup": "plus", "save": "puzzle", "undo": "undo_back", "turn": "turn", "flip": "flip", "lift": "bin", "sell": "bin", "run": "span", "line": "bends", "info": "help", "place": "check", "cancel": "cross"}

## Button name to the locale key of its caption.
var caps: Dictionary
var _box: StyleBoxFlat
var _cache := {}
## The press rings drawn last, kept until the next draw replaces them.
var _ring: ArrayMesh

func _init(captions: Dictionary) -> void:
	caps = captions
	_box = CozyTheme.lifted(PAPER, 36, 8)

## The capsule and its buttons for `names`, by a piece whose top middle is
## `top` and foot middle `foot` (the owner's pixels): under the piece, over
## it when the piece is in the lower third of `view`, and kept inside it.
static func layout(names: Array, top: Vector2, foot: Vector2, view: Rect2) -> Dictionary:
	var n := names.size()
	var w := PAD * 2.0 + n * BTN + (n - 1) * GAP
	var title_h := TITLE_FS + 10.0
	var h := PAD + title_h + BTN + 6.0 + CAP_FS + PAD * 0.75
	var c := (top + foot) * 0.5
	var low := foot.y > view.position.y + view.size.y * 2.0 / 3.0
	var y := top.y - OFF - h if low else foot.y + OFF
	var r := Rect2(c.x - w * 0.5, y, w, h)
	r.position.x = clampf(r.position.x, view.position.x + 8.0, maxf(view.position.x + 8.0, view.end.x - w - 8.0))
	r.position.y = clampf(r.position.y, view.position.y + 8.0, maxf(view.position.y + 8.0, view.end.y - h - 8.0))
	var btns := {}
	for j in n:
		btns[names[j]] = Rect2(r.position.x + PAD + j * (BTN + GAP), r.position.y + PAD + title_h, BTN, BTN + 6.0 + CAP_FS)
	return {"rect": r, "buttons": btns, "title_at": r.position + Vector2(w * 0.5, PAD + TITLE_FS * 0.8)}

## The button of `lay` under `p`, or "".
static func button_at(lay: Dictionary, p: Vector2) -> String:
	if lay.is_empty():
		return ""
	for nm: String in lay.buttons:
		if (lay.buttons[nm] as Rect2).grow(6.0).has_point(p):
			return nm
	return ""

## The pill of `lay` on `ci`: the capsule popping in since `opened_at`, the
## buttons with their glyphs as one cached mesh (Place in the sun, greyed
## with `dim`), a ring off a button pressed (`pressed_at`: name to when),
## the captions and the title. `clock` is the owner's.
func draw(ci: CanvasItem, lay: Dictionary, names: Array, title: String, font: Font, clock: float, opened_at: float, pressed_at: Dictionary, dim: bool) -> void:
	var r: Rect2 = lay.rect
	var pop := 1.0
	if not Motion.reduce:
		var u := clampf((clock - opened_at) / POP, 0.0, 1.0)
		pop = lerpf(0.86, 1.0, Motion.back_out(u))
	var c := r.get_center()
	ci.draw_set_transform(c - c * pop, 0.0, Vector2(pop, pop))
	ci.draw_style_box(_box, r)
	var key := [names, dim]
	var m: ArrayMesh = _cache.get(key)
	if m == null:
		var b := Face.Builder.new()
		for j in names.size():
			var nm: String = names[j]
			var at := Vector2(PAD + j * (BTN + GAP) + BTN * 0.5, BTN * 0.5)
			var off := nm == "place" and dim
			var fill := Color("f3ead6")
			if nm == "place":
				fill = Color("e4dccb") if off else SUN
			b.disc(at + Vector2(0, 4.0), BTN * 0.5, Color(INK, 0.14))
			b.disc(at, BTN * 0.5, fill)
			glyph_into(b, String(ICON[nm]), Rect2(at - Vector2.ONE * 21.0, Vector2.ONE * 42.0), Color(INK, 0.35 if off else 1.0))
		m = b.mesh()
		_cache[key] = m
	var origin: Vector2 = (lay.buttons[names[0]] as Rect2).position
	ci.draw_mesh(m, null, Transform2D(0.0, origin))
	# a button just pressed sinks and rings
	var live := Face.Builder.new()
	for nm: String in names:
		var u := (clock - float(pressed_at.get(nm, -10.0))) / 0.3
		if u < 0.0 or u >= 1.0 or Motion.reduce:
			continue
		var at: Vector2 = (lay.buttons[nm] as Rect2).position + Vector2(BTN * 0.5, BTN * 0.5)
		live.stroke(Face.Builder.ring(at, BTN * (0.5 + 0.3 * u), BTN * (0.5 + 0.3 * u)), 6.0 * (1.0 - u), Color(SUN, 1.0 - u), true)
	_ring = live.mesh() if not live.verts.is_empty() else null
	if _ring != null:
		ci.draw_mesh(_ring, null)
	for nm: String in names:
		var cap := ci.tr(String(caps[nm]))
		var br: Rect2 = lay.buttons[nm]
		var col := Color(INK, 0.4 if nm == "place" and dim else 0.85)
		ci.draw_string(font, Vector2(br.position.x - 20.0, br.position.y + BTN + 6.0 + CAP_FS * 0.9), cap, HORIZONTAL_ALIGNMENT_CENTER, BTN + 40.0, CAP_FS, col)
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FS).x
	var title_at: Vector2 = lay.title_at
	ci.draw_string(font, Vector2(title_at.x - tw * 0.5, title_at.y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FS, INK)
	ci.draw_set_transform(Vector2.ZERO)

## Icon `name` (ui/icons.gd) filled into `rect` on a mesh builder.
static func glyph_into(b: Face.Builder, name: String, rect: Rect2, c: Color) -> void:
	var s: Dictionary = Icons.shape(name)
	var xf := Transform2D(0.0, rect.size, 0.0, rect.position)
	for poly: PackedVector2Array in s.polys:
		b.polygon(xf * poly, c)
	for line: PackedVector2Array in s.lines:
		b.stroke(xf * line, Icons.STROKE * rect.size.x, c)
