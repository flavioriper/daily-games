extends RefCounted

## Super Slider's drawings: the walnut tray with its gate, and the painted
## wooden blocks -- the big red one with a face, blue bars with a carved slot,
## yellow squares with a carved cross and boss -- after the handheld's own
## pieces. Builder shapes, not Controls: the board (puzzles/slider2d.gd)
## bakes the tray into one mesh and every block into another, and the menu
## card (ui/menu/card_art.gd) draws the same tray and blocks, so the two
## cannot drift apart.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Gen = preload("res://puzzles/slider_gen.gd")

## A block's gap to its cell's edge, its corner, the depth of its shaded lip
## and the width of a carving, all in cells.
const GAP := 0.045
const RADIUS := 0.16
const LIP := 0.07
const CARVE := 0.035
## The frame's thickness and corner, in cells.
const FRAME := 0.2
const FRAME_R := 0.3

## The tray at `o` (the floor's top-left), `cell` a side: its shadow, the
## frame with a gap in the bottom edge under the gate's two columns, the
## floor, its pressed grid and the gate's mat with its carved arrow.
static func tray(b: Face.Builder, o: Vector2, cell: float, cols := Gen.COLS, rows := Gen.ROWS) -> void:
	var g := Vector2(cols, rows) * cell
	var f := FRAME * cell
	var out := o - Vector2.ONE * f
	var out_size := g + Vector2.ONE * f * 2.0
	b.fan(Face.Builder.round_rect(out + Vector2(0.0, cell * 0.1), out_size, FRAME_R * cell), Color(Pal.TEXT, 0.14))
	b.fan(Face.Builder.round_rect(out + Vector2(0.0, cell * 0.05), out_size, FRAME_R * cell), Pal.SLIDE_FRAME_DEEP)
	b.fan(Face.Builder.round_rect(out, out_size, FRAME_R * cell), Pal.SLIDE_FRAME)
	b.fan(Face.Builder.round_rect(out + Vector2(FRAME_R * cell, f * 0.22), Vector2(out_size.x - FRAME_R * cell * 2.0, f * 0.22), f * 0.11),
		Pal.SLIDE_FRAME_HI)
	# the frame's grain: long faint wavy lines down every side, a knot or two
	var grain := Color(Pal.SLIDE_FRAME_DEEP, 0.3)
	for k in 3:
		var d := f * (0.3 + 0.2 * float(k))
		var y := out.y + d + f * 0.12
		_grain(b, Vector2(out.x + FRAME_R * cell, y), Vector2(out.x + out_size.x * (0.55 + 0.14 * float(k)), y), cell * 0.012, grain, k)
		var y2 := out.y + out_size.y - d
		_grain(b, Vector2(out.x + out_size.x * (0.08 + 0.1 * float(k)), y2), Vector2(out.x + out_size.x * (0.3 + 0.06 * float(k)), y2), cell * 0.012, grain, k + 3)
		var x := out.x + d
		_grain(b, Vector2(x, out.y + out_size.y * (0.12 + 0.2 * float(k))), Vector2(x, out.y + out_size.y * (0.55 + 0.14 * float(k))), cell * 0.012, grain, k + 6)
		var x2 := out.x + out_size.x - d
		_grain(b, Vector2(x2, out.y + out_size.y * (0.3 + 0.1 * float(k))), Vector2(x2, out.y + out_size.y * (0.85 - 0.05 * float(k))), cell * 0.012, grain, k + 9)
	b.ellipse(Vector2(out.x + f * 0.5, out.y + out_size.y * 0.36), f * 0.16, f * 0.3, Color(Pal.SLIDE_FRAME_DEEP, 0.3))
	b.ellipse(Vector2(out.x + out_size.x - f * 0.5, out.y + out_size.y * 0.7), f * 0.14, f * 0.26, Color(Pal.SLIDE_FRAME_DEEP, 0.3))
	b.fan(Face.Builder.round_rect(o - Vector2.ONE * cell * 0.02, g + Vector2.ONE * cell * 0.04, cell * 0.1), Pal.SLIDE_FRAME_DEEP)
	b.fan(Face.Builder.round_rect(o, g, cell * 0.08), Pal.SLIDE_FLOOR)
	# the floor's inner shade along its top and left, where the frame stands over it
	b.fan(Face.Builder.round_rect(o, Vector2(g.x, cell * 0.06), cell * 0.03), Color(Pal.SLIDE_FRAME_DEEP, 0.18))
	for x in range(1, cols):
		b.stroke(PackedVector2Array([o + Vector2(x * cell, cell * 0.12), o + Vector2(x * cell, g.y - cell * 0.12)]), cell * 0.012, Pal.SLIDE_GROOVE)
	for y in range(1, rows):
		b.stroke(PackedVector2Array([o + Vector2(cell * 0.12, y * cell), o + Vector2(g.x - cell * 0.12, y * cell)]), cell * 0.012, Pal.SLIDE_GROOVE)
	# a speckle in the floor's wood, very faint
	for i in 26:
		var sp := o + Vector2(_hash(i, 5) * g.x, _hash(i, 9) * g.y)
		b.ellipse(sp, cell * (0.03 + 0.03 * _hash(i, 13)), cell * 0.012, Color(Pal.SLIDE_GROOVE, 0.9))
	mat(b, o, cell, 0.0)
	# brass pegs where the frame's sides are joined
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var peg := out + Vector2(f * 0.5, f * 0.5) + corner * (out_size - Vector2.ONE * f)
		b.disc(peg + Vector2(0.0, f * 0.08), f * 0.24, Pal.SLIDE_FRAME_DEEP)
		b.disc(peg, f * 0.22, Pal.SLIDE_BRASS)
		b.disc(peg + Vector2(-f * 0.06, -f * 0.07), f * 0.08, Pal.SLIDE_BRASS_HI)
	# the gate: the bottom frame cut away under the two middle columns
	var gx := o.x + cell * float(Gen.GOAL % Gen.COLS)
	var gy := o.y + g.y
	b.fan(PackedVector2Array([Vector2(gx, gy - cell * 0.02), Vector2(gx + cell * 2.0, gy - cell * 0.02),
		Vector2(gx + cell * 2.0, gy + f + cell * 0.06), Vector2(gx, gy + f + cell * 0.06)]), Pal.SLIDE_MAT)
	for side: float in [0.0, 2.0]:
		var post := Vector2(gx + cell * side, gy + f * 0.5)
		b.disc(post + Vector2(0.0, cell * 0.03), f * 0.62, Pal.SLIDE_FRAME_DEEP)
		b.disc(post, f * 0.62, Pal.SLIDE_FRAME_HI)
		b.disc(post, f * 0.34, Pal.SLIDE_FRAME)

## A grain line from `a` to `z` that wanders a little, `k` choosing how.
static func _grain(b: Face.Builder, a: Vector2, z: Vector2, width: float, colour: Color, k: int) -> void:
	var pts := PackedVector2Array()
	var along := z - a
	var nrm := Vector2(-along.y, along.x).normalized()
	var amp := width * (1.2 + 1.5 * _hash(k, 21))
	var phase := _hash(k, 29) * TAU
	for i in 13:
		var u := float(i) / 12.0
		pts.append(a + along * u + nrm * amp * sin(phase + u * TAU * (1.0 + _hash(k, 31))))
	b.stroke(pts, width, colour)

static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) ^ (a * b * 1274126177)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0x7fffffff) / float(0x7fffffff)

## An empty cell's hollow: the floor pressed down a little, shaded under the
## top edge where the cell's own rim stands over it. `at` its top-left.
static func hollow(b: Face.Builder, at: Vector2, cell: float) -> void:
	var inset := cell * 0.07
	var sz := Vector2.ONE * (cell - inset * 2.0)
	b.fan(Face.Builder.round_rect(at + Vector2.ONE * inset, sz, cell * 0.12), Color(Pal.SLIDE_GROOVE, 0.28))
	b.fan(Face.Builder.round_rect(at + Vector2.ONE * inset, Vector2(sz.x, cell * 0.05), cell * 0.025), Color(Pal.SLIDE_FRAME_DEEP, 0.08))

## The gate's mat over the goal's four cells, glowing by `glow` (0 to 1) as
## the big block lands on it, with the handheld's carved arrow pointing out.
static func mat(b: Face.Builder, o: Vector2, cell: float, glow: float) -> void:
	var at := o + Vector2(float(Gen.GOAL % Gen.COLS), float(Gen.GOAL / Gen.COLS)) * cell
	var sz := Vector2(2.0, 2.0) * cell
	b.fan(Face.Builder.round_rect(at + Vector2.ONE * cell * 0.08, sz - Vector2.ONE * cell * 0.16, cell * 0.14),
		Color(Pal.SLIDE_MAT, 0.55 + 0.45 * glow))
	if glow > 0.0:
		# the lit mat breathes a soft halo past its own edge
		for k in 3:
			var grow := cell * (0.05 + 0.07 * float(k)) * glow
			b.fan(Face.Builder.round_rect(at + Vector2.ONE * (cell * 0.08 - grow), sz - Vector2.ONE * (cell * 0.16 - grow * 2.0), cell * 0.14 + grow),
				Color(Pal.SLIDE_MAT_HI, 0.16 * glow))
		b.fan(Face.Builder.round_rect(at + Vector2.ONE * cell * 0.16, sz - Vector2.ONE * cell * 0.32, cell * 0.1),
			Color(Pal.SLIDE_MAT_HI, 0.5 * glow))
	var c := at + sz * 0.5
	var ink := Color(Pal.SLIDE_MAT_DEEP, 0.7 + 0.3 * glow)
	var r := cell * 0.42
	var tri := PackedVector2Array([c + Vector2(-r, -r * 0.55), c + Vector2(r, -r * 0.55), c + Vector2(0.0, r * 0.85)])
	b.stroke(tri, cell * 0.05, ink, true)
	b.stroke(PackedVector2Array([c + Vector2(-r * 0.3, -r * 0.05), c + Vector2(-r * 0.02, r * 0.25), c + Vector2(r * 0.34, -r * 0.2)]),
		cell * 0.05, ink)

## The gate's two little doors across the gap, hinged on its posts, open by
## `open` (0 shut, 1 folded back against the frame).
static func doors(b: Face.Builder, o: Vector2, cell: float, open: float) -> void:
	if open >= 0.999:
		return
	var gx := o.x + cell * float(Gen.GOAL % Gen.COLS)
	var gy := o.y + float(Gen.ROWS) * cell + FRAME * cell * 0.5
	var w := cell * (1.0 - open) * 0.94
	for side: float in [1.0, -1.0]:
		var hinge := Vector2(gx if side > 0.0 else gx + cell * 2.0, gy)
		var tip := hinge + Vector2(side * w, 0.0)
		var h := FRAME * cell * 0.8
		if w < cell * 0.02:
			continue
		# a door folding back reads shorter and rides up as it turns on its hinge
		var rise := -h * 0.35 * sin(PI * open)
		var hp := hinge + Vector2(0.0, rise)
		var tp := tip + Vector2(0.0, rise)
		b.fan(PackedVector2Array([hp + Vector2(0.0, -h * 0.5 + cell * 0.03), tp + Vector2(0.0, -h * 0.5 + cell * 0.03),
			tp + Vector2(0.0, h * 0.5 + cell * 0.03), hp + Vector2(0.0, h * 0.5 + cell * 0.03)]), Pal.SLIDE_FRAME_DEEP)
		b.fan(PackedVector2Array([hp + Vector2(0.0, -h * 0.5), tp + Vector2(0.0, -h * 0.5),
			tp + Vector2(0.0, h * 0.5), hp + Vector2(0.0, h * 0.5)]), Pal.SLIDE_FRAME_HI)
		for k in 3:
			var x := hinge.x + side * w * (0.25 + 0.3 * float(k))
			b.stroke(PackedVector2Array([Vector2(x, hp.y - h * 0.4), Vector2(x, hp.y + h * 0.4)]), cell * 0.02, Pal.SLIDE_FRAME)
		# the hinge strap and, at the meeting edge, the latch's brass knob
		b.stroke(PackedVector2Array([hp, hp + Vector2(side * w * 0.4, 0.0)]), h * 0.22, Pal.SLIDE_FRAME_DEEP)
		b.disc(tp + Vector2(-side * cell * 0.07, 0.0), h * 0.2, Pal.SLIDE_BRASS)
		b.disc(tp + Vector2(-side * cell * 0.07 - cell * 0.012, -cell * 0.012), h * 0.08, Pal.SLIDE_BRASS_HI)

## One block, its cells' box at `at` (top-left, pixels) `cells` across and
## down, `cell` a side. `lift` 0 to 1 raises it off the floor (a longer
## shadow and a rise); `squash` is a landing's dip, a fraction of its
## height; `expr` is the big block's face.
##
## `lean` stretches it along its travel and squeezes it across (a fraction a
## side, signed: the leading edge runs ahead), so a quick slide reads as
## speed. The big block's face looks `look` (a fraction of a cell, toward
## what it watches) and opens its eyes by `eye` (0 shut, 1 open).
static func block(b: Face.Builder, at: Vector2, cells: Vector2i, cell: float, kind: int, lift := 0.0,
		squash := 0.0, expr := Face.Expr.HAPPY, lean := Vector2.ZERO, look := Vector2.ZERO, eye := 1.0) -> void:
	var box := Vector2(cells) * cell - Vector2.ONE * GAP * cell * 2.0
	var h := box.y * (1.0 - squash)
	var p := at + Vector2.ONE * GAP * cell + Vector2(0.0, box.y - h)
	var sz := Vector2(box.x * (1.0 + squash * 0.5), h)
	p.x -= box.x * squash * 0.25
	if lean != Vector2.ZERO:
		var st := Vector2(absf(lean.x), absf(lean.y)) * cell
		var across := Vector2(st.y, st.x) * 0.5
		var grown := sz + st - across
		# the trailing edge stays, the leading edge runs ahead
		p += Vector2(minf(lean.x, 0.0), minf(lean.y, 0.0)) * cell + across * 0.5
		sz = grown
	var rad := RADIUS * cell
	var rise := lift * cell * 0.1
	var shade := LIP * cell
	# a soft outer shadow that spreads as it lifts, then the contact shadow
	if lift > 0.01:
		var spread := cell * 0.05 * lift
		b.fan(Face.Builder.round_rect(p + Vector2(lift * cell * 0.06 - spread, shade + rise * 0.9 - spread * 0.5), sz + Vector2.ONE * spread * 2.0, rad + spread),
			Color(Pal.TEXT, 0.06 * lift))
	b.fan(Face.Builder.round_rect(p + Vector2(lift * cell * 0.04, shade + cell * 0.02 + rise * 0.6), sz, rad),
		Color(Pal.TEXT, 0.13 - 0.04 * lift))
	p.y -= rise
	var main: Color
	var hi: Color
	var deep: Color
	match kind:
		Gen.B0:
			main = Pal.SLIDE_BIG
			hi = Pal.SLIDE_BIG_HI
			deep = Pal.SLIDE_BIG_DEEP
		Gen.SQ:
			main = Pal.SLIDE_SQ
			hi = Pal.SLIDE_SQ_HI
			deep = Pal.SLIDE_SQ_DEEP
		_:
			main = Pal.SLIDE_BAR
			hi = Pal.SLIDE_BAR_HI
			deep = Pal.SLIDE_BAR_DEEP
	b.fan(Face.Builder.round_rect(p, sz, rad), deep)
	var top := sz - Vector2(0.0, shade)
	b.fan(Face.Builder.round_rect(p, top, rad), main)
	# the bevel: a lit band inside the top edge, a softer one down the left
	b.fan(Face.Builder.round_rect(p + Vector2(rad * 0.7, cell * 0.045), Vector2(top.x - rad * 1.4, cell * 0.05), cell * 0.025),
		Color(hi, 0.9))
	b.fan(Face.Builder.round_rect(p + Vector2(cell * 0.045, rad * 0.8), Vector2(cell * 0.04, maxf(0.0, top.y - rad * 1.8)), cell * 0.02),
		Color(hi, 0.5))
	# the painted wood's grain along the block's long way, faint, carried with it
	var tall := top.y > top.x
	var n_grain := 2 if cells == Vector2i.ONE else 3
	for k in n_grain:
		var u := (float(k) + 0.6) / (float(n_grain) + 0.2)
		var a: Vector2
		var z: Vector2
		if tall:
			a = p + Vector2(top.x * u, rad * 1.2)
			z = p + Vector2(top.x * u, top.y - rad * 1.2)
		else:
			a = p + Vector2(rad * 1.2, top.y * u)
			z = p + Vector2(top.x - rad * 1.2, top.y * u)
		_grain(b, a, z, cell * 0.01, Color(deep, 0.16), kind * 7 + k + cells.x * 3)
	# a sheen across the top as it is lifted toward the light
	if lift > 0.01:
		b.fan(Face.Builder.round_rect(p + Vector2(rad * 0.5, cell * 0.03), Vector2(top.x - rad, top.y * 0.3), rad * 0.8),
			Color(hi, 0.22 * lift))
	var c := p + top * 0.5
	var w := CARVE * cell
	match kind:
		Gen.SQ:
			var ring := cell * 0.15
			b.disc(c, ring, Color(deep, 0.35))
			b.stroke(Face.Builder.ring(c, ring, ring), w, deep, true)
			b.disc(c + Vector2(-ring * 0.25, -ring * 0.3), ring * 0.3, Color(hi, 0.8))
			var k := cell * 0.13
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var from := c + corner * (top * 0.5 - Vector2.ONE * k)
				var to := c + corner.normalized() * ring * 1.05
				b.stroke(PackedVector2Array([from, to]), w, Color(deep, 0.85))
		Gen.V0, Gen.H0:
			var long := Vector2(0.0, top.y - cell * 0.5) if kind == Gen.V0 else Vector2(top.x - cell * 0.5, 0.0)
			var wide := cell * 0.17
			var slot := Vector2(wide, long.y) if kind == Gen.V0 else Vector2(long.x, wide)
			var r0 := c - slot * 0.5
			b.fan(Face.Builder.round_rect(r0, slot, wide * 0.5), Color(deep, 0.3))
			b.stroke(Face.Builder.round_rect(r0, slot, wide * 0.5), w, deep, true)
			var gl := Vector2(wide * 0.22, cell * 0.1) if kind == Gen.V0 else Vector2(cell * 0.1, wide * 0.22)
			b.stroke(PackedVector2Array([r0 + gl, r0 + gl + (Vector2(0.0, slot.y * 0.35) if kind == Gen.V0 else Vector2(slot.x * 0.35, 0.0))]),
				cell * 0.02, Color(hi, 0.9))
		Gen.B0:
			var ink := deep.darkened(0.45)
			Face.face_parts(b, cell * 0.5, c + Vector2(0.0, -cell * 0.18) + look * cell, ink, eye, expr)
			# the handheld's double chevron, pointing at the gate
			for k in 2:
				var y := c.y + cell * (0.42 + 0.14 * float(k))
				b.stroke(PackedVector2Array([Vector2(c.x - cell * 0.13, y), Vector2(c.x, y + cell * 0.1), Vector2(c.x + cell * 0.13, y)]),
					w * 1.2, Color(deep, 0.9))
