extends SceneTree

## Sunbeam, measured (2026-10-29 made-fun pass). Per band over `days`
## floors: the shortest way home, and two players who let go one piece a
## move (cap 300 moves): a **fiddler** who slides a random piece to its best
## peg by drops lit (a random peg a third of the time), and a **catcher**
## who only lets go a piece on a peg the light crosses now (the pegs the
## held piece's catch marks show, State.catches), best by drops lit, a
## random catch a third of the time, a random move when no catch exists.
## Also: how often a catch exists at all, and the reading bulb's first step.
##
##     godot --headless --path . --script res://tests/_probe_sb_fun.gd

const State = preload("res://puzzles/sunbeam_state.gd")

func _initialize() -> void:
	for band in 4:
		_band(band)
	quit()

func _score(s) -> int:
	return (1000 if s.is_solved() else 0) + s.lit_drops() * 10 + (3 if s.beam.end == "bud" else 0)

func _band(band: int) -> void:
	var rng := RandomNumberGenerator.new()
	var days := 30
	var short := []
	var res := {"fiddler": [], "catcher": []}
	var fails := {"fiddler": 0, "catcher": 0}
	var catch_seen := 0
	var catch_turns := 0
	var ring_ok := 0
	var ring_n := 0
	for day in days:
		rng.seed = 7300 + day * 17 + band
		var s = State.new()
		s.build(rng, band, day)
		short.append(s.shortest_solve())
		# The reading bulb: walk home by hints, checking each ringed piece.
		s.setup()
		var guard := 0
		while not s.is_solved() and guard < 20:
			guard += 1
			var hp: int = s.hint_piece()
			if hp < 0:
				break
			ring_n += 1
			if (s.catches(hp) as Array).has(s.home(hp)):
				ring_ok += 1
			s.hint()
		for who: String in ["fiddler", "catcher"]:
			var me := RandomNumberGenerator.new()
			me.seed = 5 + day
			s.setup()
			var moves := 0
			while not s.is_solved() and moves < 300:
				var opts: Array = []  # [piece, peg]
				if who == "catcher":
					for p in s.pos.size():
						for q: int in s.catches(p):
							if q != s.pos[p]:
								opts.append([p, q])
					catch_turns += 1
					if not opts.is_empty():
						catch_seen += 1
				if opts.is_empty():
					var p := me.randi_range(0, s.pos.size() - 1)
					for q in (s.g.pieces[p].rail as PackedInt32Array).size():
						if q != s.pos[p] and not s.taken(p, q):
							opts.append([p, q])
					if who == "fiddler" and me.randf() >= 0.33:
						opts = [_best(s, opts)] if not opts.is_empty() else []
				elif me.randf() >= 0.33:
					opts = [_best(s, opts)]
				if opts.is_empty():
					continue
				var pick: Array = opts[me.randi_range(0, opts.size() - 1)]
				var before: PackedInt32Array = s.pos.duplicate()
				if s.place(int(pick[0]), int(pick[1])):
					if s.judge() != "":
						s.take_back(before)
					moves += 1
			if s.is_solved():
				(res[who] as Array).append(moves - int(short.back()))
			else:
				fails[who] += 1
	short.sort()
	print("band %d: the bulb's ringed piece has its home among its catches %d of %d presses" % [band, ring_ok, ring_n])
	var line := "band %d: shortest p50 %d | catch on %d%% of turns" % [band, short[days / 2], 100 * catch_seen / maxi(1, catch_turns)]
	for who: String in ["fiddler", "catcher"]:
		var a: Array = res[who]
		a.sort()
		line += " | %s over p50 %s p90 %s, unsolved %d" % [who,
			a[a.size() / 2] if not a.is_empty() else "-",
			a[a.size() * 9 / 10] if not a.is_empty() else "-", fails[who]]
	print(line)

func _best(s, opts: Array) -> Array:
	var best: Array = opts[0]
	var top := -1
	for o: Array in opts:
		var keep: PackedInt32Array = s.pos.duplicate()
		s.place(int(o[0]), int(o[1]))
		var sc := _score(s)
		s.pos = keep
		s.retrace()
		if sc > top:
			top = sc
			best = o
	return best
