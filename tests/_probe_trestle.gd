extends SceneTree

## Tunes and checks Trestle's physics headless:
##
##     godot --headless --script res://tests/_probe_trestle.gd -- [w] [cart] [dy]
##
## Runs the plain deck (which should fall), the full truss under the road and
## the one over it, and prints whether the cart got over, the worst stress,
## the cost and how long the run took.

const Sim = preload("res://puzzles/trestle_sim.gd")
const Gen = preload("res://puzzles/trestle_gen.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var w := int(args[0]) if args.size() > 0 else 4
	var cart := float(args[1]) if args.size() > 1 else 1.2
	var dy := int(args[2]) if args.size() > 2 else 0
	var level := {"w": w, "dy": dy, "cart": cart,
		"anchors": [[0, 0], [w, dy], [0, -1], [w, dy - 1], [0, -2], [w, dy - 2]]}
	_try("deck", level, Gen.plain_deck(level))
	for dg in 3:
		_try("under1/%d" % dg, level, Gen.full(level, 1, 0, dg))
		_try("under2/%d" % dg, level, Gen.full(level, 2, 0, dg))
		_try("over1/%d" % dg, level, Gen.full(level, 0, 1, dg))
		_try("both/%d" % dg, level, Gen.full(level, 1, 1, dg))
	quit()

func _try(name: String, level: Dictionary, design: Array) -> void:
	var sim := Sim.new()
	sim.setup(level, design)
	var t0 := Time.get_ticks_usec()
	while not sim.done():
		sim.step()
		if not sim.broken.is_empty() and sim.cart == Sim.CART_WATER:
			break
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("%-7s members %3d cost %5d  over %s  broke %2d  worst %.2f  t %.1f  %.0f ms" % [
		name, design.size(), Sim.cost_of(design), sim.crossed(), sim.broken.size(), sim.worst(), sim.t, ms])
