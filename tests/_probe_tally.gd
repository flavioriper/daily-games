extends SceneTree

## Proves Tally's paper headless. Run after touching arcade/tally_sim.gd.
##   godot --headless --script tests/_probe_tally.gd
## The paper's promises: numbers saturate at both ends, A ÷ 0 is (0, A) and a
## zero remainder is not put out, A^0 is 1 and a negative power 0; a dig on a
## belt to the box fills the belt at the belt's speed and no faster; a level
## counts only its target and hands over its reward; each operator takes A on
## its A square and B on its B square, from any edge; a belt hands to a side only where a path was begun on it (a
## fork, taking turns), a line drawn onto another joins it and they take turns, a loose end holds its token at its middle; a crossing
## carries both lanes across; a path runs the way it was drawn and Flip
## turns its line round; a crate keeps one number; a
## full output stops a machine; upgrades spend the tally and go faster; the
## ladder only climbs and never passes the top; the paper is printed the same
## from the same seed with 1s near the box and no 10; and a paper saved comes
## back as it was. A machine stands over belts: they stay under it, its
## answer rides out on the belt under its answer square, and a lift, a save
## and a template keep them; a template takes its digs onto numbers.

const Sim = preload("res://arcade/tally_sim.gd")

const E := 0
const S := 1
const Wd := 2
const Nd := 3

var _fails := 0
## Every paper the checks build: at the end each is wired again from
## nothing and must come out as the edits left it, piece by piece.
var _sims: Array = []

func _initialize() -> void:
	Sim.path = "user://_probe_tally.cfg"
	_numbers()
	_paper()
	_belt_to_box()
	_operators()
	_divider()
	_split_merge()
	_bridge()
	_prios()
	_path()
	_crate()
	_stall()
	_ladder()
	_upgrades()
	_kept()
	_templates()
	_over_belts()
	_wiring()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sim.path))
	print("%d failed" % _fails)
	quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1

## A paper with nothing printed on it, at level `lvl`.
func _blank(lvl := 30) -> RefCounted:
	var s = Sim.new(11)
	s.dep.fill(0)
	s.level = lvl
	# the paper is wide: runs to the box are long (a thousand squares from
	# the corner's routes), so belts go at the top rank, 20 a second
	s.lv.belt = 128
	_sims.append(s)
	return s

## The wiring as the edits left it, in a shape that does not mind the order
## the feeders were found in.
func _wiring_of(s: RefCounted) -> Dictionary:
	var feeders := {}
	for id in s.feeders:
		var fs: PackedInt32Array = (s.feeders[id] as PackedInt32Array).duplicate()
		fs.sort()
		feeders[id] = fs
	var machines := {}
	for r in s.machines:
		var m: Dictionary = s.machines[r]
		var a: PackedInt32Array = (m.ins[0] as PackedInt32Array).duplicate()
		var b: PackedInt32Array = (m.ins[1] as PackedInt32Array).duplicate()
		var fr: PackedInt32Array = (m.fronts as PackedInt32Array).duplicate()
		var rm: PackedInt32Array = (m.rems as PackedInt32Array).duplicate()
		a.sort()
		b.sort()
		fr.sort()
		rm.sort()
		machines[r] = [a, b, fr, rm]
	var digs := {}
	for r in s.digs:
		var o: PackedInt32Array = (s.digs[r].outs as PackedInt32Array).duplicate()
		o.sort()
		digs[r] = o
	var crates := {}
	for r in s.crates:
		var o: PackedInt32Array = (s.crates[r].outs as PackedInt32Array).duplicate()
		o.sort()
		crates[r] = o
	var lanes: PackedInt32Array = s.lanes.duplicate()
	lanes.sort()
	return {"lanes": lanes, "outs": s.outs.duplicate(true), "feeders": feeders, "dead": s.dead.duplicate(), "intake": s.intake.duplicate(), "machines": machines, "digs": digs, "crates": crates}

func _wiring() -> void:
	var n := 0
	for s in _sims:
		var was := _wiring_of(s)
		s._wire_all()
		var now := _wiring_of(s)
		for key: String in was:
			if was[key] != now[key]:
				_check("paper %d wired piece by piece differs from the whole in %s" % [n, key], false)
		n += 1
	_check("%d papers wired piece by piece match the whole sheet wired again" % n, true)

## A one-square dig written straight onto the paper, past the footprint:
## for the machines' and belts' checks, where digs stand close.
func _dig1(s: RefCounted, at: Vector2i, v: int) -> void:
	var i := Sim._i(at)
	s.dep[i] = v
	s.kind[i] = Sim.DIG
	s.face[i] = E
	s.touch(i)
	s._wire()

func _run(s: RefCounted, from: Vector2i, to: Vector2i, f: int) -> void:
	var tiles := []
	var t := from
	while true:
		tiles.append(t)
		if t == to:
			break
		t += Sim.DIRS[f]
	s.lay_run(tiles, f)

func _numbers() -> void:
	_check("adding past the top stays at the top", Sim.apply(Sim.ADD, 2147483647, 5) == 2147483647)
	_check("multiplying past the top stays at the top", Sim.apply(Sim.MUL, 70000, 70000) == 2147483647)
	_check("below the floor stays at the floor", Sim.apply(Sim.SUB, -2147483648, 1) == -2147483648)
	_check("A - B keeps its order", Sim.apply(Sim.SUB, 3, 8) == -5)
	_check("2^10 = 1024", Sim.power(2, 10) == 1024)
	_check("2^40 stays at the top", Sim.power(2, 40) == 2147483647)
	_check("(-2)^41 stays at the floor", Sim.power(-2, 41) == -2147483648)
	_check("A^0 = 1 and 0^0 = 1", Sim.power(7, 0) == 1 and Sim.power(0, 0) == 1)
	_check("a negative power is 0 but for 1 and -1", Sim.power(5, -2) == 0 and Sim.power(1, -3) == 1 and Sim.power(-1, -3) == -1)
	_check("5 ÷ 2 = 2 r 1", Sim.divide(5, 2) == [2, 1])
	_check("-7 ÷ 2 truncates: -3 r -1", Sim.divide(-7, 2) == [-3, -1])
	_check("50706 ÷ 0 = 0 r 50706", Sim.divide(50706, 0) == [0, 50706])
	_check("short numbers: 9999, 12.4k, 3.1M", Sim.short(9999) == "9999" and Sim.short(12450) == "12.4k" and Sim.short(3100000) == "3.1M")

func _paper() -> void:
	var a = Sim.new(5)
	var b = Sim.new(5)
	_check("the same seed prints the same paper", a.dep == b.dep)
	var ones := 0
	var far_one := 0
	var tens := 0
	var most := 0
	for i in Sim.N:
		var v := int(a.dep[i])
		if v == 1:
			ones += 1
			far_one = maxi(far_one, Sim.ring(Sim.tile_of(i)))
		if v == 10:
			tens += 1
		most = maxi(most, v)
	_check("%d 1s within %d squares of the box (%d, furthest %d)" % [Sim.copies(1), Sim.band(1).y, ones, far_one], ones == Sim.copies(1) and far_one <= Sim.band(1).y)
	# the small numbers close, the big ones at the edge: each value's
	# copies in its band, and the bands' near edges growing with the value
	var off_band := 0
	var rings := {}
	for i in Sim.N:
		var v := int(a.dep[i])
		if v == 0:
			continue
		var d := Sim.ring(Sim.tile_of(i))
		if d < Sim.band(v).x or d > Sim.band(v).y:
			off_band += 1
		rings[v] = maxf(float(rings.get(v, 0.0)), float(d))
	_check("every printed number lies in its value's band (%d off)" % off_band, off_band == 0)
	var short := []
	for sd in range(1, 9):
		var q = Sim.new(sd)
		var seen := {}
		for i: int in q.printed:
			seen[int(q.dep[i])] = int(seen.get(int(q.dep[i]), 0)) + 1
		for v in range(1, Sim.MOST + 1):
			if v != 10 and int(seen.get(v, 0)) < Sim.copies(v):
				short.append([sd, v])
	_check("eight seeds print every copy of every number %s" % [short], short.is_empty())
	_check("a 1 is never nearer than %d squares, a 60 never under %d" % [Sim.band(1).x, Sim.band(60).x], Sim.band(1).x >= 8 and Sim.band(60).x > Sim.band(30).x and Sim.band(30).x > Sim.band(9).x and Sim.band(9).x > Sim.band(1).x)
	_check("the furthest 60 lies past the furthest 9, that past the furthest 1 (%d, %d, %d)" % [int(rings.get(1, 0)), int(rings.get(9, 0)), int(rings.get(60, 0))], float(rings.get(60, 0)) > float(rings.get(9, 0)) and float(rings.get(9, 0)) > float(rings.get(1, 0)))
	# to 60 none within APART of another; past it none within APART_FAR
	var near := 99
	var near_far := 99
	for i: int in a.printed:
		var t := Sim.tile_of(i)
		var v := int(a.dep[i])
		for dy in range(-Sim.APART, Sim.APART + 1):
			for dx in range(-Sim.APART, Sim.APART + 1):
				var u := t + Vector2i(dx, dy)
				if u != t and Sim.inside(u) and int(a.dep[Sim._i(u)]) != 0:
					var d := maxi(absi(dx), absi(dy))
					if Sim.apart(v) == Sim.APART and Sim.apart(int(a.dep[Sim._i(u)])) == Sim.APART:
						near = mini(near, d)
					else:
						near_far = mini(near_far, d)
	_check("no two printed numbers to 60 within %d squares (nearest %d), none past it within %d (nearest %d)" % [Sim.APART, near, Sim.APART_FAR, near_far], near > Sim.APART and near_far > Sim.APART_FAR)
	_check("no 10 is printed", tens == 0)
	_check("numbers to %d are printed (%d)" % [Sim.MOST, most], most == Sim.MOST)
	var printed := {}
	for i in Sim.N:
		if int(a.dep[i]) > 0:
			printed[int(a.dep[i])] = true
	var missing := []
	for v in range(1, Sim.MOST + 1):
		if v != 10 and not printed.has(v):
			missing.append(v)
	_check("every number but 10 is printed somewhere %s" % str(missing), missing.is_empty())

func _belt_to_box() -> void:
	var s = _blank(1)
	s.lv.belt = 1
	var dig_at := Sim.HUB_AT + Vector2i(-17, 1)
	s.dep[Sim._i(dig_at)] = 1
	_check("a dig is refused off a number", not s.place(Sim.DIG, dig_at + Vector2i(-1, 0), E))
	_check("a dig goes on a 1 at level 1", s.place(Sim.DIG, dig_at, E))
	_check("a dig covers three by three", s.kind_at(dig_at + Vector2i(1, 1)) == Sim.DIG and s.kind_at(dig_at + Vector2i(-1, -1)) == Sim.DIG and s.digs.size() == 1)
	_run(s, dig_at + Vector2i(2, 0), Sim.HUB_AT + Vector2i(-1, 1), E)
	_check("the run leads away from the dig's edge", (s.digs[Sim._i(dig_at)].outs as PackedInt32Array).size() == 1)
	s.events.clear()
	s.step(20.0)
	var d1: int = s.made
	s.step(10.0)
	var rate := float(s.made - d1) / 10.0
	_check("a full belt at level 1 brings one a second (%.2f)" % rate, absf(rate - 1.0) < 0.12)
	_check("ten 1s finish level 1 and hand over the adder", s.level >= 2 and s.has(Sim.ADD))
	var unlocked := false
	for ev: Dictionary in s.events:
		if ev.type == "unlock" and int(ev.reward) == Sim.ADD:
			unlocked = true
	_check("the level's end says the adder is handed over", unlocked)
	_check("the tally kept every 1", s.held(1) == s.made)
	var got: int = s.got
	s.step(5.0)
	_check("1s count for nothing on level 2", s.got == got)
	_check("a 2 cannot be dug before level 3", not s.can_dig(2))
	s.level = 4
	_check("a 2 can be dug from level 4", s.can_dig(2))
	_check("a 3 cannot", not s.can_dig(3))

## Lays a path through the corner points `pts` (each step straight).
func _route(s: RefCounted, pts: Array) -> void:
	var tiles := [pts[0]]
	for j in range(1, pts.size()):
		var a: Vector2i = tiles[-1]
		var b: Vector2i = pts[j]
		var d := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		while a != b:
			a += d
			tiles.append(a)
	var f_last := Sim.DIRS.find((tiles[-1] as Vector2i) - (tiles[-2] as Vector2i)) if tiles.size() > 1 else E
	s.lay_path(tiles, f_last)

## From `from` north to row `row`, east to column `col`, south into the box.
func _to_box(s: RefCounted, from: Vector2i, row: int, col := Sim.HUB_AT.x + 1) -> void:
	_route(s, [from, Vector2i(from.x, row), Vector2i(col, row), Vector2i(col, Sim.HUB_AT.y)])

## The squares of a machine of `k` at `m` facing `f` with role `want`.
func _role(k: int, m: Vector2i, f: int, want: int) -> Array:
	var out := []
	for c: Array in Sim.footprint(k, m, f):
		if int(c[1]) == want:
			out.append(c[0])
	return out

## A machine at (10, 10) facing north over belts: A and B each a line from
## a dig on row 14 ending under it, its answer square's line led north to
## row 5 (and into the box when `to_box`).
func _two_digs(s: RefCounted, k: int, va: int, vb: int, to_box := true) -> Vector2i:
	var m := Vector2i(10, 10)
	s.place(k, m, Nd)
	for side in 2:
		var u: Vector2i = _role(k, m, Nd, Sim.R_A if side == 0 else Sim.R_B)[0]
		_dig1(s, Vector2i(u.x, 14), va if side == 0 else vb)
		_run(s, Vector2i(u.x, 13), u, Nd)
	if to_box:
		_to_box(s, m, 5)
	else:
		_run(s, m, Vector2i(m.x, 5), Nd)
	return m

## The numbers the box has had besides any in `but`.
func _came(s: RefCounted) -> Array:
	var vs := []
	for v: int in s.ledger:
		if s.held(v) > 0:
			vs.append(v)
	vs.sort()
	return vs

func _operators() -> void:
	for row: Array in [[Sim.ADD, 7, 3, 10], [Sim.MUL, 7, 3, 21], [Sim.SUB, 7, 3, 4], [Sim.POW, 7, 3, 343]]:
		var s = _blank()
		_two_digs(s, int(row[0]), int(row[1]), int(row[2]))
		s.step(120.0)
		_check("%s of %d and %d gives %d (had %s)" % [Sim.KIND_IDS[int(row[0])], row[1], row[2], row[3], str(_came(s))], _came(s) == [int(row[3])])
	# the footprints
	for row: Array in [[Sim.ADD, 4], [Sim.MUL, 3], [Sim.SUB, 3], [Sim.DIV, 4], [Sim.POW, 3]]:
		var s = _blank()
		s.place(int(row[0]), Vector2i(10, 10), E)
		var n := 0
		for i in Sim.N:
			if int(s.op[i]) == int(row[0]):
				n += 1
		_check("%s covers %d squares (%d)" % [Sim.KIND_IDS[int(row[0])], row[1], n], n == int(row[1]) and s.machines.size() == 1)
	# a machine is not seen by belts: one run up to it is a loose end, one
	# run under its A square holds its token there for it
	var s1 = _blank()
	s1.place(Sim.MUL, Vector2i(10, 10), Nd)
	_run(s1, Vector2i(6, 10), Vector2i(8, 10), E)
	_check("a belt run up to a machine's square is a loose end", (s1.outs[Sim._i(Vector2i(8, 10))] as PackedInt32Array).is_empty())
	_run(s1, Vector2i(9, 13), Vector2i(9, 10), Nd)
	_check("a belt run under A hands into it and holds its token for it", (s1.outs[Sim._i(Vector2i(9, 11))] as PackedInt32Array) == PackedInt32Array([(Sim._i(Vector2i(9, 10)) << 2) | Nd]) and int(s1.intake[Sim._i(Vector2i(9, 10))]) == 1)
	# a turn needs room and takes no belt; a lift from any square takes it all
	var s2 = _blank()
	s2.place(Sim.MUL, Vector2i(10, 10), Nd)
	_run(s2, Vector2i(10, 9), Vector2i(10, 9), Nd)
	_check("with room it turns about its answer square, over a belt left as it was", s2.turn(Vector2i(11, 10)) and s2.kind_at(Vector2i(10, 9)) == Sim.MUL and s2.belt_at(Vector2i(10, 9)) == Sim.BELT and s2.kind_at(Vector2i(9, 10)) == Sim.EMPTY)
	for kd: int in [Sim.ADD, Sim.DIV]:
		var sq = _blank()
		sq.place(kd, Vector2i(20, 20), Nd)
		var was: Array = sq.piece_squares(Vector2i(20, 20))
		var same := true
		for n in 4:
			sq.turn(was[0])
			for q: Vector2i in was:
				same = same and sq.kind_at(q) == kd
		_check("a square machine (%s) turns on the squares it stands on, faced round" % Sim.KIND_IDS[kd], same and sq.machines.size() == 1 and sq.oface[sq.machines.keys()[0]] == Nd)
	_check("a lift from an input square lifts it all, the belt under it left", s2.remove(Vector2i(10, 9)) and s2.machines.is_empty() and s2.kind_at(Vector2i(10, 10)) == Sim.EMPTY and s2.kind_at(Vector2i(10, 9)) == Sim.BELT)
	_check("a machine is refused where it would cover a dig", (func() -> bool:
		var q = _blank()
		q.dep[Sim._i(Vector2i(11, 11))] = 1
		q.place(Sim.DIG, Vector2i(11, 11), E)
		return not q.place(Sim.ADD, Vector2i(10, 10), Nd)).call())
	var s4 = _blank()
	_two_digs(s4, Sim.ADD, 1, 1)
	s4.step(120.0)
	var m0: int = s4.made
	s4.step(40.0)
	var rate := float(s4.made - m0) / 40.0
	_check("an adder at level 1 makes one in 4 s (%.2f a second)" % rate, absf(rate - 0.25) < 0.05)

func _divider() -> void:
	var s = _blank()
	_two_digs(s, Sim.DIV, 8, 2)
	s.step(150.0)
	_check("8 ÷ 2 gives 4 and no 0 (had %s)" % str(_came(s)), _came(s) == [4])
	var s2 = _blank()
	var m := _two_digs(s2, Sim.DIV, 7, 2)
	s2.step(30.0)
	var mm: Dictionary = s2.machines[Sim._i(m)]
	_check("7 ÷ 2 with nothing for the remainder stops once two wait", (mm.rem as Array).size() == Sim.OUT and s2.held(3) <= 3)
	# the remainder taken by a line from under its own square, over the answer's
	_to_box(s2, m + Vector2i(1, 0), 7, Sim.HUB_AT.x + 2)
	s2.step(150.0)
	_check("with the remainder taken: 3 and 1 both come (had %s)" % str(_came(s2)), _came(s2) == [1, 3])
	var s3 = _blank()
	var m3 := Vector2i(10, 10)
	s3.place(Sim.DIV, m3, E)
	for side in 2:
		var u: Vector2i = _role(Sim.DIV, m3, E, Sim.R_A if side == 0 else Sim.R_B)[0]
		s3.lay_path([u], E)
		var j := Sim._i(u)
		s3.occ[j] = 1
		s3.val[j] = 9 if side == 0 else 0
		s3.prog[j] = 0.5
	var mm3: Dictionary = s3.machines[Sim._i(m3)]
	s3.step(6.0)
	_check("9 ÷ 0 puts out 0 and 9 for the remainder", mm3.out == [0] and mm3.rem == [9])

func _split_merge() -> void:
	var s = _blank()
	_dig1(s, Vector2i(5, 30), 1)
	_run(s, Vector2i(6, 30), Vector2i(12, 30), E)
	# a belt whose back touches (9, 30)'s side, going north: no split
	_run(s, Vector2i(9, 29), Vector2i(9, 26), Nd)
	_check("a belt hands only to its front: no split to a side", (s.outs[Sim._i(Vector2i(9, 30))] as PackedInt32Array).size() == 1)
	# a line drawn to end on another runs into its side: a join, taking turns
	var m = _blank()
	_dig1(m, Vector2i(10, 30), 1)
	_dig1(m, Vector2i(16, 34), 2)
	_route(m, [Vector2i(11, 30), Vector2i(Sim.HUB_AT.x + 1, 30), Sim.HUB_AT + Vector2i(1, -1)])
	var p: Dictionary = m.trim_path([Vector2i(16, 33), Vector2i(16, 32), Vector2i(16, 31), Vector2i(16, 30)], Nd)
	_check("a path ending on a line across it joins it (cut %d, merge %s)" % [p.cut, p.merge], int(p.cut) == 3 and bool(p.merge))
	m.lay_path([Vector2i(16, 33), Vector2i(16, 32), Vector2i(16, 31), Vector2i(16, 30)], Nd)
	_check("the join leaves the line as it was", m.kind_at(Vector2i(16, 30)) == Sim.BELT and m.face_at(Vector2i(16, 30)) == E and m.face_at(Vector2i(16, 31)) == Nd)
	m.step(120.0)
	var r2 := float(m.held(1)) / maxf(1.0, float(m.held(2)))
	_check("a join takes turns (%d 1s, %d 2s)" % [m.held(1), m.held(2)], r2 > 0.8 and r2 < 1.25)
	_check("a joined belt runs full (%d)" % m.made, m.made >= 30)
	# a line's loose end holds its token at its middle
	var d = _blank()
	_dig1(d, Vector2i(10, 10), 1)
	_run(d, Vector2i(11, 10), Vector2i(13, 10), E)
	d.step(10.0)
	var end := Sim._i(Vector2i(13, 10))
	_check("a loose end's token waits at its middle (%.2f)" % d.prog[end], d.occ[end] == 1 and absf(d.prog[end] - 0.5) < 0.01 and d.dead[end] == 1)
	_run(d, Vector2i(14, 10), Vector2i(15, 10), E)
	d.step(1.0)
	_check("drawn on, it goes on", d.dead[end] == 0 and d.occ[Sim._i(Vector2i(15, 10))] == 1)

func _bridge() -> void:
	var n = _blank(4)
	_dig1(n, Vector2i(5, 12), 1)
	_run(n, Vector2i(6, 12), Vector2i(20, 12), E)
	_run(n, Vector2i(12, 8), Vector2i(12, 16), S)
	_check("before level 5 a run across a belt stops at its side and joins it", n.kind_at(Vector2i(12, 12)) == Sim.BELT and n.face_at(Vector2i(12, 12)) == E and n.face_at(Vector2i(12, 11)) == S and n.kind_at(Vector2i(12, 13)) == Sim.EMPTY)
	_check("level 4's end hands crossings over", n.reward_of(4) == Sim.BRIDGE and not n.has(Sim.BRIDGE))
	var s = _blank(5)
	_dig1(s, Vector2i(5, 12), 1)
	_run(s, Vector2i(6, 12), Vector2i(20, 12), E)
	_run(s, Vector2i(12, 8), Vector2i(12, 16), S)
	_check("from level 5 a run across a belt makes a crossing", s.kind_at(Vector2i(12, 12)) == Sim.BRIDGE and s.kind_at(Vector2i(12, 13)) == Sim.BELT)
	var b = _blank(6)
	_dig1(b, Vector2i(5, 12), 1)
	_dig1(b, Vector2i(12, 4), 3)
	_route(b, [Vector2i(6, 12), Vector2i(Sim.HUB_AT.x + 1, 12), Sim.HUB_AT + Vector2i(1, -1)])
	_route(b, [Vector2i(12, 5), Vector2i(12, 20), Vector2i(Sim.HUB_AT.x + 2, 20), Sim.HUB_AT + Vector2i(2, -1)])
	_check("a run across a belt makes a crossing", b.kind_at(Vector2i(12, 12)) == Sim.BRIDGE and b.kind_at(Vector2i(Sim.HUB_AT.x + 1, 20)) == Sim.BRIDGE)
	b.step(150.0)
	_check("both lanes cross (%d 1s, %d 3s)" % [b.held(1), b.held(3)], b.held(1) > 20 and b.held(3) > 20)
	# a belt a side line joins is never crossed: its join would be cut off
	var j = _blank(1)
	_run(j, Vector2i(5, 12), Vector2i(20, 12), E)
	_run(j, Vector2i(10, 8), Vector2i(10, 11), S)
	j.lay_path([Vector2i(10, 15), Vector2i(10, 14), Vector2i(10, 13), Vector2i(10, 12), Vector2i(10, 11), Vector2i(10, 10)], Nd)
	_check("a run never crosses a belt a join comes into", j.kind_at(Vector2i(10, 12)) == Sim.BELT and j.face_at(Vector2i(10, 11)) == S)

## A traced path: each square faces the next, a belt along the way takes the
## path's facing, the ends start beside a dig and face into the box, and
## one step back puts it all as it was.
func _path() -> void:
	var s = _blank(3)
	var off := Sim.HUB_AT - Vector2i(57, 57)
	var dig_at := Vector2i(50, 52) + off
	s.dep[Sim._i(dig_at)] = 1
	s.place(Sim.DIG, dig_at, E)
	# begun on the dig's middle, east out of it, south to the box's row, east into the box
	var path := []
	for x in range(50, 55):
		path.append(Vector2i(x, 52) + off)
	for y in range(53, 59):
		path.append(Vector2i(54, y) + off)
	for x in range(55, 59):
		path.append(Vector2i(x, 58) + off)
	s.mark()
	var n: int = s.lay_path(path, E)
	_check("a traced path drops the dig and the box at its ends (%d laid)" % n, n == 11 and s.kind_at(dig_at) == Sim.DIG)
	_check("each square faces the next and the corner turns south", s.face_at(Vector2i(52, 52) + off) == E and s.face_at(Vector2i(54, 52) + off) == S and s.face_at(Vector2i(54, 56) + off) == S)
	_check("the last square faces into the box", s.face_at(Vector2i(56, 58) + off) == E)
	s.step(20.0)
	_check("the 1s ride the corner into the box (%d)" % s.made, s.made >= 10)
	_check("one step back lifts the whole path", s.undo() and s.lanes.is_empty() and s.kind_at(dig_at) == Sim.DIG and not s.can_undo())
	# a path drawn back along a line reverses it
	var r = _blank(3)
	_run(r, Vector2i(5, 5), Vector2i(9, 5), E)
	r.lay_path([Vector2i(9, 5), Vector2i(8, 5), Vector2i(7, 5), Vector2i(6, 5), Vector2i(5, 5)], Wd)
	_check("a path along a line reverses it", r.face_at(Vector2i(5, 5)) == Wd and r.face_at(Vector2i(9, 5)) == Wd)
	# a path begun on a line's belt and drawn away starts beside it, the finger's way
	var mj = _blank(3)
	_dig1(mj, Vector2i(4, 5), 1)
	_run(mj, Vector2i(5, 5), Vector2i(9, 5), E)
	mj.lay_path([Vector2i(7, 5), Vector2i(7, 6), Vector2i(7, 7)], S)
	_check("a path begun on a line and drawn away runs the finger's way", mj.face_at(Vector2i(7, 5)) == E and mj.face_at(Vector2i(7, 6)) == S and mj.face_at(Vector2i(7, 7)) == S)
	# ... and forks the line there: the square keeps its way and hands to both by turns
	var fk = _blank(3)
	_dig1(fk, Vector2i(4, 40), 1)
	_run(fk, Vector2i(5, 40), Vector2i(12, 40), E)
	fk.mark()
	fk.lay_path([Vector2i(8, 40), Vector2i(8, 41), Vector2i(8, 42), Vector2i(8, 43)], S)
	var fi := Sim._i(Vector2i(8, 40))
	_check("a path begun across a line forks it there", fk.face_at(Vector2i(8, 40)) == E and fk.fork[fi] == (1 << S) and (fk.outs[fi] as PackedInt32Array).size() == 2 and fk.face_at(Vector2i(8, 41)) == S)
	fk.step(30.0)
	_check("both ways of a fork fill", fk.occ[Sim._i(Vector2i(12, 40))] == 1 and fk.occ[Sim._i(Vector2i(8, 43))] == 1)
	_check("a branch's line stops at its fork (%d slots)" % fk.line_through(Vector2i(8, 42)).size(), fk.line_through(Vector2i(8, 42)).size() == 3)
	_check("one step back lifts the branch and the fork", fk.undo() and fk.fork[fi] == 0 and fk.kind_at(Vector2i(8, 41)) == Sim.EMPTY and (fk.outs[fi] as PackedInt32Array).size() == 1)
	# a second stroke begun on a line's loose end turns it into the corner
	var x = _blank(3)
	_run(x, Vector2i(5, 9), Vector2i(9, 9), E)
	x.lay_path([Vector2i(9, 9), Vector2i(9, 10), Vector2i(9, 11)], S)
	_check("a path begun on a line's loose end goes on from it round the corner", x.face_at(Vector2i(9, 9)) == S and x.face_at(Vector2i(9, 11)) == S and (x.outs[Sim._i(Vector2i(8, 9))] as PackedInt32Array).size() == 1)
	# drawn out of the box, a path runs the finger's way; Flip turns it round
	var bx = _blank(3)
	var left := Vector2i(Sim.HUB_AT.x - 1, Sim.HUB_AT.y + 1)
	var down := [Vector2i(Sim.HUB_AT.x, Sim.HUB_AT.y + 1), left]
	for y in range(1, 9):
		down.append(left + Vector2i(0, y))
	bx.lay_path(down, S)
	_check("a path drawn out of the box runs the way the finger went", bx.face_at(left) == S and bx.face_at(left + Vector2i(0, 4)) == S and bx.kind_at(Vector2i(Sim.HUB_AT.x, Sim.HUB_AT.y + 1)) == Sim.BOX)
	bx.mark()
	_check("Flip turns the whole line round", bx.flip_line(left + Vector2i(0, 3)) and bx.face_at(left + Vector2i(0, 8)) == Nd and bx.face_at(left + Vector2i(0, 1)) == Nd)
	_check("the flipped line's end faces into the box beside it", bx.face_at(left) == E and (bx.outs[Sim._i(left)] as PackedInt32Array).size() == 1)
	_check("one step back unflips it", bx.undo() and bx.face_at(left) == S and bx.face_at(left + Vector2i(0, 8)) == S)
	# a flip goes through a crossing's lane and stops at a join
	var fx = _blank(5)
	_dig1(fx, Vector2i(4, 20), 1)
	_run(fx, Vector2i(5, 20), Vector2i(14, 20), E)
	_run(fx, Vector2i(9, 16), Vector2i(9, 24), S)
	fx.lay_path([Vector2i(12, 17), Vector2i(12, 18), Vector2i(12, 19), Vector2i(12, 20)], S)
	var vl: Array = fx.line_through(Vector2i(9, 16))
	_check("a line runs through a crossing's lane (%d slots)" % vl.size(), vl.size() == 9 and fx.kind_at(Vector2i(9, 20)) == Sim.BRIDGE)
	fx.flip_line(Vector2i(9, 18))
	_check("flipped, the crossing's other lane keeps its way", fx.face2[Sim._i(Vector2i(9, 20))] == Nd and fx.face[Sim._i(Vector2i(9, 20))] == E and fx.face_at(Vector2i(9, 24)) == Nd)
	var hl: Array = fx.line_through(Vector2i(13, 20))
	_check("a line's run stops at a join (%d slots)" % hl.size(), hl.size() == 2)
	var tp = _blank(3)
	tp.lay_path([left], S)
	_check("a belt tapped beside the box faces into it", tp.face_at(left) == E)
	# a line's first belt along a dig's edge is fed by it
	var sd = _blank(3)
	sd.dep[Sim._i(Vector2i(20, 20))] = 1
	sd.place(Sim.DIG, Vector2i(20, 20), E)
	sd.lay_path([Vector2i(22, 19), Vector2i(22, 20), Vector2i(22, 21), Vector2i(22, 22), Vector2i(22, 23)], S)
	_check("a line begun beside a dig and going along it is fed only at its start", (sd.digs[Sim._i(Vector2i(20, 20))].outs as PackedInt32Array).size() == 1)
	sd.step(10.0)
	_check("its numbers ride it (%d)" % sd.occ[Sim._i(Vector2i(22, 23))], sd.occ[Sim._i(Vector2i(22, 23))] == 1)
	_check("a belt lying beside a line still takes nothing from it", (func() -> bool:
		var q = _blank(3)
		_run(q, Vector2i(5, 20), Vector2i(12, 20), E)
		_run(q, Vector2i(8, 21), Vector2i(8, 23), S)
		return q.kind_at(Vector2i(8, 20)) == Sim.BELT and (q.outs[Sim._i(Vector2i(8, 20))] as PackedInt32Array).size() == 1).call())
	var one = _blank(3)
	one.lay_path([Vector2i(3, 3)], Nd)
	_check("a path of one square faces the way given", one.kind_at(Vector2i(3, 3)) == Sim.BELT and one.face_at(Vector2i(3, 3)) == Nd)
	# undo puts a lifted machine back whole
	var u = _blank()
	u.place(Sim.DIV, Vector2i(10, 10), E)
	u.mark()
	u.remove(Vector2i(9, 11))
	_check("undo puts a lifted divider back whole", u.undo() and u.machines.size() == 1 and u.kind_at(Vector2i(9, 11)) == Sim.DIV and int(u.oroot[Sim._i(Vector2i(9, 11))]) == Sim._i(Vector2i(10, 10)))
	# a one-sided adder makes nothing and says which side starves
	var a = _blank()
	var m := Vector2i(10, 10)
	a.place(Sim.ADD, m, Nd)
	_dig1(a, Vector2i(10, 14), 1)
	_run(a, Vector2i(10, 13), Vector2i(10, 11), Nd)
	_to_box(a, m, 5)
	a.step(10.0)
	_check("an adder fed on A alone makes nothing and starves on B", a.made == 0 and a.starving(Sim._i(m)) == 1)
	_dig1(a, Vector2i(11, 14), 1)
	_run(a, Vector2i(11, 13), Vector2i(11, 11), Nd)
	a.step(10.0)
	_check("fed on both it works and starves no more", a.starving(Sim._i(m)) == -1 and bool(a.machines[Sim._i(m)].has_last))
	# twenty non-targets with no hit: the box says so once
	var o = _blank(2)
	o.dep[Sim._i(Sim.HUB_AT + Vector2i(-6, 1))] = 1
	o.place(Sim.DIG, Sim.HUB_AT + Vector2i(-6, 1), E)
	_run(o, Sim.HUB_AT + Vector2i(-4, 1), Sim.HUB_AT + Vector2i(-1, 1), E)
	o.events.clear()
	o.step(40.0)
	var said := 0
	for ev: Dictionary in o.events:
		if ev.type == "off_target":
			said += 1
	_check("the box says once that the 1s do not count (%d)" % said, said == 1 and o.off >= Sim.OFF_SAY)

func _crate() -> void:
	var s = _blank()
	_dig1(s, Vector2i(5, 40), 1)
	_dig1(s, Vector2i(5, 42), 2)
	_run(s, Vector2i(6, 40), Vector2i(8, 40), E)
	s.place(Sim.CRATE, Vector2i(9, 40), E)
	_run(s, Vector2i(6, 42), Vector2i(8, 42), E)
	_run(s, Vector2i(9, 42), Vector2i(9, 41), Nd)
	s.step(20.0)
	var c: Dictionary = s.crates[Sim._i(Vector2i(9, 40))]
	_check("a crate keeps the first number only (%d of %d)" % [int(c.n), int(c.v)], int(c.v) == 1 and int(c.n) > 10)
	_route(s, [Vector2i(10, 40), Vector2i(Sim.HUB_AT.x - 1, 40), Sim.HUB_AT + Vector2i(-1, 1), Sim.HUB_AT + Vector2i(0, 1)])
	s.step(120.0)
	_check("a crate lets its number out to the box", s.held(1) > 10)

## Priorities (from level 10): at a join the marked way in goes first and
## the other fills its gaps; at a split the marked way out is filled first.
func _prios() -> void:
	# a join: 1s from the west, 2s from the north, into one belt east to its end
	var j = _blank(30)
	_dig1(j, Vector2i(5, 30), 1)
	_dig1(j, Vector2i(12, 24), 2)
	_route(j, [Vector2i(6, 30), Vector2i(Sim.HUB_AT.x + 1, 30), Sim.HUB_AT + Vector2i(1, -1)])
	j.lay_path([Vector2i(12, 25), Vector2i(12, 26), Vector2i(12, 27), Vector2i(12, 28), Vector2i(12, 29), Vector2i(12, 30)], S)
	_check("a join is a place for a priority, a plain belt is not", j.can_prio(Vector2i(12, 30)) and not j.can_prio(Vector2i(15, 30)))
	var shut = _blank(10)
	_run(shut, Vector2i(6, 30), Vector2i(20, 30), E)
	shut.lay_path([Vector2i(12, 26), Vector2i(12, 27), Vector2i(12, 28), Vector2i(12, 29), Vector2i(12, 30)], S)
	_check("before level 11 no priority is set", not shut.set_prio(Vector2i(12, 30), 3))
	_check("tapped by the north edge, the 2s coming down go first", j.set_prio(Vector2i(12, 30), 3) and int(j.prio[Sim._i(Vector2i(12, 30))]) == 1 + S)
	_check("an edge nothing comes in or goes out by sets nothing", not j.set_prio(Vector2i(12, 30), 1))
	# both feeders run full: unmarked they take turns (as the join above, about
	# even); marked, the 2s pass all their line carries and the 1s fill its gaps
	j.step(120.0)
	_check("with the north first the 2s pass whole, the 1s fill the gaps (%d 2s, %d 1s)" % [j.held(2), j.held(1)], j.held(2) > j.held(1) * 2 and j.held(1) > 0 and j.held(2) + j.held(1) > 1300)
	_check("the same tap again clears it", j.set_prio(Vector2i(12, 30), 3) and int(j.prio[Sim._i(Vector2i(12, 30))]) == 0)
	# a split: one line of 1s, forked at (12, 30) to the south too; east gets first
	var sp = _blank(30)
	sp.lv.belt = 1
	_dig1(sp, Vector2i(5, 30), 1)
	_run(sp, Vector2i(6, 30), Vector2i(16, 30), E)
	sp.place(Sim.CRATE, Vector2i(17, 30), E)
	sp.lay_path([Vector2i(12, 30), Vector2i(12, 31), Vector2i(12, 32), Vector2i(12, 33)], S)
	sp.place(Sim.CRATE, Vector2i(12, 34), S)
	_check("a fork is a place for a priority", sp.can_prio(Vector2i(12, 30)))
	_check("tapped by the east edge, east is filled first", sp.set_prio(Vector2i(12, 30), 0) and int(sp.prio[Sim._i(Vector2i(12, 30))]) == 5 + E)
	sp.step(40.0)
	var ce: Dictionary = sp.crates[Sim._i(Vector2i(17, 30))]
	var cs: Dictionary = sp.crates[Sim._i(Vector2i(12, 34))]
	_check("east takes all while it has room (%d east, %d south)" % [int(ce.n), int(cs.n)], int(ce.n) > 20 and int(cs.n) == 0)
	# kept, and undone
	sp.save()
	var r = Sim.load_saved()
	_check("a priority comes back from a save", int(r.prio[Sim._i(Vector2i(12, 30))]) == 5 + E)
	sp.mark()
	sp.set_prio(Vector2i(12, 30), 0)
	_check("one step back puts a cleared priority back", sp.undo() and int(sp.prio[Sim._i(Vector2i(12, 30))]) == 5 + E)

func _stall() -> void:
	var s = _blank()
	var m := _two_digs(s, Sim.ADD, 1, 1, false)
	# the run north of the machine leads nowhere: it fills and the adder stops
	s.step(200.0)
	var mm: Dictionary = s.machines[Sim._i(m)]
	_check("a full output stops the machine: %d out, %d a side" % [(mm.out as Array).size(), (mm.a as Array).size()], (mm.out as Array).size() == Sim.OUT and (mm.a as Array).size() == 1)
	s.remove(Vector2i(10, 7))
	_check("a lifted belt drops its token", s.occ[Sim._i(Vector2i(10, 7))] == 0)

func _ladder() -> void:
	var s = Sim.new(3)
	_sims.append(s)
	var last := 0
	var ok := true
	var t0 := Time.get_ticks_msec()
	for n in range(1, 1001):
		var t: int = s.target_of(n)
		if t <= last and t < Sim.TOP:
			ok = false
		if t > Sim.TOP:
			ok = false
		last = t
	_check("targets climb to level 1000 and never pass the top (%d, %d ms)" % [last, Time.get_ticks_msec() - t0], ok)
	_check("level 5 asks 10, which cannot be dug", s.target_of(5) == 10 and Sim.dig_level(10) == -1)
	_check("level 40's target is near 35,541 (%d)" % s.target_of(40), absf(s.target_of(40) / 35541.0 - 1.0) <= Sim.BAND + 0.001)
	_check("level 23 hands over 16, level 1006 hands over 999", s.reward_of(23) == -16 and s.reward_of(1006) == -999 and s.reward_of(1007) == 0)
	_check("counts stop at %d" % Sim.COUNT_TOP, s.count_of(200) == Sim.COUNT_TOP)

func _upgrades() -> void:
	var s = _blank(2)
	s.lv.belt = 1
	var asks: Array = s.asks("belt")
	_check("the belt's first rank asks for 200 1s (%s)" % str(asks), asks == [[1, 200]])
	_check("short of it, nothing is bought", not s.buy("belt"))
	s.ledger[1] = 205
	_check("with 205 1s the belt is bought", s.buy("belt") and int(s.lv.belt) == 2)
	_check("5 1s are left", s.held(1) == 5)
	_check("belt level 2 runs 2 a second", s.belt_speed() == 2.0)
	_check("rank two asks two numbers, rank three three", s.asks("belt").size() == 2)
	s.lv.belt = 3
	_check("rank three asks three", s.asks("belt").size() == 3)
	_check("the multiplier's track is shut before level 8", not s.track_open("mul"))
	_check("the speeds' tops: belt 20, adder 4, others 3", absf(Sim.speed_for("belt", 128) - 20.0) < 0.001 and absf(Sim.speed_for("add", 108) - 4.0) < 0.001 and absf(Sim.speed_for("mul", 108) - 3.0) < 0.001)
	_check("operators at level 8 do one a second", absf(Sim.speed_for("mul", 8) - 1.0) < 0.001 and absf(Sim.speed_for("mul", 7) - 0.8) < 0.001)
	s.lv.dig = 12
	_check("the dig stops at 12", s.at_top("dig") and not s.can_buy("dig"))

func _kept() -> void:
	var s = Sim.new(21)
	_sims.append(s)
	s.level = 9
	s.got = 33
	s.made = 1234
	s.lv.belt = 4
	s.ledger[19] = 50
	var dig_at := Vector2i(-1, -1)
	for i in Sim.N:
		if int(s.dep[i]) == 1:
			dig_at = Sim.tile_of(i)
			break
	s.place(Sim.DIG, dig_at, E)
	s.place(Sim.ADD, Vector2i(2, 2), S)
	_run(s, Vector2i(0, 0), Vector2i(5, 0), E)
	s.lay_path([Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)], S)
	s.save()
	var r = Sim.load_saved()
	_check("a saved paper comes back: level, count, made", r.level == 9 and r.got == 33 and r.made == 1234)
	_check("its upgrades and tally", int(r.lv.belt) == 4 and r.held(19) == 50)
	_check("its pieces", r.kind_at(dig_at) == Sim.DIG and r.kind_at(Vector2i(2, 2)) == Sim.ADD and r.face_at(Vector2i(2, 2)) == S and r.kind_at(Vector2i(3, 0)) == Sim.BELT)
	_check("a fork comes back", r.fork[Sim._i(Vector2i(4, 0))] == (1 << S) and (r.outs[Sim._i(Vector2i(4, 0))] as PackedInt32Array).size() == 2)
	_check("a machine comes back whole", r.kind_at(Vector2i(1, 1)) == Sim.ADD and int(r.oroot[Sim._i(Vector2i(1, 1))]) == Sim._i(Vector2i(2, 2)) and r.machines.size() == 1)
	# a sheet kept before the footprints keeps its progress and drops its pieces
	var cfg := ConfigFile.new()
	cfg.load(Sim.path)
	cfg.set_value("paper", "ver", 1)
	cfg.save(Sim.path)
	var old = Sim.load_saved()
	_check("an old sheet keeps its level and tally, not its pieces", old.level == 9 and old.held(19) == 50 and old.machines.is_empty() and old.lanes.is_empty())
	_check("the same paper is printed", r.dep == s.dep and r.target_of(30) == s.target_of(30))
	_check("the card reads it", Sim.kept().level == 9)

## Picked pieces as a template: set down turned, plain pieces after, undone
## whole; a part saved from them; a picked lot lifted and put back.
func _templates() -> void:
	var s = Sim.new(23)
	_sims.append(s)
	s.level = 3
	s.place(Sim.ADD, Vector2i(12, 12), S)
	_run(s, Vector2i(10, 10), Vector2i(14, 10), E)
	var pick := []
	for y in range(9, 15):
		for x in range(9, 16):
			pick.append(Vector2i(x, y))
	var d: Dictionary = s.template_of(pick)
	_check("a template holds the adder and the run", (d.pieces as Array).size() == 6 and int(d.w) >= 5)
	var at := Vector2i(30, 30)
	_check("it can go on bare paper", s.why_not_template(d, at, 0) == "")
	s.mark()
	var laid: Array = s.stamp_template(d, at, 1)
	var ops := 0
	for t: Vector2i in laid:
		if Sim.is_op(s.kind_at(t)) and int(s.oroot[Sim._i(t)]) == Sim._i(t):
			ops += 1
	_check("set down turned: one adder, its run turned south", ops == 1 and s.machines.size() == 2 and s.face_at(at + Vector2i(int(d.h) - 1, 0)) == S)
	_check("it cannot go on itself again", s.why_not_template(d, at, 1) == "taken")
	s.undo()
	_check("undo takes the whole stamp back", s.machines.size() == 1 and s.kind_at(at + Vector2i(int(d.h) - 1, 0)) == Sim.EMPTY)
	var id: int = s.save_part(pick)
	_check("a part saved from the pick", id > 0 and s.defs.has(id))
	s.stamp_template(s.defs[id], at, 0)
	s.mark()
	s.turn(Vector2i(10, 10))
	_check("a set-down part shares nothing: the first run turned, the copy not", s.face_at(Vector2i(10, 10)) == S and s.face_at(at) == E)
	s.mark()
	_check("a pick lifted whole", s.lift_all(pick) > 0 and s.machines.size() == 1 and s.kind_at(Vector2i(12, 12)) == Sim.EMPTY)
	s.undo()
	_check("and put back by undo", s.machines.size() == 2 and s.kind_at(Vector2i(12, 12)) == Sim.ADD)

## A machine set over belts (the user, 2026-10-19: "it goes on top of the
## convey"): the belts stay under it, A and B take what rides in, the answer
## comes out at its square's middle and rides the belt under it on; a line
## drawn from an answer square turns at once; a lift leaves the belts; the
## belts under it are saved and copied with it; a dig goes in a template.
func _over_belts() -> void:
	var s = _blank()
	_dig1(s, Vector2i(18, 30), 2)
	_dig1(s, Vector2i(18, 31), 3)
	_run(s, Vector2i(19, 30), Vector2i(30, 30), E)
	_run(s, Vector2i(19, 31), Vector2i(30, 31), E)
	_check("an adder set over two lines", s.place(Sim.ADD, Vector2i(25, 30), E))
	var a := Sim._i(Vector2i(24, 30))
	var o := Sim._i(Vector2i(25, 30))
	var o2 := Sim._i(Vector2i(25, 31))
	_check("the belts run on under it", s.belt_at(Vector2i(24, 30)) == Sim.BELT and s.belt_at(Vector2i(25, 30)) == Sim.BELT and s.belt_at(Vector2i(25, 31)) == Sim.BELT and int(s.intake[a]) == 1)
	_check("its answer squares are lanes it puts out on", s.lanes.has(o) and s.lanes.has(o2) and (s.machines[o].fronts as PackedInt32Array).size() == 2)
	var seen := {}
	var mid := true
	for n in 400:
		s.step(1.0 / 30.0)
		for j in [o, o2]:
			if s.occ[j] == 1 and s.prog[j] < 0.5:
				mid = false
		for x in range(26, 31):
			for y in [30, 31]:
				var j := Sim._i(Vector2i(x, y))
				if s.occ[j] == 1:
					seen[int(s.val[j])] = true
	_check("2 + 3 rides out past it on both lines (%s)" % str(seen.keys()), seen.has(5) and seen.size() == 1)
	_check("an answer comes out at its square's middle", mid)
	Sim.path = "user://_probe_tally.cfg"
	s.save()
	var l = Sim.load_saved()
	_check("saved and read with the belts under it", l.kind_at(Vector2i(25, 30)) == Sim.ADD and l.belt_at(Vector2i(25, 30)) == Sim.BELT and l.belt_at(Vector2i(24, 30)) == Sim.BELT and l.lanes.has(o2) and l.machines.size() == 1)
	var pick := []
	for y in range(30, 32):
		for x in range(24, 27):
			pick.append(Vector2i(x, y))
	var d: Dictionary = s.template_of(pick)
	var st: Array = s.stamp_template(d, Vector2i(24, 50), 0)
	_check("a template carries the belts under its machine", not st.is_empty() and s.kind_at(Vector2i(25, 50)) == Sim.ADD and s.belt_at(Vector2i(25, 50)) == Sim.BELT and s.kind_at(Vector2i(26, 51)) == Sim.BELT)
	s.mark()
	s.remove(Vector2i(24, 30))
	_check("a lift leaves the belts it stood on", s.kind_at(Vector2i(24, 30)) == Sim.BELT and s.kind_at(Vector2i(25, 31)) == Sim.BELT and s.face_at(Vector2i(25, 30)) == E)
	s.undo()
	_check("and undo sets it back over them", s.kind_at(Vector2i(25, 30)) == Sim.ADD and s.belt_at(Vector2i(25, 30)) == Sim.BELT)
	# a line drawn out of an answer square turns at once (the user, 2026-10-19:
	# "right now user can't turn convey after a module")
	var s3 = _blank()
	s3.place(Sim.ADD, Vector2i(25, 30), E)
	s3.lay_path([Vector2i(25, 30), Vector2i(26, 30), Vector2i(26, 31), Vector2i(26, 32)], S)
	_check("a line begun on an answer square is laid under it and turns", s3.belt_at(Vector2i(25, 30)) == Sim.BELT and int(s3.face[o]) == E and s3.face_at(Vector2i(26, 30)) == S and (s3.outs[o] as PackedInt32Array).size() == 1)
	s3.lay_path([Vector2i(20, 31), Vector2i(21, 31), Vector2i(22, 31), Vector2i(23, 31), Vector2i(24, 31)], E)
	var bi := Sim._i(Vector2i(23, 31))
	_check("a line drawn into B ends at its middle, under it, held there", s3.belt_at(Vector2i(24, 31)) == Sim.BELT and ((s3.outs[bi] as PackedInt32Array)[0] >> 2) == Sim._i(Vector2i(24, 31)) and int(s3.intake[Sim._i(Vector2i(24, 31))]) == 2)
	# a dig in a template goes onto a number it can dig
	var s5 = _blank()
	s5.dep[Sim._i(Vector2i(40, 40))] = 1
	s5.place(Sim.DIG, Vector2i(40, 40), E)
	_run(s5, Vector2i(42, 40), Vector2i(44, 40), E)
	var pk := []
	for y in range(39, 42):
		for x in range(39, 45):
			pk.append(Vector2i(x, y))
	var dd: Dictionary = s5.template_of(pk)
	var digs := 0
	for pc: Array in dd.pieces:
		if int(pc[2]) == Sim.DIG:
			digs += 1
	_check("a template keeps the dig, once", digs == 1 and int(dd.w) == 6 and int(dd.h) == 3)
	_check("off a number it cannot go", s5.why_not_template(dd, Vector2i(39, 60), 0) == "no_number")
	s5.dep[Sim._i(Vector2i(40, 70))] = 2
	_check("on one it goes, digging that number", not s5.stamp_template(dd, Vector2i(39, 69), 0).is_empty() and s5.digs.has(Sim._i(Vector2i(40, 70))) and s5.kind_at(Vector2i(43, 70)) == Sim.BELT)

	# two adders stacked touching, a line under the top one's first answer
	# square alone: the other answer square does not hand into the adder below
	var s6 = _blank()
	_dig1(s6, Vector2i(18, 30), 2)
	_dig1(s6, Vector2i(18, 31), 3)
	_run(s6, Vector2i(19, 30), Vector2i(30, 30), E)
	_run(s6, Vector2i(19, 31), Vector2i(24, 31), E)
	s6.place(Sim.ADD, Vector2i(25, 30), E)
	s6.place(Sim.ADD, Vector2i(25, 32), E)
	for n in 400:
		s6.step(1.0 / 30.0)
	var low: Dictionary = s6.machines[Sim._i(Vector2i(25, 32))]
	_check("a stacked adder below is not fed by the bare answer square above", (low.a as Array).is_empty() and (low.b as Array).is_empty() and int(s6.machines[Sim._i(Vector2i(25, 30))].last) == 5)
	# a line drawn across a machine's middle runs as if it were not there
	var s7 = _blank()
	s7.place(Sim.ADD, Vector2i(25, 30), E)
	_run(s7, Vector2i(20, 31), Vector2i(30, 31), E)
	_run(s7, Vector2i(25, 27), Vector2i(25, 34), S)
	_check("a line laid through a machine is a plain line, crossings and all", s7.belt_at(Vector2i(25, 30)) == Sim.BELT and s7.belt_at(Vector2i(25, 31)) == Sim.BRIDGE and s7.belt_at(Vector2i(24, 31)) == Sim.BELT and s7.kind_at(Vector2i(25, 31)) == Sim.ADD)
	# a paper kept before the machines' layer: belts given under its machines
	var s8 = _blank()
	s8.place(Sim.MUL, Vector2i(10, 10), Nd)
	_run(s8, Vector2i(9, 13), Vector2i(9, 11), Nd)
	_run(s8, Vector2i(10, 9), Vector2i(10, 6), Nd)
	Sim.path = "user://_probe_tally.cfg"
	s8.save()
	var cfg := ConfigFile.new()
	cfg.load(Sim.path)
	cfg.erase_section_key("paper", "layers")
	cfg.save(Sim.path)
	var old = Sim.load_saved()
	_check("a kept paper's machine gets belts under its A and answer squares", old.belt_at(Vector2i(9, 10)) == Sim.BELT and int(old.face[Sim._i(Vector2i(9, 10))]) == Nd and old.belt_at(Vector2i(10, 10)) == Sim.BELT and int(old.face[Sim._i(Vector2i(10, 10))]) == Nd and old.belt_at(Vector2i(11, 10)) == Sim.EMPTY)
