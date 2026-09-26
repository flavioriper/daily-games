extends SceneTree

## The checkers rules and computer, checked:
##
##     godot --headless --path . --script res://tests/_probe_checkers.gd
##
## perft from the opening under AMERICAN rules against the published counts
## for English draughts; hand-built positions for what only BRAZILIAN has
## (flying kings, men taking backwards, the most-pieces rule, the Turkish
## rule, a man passing the far row mid-capture); make/unmake restoring the
## hash; and the computer's timing and depth at each level.

const Rules = preload("res://versus/checkers_rules.gd")
const AI = preload("res://versus/checkers_ai.gd")

var _fails := 0

func _initialize() -> void:
	_perft_american()
	_brazilian()
	_unmake()
	_ai()
	print("FAILS: %d" % _fails)
	quit()

func check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print(("ok   " if ok else "FAIL ") + what)

func perft(g: RefCounted, depth: int) -> int:
	if depth == 0:
		return 1
	var moves: Array = g.legal_moves()
	if depth == 1:
		return moves.size()
	var n := 0
	for m in moves:
		g.make(m)
		n += perft(g, depth - 1)
		g.unmake()
	return n

func _perft_american() -> void:
	var want := [7, 49, 302, 1469, 7361, 36768]
	var g: RefCounted = Rules.new(Rules.Variant.AMERICAN)
	for d in want.size():
		var t := Time.get_ticks_msec()
		var n := perft(g, d + 1)
		check(n == want[d], "american perft %d = %d (want %d, %d ms)" % [d + 1, n, want[d], Time.get_ticks_msec() - t])
	var b: RefCounted = Rules.new()
	var counts := []
	for d in 6:
		counts.append(perft(b, d + 1))
	print("     brazilian perft 1-6: ", counts)

## A board from a list of "sq:piece" (a1 notation, M/K light, m/k dark).
func pos(spec: String, turn := Rules.LIGHT) -> RefCounted:
	var g: RefCounted = Rules.new(Rules.Variant.BRAZILIAN, true)
	for item in spec.split(" ", false):
		var sq := sq_of(item.substr(0, 2))
		var ch := item[3]
		var v := Rules.MAN if ch.to_lower() == "m" else Rules.KING
		g.board[sq] = v if ch == ch.to_upper() else -v
	g.turn = turn
	g.rehash()
	g.hashes = PackedInt64Array([g.hash])
	return g

func sq_of(n: String) -> int:
	return "abcdefgh".find(n[0]) + (int(n[1]) - 1) * 8

func names(moves: Array) -> Array:
	var out := []
	for m: PackedInt32Array in moves:
		var s := "abcdefgh"[m[0] & 7] + str((m[0] >> 3) + 1)
		for t in Rules.mv_path(m):
			s += ("x" if Rules.mv_ncaps(m) > 0 else "-") + "abcdefgh"[t & 7] + str((t >> 3) + 1)
		out.append(s)
	out.sort()
	return out

func _brazilian() -> void:
	# a flying king takes from afar and lands anywhere beyond
	var g := pos("a1:K d4:m")
	check(names(g.legal_moves()) == ["a1xe5", "a1xf6", "a1xg7", "a1xh8"], "flying king capture: %s" % [names(g.legal_moves())])
	# and moves any distance
	g = pos("a1:K h8:m")
	check(g.legal_moves().size() == 6, "flying king quiet moves: %d" % g.legal_moves().size())
	# a man takes backwards
	g = pos("d4:M c3:m")
	check(names(g.legal_moves()) == ["d4xb2"], "man takes backwards: %s" % [names(g.legal_moves())])
	# the most pieces: one way takes one, the other two
	g = pos("c3:M d4:m b4:m b6:m")
	check(names(g.legal_moves()) == ["c3xa5xc7"], "most pieces: %s" % [names(g.legal_moves())])
	# American: no backwards capture, any sequence
	var a: RefCounted = Rules.new(Rules.Variant.AMERICAN, true)
	a.board[sq_of("d4")] = Rules.MAN
	a.board[sq_of("c3")] = -Rules.MAN
	a.turn = Rules.LIGHT
	check(a.legal_moves().size() == 2 and Rules.mv_ncaps(a.legal_moves()[0]) == 0, "american man does not take backwards")
	# Turkish rule: the king cannot jump the same piece twice, and a taken
	# piece still blocks
	g = pos("a1:K c3:m c5:m e5:m e3:m")
	var best := 0
	for m in g.legal_moves():
		best = maxi(best, Rules.mv_ncaps(m))
	check(best <= 4, "turkish rule, most taken %d" % best)
	# a man crossing the far row mid-capture stays a man
	g = pos("b6:M c7:m e7:m")
	var moves: Array = g.legal_moves()
	print("     crossing: ", names(moves))
	for m: PackedInt32Array in moves:
		var d: Dictionary = g.describe(m)
		if d.to >> 3 != 7:
			check(not d.crown, "no crown when the capture ends off the far row")
	# no moves left is a loss
	g = pos("a1:M b2:m c3:m", Rules.LIGHT)
	check(g.status() == Rules.NO_MOVES, "blocked side has lost (status %d)" % g.status())

func _unmake() -> void:
	var g: RefCounted = Rules.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var h0: int = g.hash
	var b0: PackedInt32Array = g.board.duplicate()
	var n := 0
	for i in 60:
		var moves: Array = g.legal_moves()
		if moves.is_empty():
			break
		g.make(moves[rng.randi() % moves.size()])
		n += 1
	var h1: int = g.hash
	g.rehash()
	check(g.hash == h1, "incremental hash matches after %d plies" % n)
	for i in n:
		g.unmake()
	check(g.hash == h0 and g.board == b0, "unmake restores the opening")

func _ai() -> void:
	for level in 3:
		var g: RefCounted = Rules.new()
		var ai: RefCounted = AI.new()
		var t := Time.get_ticks_msec()
		var m: PackedInt32Array = ai.plan(g.copy(), level, 7)
		print("     level %d: %s in %d ms, depth %d, %d nodes, score %d" % [level, names([m]), Time.get_ticks_msec() - t, ai.reached, ai.nodes, ai.score])
	# takes a free piece
	var g := pos("c3:M d4:m h8:k", Rules.LIGHT)
	var ai: RefCounted = AI.new()
	var m: PackedInt32Array = ai.plan(g.copy(), 2, 1)
	check(Rules.mv_ncaps(m) == 1, "the computer takes when it must")
	# a king against a man: wins it
	g = pos("a1:K h8:m", Rules.LIGHT)
	m = ai.plan(g.copy(), 2, 1)
	print("     K vs m: ", names([m]), " score ", ai.score)
