extends SceneTree

## Proves Tally's paper headless. Run after touching arcade/tally_sim.gd.
##   godot --headless --script tests/_probe_tally.gd
## The paper's promises: numbers saturate at both ends, A ÷ 0 is (0, A) and a
## zero remainder is not put out, A^0 is 1 and a negative power 0; a dig on a
## belt to the box fills the belt at the belt's speed and no faster; a level
## counts only its target and hands over its reward; each operator takes A on
## its back square, B on its other, and puts out of its answer square's
## front alone; a belt hands to a side only where a path was begun on it (a
## fork, taking turns), a line drawn onto another joins it and they take turns, a loose end holds its token at its middle; a crossing
## carries both lanes across; a path runs the way it was drawn and Flip
## turns its line round; a crate keeps one number; a
## full output stops a machine; upgrades spend the tally and go faster; the
## ladder only climbs and never passes the top; the paper is printed the same
## from the same seed with 1s near the box and no 10; and a paper saved comes
## back as it was.

const Sim = preload("res://arcade/tally_sim.gd")

const E := 0
const S := 1
const Wd := 2
const Nd := 3

var _fails := 0

func _initialize() -> void:
	Sim.path = "user://_probe_tally.cfg"
	_numbers()
	_paper()
	_belt_to_box()
	_operators()
	_divider()
	_split_merge()
	_bridge()
	_path()
	_crate()
	_stall()
	_ladder()
	_upgrades()
	_kept()
	_templates()
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
	# the paper is wide: runs to the box are long, so belts go 8 a second
	s.lv.belt = 8
	return s

## A one-square dig written straight onto the paper, past the footprint:
## for the machines' and belts' checks, where digs stand close.
func _dig1(s: RefCounted, at: Vector2i, v: int) -> void:
	var i := Sim._i(at)
	s.dep[i] = v
	s.kind[i] = Sim.DIG
	s.face[i] = E
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
	_check("six 1s within %d squares of the box (%d, furthest %d)" % [int(Sim.DEPOSITS[0][3]), ones, far_one], ones == 6 and far_one <= int(Sim.DEPOSITS[0][3]))
	var near := 99
	for i in Sim.N:
		if int(a.dep[i]) == 0:
			continue
		var t := Sim.tile_of(i)
		for dy in range(-Sim.APART, Sim.APART + 1):
			for dx in range(-Sim.APART, Sim.APART + 1):
				var u := t + Vector2i(dx, dy)
				if u != t and Sim.inside(u) and int(a.dep[Sim._i(u)]) != 0:
					near = mini(near, maxi(absi(dx), absi(dy)))
	_check("no two printed numbers within %d squares (nearest %d)" % [Sim.APART, near], near > Sim.APART)
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
	var dig_at := Vector2i(40, 58)
	s.dep[Sim._i(dig_at)] = 1
	_check("a dig is refused off a number", not s.place(Sim.DIG, Vector2i(39, 58), E))
	_check("a dig goes on a 1 at level 1", s.place(Sim.DIG, dig_at, E))
	_check("a dig covers three by three", s.kind_at(dig_at + Vector2i(1, 1)) == Sim.DIG and s.kind_at(dig_at + Vector2i(-1, -1)) == Sim.DIG and s.digs.size() == 1)
	_run(s, Vector2i(42, 58), Vector2i(56, 58), E)
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

## A machine at (10, 10) facing north, A and B each fed from straight
## behind by a dig on row 14, its answer led north to row 5 (and into the
## box when `to_box`).
func _two_digs(s: RefCounted, k: int, va: int, vb: int, to_box := true) -> Vector2i:
	var m := Vector2i(10, 10)
	s.place(k, m, Nd)
	for side in 2:
		var u: Vector2i = _role(k, m, Nd, Sim.R_A if side == 0 else Sim.R_B)[0]
		_dig1(s, Vector2i(u.x, 14), va if side == 0 else vb)
		_run(s, Vector2i(u.x, 13), u + Vector2i(0, 1), Nd)
	if to_box:
		_to_box(s, m + Vector2i(0, -1), 5)
	else:
		_run(s, m + Vector2i(0, -1), Vector2i(m.x, 5), Nd)
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
		s.step(60.0)
		_check("%s of %d and %d gives %d (had %s)" % [Sim.KIND_IDS[int(row[0])], row[1], row[2], row[3], str(_came(s))], _came(s) == [int(row[3])])
	# the footprints
	for row: Array in [[Sim.ADD, 4], [Sim.MUL, 3], [Sim.SUB, 3], [Sim.DIV, 4], [Sim.POW, 3]]:
		var s = _blank()
		s.place(int(row[0]), Vector2i(10, 10), E)
		var n := 0
		for i in Sim.N:
			if int(s.kind[i]) == int(row[0]):
				n += 1
		_check("%s covers %d squares (%d)" % [Sim.KIND_IDS[int(row[0])], row[1], n], n == int(row[1]) and s.machines.size() == 1)
	# a belt into an input's side is taken (any face), into the answer square not
	var s1 = _blank()
	s1.place(Sim.MUL, Vector2i(10, 10), Nd)
	_run(s1, Vector2i(6, 10), Vector2i(8, 10), E)
	_check("a belt into A's side is taken", not (s1.outs[Sim._i(Vector2i(8, 10))] as PackedInt32Array).is_empty())
	_run(s1, Vector2i(10, 13), Vector2i(10, 11), Nd)
	_check("a belt into the answer square's back hands nothing", (s1.outs[Sim._i(Vector2i(10, 11))] as PackedInt32Array).is_empty())
	_run(s1, Vector2i(9, 13), Vector2i(9, 11), Nd)
	_check("a belt into A's back is taken", (s1.outs[Sim._i(Vector2i(9, 11))] as PackedInt32Array).size() == 1)
	# a turn needs room and takes no belt; a lift from any square takes it all
	var s2 = _blank()
	s2.place(Sim.MUL, Vector2i(10, 10), Nd)
	_run(s2, Vector2i(10, 9), Vector2i(10, 9), Nd)
	_check("a turn onto a belt is refused", not s2.turn(Vector2i(9, 10)) and s2.face_at(Vector2i(10, 10)) == Nd and s2.kind_at(Vector2i(10, 9)) == Sim.BELT)
	s2.remove(Vector2i(10, 9))
	_check("with room it turns about its answer square", s2.turn(Vector2i(11, 10)) and s2.kind_at(Vector2i(10, 9)) == Sim.MUL and s2.kind_at(Vector2i(9, 10)) == Sim.EMPTY)
	for kd: int in [Sim.ADD, Sim.DIV]:
		var sq = _blank()
		sq.place(kd, Vector2i(20, 20), Nd)
		var was: Array = sq.piece_squares(Vector2i(20, 20))
		var same := true
		for n in 4:
			sq.turn(was[0])
			for q: Vector2i in was:
				same = same and sq.kind_at(q) == kd
		_check("a square machine (%s) turns on the squares it stands on, faced round" % Sim.KIND_IDS[kd], same and sq.machines.size() == 1 and sq.face[sq.machines.keys()[0]] == Nd)
	_check("a lift from an input square lifts it all", s2.remove(Vector2i(10, 9)) and s2.machines.is_empty() and s2.kind_at(Vector2i(10, 10)) == Sim.EMPTY)
	_check("a machine is refused where it would cover a dig", (func() -> bool:
		var q = _blank()
		q.dep[Sim._i(Vector2i(11, 11))] = 1
		q.place(Sim.DIG, Vector2i(11, 11), E)
		return not q.place(Sim.ADD, Vector2i(10, 10), Nd)).call())
	var s4 = _blank()
	_two_digs(s4, Sim.ADD, 1, 1)
	s4.step(60.0)
	var m0: int = s4.made
	s4.step(40.0)
	var rate := float(s4.made - m0) / 40.0
	_check("an adder at level 1 makes one in 4 s (%.2f a second)" % rate, absf(rate - 0.25) < 0.05)

func _divider() -> void:
	var s = _blank()
	_two_digs(s, Sim.DIV, 8, 2)
	s.step(80.0)
	_check("8 ÷ 2 gives 4 and no 0 (had %s)" % str(_came(s)), _came(s) == [4])
	var s2 = _blank()
	var m := _two_digs(s2, Sim.DIV, 7, 2)
	s2.step(30.0)
	var mm: Dictionary = s2.machines[Sim._i(m)]
	_check("7 ÷ 2 with nothing for the remainder stops once two wait", (mm.rem as Array).size() == Sim.OUT and s2.held(3) <= 3)
	# the remainder taken off its own square's front, over the answer's belt
	_to_box(s2, m + Vector2i(1, -1), 7, Sim.HUB_AT.x + 2)
	s2.step(80.0)
	_check("with the remainder taken: 3 and 1 both come (had %s)" % str(_came(s2)), _came(s2) == [1, 3])
	var s3 = _blank()
	var m3 := Vector2i(10, 10)
	s3.place(Sim.DIV, m3, E)
	var mm3: Dictionary = s3.machines[Sim._i(m3)]
	mm3.a.append(9)
	mm3.b.append(0)
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
	_route(m, [Vector2i(11, 30), Vector2i(58, 30), Vector2i(58, 56)])
	var p: Dictionary = m.trim_path([Vector2i(16, 33), Vector2i(16, 32), Vector2i(16, 31), Vector2i(16, 30)], Nd)
	_check("a path ending on a line across it joins it (cut %d, merge %s)" % [p.cut, p.merge], int(p.cut) == 3 and bool(p.merge))
	m.lay_path([Vector2i(16, 33), Vector2i(16, 32), Vector2i(16, 31), Vector2i(16, 30)], Nd)
	_check("the join leaves the line as it was", m.kind_at(Vector2i(16, 30)) == Sim.BELT and m.face_at(Vector2i(16, 30)) == E and m.face_at(Vector2i(16, 31)) == Nd)
	m.step(60.0)
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
	var s = _blank(1)
	_dig1(s, Vector2i(5, 12), 1)
	_run(s, Vector2i(6, 12), Vector2i(20, 12), E)
	_run(s, Vector2i(12, 8), Vector2i(12, 16), S)
	_check("from level 1 a run across a belt makes a crossing", s.kind_at(Vector2i(12, 12)) == Sim.BRIDGE and s.kind_at(Vector2i(12, 13)) == Sim.BELT)
	var b = _blank(6)
	_dig1(b, Vector2i(5, 12), 1)
	_dig1(b, Vector2i(12, 4), 3)
	_route(b, [Vector2i(6, 12), Vector2i(58, 12), Vector2i(58, 56)])
	_route(b, [Vector2i(12, 5), Vector2i(12, 20), Vector2i(59, 20), Vector2i(59, 56)])
	_check("a run across a belt makes a crossing", b.kind_at(Vector2i(12, 12)) == Sim.BRIDGE and b.kind_at(Vector2i(58, 20)) == Sim.BRIDGE)
	b.step(80.0)
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
	var dig_at := Vector2i(50, 52)
	s.dep[Sim._i(dig_at)] = 1
	s.place(Sim.DIG, dig_at, E)
	# begun on the dig's middle, east out of it, south to the box's row, east into the box
	var path := []
	for x in range(50, 55):
		path.append(Vector2i(x, 52))
	for y in range(53, 59):
		path.append(Vector2i(54, y))
	for x in range(55, 59):
		path.append(Vector2i(x, 58))
	s.mark()
	var n: int = s.lay_path(path, E)
	_check("a traced path drops the dig and the box at its ends (%d laid)" % n, n == 11 and s.kind_at(dig_at) == Sim.DIG)
	_check("each square faces the next and the corner turns south", s.face_at(Vector2i(52, 52)) == E and s.face_at(Vector2i(54, 52)) == S and s.face_at(Vector2i(54, 56)) == S)
	_check("the last square faces into the box", s.face_at(Vector2i(56, 58)) == E)
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
	var fx = _blank(1)
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
	_check("undo puts a lifted divider back whole", u.undo() and u.machines.size() == 1 and u.kind_at(Vector2i(9, 11)) == Sim.DIV and int(u.root[Sim._i(Vector2i(9, 11))]) == Sim._i(Vector2i(10, 10)))
	# a one-sided adder makes nothing and says which side starves
	var a = _blank()
	var m := Vector2i(10, 10)
	a.place(Sim.ADD, m, Nd)
	_dig1(a, Vector2i(10, 14), 1)
	_run(a, Vector2i(10, 13), Vector2i(10, 12), Nd)
	_to_box(a, m + Vector2i(0, -1), 5)
	a.step(10.0)
	_check("an adder fed on A alone makes nothing and starves on B", a.made == 0 and a.starving(Sim._i(m)) == 1)
	_dig1(a, Vector2i(11, 14), 1)
	_run(a, Vector2i(11, 13), Vector2i(11, 12), Nd)
	a.step(10.0)
	_check("fed on both it works and starves no more", a.starving(Sim._i(m)) == -1 and bool(a.machines[Sim._i(m)].has_last))
	# twenty non-targets with no hit: the box says so once
	var o = _blank(2)
	o.dep[Sim._i(Vector2i(51, 58))] = 1
	o.place(Sim.DIG, Vector2i(51, 58), E)
	_run(o, Vector2i(53, 58), Vector2i(56, 58), E)
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
	_route(s, [Vector2i(10, 40), Vector2i(56, 40), Vector2i(56, 58), Vector2i(57, 58)])
	s.step(60.0)
	_check("a crate lets its number out to the box", s.held(1) > 10)

func _stall() -> void:
	var s = _blank()
	var m := _two_digs(s, Sim.ADD, 1, 1, false)
	# the run north of the machine leads nowhere: it fills and the adder stops
	s.step(200.0)
	var mm: Dictionary = s.machines[Sim._i(m)]
	_check("a full output stops the machine: %d out, %d a side" % [(mm.out as Array).size(), (mm.a as Array).size()], (mm.out as Array).size() == Sim.OUT and (mm.a as Array).size() == Sim.QUEUE)
	s.remove(Vector2i(10, 7))
	_check("a lifted belt drops its token", s.occ[Sim._i(Vector2i(10, 7))] == 0)

func _ladder() -> void:
	var s = Sim.new(3)
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
	_check("level 23 hands over 16, level 67 hands over 60", s.reward_of(23) == -16 and s.reward_of(67) == -60 and s.reward_of(68) == 0)
	_check("counts stop at %d" % Sim.COUNT_TOP, s.count_of(200) == Sim.COUNT_TOP)

func _upgrades() -> void:
	var s = _blank(2)
	s.lv.belt = 1
	var asks: Array = s.asks("belt")
	_check("the belt's first rank asks for 40 1s (%s)" % str(asks), asks == [[1, 40]])
	_check("short of it, nothing is bought", not s.buy("belt"))
	s.ledger[1] = 45
	_check("with 45 1s the belt is bought", s.buy("belt") and int(s.lv.belt) == 2)
	_check("5 1s are left", s.held(1) == 5)
	_check("belt level 2 runs 2 a second", s.belt_speed() == 2.0)
	_check("rank two asks two numbers, rank three three", s.asks("belt").size() == 2)
	s.lv.belt = 3
	_check("rank three asks three", s.asks("belt").size() == 3)
	_check("the multiplier's track is shut before level 8", not s.track_open("mul"))
	_check("the speeds' tops: belt 20, adder 4, others 3", absf(Sim.speed_for("belt", 128) - 20.0) < 0.001 and absf(Sim.speed_for("add", 108) - 4.0) < 0.001 and absf(Sim.speed_for("mul", 108) - 3.0) < 0.001)
	_check("operators at level 8 do one a second", absf(Sim.speed_for("mul", 8) - 1.0) < 0.001 and absf(Sim.speed_for("mul", 7) - 0.8) < 0.001)
	s.lv.dig = 4
	_check("the dig stops at 4", s.at_top("dig") and not s.can_buy("dig"))

func _kept() -> void:
	var s = Sim.new(21)
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
	_check("a machine comes back whole", r.kind_at(Vector2i(1, 1)) == Sim.ADD and int(r.root[Sim._i(Vector2i(1, 1))]) == Sim._i(Vector2i(2, 2)) and r.machines.size() == 1)
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
		if Sim.is_op(s.kind_at(t)) and int(s.root[Sim._i(t)]) == Sim._i(t):
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
