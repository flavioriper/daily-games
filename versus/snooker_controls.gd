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
		box.set_corner_radius_all(int(r + 10.0))
		box.anti_aliasing = true
		# The wooden housing, lit along its top, and a pale groove let into it.
		box.bg_color = Color("5e3a22")
		draw_style_box(box, s.grow(10.0).grow_side(SIDE_BOTTOM, 3.0))
		box.bg_color = Color("9a6440")
		draw_style_box(box, s.grow(10.0))
		box.set_corner_radius_all(int(r))
		box.bg_color = Color("d9c7a6")
		draw_style_box(box, s)
		box.bg_color = Color("efe4cd")
		draw_style_box(box, Rect2(s.position + Vector2(0.0, 5.0), s.size - Vector2(0.0, 5.0)))
		if power > 0.0:
			# The fill warms down the slot: every band keeps the colour of
			# its own depth, so a hard pull reads hot at the bottom.
			var h := maxf(s.size.y * power, s.size.x)
			var bands := 24
			var inner := s.grow(-5.0)
			for k in bands:
				var y0 := inner.position.y + inner.size.y * k / bands
				var y1 := inner.position.y + inner.size.y * (k + 1) / bands
				if y0 >= inner.position.y + h - 5.0:
					break
				y1 = minf(y1, inner.position.y + h - 5.0)
				var u := float(k) / bands
				var col := Color("8fcf7a").lerp(Color("f2c233"), clampf(u * 1.8, 0.0, 1.0)).lerp(Color("e0574f"), clampf(u * 2.0 - 1.0, 0.0, 1.0))
				var band := Rect2(Vector2(inner.position.x, y0), Vector2(inner.size.x, y1 - y0 + 0.5))
				box.bg_color = col
				box.set_corner_radius_all(0)
				if k == 0:
					box.corner_radius_top_left = int(inner.size.x * 0.5)
					box.corner_radius_top_right = int(inner.size.x * 0.5)
				draw_style_box(box, band)
			box.set_corner_radius_all(int(r))
		# Ticks every tenth, longer at the half.
		for i in range(1, 10):
			var y := s.position.y + s.size.y * i / 10.0
			var w := s.size.x * (0.28 if i % 5 else 0.5)
			draw_line(Vector2(s.get_center().x - w * 0.5, y), Vector2(s.get_center().x + w * 0.5, y), Color(0.37, 0.23, 0.13, 0.28), 2.0, true)
		if mark > 0.0:
			var y := s.position.y + s.size.y * mark
			draw_line(Vector2(s.position.x - 14.0, y), Vector2(s.end.x + 14.0, y), Pal.SUN_RAY, 6.0, true)
			draw_circle(Vector2(s.end.x + 14.0, y), 6.0, Pal.SUN_RAY)
		# The cue's butt, riding down the slot with the pull: ebony with a
		# brass ring and a rubber cap, and its shadow on the groove.
		var butt_y := s.position.y + maxf(s.size.y * power, 18.0)
		var knob := Rect2(Vector2(s.get_center().x - r * 1.2, butt_y - 20.0), Vector2(r * 2.4, 40.0))
		box.set_corner_radius_all(14)
		box.bg_color = Color(0.2, 0.1, 0.05, 0.25)
		draw_style_box(box, knob.grow(2.0).grow_side(SIDE_BOTTOM, 5.0))
		box.bg_color = Color("4a3024")
		draw_style_box(box, knob)
		box.bg_color = Color("6a4636")
		draw_style_box(box, Rect2(knob.position + Vector2(4.0, 3.0), Vector2(knob.size.x - 8.0, 10.0)))
		box.set_corner_radius_all(3)
		box.bg_color = Color("d2a857")
		draw_style_box(box, Rect2(knob.position + Vector2(0, 16), Vector2(knob.size.x, 8)))
		if not enabled:
			box.bg_color = Color(Pal.PAPER, 0.45)
			box.set_corner_radius_all(int(r))
			draw_style_box(box, s.grow(12.0))
