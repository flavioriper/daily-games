extends SceneTree

## Throwaway probe for core/cast.gd. Prints PASS or FAIL.
##   godot --headless --path . --script tests/_probe_cast.gd

var bad := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		bad += 1
		print("FAIL: ", what)

func _initialize() -> void:
	var el := Cast.eligible()
	print("eligible = ", el.size())
	var p := Cast.seeded(20261027)
	_check(p.size() == 2 and p[0] != p[1], "two distinct")
	_check(p[0] in el and p[1] in el, "eligible")
	_check(Cast.seeded(20261027) == p, "stable")
	_check(Cast.seeded(20261028) != p, "moves with the day")
	var vectors := {20261027: [14, 8], 20261028: [11, 20], 20261029: [42, 33]}
	for d in vectors:
		var got := Cast.seeded(d)
		print("cast vector ", d, " = ", got)
		_check(got == vectors[d], "vector %d" % d)
	# Published cast clamps; the field survives empty times.
	ThemedVistas.adopt({"v": 1, "theme": "t", "name": {"en": "T"}, "times": {}, "cast": [3, 99999]})
	var q := Cast.pair(Daily.date_key())
	print("published pair = ", q)
	_check(q[0] == 3 and q[1] == PeepletPersonas_count() - 1, "published clamps")
	_check(Cast.pair(20261027) == q, "published overrides the day arg")
	ThemedVistas.adopt({"v": 1, "times": {}, "cast": [1]})
	_check(ThemedVistas.cast().is_empty(), "malformed cast ignored")
	ThemedVistas.adopt({})
	_check(Cast.pair(20261027) == p, "no document falls back to seeded")
	ThemedVistas.adopt({"cast": [4, 5]})
	ThemedVistas.reload()
	# dress sets the three fields from the persona.
	var v := preload("res://ui/peeplet_view.gd").new()
	ThemedVistas.adopt({})
	Cast.dress(v, 1, 20261027)
	var pp := Cast.persona(1, 20261027)
	_check(v.color_index == int(pp["coat"]) and v.headgear == String(pp["hat"]) and v.eyewear == String(pp["eyes"]), "dress")
	v.free()
	print("PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)

func PeepletPersonas_count() -> int:
	return preload("res://peeplet/peeplet_personas.gd").count()
