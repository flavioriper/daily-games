extends SceneTree

## Writes server/functions/src/cast_personas.json from peeplet/peeplet_personas.gd
## (name, coat, hat, eyes per persona, in ALL order), which the night job's
## cast (server/functions/src/cast.ts) reads: server/ is .gdignored, so the
## phone's list reaches it as this file. Run by hand when the list changes:
##   godot --headless --path . --script tools/export_personas.gd

const Personas := preload("res://peeplet/peeplet_personas.gd")


func _initialize() -> void:
	var out: Array = []
	for i in Personas.count():
		var p: Dictionary = Personas.get_persona(i)
		out.append({"name": p["name"], "coat": p["coat"], "hat": p["hat"], "eyes": p["eyes"]})
	var path := ProjectSettings.globalize_path("res://") + "server/functions/src/cast_personas.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("export_personas: cannot write " + path)
		quit(1)
		return
	f.store_string(JSON.stringify(out, "\t") + "\n")
	f.close()
	print("export_personas: %d personas -> %s" % [out.size(), path])
	quit()
