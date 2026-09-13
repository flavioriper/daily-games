extends RefCounted

## One-shot particle pools a board fires at a point (polish spec, section 3):
## puffs and sparkles are picked round-robin, land where asked, take the
## colour given, and do nothing under reduce-motion. cue() is the audio hook.
## CPUParticles3D want a tree, so this runs from run_in_tree.

const Fx = preload("res://world/fx.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

static func run_in_tree(t) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	Motion.reduce = false
	var fx: Node3D = Fx.new()
	root.add_child(fx)
	_test_pools(t, fx)
	_test_puff(t, fx)
	_test_sparkle(t, fx)
	_test_cue(t, fx)
	_test_reduce(t, fx)
	_test_star(t)
	Motion.reduce = false
	root.remove_child(fx)
	fx.free()

static func _test_pools(t, fx) -> void:
	t.eq(String(fx.name), "Fx", "the node names itself Fx")
	t.eq(fx.puffs.size(), Fx.PUFF_POOL, "four puff emitters")
	t.eq(fx.sparkles.size(), Fx.SPARKLE_POOL, "two sparkle emitters")
	var idle := true
	for p in fx.puffs + fx.sparkles:
		if p.emitting or not p.one_shot or p.get_parent() != fx:
			idle = false
	t.check(idle, "every emitter is a one-shot child, idle at start")
	t.check(fx.puffs[0].amount == 8 and is_equal_approx(fx.puffs[0].lifetime, 0.4), "a puff is 8 specks over 0.4 s")
	t.check(fx.sparkles[0].amount == 10 and is_equal_approx(fx.sparkles[0].lifetime, 0.6), "a sparkle is 10 stars over 0.6 s")
	t.check(fx.puffs[0].gravity.y < 0.0 and fx.sparkles[0].gravity.is_zero_approx(), "puffs arc down, sparkles float")

static func _test_puff(t, fx) -> void:
	fx.puff(Vector3(1.0, 0.12, 2.0))
	var first: CPUParticles3D = fx.puffs[0]
	t.check(first.emitting, "the first puff fires the first emitter")
	t.check(first.position.is_equal_approx(Vector3(1.0, 0.12, 2.0)), "the emitter moves to the point")
	t.check(first.color.is_equal_approx(Pal.STONE), "puffs default to stone dust")
	fx.puff(Vector3(2.0, 0.12, 2.0), Pal.SUN)
	t.check(fx.puffs[1].emitting and fx.puffs[1].color.is_equal_approx(Pal.SUN), "the second puff takes the next emitter and its colour")
	fx.puff(Vector3.ZERO)
	fx.puff(Vector3.ZERO)
	fx.puff(Vector3(5.0, 0.0, 5.0))
	t.check(first.position.is_equal_approx(Vector3(5.0, 0.0, 5.0)), "the fifth puff wraps round to the first emitter")

static func _test_sparkle(t, fx) -> void:
	fx.sparkle(Vector3(0.5, 0.2, 0.5))
	t.check(fx.sparkles[0].emitting and fx.sparkles[0].position.is_equal_approx(Vector3(0.5, 0.2, 0.5)), "sparkle fires at the point")
	t.check(fx.sparkles[0].color.is_equal_approx(Pal.SUN), "sparkles default to sun gold")
	fx.sparkle(Vector3.ZERO)
	fx.sparkle(Vector3(3.0, 0.0, 3.0))
	t.check(fx.sparkles[0].position.is_equal_approx(Vector3(3.0, 0.0, 3.0)), "the third sparkle wraps round")

static func _test_cue(t, fx) -> void:
	fx.cue("roll")
	t.eq(fx.last_cue, "roll", "cue records the last name for the audio layer to come")

static func _test_reduce(t, fx) -> void:
	Motion.reduce = true
	for p in fx.puffs + fx.sparkles:
		p.emitting = false
		p.position = Vector3.ZERO
	fx.puff(Vector3(9.0, 9.0, 9.0))
	fx.sparkle(Vector3(9.0, 9.0, 9.0))
	var quiet := true
	for p in fx.puffs + fx.sparkles:
		if p.emitting or not p.position.is_zero_approx():
			quiet = false
	t.check(quiet, "reduce-motion fires nothing")
	Motion.reduce = false

static func _test_star(t) -> void:
	var tex: ImageTexture = Fx.star_texture()
	t.check(tex != null and tex.get_width() == 32 and tex.get_height() == 32, "the star is a 32 x 32 texture")
	var img := tex.get_image()
	t.check(img.get_pixel(16, 16).a > 0.9, "the star is solid at its centre")
	t.check(img.get_pixel(2, 2).a < 0.1, "the star is clear at its corners")
	t.check(img.get_pixel(16, 8).a > 0.9, "the star reaches up along its axis")
	t.check(Fx.star_texture() == tex, "the star texture is built once")
