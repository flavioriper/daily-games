extends RefCounted

## The motion library: every recipe returns a tween that lands exactly on its
## final value when stepped to the end, and reduce-motion collapses the
## decorative ones to an instant final state. Node-bound tweens need a live
## tree, so this runs from run_in_tree.

const Motion = preload("res://core/motion.gd")

const THIRD := TAU / 3.0

static func run_in_tree(t) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var node := Node3D.new()
	root.add_child(node)
	Motion.reduce = false
	_test_settle(t, node)
	_test_hop(t, node)
	_test_squash(t, node)
	_test_wobble(t, node)
	_test_fade(t, node)
	_test_stagger(t)
	_test_stop_and_running(t, node)
	_test_reduce(t, node)
	_test_settings(t)
	Motion.reduce = false
	root.remove_child(node)
	node.free()

static func _test_settle(t, node: Node3D) -> void:
	node.rotation.x = 0.0
	var tw: Tween = Motion.settle(node, "rotation:x", -THIRD, 0.34)
	t.check(tw != null and tw.is_running(), "settle returns a running tween")
	tw.custom_step(0.34 * 0.25)
	t.check(node.rotation.x < -0.1 and node.rotation.x > -THIRD, "a quarter in, settle is between start and target (%.3f)" % node.rotation.x)
	tw.custom_step(0.34 * 0.25)
	t.check(node.rotation.x < -THIRD, "halfway, settle has overshot the target (%.3f)" % node.rotation.x)
	tw.custom_step(1.0)
	t.check(is_equal_approx(node.rotation.x, -THIRD), "settle lands exactly on the target (%.4f)" % node.rotation.x)
	t.check(not tw.is_running(), "settle tween finished")
	var d: Tween = Motion.settle(node, "position:y", 1.0, 0.3, 0.2)
	d.custom_step(0.1)
	t.check(is_zero_approx(node.position.y), "a delayed settle has not moved during its delay")
	d.custom_step(1.0)
	t.check(is_equal_approx(node.position.y, 1.0), "delayed settle still lands exactly")
	node.position.y = 0.0

static func _test_hop(t, node: Node3D) -> void:
	node.position.y = 0.5
	var tw: Tween = Motion.hop(node, 0.08, 0.4)
	t.check(tw != null and tw.is_running(), "hop returns a running tween")
	tw.custom_step(0.2)
	t.check(node.position.y > 0.55, "at the top of the hop the node is up (%.3f)" % node.position.y)
	tw.custom_step(0.3)
	t.check(is_equal_approx(node.position.y, 0.5), "hop lands back on its base (%.4f)" % node.position.y)
	var dip: Tween = Motion.hop(node, -0.02, 0.35)
	dip.custom_step(0.175)
	t.check(node.position.y < 0.49, "a negative hop dips (%.3f)" % node.position.y)
	dip.custom_step(1.0)
	t.check(is_equal_approx(node.position.y, 0.5), "dip returns to base")
	# An explicit base wins over the node's current height (a cell mid-bob).
	node.position.y = 0.53
	var based: Tween = Motion.hop(node, 0.1, 0.2, 0.0, 0.5)
	based.custom_step(1.0)
	t.check(is_equal_approx(node.position.y, 0.5), "hop with an explicit base lands on that base (%.3f)" % node.position.y)

static func _test_squash(t, node: Node3D) -> void:
	node.scale = Vector3.ONE
	var tw: Tween = Motion.squash(node)
	t.check(tw != null and tw.is_running(), "squash returns a running tween")
	tw.custom_step(0.18 * 0.4)
	t.check(node.scale.y < 0.95 and node.scale.x > 1.0, "squash flattens y and widens x (%s)" % node.scale)
	tw.custom_step(1.0)
	t.check(node.scale.is_equal_approx(Vector3.ONE), "squash returns to the original scale")

static func _test_wobble(t, node: Node3D) -> void:
	node.rotation.z = 0.2
	var tw: Tween = Motion.wobble(node)
	t.check(tw != null and tw.is_running(), "wobble returns a running tween")
	tw.custom_step(0.45 / 12.0)
	t.check(not is_equal_approx(node.rotation.z, 0.2), "wobble moves the node early on (%.3f)" % node.rotation.z)
	tw.custom_step(1.0)
	t.check(is_equal_approx(node.rotation.z, 0.2), "wobble ends on its starting angle (%.4f)" % node.rotation.z)
	node.rotation.z = 0.0

static func _test_fade(t, node: Node3D) -> void:
	var got: Array = []
	var tw: Tween = Motion.fade(node, func(v: float): got.append(v), 0.0, 0.375, 0.25, 16, 0.1)
	t.check(tw != null and tw.is_running(), "fade returns a running tween")
	tw.custom_step(0.05)
	t.check(got.is_empty(), "fade calls nothing during its delay")
	for i in 60:
		tw.custom_step(0.01)
	t.check(got.size() <= 17, "fade produces at most steps + 1 levels (got %d)" % got.size())
	t.check(got.size() >= 8, "fade produces a ramp, not a jump (got %d levels)" % got.size())
	t.check(is_equal_approx(got[got.size() - 1], 0.375), "fade's last level is exactly `to` (%.4f)" % got[got.size() - 1])
	var on_grid := true
	for v in got:
		if not is_equal_approx(roundf(v / 0.375 * 16.0) / 16.0 * 0.375, v):
			on_grid = false
	t.check(on_grid, "every fade level sits on the 16-step grid")
	var distinct := true
	for i in range(1, got.size()):
		if is_equal_approx(got[i], got[i - 1]):
			distinct = false
	t.check(distinct, "fade never repeats a level")

static func _test_stagger(t) -> void:
	t.check(is_zero_approx(Motion.stagger(0, 0.03)), "first element has no delay")
	t.check(is_equal_approx(Motion.stagger(5, 0.03), 0.15), "delay grows linearly")
	t.check(is_equal_approx(Motion.stagger(100, 0.03), 0.6), "delay is capped")
	t.check(is_equal_approx(Motion.stagger(100, 0.03, 0.2), 0.2), "cap is a parameter")

static func _test_stop_and_running(t, node: Node3D) -> void:
	t.check(not Motion.running(null), "running(null) is false")
	Motion.stop(null)
	var tw: Tween = Motion.hop(node, 0.1, 0.3)
	t.check(Motion.running(tw), "running(tw) is true for a live tween")
	Motion.stop(tw)
	t.check(not Motion.running(tw), "stop kills a live tween")
	node.position.y = 0.5

static func _test_reduce(t, node: Node3D) -> void:
	Motion.reduce = true
	node.rotation.x = 0.0
	var dec: Tween = Motion.settle(node, "rotation:x", -THIRD, 0.34)
	t.check(dec == null, "reduce: decorative settle returns null")
	t.check(is_equal_approx(node.rotation.x, -THIRD), "reduce: decorative settle sets the final state at once")
	node.rotation.x = 0.0
	var ess: Tween = Motion.settle(node, "rotation:x", -THIRD, 0.34, 0.0, true)
	t.check(ess != null and ess.is_running(), "reduce: essential settle still returns a tween")
	ess.custom_step(0.075)
	t.check(is_equal_approx(node.rotation.x, -THIRD * 0.5), "reduce: essential motion is linear over 0.15 s (%.3f)" % node.rotation.x)
	ess.custom_step(0.075)
	t.check(is_equal_approx(node.rotation.x, -THIRD) and not ess.is_running(), "reduce: essential settle is done at 0.15 s")
	node.position.y = 0.5
	t.check(Motion.hop(node, 0.1, 0.3) == null and is_equal_approx(node.position.y, 0.5), "reduce: hop is skipped")
	node.scale = Vector3.ONE
	t.check(Motion.squash(node) == null and node.scale.is_equal_approx(Vector3.ONE), "reduce: squash is skipped")
	t.check(Motion.wobble(node) == null, "reduce: wobble is skipped")
	var got: Array = []
	t.check(Motion.fade(node, func(v: float): got.append(v), 0.0, 1.0, 0.3) == null, "reduce: fade returns null")
	t.eq(got, [1.0], "reduce: fade calls the setter once with `to`")
	Motion.reduce = false

static func _test_settings(t) -> void:
	Motion.settings_path = "user://_test_settings.cfg"
	Motion.reduce = true
	Motion.save_settings()
	Motion.reduce = false
	Motion.load_settings()
	t.check(Motion.reduce, "reduce round-trips through the settings file")
	Motion.reduce = false
	Motion.save_settings()
	Motion.reduce = true
	Motion.load_settings()
	t.check(not Motion.reduce, "a saved false loads as false")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_test_settings.cfg"))
	Motion.settings_path = "user://settings.cfg"
	Motion.reduce = false
	Motion.load_settings()
	Motion.reduce = false
