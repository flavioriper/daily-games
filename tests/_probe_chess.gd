extends SceneTree

## The chess rules against the published perft counts (the number of move
## sequences of each length), which catch any rule a generator gets wrong:
##
##     godot --headless --path . --script res://tests/_probe_chess.gd
##
## Then the computer against itself at every level, a few moves each, timed.

const Rules = preload("res://versus/chess_rules.gd")
const AI = preload("res://versus/chess_ai.gd")

func perft(g: RefCounted, depth: int) -> int:
	if depth == 0:
		return 1
	var n := 0
	var mover: int = g.turn
	for m in g.pseudo():
		g.make(m)
		if not g.attacked(g.kings[mover], g.turn):
			n += perft(g, depth - 1)
		g.unmake()
	return n

func from_fen(fen: String) -> RefCounted:
	var g: RefCounted = Rules.new(true)
	var parts := fen.split(" ")
	var rows := parts[0].split("/")
	var map := {"p": 1, "n": 2, "b": 3, "r": 4, "q": 5, "k": 6}
	for i in 8:
		var r := 7 - i
		var f := 0
		for ch in rows[i]:
			if ch.is_valid_int():
				f += int(ch)
			else:
				var t: int = map[ch.to_lower()]
				g.board[r * 8 + f] = t if ch == ch.to_upper() else -t
				f += 1
	g.turn = Rules.WHITE if parts[1] == "w" else Rules.BLACK
	g.castling = 0
	for ch in parts[2]:
		g.castling |= {"K": 1, "Q": 2, "k": 4, "q": 8}.get(ch, 0)
	g.ep = -1 if parts[3] == "-" else ("abcdefgh".find(parts[3][0]) + (int(parts[3][1]) - 1) * 8)
	g.rehash()
	g.hashes = PackedInt64Array([g.hash])
	return g

func _initialize() -> void:
	var cases := [
		["rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -", [20, 400, 8902, 197281]],
		["r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -", [48, 2039, 97862]],
		["8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -", [14, 191, 2812, 43238]],
		["r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq -", [6, 264, 9467]],
		["rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ -", [44, 1486, 62379]],
	]
	var ok := true
	for c: Array in cases:
		var g := from_fen(c[0])
		for d in c[1].size():
			var t := Time.get_ticks_msec()
			var n := perft(g, d + 1)
			var want: int = c[1][d]
			print("%s d%d %d %s (%d ms)" % [c[0].substr(0, 20), d + 1, n, "ok" if n == want else "WANT %d" % want, Time.get_ticks_msec() - t])
			ok = ok and n == want
	print("perft ", "PASS" if ok else "FAIL")
	# The computer, a few moves a level from the start, timed.
	for lv in 3:
		var g: RefCounted = Rules.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + lv
		var line := []
		var worst := 0
		for ply in 8:
			var t := Time.get_ticks_msec()
			var m: int = AI.new().plan(g.copy(), lv, rng.randi())
			worst = maxi(worst, Time.get_ticks_msec() - t)
			line.append(Rules.square_name(Rules.mv_from(m)) + Rules.square_name(Rules.mv_to(m)))
			g.make(m)
		print("level %d: %s  worst %d ms" % [lv, " ".join(line), worst])
	# Mate in one it must find at every level above Easy.
	var mate := from_fen("6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - -")
	for lv in [1, 2]:
		var m: int = AI.new().plan(mate.copy(), lv, 1)
		print("mate in one, level %d: %s%s" % [lv, Rules.square_name(Rules.mv_from(m)), Rules.square_name(Rules.mv_to(m))])
	quit()
