extends SceneTree
const Sim = preload("res://versus/snooker_sim.gd")
func _initialize() -> void:
	var s = Sim.new()
	# break: aim at right edge of the pack
	var t0 := Time.get_ticks_msec()
	var target: Vector2 = s.pos[11] + Vector2(Sim.R * 1.8, 0)
	s.strike((target - s.pos[0]).normalized(), 5.5, Vector2(0.3, 0.0))
	var steps := 0
	while s.moving() and steps < 20000:
		s.step(Sim.DT); steps += 1
	print("break: steps=", steps, " simt=", steps * Sim.DT, " ms=", Time.get_ticks_msec() - t0, " first=", s.first_hit, " potted=", s.potted)
	# straight pot of the blue into the left middle pocket
	var b = Sim.new()
	for i in range(1, 22): b.on[i] = false
	b.on[19] = true
	b.pos[19] = Vector2(0.4, Sim.L * 0.5)
	b.pos[0] = Vector2(0.9, Sim.L * 0.5)
	b.strike(Vector2(-1, 0), 1.5, Vector2(0, -0.5))
	t0 = Time.get_ticks_msec()
	b.settle()
	print("blue pot: potted=", b.potted, " cue at ", b.pos[0], " (draw back expected x>0.9) ms=", Time.get_ticks_msec() - t0)
	# stun: centre ball, cue should stop near contact
	var c = Sim.new()
	for i in range(1, 22): c.on[i] = false
	c.on[19] = true
	c.pos[19] = Vector2(0.9, 1.5); c.pos[0] = Vector2(0.9, 1.9)
	c.strike(Vector2(0, -1), 1.0, Vector2(0, 0.4))
	c.settle()
	print("follow: cue y=", c.pos[0].y, " blue y=", c.pos[19].y, " blue on=", c.on[19])
	# lag: how far does a 1.2 m/s rolling ball go
	var d = Sim.new()
	for i in range(1, 22): d.on[i] = false
	d.pos[0] = Vector2(0.9, 3.4)
	d.strike(Vector2(0, -1), 1.2, Vector2(0, 0.4))
	var tt := 0.0
	while d.moving(): d.step(Sim.DT); tt += Sim.DT
	print("lag: stopped at y=", d.pos[0].y, " after ", tt, "s")
	quit()
