extends SceneTree
## Throwaway probe for bot/bot_memory.gd.

const P := "user://_probe_bot_memory.json"
var _fails := 0


func _check(name: String, ok: bool, info := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (" + info + ")" if info != "" else ""))
	if not ok:
		_fails += 1


func _write(s: String) -> void:
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string(s)
	f.close()


func _cleanup() -> void:
	for p in [P, P + ".tmp"]:
		var g := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(g)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var saved := BotMemory.path
	BotMemory.path = P
	_cleanup()
	_body()
	_cleanup()
	BotMemory.path = saved
	print("FAILS: %d" % _fails)
	quit(1 if _fails else 0)


func _body() -> void:
	var m := BotMemory.load()
	_check("missing file -> empty shape", m == {"facts": [], "episodes": []}, str(m))
	BotMemory.apply({"op": "add", "id": "a", "text": "likes pears"})
	BotMemory.apply({"op": "update", "id": "a", "text": "likes plums"})
	BotMemory.apply({"op": "episode", "id": "e1", "text": "talked about the garden"})
	BotMemory.apply({"op": "add", "id": "b", "text": "has a cat"})
	BotMemory.apply({"op": "forget", "id": "b"})
	m = BotMemory.load()
	_check("one fact with updated text", m["facts"].size() == 1 and m["facts"][0]["text"] == "likes plums", str(m))
	_check("fact has since stamp", String(m["facts"][0]["since"]).ends_with("Z") and String(m["facts"][0]["since"]).length() >= 20, str(m["facts"]))
	_check("one episode", m["episodes"].size() == 1 and m["episodes"][0]["summary"] == "talked about the garden", str(m["episodes"]))
	_check("episode has at stamp", String(m["episodes"][0]["at"]).ends_with("Z"), str(m["episodes"]))
	_check("payload is facts+episodes only", BotMemory.payload().keys() == ["facts", "episodes"])
	_check("no tmp file left", not FileAccess.file_exists(P + ".tmp"))

	# add on existing id replaces, keeps since
	var since: String = m["facts"][0]["since"]
	BotMemory.apply({"op": "add", "id": "a", "text": "likes figs"})
	m = BotMemory.load()
	_check("add existing id replaces in place", m["facts"].size() == 1 and m["facts"][0]["text"] == "likes figs" and m["facts"][0]["since"] == since)

	# forget drops an episode with that id too
	BotMemory.forget("e1")
	m = BotMemory.load()
	_check("forget drops an episode", m["episodes"].is_empty() and m["facts"].size() == 1)

	# episode upsert keeps first `at`
	_write(JSON.stringify({"facts": [], "episodes": [{"id": "e", "summary": "first", "at": "2026-01-01T00:00:00Z"}]}))
	BotMemory.apply({"op": "episode", "id": "e", "text": "second"})
	m = BotMemory.load()
	_check("episode twice: one episode, second summary, first at", m["episodes"].size() == 1 and m["episodes"][0]["summary"] == "second" and m["episodes"][0]["at"] == "2026-01-01T00:00:00Z", str(m["episodes"]))

	# unknown op / bad frames ignored
	var before := FileAccess.get_file_as_string(P)
	BotMemory.apply({"op": "explode", "id": "x", "text": "t"})
	BotMemory.apply({"op": "add", "id": "", "text": "t"})
	BotMemory.apply({"op": "add", "id": "x", "text": "   "})
	BotMemory.apply({"op": "add", "id": 5, "text": "t"})
	BotMemory.apply({})
	_check("unknown op and bad frames ignored", FileAccess.get_file_as_string(P) == before)

	# hand-edited file with a bad row keeps the good ones
	_write(JSON.stringify({"language": "pt", "facts": [
		{"id": "g1", "text": "good", "since": "2026-02-02T00:00:00Z"},
		{"id": "", "text": "no id"},
		{"text": "missing id"},
		{"id": "g2", "text": "   "},
		{"id": "g3", "text": 5},
		{"id": "g4", "text": "x".repeat(301)},
		"junk",
		{"id": "g5", "text": "x".repeat(300)},
	], "episodes": [{"id": "ok", "summary": "fine"}, {"id": "bad"}, 7]}))
	m = BotMemory.load()
	_check("bad rows dropped, good kept", m["facts"].size() == 2 and m["facts"][0]["id"] == "g1" and m["facts"][1]["id"] == "g5" and m["episodes"].size() == 1, str(m["facts"].size()))
	_check("language passes through load but not payload", m.get("language") == "pt" and not BotMemory.payload().has("language"))
	BotMemory.apply({"op": "add", "id": "n", "text": "new"})
	_check("language survives a save", BotMemory.load().get("language") == "pt")

	# garbage
	for junk in ["not json {{{", "[1,2,3]", "\"str\"", "", "null", "{\"facts\": 5, \"episodes\": {}}"]:
		_write(junk)
		_check("garbage '%s' -> empty shape" % junk.left(12), BotMemory.load() == {"facts": [], "episodes": []})
	_write("not json")
	BotMemory.apply({"op": "add", "id": "r", "text": "recovered"})
	_check("apply on a corrupt file starts clean", BotMemory.load()["facts"].size() == 1)

	BotMemory.clear()
	_check("clear removes the file", not FileAccess.file_exists(P) and BotMemory.load() == {"facts": [], "episodes": []})
