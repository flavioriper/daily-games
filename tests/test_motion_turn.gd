extends RefCounted

## The vocabulary's quarter turn.

const Motion = preload("res://core/motion.gd")

static func run(t) -> void:
	_test_turn_angle_reads_as_a_curve(t)

static func _test_turn_angle_reads_as_a_curve(t) -> void:
	var was: bool = Motion.reduce
	Motion.reduce = false
	t.eq(Motion.turn_angle(0.0, 1), 0.0, "a turn starts where the piece stood")
	t.eq(Motion.turn_angle(10.0, 1), PI * 0.5, "and lands on the quarter it was given")
	t.eq(Motion.turn_angle(10.0, 3), PI * 1.5, "three quarters is three quarters")
	t.eq(Motion.turn_angle(-1.0, 1), 0.0, "before the tap it has not moved")
	# back_out overshoots, which is the whole point of a pinwheel: it must
	# pass the quarter before it settles on it.
	var most := 0.0
	for i in 40:
		most = maxf(most, Motion.turn_angle(float(i) * 0.01, 1))
	t.check(most > PI * 0.5, "the swing overshoots before it settles")
	Motion.reduce = true
	t.eq(Motion.turn_angle(0.0, 1), PI * 0.5, "reduce motion lands it at once")
	Motion.reduce = was
