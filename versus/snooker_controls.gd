extends RefCounted

## The side column beside the table: where the tip meets the cue ball, and
## how hard. Both are drawn, not built from widgets, so they look like the
## table's own furniture: a big cue ball to touch for spin, and a wooden
## slot the cue's butt is pulled down through for power.

const Sim = preload("res://versus/snooker_sim.gd")
const Pal = preload("res://core/palette.gd")

## A cue ball the size of a thumb: touch it where the tip should strike.
## Top follows through, bottom screws back, the sides turn the ball off a
## cushion. The dot never leaves the miscue limit.
class SpinPad extends Control:
	signal changed

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
		if event is InputEventScreenTouch and event.pressed:
			at = event.position
		elif event is InputEventScreenDrag:
			at = event.position
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			at = event.position
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

## The power slot: press anywhere on it and pull down, the way a cue is drawn
## back; let go to play, or push back to the top to call it off. The fill
## warms from green to red with the pace, and a hint leaves a gold notch.
class PowerBar extends Control:
	signal pulling
	signal released(power: float)

	var power := 0.0
	var enabled := true
	## A hint's suggested pull, 0 for none.
	var mark := 0.0
	var _from := -1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(150, 300)

	func _gui_input(event: InputEvent) -> void:
		if not enabled:
			return
		var y := NAN
		var press := false
		var release := false
		if event is InputEventScreenTouch:
			if event.index != 0:
				return
			y = event.position.y
			press = event.pressed
			release = not event.pressed
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			y = event.position.y
			press = event.pressed
			release = not event.pressed
		elif event is InputEventScreenDrag and event.index == 0:
			y = event.position.y
		elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			y = event.position.y
		if is_nan(y):
			return
		accept_event()
		if press:
			_from = y
			return
		if _from < 0.0:
			return
		if release:
			var p := power
			_from = -1.0
			power = 0.0
			queue_redraw()
			released.emit(p)
			return
		power = clampf((y - _from) / (_slot().size.y * 0.9), 0.0, 1.0)
		queue_redraw()
		pulling.emit()

	func set_power(p: float) -> void:
		power = p
		queue_redraw()

	func _slot() -> Rect2:
		var w := minf(size.x * 0.5, 64.0)
		return Rect2(Vector2((size.x - w) * 0.5, 8.0), Vector2(w, size.y - 16.0))

	func _draw() -> void:
		var s := _slot()
		var r := s.size.x * 0.5
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(int(r))
		box.bg_color = Color("5e3a22")
		draw_style_box(box, s.grow(10.0))
		box.bg_color = Color("8f5a36")
		draw_style_box(box, s.grow(6.0))
		box.bg_color = Color("2a1a10")
		draw_style_box(box, s)
		if power > 0.0:
			var h := s.size.y * power
			var fill := Rect2(s.position, Vector2(s.size.x, maxf(h, s.size.x)))
			box.bg_color = Color("7cc46b").lerp(Color("f2c233"), clampf(power * 1.6, 0.0, 1.0)).lerp(Color("e0574f"), clampf(power * 2.0 - 1.0, 0.0, 1.0))
			draw_style_box(box, fill.grow(-4.0))
		# Ticks every tenth.
		for i in range(1, 10):
			var y := s.position.y + s.size.y * i / 10.0
			var w := s.size.x * (0.3 if i % 5 else 0.5)
			draw_line(Vector2(s.get_center().x - w * 0.5, y), Vector2(s.get_center().x + w * 0.5, y), Color(1, 1, 1, 0.22), 2.0)
		if mark > 0.0:
			var y := s.position.y + s.size.y * mark
			draw_line(Vector2(s.position.x - 12.0, y), Vector2(s.end.x + 12.0, y), Pal.SUN_RAY, 5.0, true)
		# The cue's butt, riding down the slot with the pull.
		var butt_y := s.position.y + s.size.y * power
		var knob := Rect2(Vector2(s.get_center().x - r * 1.25, butt_y - 18.0), Vector2(r * 2.5, 36.0))
		box.bg_color = Color("4a3024")
		box.set_corner_radius_all(12)
		draw_style_box(box, knob)
		box.bg_color = Color("d2a857")
		draw_style_box(box, Rect2(knob.position + Vector2(0, 12), Vector2(knob.size.x, 8)))
		if not enabled:
			box.bg_color = Color(Pal.PAPER, 0.45)
			box.set_corner_radius_all(int(r))
			draw_style_box(box, s.grow(12.0))
