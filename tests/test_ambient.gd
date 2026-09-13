extends RefCounted

## The world's continuous motion and its one switch (polish spec, section 4):
## the Ambient node the stage creates, its pollen, the splash clock on the
## water material, and the motion_scale value reduce-motion drives to zero.
## Needs a live tree (the stage builds in _ready), so this runs from run_in_tree.

const Stage = preload("res://world/stage.gd")
const Ambient = preload("res://world/ambient.gd")
const Motion = preload("res://core/motion.gd")
const Toon = preload("res://core/toon.gd")

static func run_in_tree(t) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	Motion.reduce = false
	var stage: Node3D = Stage.new()
	root.add_child(stage)
	_test_stage_owns_ambient(t, stage)
	_test_pollen(t, stage.ambient)
	_test_refresh(t, stage.ambient)
	_test_splash(t, stage.ambient)
	_test_fit_to(t, stage.ambient)
	_test_camera_breath(t, stage)
	Motion.reduce = false
	root.remove_child(stage)
	stage.free()

static func _test_stage_owns_ambient(t, stage) -> void:
	t.check(stage.ambient != null and stage.ambient.get_parent() == stage, "stage creates an Ambient child")
	t.check(stage.get_node_or_null("Ambient") == stage.ambient, "the Ambient node is named Ambient")
	t.check(is_equal_approx(Ambient.motion_scale(), 1.0), "motion_scale is 1 when the world moves")

static func _test_pollen(t, ambient) -> void:
	var p: CPUParticles3D = ambient.pollen
	t.check(p != null and p.get_parent() == ambient, "ambient owns a pollen emitter")
	t.eq(p.amount, Ambient.POLLEN_AMOUNT, "two dozen specks")
	t.check(is_equal_approx(p.lifetime, Ambient.POLLEN_LIFETIME) and is_equal_approx(p.preprocess, Ambient.POLLEN_LIFETIME), "six-second lives, pre-rolled so the air is full on frame one")
	t.check(p.emitting and p.visible, "pollen drifts by default")
	t.check(p.emission_shape == CPUParticles3D.EMISSION_SHAPE_BOX, "pollen spawns in a box")
	t.check(p.gravity.is_zero_approx(), "pollen has no gravity; it sinks by its direction")
	t.check(p.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "specks cast no shadow")

static func _test_refresh(t, ambient) -> void:
	Motion.reduce = true
	ambient.refresh()
	t.check(is_zero_approx(Ambient.motion_scale()), "motion_scale is 0 under reduce-motion")
	t.check(not ambient.pollen.emitting and not ambient.pollen.visible, "reduce-motion stops and hides the pollen")
	Motion.reduce = false
	ambient.refresh()
	t.check(ambient.pollen.emitting and ambient.pollen.visible, "clearing reduce-motion restarts the pollen")

static func _test_splash(t, ambient) -> void:
	var water: ShaderMaterial = Toon.water()
	t.check(ambient.splash_age() < 0.0, "no splash at rest")
	ambient.splash(Vector3(1.0, -4.0, 2.0))
	t.check(is_zero_approx(ambient.splash_age()), "splash starts its clock at zero")
	t.check(Vector3(water.get_shader_parameter("splash_origin")).is_equal_approx(Vector3(1.0, -4.0, 2.0)), "splash origin reaches the water material")
	ambient._process(0.5)
	t.check(is_equal_approx(ambient.splash_age(), 0.5), "the clock advances with process time")
	t.check(is_equal_approx(float(water.get_shader_parameter("splash_age")), 0.5), "the water material sees the age")
	ambient._process(Ambient.SPLASH_TIME)
	t.check(ambient.splash_age() < 0.0, "the splash ends after SPLASH_TIME")
	t.check(float(water.get_shader_parameter("splash_age")) < 0.0, "the water material sees the end")
	Motion.reduce = true
	ambient.splash(Vector3.ZERO)
	t.check(ambient.splash_age() < 0.0, "reduce-motion skips the splash")
	Motion.reduce = false

static func _test_fit_to(t, ambient) -> void:
	ambient.fit_to(AABB(Vector3(-3.0, -0.6, -3.0), Vector3(6.0, 1.1, 6.0)))
	var p: CPUParticles3D = ambient.pollen
	t.check(p.position.is_equal_approx(Vector3(0.0, 1.5, 0.0)), "pollen floats one cell above the board's top (%s)" % p.position)
	t.check(p.emission_box_extents.is_equal_approx(Vector3(4.0, 0.2, 4.0)), "pollen volume is the board plus a one-cell margin, 0.4 tall (%s)" % p.emission_box_extents)

## Camera breath (polish spec, section 4): a slow, tiny drift of camera and
## target together, a fraction of the fitted distance, off under reduce-motion.
static func _test_camera_breath(t, stage) -> void:
	var rig = stage.rig
	var cam: Camera3D = rig.camera
	rig._distance = 10.0
	rig._target = Vector3.ZERO
	rig._place()
	var still := cam.global_position
	rig._process(2.0)
	var moved := cam.global_position
	var shift := (moved - still).length()
	t.check(shift > 0.001, "the camera has drifted after two seconds (%.4f)" % shift)
	t.check(shift <= 10.0 * rig.BREATH * 1.7, "the drift is a fraction of the distance (%.4f)" % shift)
	t.check(rig.breath_offset().length() > 0.0, "breath_offset reports the drift")
	# The target moves with the camera, so the view direction is unchanged.
	var dir_still: Vector3 = rig.view_offset_dir()
	var dir_now: Vector3 = (cam.global_position - (rig._target + rig.breath_offset())).normalized()
	t.check(dir_now.is_equal_approx(dir_still), "camera and target drift together; the view direction holds")
	Motion.reduce = true
	rig._process(0.1)
	t.check(rig.breath_offset().is_zero_approx(), "reduce-motion zeroes the breath")
	t.check(cam.global_position.is_equal_approx(still), "reduce-motion puts the camera back on its fitted spot")
	Motion.reduce = false
	rig.breathing = false
	rig._process(1.0)
	t.check(rig.breath_offset().is_zero_approx(), "breathing=false also stills the camera")
	rig.breathing = true
