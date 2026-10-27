extends SceneTree

## Throwaway probe: server/functions/src/cast_personas.json matches
## PeepletPersonas.ALL entry by entry. Prints PASS or FAIL.
##   godot --headless --path . --script tests/_probe_cast_parity.gd

const Personas := preload("res://peeplet/peeplet_personas.gd")


func _initialize() -> void:
	var path := ProjectSettings.globalize_path("res://") + "server/functions/src/cast_personas.json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("FAIL: cannot read ", path)
		quit(1)
		return
	var got = JSON.parse_string(f.get_as_text())
	f.close()
	var bad := 0
	if not (got is Array):
		print("FAIL: not an array")
		quit(1)
		return
	if got.size() != Personas.count():
		print("FAIL: %d entries, expected %d" % [got.size(), Personas.count()])
		bad += 1
	for i in mini(got.size(), Personas.count()):
		var p: Dictionary = Personas.get_persona(i)
		var g: Dictionary = got[i]
		if g.get("name") != p["name"] or int(g.get("coat", -1)) != int(p["coat"]) \
				or g.get("hat") != p["hat"] or g.get("eyes") != p["eyes"]:
			print("FAIL: entry %d differs: %s vs %s" % [i, g, p["name"]])
			bad += 1
	print("PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
