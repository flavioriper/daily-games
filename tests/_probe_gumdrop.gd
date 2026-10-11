extends SceneTree

## Proves what of Gumdrop runs headless. Run after touching
## arcade/gumdrop_sim.gd or arcade/gumdrop_mould.gd.
##   godot --headless --script tests/_probe_gumdrop.gd
## The syrup itself is a fluid on the GPU since 2026-10-11
## (arcade/gumdrop_fluid.gd) and cannot run here: tests/_shot_gumdrop.gd
## plays it windowed with a bot that reads the fluid back. Here: every
## design is built and its cells counted; the colour maths the judge's
## shader carries word for word (the hue of two pigments is the flavour
## between, the strength climbs to the card's shade and no further, past
## it the colour deepens and matches less, a pale lemon and a pale cherry
## are judged alike); the run (a mould served asks to be judged, the
## verdict follows the answer, under the mark the run is over, the mark
## climbs 60 to 80); the boosters and the Second chance.

const Sim = preload("res://arcade/gumdrop_sim.gd")
const Mould = preload("res://arcade/gumdrop_mould.gd")
const Boosters = preload("res://arcade/boosters.gd")

var _fails := 0

func _initialize() -> void:
	_designs()
	_colour()
	_run()
	_kit()
	print("%d failed" % _fails)
	quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1

func _designs() -> void:
	var least := 9999
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for row: Array in Mould.DESIGNS:
		var m := Mould.build(row[0], row[1], row[2])
		if m.is_empty():
			_check("design %s builds" % str(row), false)
			continue
		Mould.dress(m, 9, rng)
		var s = Sim.new(1)
		s.deal(m)
		var small := 9999
		var all := 0
		for c in s.count.size():
			small = mini(small, s.count[c])
			all += s.count[c]
		least = mini(least, small)
		print("     design %s: %d cells, %d squares, the smallest %d" % [str(row), s.count.size(), all, small])
	_check("every design's smallest cell has 12 squares or more (%d)" % least, least >= 12)
	var s = Sim.new(2)
	var starts_in: bool = s.tip_cell() == 0
	s.aim(Vector2(1, 1))
	_check("the tip starts in a cell, and over the tray's corner it is in none", starts_in and s.tip_cell() == -1)

func _colour() -> void:
	var F := Mould.Flavour
	var full := Sim.C_FULL
	var orange := Sim.colour(full * 0.5, full * 0.5, 0.0)
	_check("cherry and lemon half and half are orange (%.2f)" % Sim.nearness(orange, F.ORANGE), Sim.nearness(orange, F.ORANGE) >= 0.95)
	var lime := Sim.colour(0.0, full * 0.5, full * 0.5)
	_check("lemon and blueberry are lime (%.2f)" % Sim.nearness(lime, F.LIME), Sim.nearness(lime, F.LIME) >= 0.95)
	_check("at the card's shade a flavour matches itself (%.2f)" % Sim.nearness(Sim.colour(full, 0, 0), F.CHERRY), Sim.nearness(Sim.colour(full, 0, 0), F.CHERRY) >= 0.99)
	var climbs := true
	var last := -1.0
	for k in 20:
		var s := Sim.strength(k * 0.1)
		climbs = climbs and s >= last
		last = s
	_check("the strength climbs with the pigment to the card's shade and no further (%.2f at 1.9)" % last, climbs and is_equal_approx(last, 1.0))
	var dark := Sim.nearness(Sim.colour(full * 2.0, 0, 0), F.CHERRY)
	_check("twice the shade is deeper and matches less (%.2f)" % dark, dark < 0.95 and dark > 0.7)
	var pale_c := Sim.nearness(Sim.colour(full * 0.3, 0, 0), F.CHERRY)
	var pale_l := Sim.nearness(Sim.colour(0, full * 0.3, 0), F.LEMON)
	_check("a pale cherry and a pale lemon are judged alike (%.2f, %.2f)" % [pale_c, pale_l], absf(pale_c - pale_l) < 0.03)
	_check("clear jelly matches nothing", Sim.nearness(Sim.colour(0, 0, 0), F.CHERRY) == 0.0)

## Serves the mould and answers the judge with `pct` for every cell.
func _serve_as(s: RefCounted, pct: float) -> Dictionary:
	s.squeeze(true)
	for i in 6:
		s.step()
	s.squeeze(false)
	s.serve()
	var tally := {}
	var guard := 0
	while s.phase == Sim.Phase.SETTLE and guard < 200:
		guard += 1
		s.step()
		for ev: Dictionary in s.events:
			tally[ev.type] = int(tally.get(ev.type, 0)) + 1
			if ev.type == "judge":
				var near := PackedFloat32Array()
				near.resize(s.count.size())
				near.fill(pct)
				s.judge(near, pct)
		s.events.clear()
	for i in int(Sim.SHOW_T / Sim.DT) + 2:
		s.step()
	for ev: Dictionary in s.events:
		tally[ev.type] = int(tally.get(ev.type, 0)) + 1
	s.events.clear()
	return tally

func _run() -> void:
	var s = Sim.new(7)
	s.events.clear()
	_check("nothing to serve until something is squeezed", not s.can_serve())
	var tally := _serve_as(s, 0.86)
	_check("a mould served asks to be judged once and the verdict follows (%s)" % str(tally), int(tally.get("judge", 0)) == 1 and int(tally.get("served", 0)) == 1)
	_check("86%% over a mark of 60 is 86 points and the next mould (%d, level %d)" % [s.score, s.level], s.score == 86 and s.level == 2 and s.phase == Sim.Phase.PLAY)
	tally = _serve_as(s, 0.97)
	_check("97%% is perfect: 97 and %d more (%d)" % [Sim.PERFECT_BONUS, s.score], s.score == 86 + 97 + Sim.PERFECT_BONUS and s.perfects == 1)
	var marks := []
	for lv in [1, 2, 11, 12, 30]:
		marks.append(Sim.mark_of(lv))
	_check("the mark climbs 60 to 80 (%s)" % str(marks), marks == [60, 62, 80, 80, 80])
	s.level = 10
	var had: int = s.score
	tally = _serve_as(s, 0.5)
	_check("50%% under the mark is worth nothing and ends the run (%d, over %s)" % [s.score, str(s.is_over())], s.score == had and s.is_over() and int(tally.get("over", 0)) == 1)

func _kit() -> void:
	var s = Sim.new(9)
	var plain: int = s.mark()
	Boosters.apply("gumdrop", s, ["gd_soft", "gd_kind"])
	_check("softer jelly, kinder marks", s.soft and s.mark() == plain - Sim.KINDER)
	s.filled(0, 0, 1.0)
	_check("a tutorial page's cell is coloured through the prefill", s.prefill.size() == 1 and s.wet())
	_serve_as(s, 0.1)
	_check("a mould served nearly clear ends the run", s.is_over())
	var had: int = s.score
	Boosters.revive("gumdrop", s)
	_check("the Second chance clears the mould", not s.is_over() and not s.wet() and s.score <= had)
