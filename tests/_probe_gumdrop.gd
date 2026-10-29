extends SceneTree

## Proves what of Gumdrop runs headless. Run after touching
## puzzles/gumdrop_sim.gd or puzzles/gumdrop_mould.gd.
##   godot --headless --script tests/_probe_gumdrop.gd
## The syrup itself is a fluid on the GPU (puzzles/gumdrop_fluid.gd) and
## cannot run here: tests/_shot_gumdrop.gd plays it windowed with a bot
## that reads the fluid back. Here: every picture is built and its parts
## counted; the colour maths the judge's shader carries word for word; a
## band's day (how many moulds, the same off the same seed, what stands by
## the tray, every wanted flavour makeable from the pots); and the day's
## run with the judge answered by hand (nothing served until every chunk
## has colour, every mould served is taken away with its tier and the last
## is the day done, a chunk held to the card's shade lands once, Insane the
## same, a finished day put back); and the themed jellies the night wrote
## for the days in tools/days/themed-pixel/ (server/functions/src/jelly.ts):
## each kept one keeps its band's row here too, and is dealt first.

const Sim = preload("res://puzzles/gumdrop_sim.gd")
const Mould = preload("res://puzzles/gumdrop_mould.gd")

var _fails := 0

func _initialize() -> void:
	_designs()
	_colour()
	_days()
	_run()
	_insane()
	_themed()
	_why()
	print("%d failed" % _fails)
	quit(1 if _fails > 0 else 0)

## Made fun (2026-10-29): what the serve's toast and the bulb say of a
## chunk, from its pigments; and runs of Great serves.
func _why() -> void:
	var full: float = Sim.C_FULL
	_check("an orange of cherry and lemon half each, full, reads right",
		String(Sim.why(Vector3(0.5, 0.5, 0) * full, 1).kind) == "ok")
	var mix: Dictionary = Sim.why(Vector3(0.85, 0.15, 0) * full, 1)
	_check("an orange heavy on cherry reads too much cherry, not enough lemon",
		String(mix.kind) == "mix" and int(mix.over) == 0 and int(mix.under) == 1)
	_check("a lime at a third of its shade reads pale", String(Sim.why(Vector3(0, 0.5, 0.5) * full * 0.33, 3).kind) == "pale")
	_check("an empty chunk reads dry", String(Sim.why(Vector3.ZERO, 0).kind) == "dry")
	var s = Sim.new()
	s.marks = [70, 85, 96, 99, 60, 90]
	_check("runs of Great: the last 1, the best 3", s.run() == 1 and s.best_run() == 3)

func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1

func _designs() -> void:
	var least := 9999
	var whole := true
	var most := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for id: String in Mould.PICTURES:
		var m := Mould.build(id)
		if m.is_empty():
			_check("picture %s builds" % id, false)
			continue
		Mould.dress(m, Mould.Stood.ONE_MIXED, rng)
		var s = Sim.new()
		s.deal(m)
		var small := 9999
		var all := 0
		for c in s.count.size():
			small = mini(small, s.count[c])
			all += s.count[c]
		least = mini(least, small)
		most = maxi(most, s.count.size())
		whole = whole and int(m.pieces) == 1
		var box := Rect2(m.outline[0], Vector2.ZERO)
		for q: Vector2 in m.outline:
			box = box.expand(q)
		whole = whole and Rect2(3, 3, 94, 94).encloses(box)
		print("     %s: %d parts in %s, %d squares, the smallest %d, %d piece(s), pots %s%s" % [id, s.count.size(), str(Mould.flavours(m)), all, small, int(m.pieces), str(m.pots), "" if m.mixed < 0 else " (mixes %d)" % m.mixed])
	_check("every picture is one piece of jelly on the tray, %d parts at the most" % most, whole and most <= Mould.CELLS_TOP)
	_check("every picture's smallest part shows 9 squares or more (%d)" % least, least >= 9)
	var s = Sim.new()
	var starts_in: bool = s.tip_cell() >= 0
	s.aim(Vector2(1, 1))
	_check("the tip starts in the jelly, and over the tray's corner it is in none", starts_in and s.tip_cell() == -1)

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
	# it matched less until the judge was given an eye's tolerance (NEAR_FREE):
	# the tip stops at 1.6 times the shade, and nothing it pours reads dark
	_check("twice the shade is deeper, and the eye still calls it the card's (%.2f)" % dark, dark > 0.95)
	var pale_c := Sim.nearness(Sim.colour(full * 0.3, 0, 0), F.CHERRY)
	var pale_l := Sim.nearness(Sim.colour(0, full * 0.3, 0), F.LEMON)
	_check("a pale cherry and a pale lemon are judged alike (%.2f, %.2f)" % [pale_c, pale_l], absf(pale_c - pale_l) < 0.03)
	_check("clear jelly matches nothing", Sim.nearness(Sim.colour(0, 0, 0), F.CHERRY) == 0.0)

## A trace of syrup squeezed into every chunk, so the mould can be served.
func _wet_all(s: RefCounted) -> void:
	for c in s.count.size():
		s.aim(s.centre_of(c))
		s.squeeze(true)
		for i in 6:
			s.step()
		s.squeeze(false)

## Colours every chunk, serves the mould and answers the judge with `pct` for every cell.
func _serve_as(s: RefCounted, pct: float) -> Dictionary:
	_wet_all(s)
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

func _day(band: int, seed_value: int) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var s = Sim.new()
	s.deal_day(band, rng)
	s.events.clear()
	return s

func _days() -> void:
	for band in 4:
		var spec: Dictionary = Mould.BANDS[band]
		var ok := true
		var makeable := true
		var cells := []
		var pots_most := 0
		var mixed_least := 99
		for seed_value in 200:
			var s = _day(band, seed_value)
			ok = ok and s.moulds.size() == int(spec.moulds)
			for m: Dictionary in s.moulds:
				cells.append(m.cells.size())
				pots_most = maxi(pots_most, m.pots.size())
				var mixed := 0
				for f: int in m.want:
					var recipe: Dictionary = Mould.recipe(f, m.pots)
					for pot: int in recipe:
						makeable = makeable and m.pots.has(pot)
					if recipe.size() > 1:
						mixed += 1
				mixed_least = mini(mixed_least, mixed)
		_check("band %d: %d moulds on every one of 200 days, %d to %d cells, %d pots at most" % [band, int(spec.moulds), cells.min(), cells.max(), pots_most],
			ok and pots_most <= [2, 4, 4, 3][band])
		_check("band %d: every wanted flavour is a pot or its two neighbours, both stood by the tray" % band, makeable)
		if band < 1:
			_check("band %d: nothing to mix" % band, mixed_least == 0)
		if band == 3:
			_check("Three Pots: only the pigments stand by the tray and a cell or more is mixed (least %d)" % mixed_least, mixed_least >= 1)
	var a = _day(2, 77)
	var b = _day(2, 77)
	var same: bool = a.moulds.size() == b.moulds.size()
	for i in a.moulds.size():
		same = same and a.moulds[i].want == b.moulds[i].want and a.moulds[i].pots == b.moulds[i].pots \
			and String(a.moulds[i].id) == String(b.moulds[i].id)
	_check("the same seed deals the same day", same)

func _run() -> void:
	var s = _day(0, 7)
	_check("nothing to serve until every piece has colour", not s.can_serve())
	s.squeeze(true)
	for i in 6:
		s.step()
	s.squeeze(false)
	_check("one wet chunk is not enough to serve", not s.can_serve() and s.wet())
	_wet_all(s)
	_check("every chunk wet: it can be served", s.can_serve())
	var first: Dictionary = s.mould
	var tally := _serve_as(s, 0.3)
	_check("a mould served at 30%% is taken away all the same, tier 0 (%s)" % str(tally), s.index == 1 and not is_same(s.mould, first) and int(tally.get("deal", 0)) == 1 and int(s.verdict.tier) == 0 and int(tally.get("again", 0)) == 0)
	_wet_all(s)
	tally = _serve_as(s, 0.97)
	_check("the last mould served is the day done (%s)" % str(s.marks), s.is_done() and int(tally.get("done", 0)) == 1 and s.marks == [30, 97] and s.serves == 2 and int(s.verdict.tier) == 2)
	_check("tiers: 79 served, 80 great, 94 great, 95 perfect", Sim.tier(79) == 0 and Sim.tier(80) == 1 and Sim.tier(94) == 1 and Sim.tier(95) == 2)
	var back = _day(0, 7)
	back.finish([30, 97])
	_check("a finished day put back keeps a 30 and passes", back.is_done() and back.marks == [30, 97] and bool(back.verdict["pass"]) and int(back.verdict.tier) == 2)
	# the landing
	var l = _day(0, 7)
	l.aim(l.centre_of(0))
	l.squeeze(true)
	var lands := 0
	for i in 240:
		l.step()
		for ev: Dictionary in l.events:
			if ev.type == "land":
				lands += 1
		l.events.clear()
	_check("a chunk held to the card's shade lands once (%d)" % lands, lands == 1)
	l.squeeze(false)
	l.drain(true)
	for i in 60:
		l.step()
	l.drain(false)
	l.squeeze(true)
	for i in 240:
		l.step()
		for ev: Dictionary in l.events:
			if ev.type == "land":
				lands += 1
		l.events.clear()
	_check("drained under the re-arm and poured again, it lands again (%d)" % lands, lands == 2)
	# inside the band: drained to between LAND_REARM and LAND it is still
	# landed, and squeezed again it does not land a second time
	var h = _day(0, 7)
	h.aim(h.centre_of(0))
	h.squeeze(true)
	var h_lands := 0
	for i in 240:
		h.step()
		for ev: Dictionary in h.events:
			if ev.type == "land":
				h_lands += 1
		h.events.clear()
	h.squeeze(false)
	h.drain(true)
	var guard := 0
	while h.tank[0] >= 0.92 * Sim.C_FULL and guard < 600:
		guard += 1
		h.step()
	h.drain(false)
	var low: float = h.tank[0]
	h.squeeze(true)
	for i in 240:
		h.step()
		for ev: Dictionary in h.events:
			if ev.type == "land":
				h_lands += 1
		h.events.clear()
	_check("drained only to %.2f of the shade (over the re-arm) and poured again, it does not land again (%d)" % [low / Sim.C_FULL, h_lands], h_lands == 1 and low >= Sim.LAND_REARM * Sim.C_FULL and low < Sim.LAND * Sim.C_FULL)
	var p = _day(0, 7)
	p.filled(0, int(p.mould.want[0]), 1.2)
	p.aim(p.centre_of(0))
	p.squeeze(true)
	var p_lands := 0
	for i in 60:
		p.step()
		for ev: Dictionary in p.events:
			if ev.type == "land":
				p_lands += 1
		p.events.clear()
	_check("a prefilled cell squeezed again never lands (%d)" % p_lands, p_lands == 0)

func _insane() -> void:
	# a serve never fails since 2026-10-26 (spec 2026-10-26-gumdrop-fun):
	# every mould served is taken away, whatever it scored
	var s = _day(3, 11)
	_serve_as(s, 0.3)
	s.restart()
	_check("Reset is the day from its first mould, the serves from zero", s.index == 0 and s.serves == 0 and s.marks.is_empty())
	for i in s.moulds.size():
		_serve_as(s, 0.3)
	_check("Insane: five moulds at 30%% are the day done in five serves (%d)" % s.serves, s.is_done() and s.serves == 5 and s.moulds.size() == 5)

func _themed() -> void:
	var dir := "res://tools/days/themed-pixel/"
	var seen := 0
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"):
			continue
		var day = JSON.parse_string(FileAccess.get_file_as_string(dir + f))
		if not day is Dictionary or not day.get("pictures") is Dictionary or not day.pictures.get("jellies") is Dictionary:
			continue
		for key: String in day.pictures.jellies:
			var band := int(key)
			var built: Array = []
			for j: Dictionary in day.pictures.jellies[key]:
				var m := Mould.build_parts("themed_" + String(j.id), Mould.from_doc(j.parts))
				var why := Mould.unfit(m, band)
				# Medium asks for a mixed flavour since 2026-10-29: a night
				# written before that may lack one, and is turned down for
				# the pictures (which mix), as any unfit jelly is
				var older: bool = band == 1 and why == "too few mixed flavours" and f.get_basename() < "20261030"
				_check("%s band %d: the night's %s keeps its row here (%s)" % [f.get_basename(), band, j.id, why if why != "" else "%d chunks, %d cells" % [int(m.laid), (m.cells as Array).size()]], why == "" or older)
				if why == "":
					built.append(m)
			if built.is_empty():
				continue
			seen += built.size()
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			var s = Sim.new()
			s.deal_day(band, rng, built)
			var ids: Array = s.moulds.map(func(x: Dictionary) -> String: return String(x.id))
			var once := ids.all(func(i: String) -> bool: return ids.count(i) == 1 and not ids.has("themed_" + i))
			var lead := true
			for k in mini(built.size(), s.moulds.size()):
				lead = lead and s.moulds[k] == built[k] and not (built[k].pots as Array).is_empty()
			_check("  %d of %d moulds themed, first and in order, no picture twice (%s)" % [mini(built.size(), s.moulds.size()), int(Mould.BANDS[band].moulds), ", ".join(ids)],
				lead and s.moulds.size() == int(Mould.BANDS[band].moulds) and once)
			# by the night's chunks: a piece a later chunk cuts off is a
			# cell of its own here, and may be small
			var least := 9999
			var small := 9999
			for m: Dictionary in built:
				s.deal(m)
				var by_source := PackedInt32Array()
				by_source.resize(int(m.laid))
				for c in s.count.size():
					by_source[m.source[c]] += s.count[c]
					small = mini(small, s.count[c])
				for k in by_source:
					least = mini(least, k)
			_check("  the sim counts every chunk of the night's 9 squares or more (%d; the smallest cell cut %d)" % [least, small], least >= 9)
	# tools/days/ is not in git: a clone with no made days skips them
	if seen == 0:
		print("     no made day holds themed jellies here (tools/days/themed-pixel/, node lib/cli.js jellies)")
	_check("a part that is not one is no jelly", Mould.from_doc([{"flavour": "mint", "shapes": [{"kind": "ell", "n": [50, 50, 20, 20]}]}]).is_empty()
		and Mould.from_doc([{"flavour": "cherry", "shapes": [{"kind": "ell", "n": [50, 50]}]}]).is_empty() and Mould.from_doc("x").is_empty())
	var off := Mould.build_parts("themed_x", Mould.from_doc([{"flavour": "cherry", "shapes": [{"kind": "ell", "n": [50, 50, 40, 40]}]}, {"flavour": "lemon", "shapes": [{"kind": "ell", "n": [50, 50, 10, 10]}]}]))
	_check("an Easy jelly of two flavours keeps Easy (%s) and not Medium (%s)" % [Mould.unfit(off, 0), Mould.unfit(off, 1)], Mould.unfit(off, 0) == "" and Mould.unfit(off, 1) != "")
