extends SceneTree
## Throwaway (the made-fun pass, 2026-10-28): how far a player reading what
## each sign can still reach gets on a new field (puzzles/shikaku_reader.gd),
## that every bed it lays is the answer's, and how many signs have one way
## from the start.
##   godot --headless --path . --script tests/_probe_sk_fun.gd -- [days] [bands]
const State = preload("res://puzzles/shikaku_state.gd")
const Reader = preload("res://puzzles/shikaku_reader.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 40
	var bands := String(args[1]) if args.size() > 1 else "0123"
	for bc in bands:
		var band := int(bc)
		var share := 0.0
		var full := 0
		var wrong := 0
		var first := 0.0
		var worst := 1.0
		var rules := [0, 0, 0, 0]
		for s in days:
			var rng := RandomNumberGenerator.new()
			rng.seed = 20261028 + s * 7919 + band
			var st = State.new()
			st.setup(rng, band, s)
			var r = Reader.new(st.w, st.h, st.clues)
			var one := 0
			for i in st.clues.size():
				if r.cands[i].size() == 1:
					one += 1
			first += one
			var n := 0
			while true:
				var got: Dictionary = r.next()
				if got.is_empty():
					break
				if not st.solution.has(got.rect):
					wrong += 1
				rules[int(got.rule)] += 1
				r._place(int(got.clue), got.rect)
				r._prune()
				n += 1
			var f := n / float(st.clues.size())
			share += f
			worst = minf(worst, f)
			if n == st.clues.size():
				full += 1
		print("band %d: read %.0f%% of beds on average, worst %.0f%%, whole field %d/%d, one way at the start %.1f, wrong beds %d, rules one/only/crowd %s" % [band, 100.0 * share / days, 100.0 * worst, full, days, first / days, wrong, str(rules.slice(1))])
	quit()
