extends SceneTree

## Proves Tally's paper headless. Run after touching arcade/tally_sim.gd.
##   godot --headless --script tests/_probe_tally.gd
## The paper's promises: numbers saturate at both ends, A ÷ 0 is (0, A) and a
## zero remainder is not put out, A^0 is 1 and a negative power 0; a dig on a
## belt to the box fills the belt at the belt's speed and no faster; a level
## counts only its target and hands over its reward; each operator takes A on
## its left and B on its right; a split shares evenly and a merge takes
## turns; a bridge carries both lanes across; a crate keeps one number; a
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
	_crate()
	_stall()
	_ladder()
	_upgrades()
	_kept()
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
	return s

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
	_check("six 1s within six squares of the box (%d, furthest %d)" % [ones, far_one], ones == 6 and far_one <= 6)
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
	var dig_at := Vector2i(14, 22)
	s.dep[Sim._i(dig_at)] = 1
	_check("a dig is refused off a number", not s.place(Sim.DIG, Vector2i(13, 22), E))
	_check("a dig goes on a 1 at level 1", s.place(Sim.DIG, dig_at, E))
	_run(s, Vector2i(15, 22), Vector2i(20, 22), E)
	_check("the run leads away from the dig", (s.digs[Sim._i(dig_at)].outs as PackedInt32Array).size() == 1)
	s.events.clear()
	s.step(8.0)
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

func _two_digs(s: RefCounted, k: int, va: int, vb: int, f := E) -> Vector2i:
	# the machine at (10, 10) facing east: A comes down from the north, B up from the south
	var m := Vector2i(10, 10)
	s.place(k, m, f)
	s.dep[Sim._i(Vector2i(10, 6))] = va
	s.dep[Sim._i(Vector2i(10, 14))] = vb
	s.place(Sim.DIG, Vector2i(10, 6), E)
	s.place(Sim.DIG, Vector2i(10, 14), E)
	_run(s, Vector2i(10, 7), Vector2i(10, 9), S)
	_run(s, Vector2i(10, 13), Vector2i(10, 11), Nd)
	_run(s, Vector2i(11, 10), Vector2i(20, 10), E)
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
		# the box is at x 21..24, so (20, 10) leads into nothing: end the run at the box's row
		_two_digs(s, int(row[0]), int(row[1]), int(row[2]))
		_run(s, Vector2i(21, 10), Vector2i(21, 20), S)
		s.step(40.0)
		_check("%s of %d and %d gives %d (had %s)" % [Sim.KIND_IDS[int(row[0])], row[1], row[2], row[3], str(_came(s))], _came(s) == [int(row[3])])
	# turned round, A and B change sides
	var s2 = _blank()
	var m := _two_digs(s2, Sim.SUB, 7, 3)
	s2.turn(m)
	s2.turn(m)
	_check("a machine faced away from its belt hands nothing on", s2.machines[Sim._i(m)].front == -1)
	var s3 = _blank()
	s3.place(Sim.SUB, Vector2i(10, 10), Wd)
	s3.dep[Sim._i(Vector2i(10, 6))] = 7
	s3.dep[Sim._i(Vector2i(10, 14))] = 3
	s3.place(Sim.DIG, Vector2i(10, 6), E)
	s3.place(Sim.DIG, Vector2i(10, 14), E)
	_run(s3, Vector2i(10, 7), Vector2i(10, 9), S)
	_run(s3, Vector2i(10, 13), Vector2i(10, 11), Nd)
	_run(s3, Vector2i(9, 10), Vector2i(4, 10), Wd)
	_run(s3, Vector2i(3, 10), Vector2i(3, 21), S)
	_run(s3, Vector2i(3, 22), Vector2i(20, 22), E)
	s3.step(60.0)
	_check("facing west, the north side is B: 3 - 7 = -4 (had %s)" % str(_came(s3)), _came(s3) == [-4])
	var s4 = _blank()
	_two_digs(s4, Sim.ADD, 1, 1)
	_run(s4, Vector2i(21, 10), Vector2i(21, 20), S)
	s4.step(60.0)
	var m0: int = s4.made
	s4.step(40.0)
	var rate := float(s4.made - m0) / 40.0
	_check("an adder at level 1 makes one in 4 s (%.2f a second)" % rate, absf(rate - 0.25) < 0.05)

func _divider() -> void:
	var s = _blank()
	_two_digs(s, Sim.DIV, 8, 2)
	_run(s, Vector2i(21, 10), Vector2i(21, 20), S)
	s.step(60.0)
	_check("8 ÷ 2 gives 4 and no 0 (had %s)" % str(_came(s)), _came(s) == [4])
	var s2 = _blank()
	var m := _two_digs(s2, Sim.DIV, 7, 2)
	_run(s2, Vector2i(21, 10), Vector2i(21, 20), S)
	s2.step(30.0)
	var mm: Dictionary = s2.machines[Sim._i(m)]
	_check("7 ÷ 2 with nothing behind for the remainder stops once two wait", (mm.rem as Array).size() == Sim.OUT and s2.held(3) <= 3)
	# the remainder taken off the back
	_run(s2, Vector2i(9, 10), Vector2i(4, 10), Wd)
	_run(s2, Vector2i(3, 10), Vector2i(3, 21), S)
	_run(s2, Vector2i(3, 22), Vector2i(20, 22), E)
	s2.step(60.0)
	_check("with the back taken: 3 and 1 both come (had %s)" % str(_came(s2)), _came(s2) == [1, 3])
	var s3 = _blank()
	var m3 := Vector2i(10, 10)
	s3.place(Sim.DIV, m3, E)
	var mm3: Dictionary = s3.machines[Sim._i(m3)]
	mm3.a.append(9)
	mm3.b.append(0)
	s3.step(6.0)
	_check("9 ÷ 0 puts out 0 forward and 9 back", mm3.out == [0] and mm3.rem == [9])

func _split_merge() -> void:
	var s = _blank()
	s.dep[Sim._i(Vector2i(5, 30))] = 1
	s.place(Sim.DIG, Vector2i(5, 30), E)
	_run(s, Vector2i(6, 30), Vector2i(12, 30), E)
	# a belt whose back touches (9, 30)'s side, going north
	_run(s, Vector2i(9, 29), Vector2i(9, 26), Nd)
	var main_end := Sim._i(Vector2i(12, 30))
	var side_end := Sim._i(Vector2i(9, 26))
	_check("the side belt is one of (9, 30)'s ends", (s.outs[Sim._i(Vector2i(9, 30))] as PackedInt32Array).size() == 2)
	# count what passes the two ends by watching them fill: both lead nowhere, so they stop
	s.step(30.0)
	var on_main := 0
	var on_side := 0
	for x in range(10, 13):
		on_main += s.occ[Sim._i(Vector2i(x, 30))]
	for y in range(26, 30):
		on_side += s.occ[Sim._i(Vector2i(9, y))]
	_check("both arms of a split fill (%d, %d)" % [on_main, on_side], on_main == 3 and on_side == 4)
	# a merge: two digs into one belt, a box at the end
	var m = _blank()
	m.dep[Sim._i(Vector2i(10, 30))] = 1
	m.dep[Sim._i(Vector2i(12, 34))] = 2
	m.place(Sim.DIG, Vector2i(10, 30), E)
	m.place(Sim.DIG, Vector2i(12, 34), E)
	_run(m, Vector2i(11, 30), Vector2i(21, 30), E)
	_run(m, Vector2i(22, 30), Vector2i(22, 25), Nd)
	_run(m, Vector2i(12, 33), Vector2i(12, 31), Nd)
	m.step(60.0)
	var r := float(m.held(1)) / maxf(1.0, float(m.held(2)))
	_check("a merge takes turns (%d 1s, %d 2s)" % [m.held(1), m.held(2)], r > 0.8 and r < 1.25)
	_check("a merged belt still runs full (%d in ~%d s)" % [m.made, 60 - 17], m.made >= 38)

func _bridge() -> void:
	var s = _blank(3)
	s.dep[Sim._i(Vector2i(5, 12))] = 1
	s.place(Sim.DIG, Vector2i(5, 12), E)
	_run(s, Vector2i(6, 12), Vector2i(20, 12), E)
	_run(s, Vector2i(12, 8), Vector2i(12, 16), S)
	_check("before bridges, crossing a belt turns it", s.kind_at(Vector2i(12, 12)) == Sim.BELT and s.face_at(Vector2i(12, 12)) == S)
	var b = _blank(6)
	b.dep[Sim._i(Vector2i(5, 12))] = 1
	b.dep[Sim._i(Vector2i(12, 4))] = 3
	b.place(Sim.DIG, Vector2i(5, 12), E)
	b.place(Sim.DIG, Vector2i(12, 4), E)
	_run(b, Vector2i(6, 12), Vector2i(19, 12), E)
	_run(b, Vector2i(20, 12), Vector2i(20, 21), S)
	_run(b, Vector2i(20, 22), Vector2i(20, 22), E)
	_run(b, Vector2i(12, 5), Vector2i(12, 23), S)
	_run(b, Vector2i(12, 24), Vector2i(20, 24), E)
	_check("a run across a belt makes a bridge", b.kind_at(Vector2i(12, 12)) == Sim.BRIDGE)
	b.step(60.0)
	_check("both lanes cross (%d 1s, %d 3s)" % [b.held(1), b.held(3)], b.held(1) > 20 and b.held(3) > 20)

func _crate() -> void:
	var s = _blank()
	s.dep[Sim._i(Vector2i(5, 40))] = 1
	s.dep[Sim._i(Vector2i(5, 42))] = 2
	s.place(Sim.DIG, Vector2i(5, 40), E)
	s.place(Sim.DIG, Vector2i(5, 42), E)
	_run(s, Vector2i(6, 40), Vector2i(8, 40), E)
	s.place(Sim.CRATE, Vector2i(9, 40), E)
	_run(s, Vector2i(6, 42), Vector2i(8, 42), E)
	_run(s, Vector2i(9, 42), Vector2i(9, 41), Nd)
	s.step(20.0)
	var c: Dictionary = s.crates[Sim._i(Vector2i(9, 40))]
	_check("a crate keeps the first number only (%d of %d)" % [int(c.n), int(c.v)], int(c.v) == 1 and int(c.n) > 10)
	_run(s, Vector2i(10, 40), Vector2i(20, 40), E)
	_run(s, Vector2i(21, 40), Vector2i(21, 25), Nd)
	s.step(60.0)
	_check("a crate lets its number out to the box", s.held(1) > 10)

func _stall() -> void:
	var s = _blank()
	var m := _two_digs(s, Sim.ADD, 1, 1)
	# the run east of the machine leads nowhere: it fills and the adder stops
	s.step(200.0)
	var mm: Dictionary = s.machines[Sim._i(m)]
	_check("a full output stops the machine: %d out, %d a side" % [(mm.out as Array).size(), (mm.a as Array).size()], (mm.out as Array).size() == Sim.OUT and (mm.a as Array).size() == Sim.QUEUE)
	s.remove(Vector2i(15, 10))
	_check("a lifted belt drops its token", s.occ[Sim._i(Vector2i(15, 10))] == 0)

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
	s.save()
	var r = Sim.load_saved()
	_check("a saved paper comes back: level, count, made", r.level == 9 and r.got == 33 and r.made == 1234)
	_check("its upgrades and tally", int(r.lv.belt) == 4 and r.held(19) == 50)
	_check("its pieces", r.kind_at(dig_at) == Sim.DIG and r.kind_at(Vector2i(2, 2)) == Sim.ADD and r.face_at(Vector2i(2, 2)) == S and r.kind_at(Vector2i(3, 0)) == Sim.BELT)
	_check("the same paper is printed", r.dep == s.dep and r.target_of(30) == s.target_of(30))
	_check("the card reads it", Sim.kept().level == 9)
