extends SceneTree

## Throwaway: finds the angles Marigold's tutorial gardens play. A garden is
## staggered rows (the board's own field) with some buds made marigolds,
## clovers or a pair; `then=<a>,<b>` plays those shots first (each picked as
## the board picks them); it scans the fan and prints runs of angles that give
## the same shot (what blooms, a split, a pot catch), widest first.
##
##   godot --headless --script res://tests/_mg_tut_search.gd -- <garden> [then=a,b] [pot=x]

const State = preload("res://puzzles/marigold_state.gd")
const Diagram = preload("res://ui/hud/marigold_tutorial_diagram.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var want: String = args[0]
	var then: Array = []
	var pots := [50.0]
	var need: Array = []
	var avoid: Array = []
	var band := 0
	for a in args:
		if a.begins_with("then="):
			for x in a.substr(5).split(","):
				then.append(float(x))
		elif a.begins_with("pot="):
			pots = [float(a.substr(4))]
		elif a.begins_with("need="):
			need = Array(a.substr(5).split(","))
		elif a.begins_with("avoid="):
			avoid = Array(a.substr(6).split(","))
		elif a.begins_with("band="):
			band = int(a.substr(5))
		elif a == "pots":
			pots = []
			for k in 36:
				pots.append(12.0 + k * 2.2)
	var s = State.new()
	Diagram.Garden.lay_state(s, want, band)
	for a: float in then:
		var r := _shot(s, a, float(pots[0]), true)
		print("then %.4f: %s" % [a, r])
	if args.has("only"):
		quit()
		return
	var rows: Array = []
	for px: float in pots:
		var last := ""
		var from := 0.0
		var n := 0
		var a := State.AIM_MIN + 0.02
		while a < PI - State.AIM_MIN - 0.02:
			var r := _shot(s, a, px, false)
			if r != last:
				if last != "":
					rows.append([n, from, a - 0.002, last, px])
				last = r
				from = a
				n = 0
			n += 1
			a += 0.002
		rows.append([n, from, a, last, px])
	rows = rows.filter(func(row) -> bool:
		var toks: Array = String(row[3]).split(" ")
		for t in need:
			if t == "O":
				if not String(row[3]).contains("O"):
					return false
			elif not toks.has(t):
				return false
		for t in avoid:
			if t == "O" and String(row[3]).contains("O"):
				return false
			if toks.has(t):
				return false
		return true)
	rows.sort_custom(func(x, y): return x[0] > y[0] or (x[0] == y[0] and String(x[3]).length() > String(y[3]).length()))
	for row in rows.slice(0, 50):
		print("%3d  %.4f..%.4f  mid %.4f  pot %.0f  %s" % [row[0], row[1], row[2], (row[1] + row[2]) * 0.5, row[4], row[3]])
	quit()

## What the shot at `a` does: the buds it blooms (index:kind), a split, a
## pot. `keep` plays it on the garden itself and ends the shot as the board
## does.
func _shot(s, a: float, pot_x: float, keep: bool) -> String:
	var c = s
	if not keep:
		c = s.clone()
		c.kind = s.kind.duplicate()
	c.pot_x = pot_x
	c.pot_dir = 1.0
	c.seeds = maxi(c.seeds, 3)
	c.fire(a)
	var out := []
	var order := PackedInt32Array()
	for k in int(State.SHOT_CAP / State.DT):
		for e: Dictionary in c.step([]):
			match String(e.t):
				"hit":
					order.append(int(e.i))
					out.append("%d%s" % [int(e.i), ["b", "O", "g", "p"][c.kind[int(e.i)]]])
				"pot":
					out.append("POT")
				"split":
					out.append("SPLIT")
				"fever":
					out.append("FEVER")
		if c.balls.is_empty():
			break
	if keep:
		var r: Dictionary = c.end_shot(order)
		out.append("folded %s" % [r.folded])
	return " ".join(out)
