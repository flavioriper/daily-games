extends RefCounted

## The side column beside the table: where the tip meets the cue ball, drawn
## rather than built from widgets so it looks like the table's own
## furniture -- a big cue ball to touch for spin. The pace is not here: the
## cue is drawn back on the table itself (versus/snooker_table.gd).

const Sim = preload("res://versus/snooker_sim.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")

## A cue ball the size of a thumb: touch it where the tip should strike.
## Top follows through, bottom screws back, the sides turn the ball off a
## cushion. The dot never leaves the miscue limit.
class SpinPad extends Control:
	signal changed
	## A finger came down on the pad (once a touch, where `changed` is every move of it).
	signal pressed

	var tip := Vector2.ZERO
	var enabled := true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(150, 150)

	func set_tip(t: Vector2) -> void:
		tip = t
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if not enabled:
			return
		var at := Vector2.INF
		var down := false
		if event is InputEventScreenTouch and event.pressed:
			at = event.position
			down = true
		elif event is InputEventScreenDrag:
			at = event.position
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			at = event.position
			down = true
		elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			at = event.position
		if at == Vector2.INF:
			return
		accept_event()
		var r := _r()
		var t := (at - size * 0.5) / r
		# Screen down is screw: tip.y is positive for top.
		t = Vector2(t.x, -t.y).limit_length(Sim.MAX_TIP)
		# A touch near the middle is a plain ball.
		if t.length() < 0.07:
			t = Vector2.ZERO
		tip = t
		queue_redraw()
		changed.emit()
		if down:
			pressed.emit()

	func _r() -> float:
		return minf(size.x, size.y) * 0.42

	func _disc(at: Vector2, r: float, col: Color) -> void:
		draw_circle(at, r, col)
		draw_arc(at, r, 0.0, TAU, 48, col, 1.5, true)

	func _draw() -> void:
		var c := size * 0.5
		var r := _r()
		var base := Color("f6f0e2")
		draw_circle(c + Vector2(r * 0.12, r * 0.18), r * 1.03, Color(0.24, 0.13, 0.07, 0.18))
		_disc(c, r, base.darkened(0.2))
		_disc(c + Vector2(-0.06, -0.08) * r, r * 0.9, base)
		draw_circle(c + Vector2(-0.4, -0.45) * r, r * 0.16, Color(1, 1, 1, 0.8))
		# The miscue limit and the cross through the middle.
		draw_arc(c, r * Sim.MAX_TIP, 0.0, TAU, 48, Color(Pal.LINE, 0.55), 2.0, true)
		draw_line(c - Vector2(r * 0.25, 0), c + Vector2(r * 0.25, 0), Color(Pal.LINE, 0.5), 2.0, true)
		draw_line(c - Vector2(0, r * 0.25), c + Vector2(0, r * 0.25), Color(Pal.LINE, 0.5), 2.0, true)
		var dot := c + Vector2(tip.x, -tip.y) * r
		_disc(dot, r * 0.15, Color("d6464a").darkened(0.15))
		_disc(dot + Vector2(-1.5, -1.5), r * 0.12, Color("d6464a"))
		if not enabled:
			draw_circle(c, r * 1.04, Color(Pal.PAPER, 0.45))

## A ribbed wheel under the spin pad: a long drag turns the aim a hair, for
## the pot a thumb on the table cannot quite find. A pot goes from 94 of 100
## dead on to 55 at 0.11 degrees off (tests/_probe_sn_margin.gd).
class FineWheel extends Control:
	## The aim turned by this many radians.
	signal nudged(radians: float)
	signal pressed
	## Radians a pixel of drag, and how far the ribs roll for it.
	const TURN := 0.00035
	const RIBS := 13
	var enabled := true
	var _roll := 0.0
	var _shown: ArrayMesh

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(150, 400)
		resized.connect(queue_redraw)

	func _gui_input(event: InputEvent) -> void:
		if not enabled:
			return
		if event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit()
		elif event is InputEventScreenDrag or event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			accept_event()
			_roll += event.relative.y
			queue_redraw()
			nudged.emit(event.relative.y * TURN)

	func _draw() -> void:
		var b := Face.Builder.new()
		var w := 104.0
		var box := Rect2((size.x - w) * 0.5, 0.0, w, size.y)
		b.fan(Face.Builder.round_rect(box.position + Vector2(0, 6), box.size, 30.0), Color("6d4227"))
		b.fan(Face.Builder.round_rect(box.position, box.size, 30.0), Color("e9dcc4") if enabled else Color("cdbfa8"))
		# Ribs on a drum: packed toward the ends, and rolling with the drag.
		var mid := size.y * 0.5
		for k in RIBS:
			var a := wrapf(float(k) / RIBS * PI + _roll * 0.012, 0.0, PI)
			var y := mid - cos(a) * (mid - 30.0)
			var shade := 0.2 + 0.5 * sin(a)
			b.stroke(PackedVector2Array([Vector2(box.position.x + 16.0, y), Vector2(box.end.x - 16.0, y)]), 2.0 + 4.0 * sin(a), Color(0.42, 0.26, 0.16, shade), false, true)
		_shown = b.mesh()
		draw_mesh(_shown, null)
