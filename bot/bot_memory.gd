class_name BotMemory
extends RefCounted

## The player's memory, one JSON file on the phone (docs/agents/bot.md). The
## call server keeps nothing: BotCall sends `payload()` whole in the `hello`,
## and each `memory` frame the server emits during the call comes back through
## `apply`, which saves at once. Facts are {id, text, since}, episodes
## {id, summary, at}; the server never sends the stamps, so they are set here
## (UTC ISO, "Z"). A top-level `language` string, if the file has one, is kept
## through every save but is not part of `payload()` (the hello carries its own
## `language`; the server reads only `facts` and `episodes`).
##
## Loading drops the rows server/bot/memory/device.py `_items` would drop: no
## id, no text, or text over LIMIT. The file itself is uncapped (the server
## keeps only the newest MAX_FACTS and MAX_EPISODES of it per call).

const LIMIT := 300  # characters, as device.py LIMIT
const TMP_SUFFIX := ".tmp"

static var path := "user://bot_memory.json"


static func _empty() -> Dictionary:
	return {"facts": [], "episodes": []}


static func _ok(row: Variant, field: String) -> bool:
	if not (row is Dictionary):
		return false
	var id: Variant = row.get("id")
	var text: Variant = row.get(field)
	return id is String and id != "" and text is String and text.strip_edges() != "" and text.length() <= LIMIT


static func _rows(data: Variant, key: String, field: String, stamp: String) -> Array:
	var out: Array = []
	var rows: Variant = data.get(key) if data is Dictionary else null
	if not (rows is Array):
		return out
	for r in rows:
		if _ok(r, field):
			var s: Variant = r.get(stamp)
			out.append({"id": r["id"], field: r[field], stamp: s if s is String else ""})
	return out


static func load() -> Dictionary:
	return _read()


static func _read() -> Dictionary:
	var out := _empty()
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()  # parse() reports a bad file as an error code, without logging
	if json.parse(text) != OK:
		return out
	var data: Variant = json.data
	if not (data is Dictionary):
		return out
	out["facts"] = _rows(data, "facts", "text", "since")
	out["episodes"] = _rows(data, "episodes", "summary", "at")
	if data.get("language") is String:
		out["language"] = data["language"]
	return out


## What `hello` sends: only the two lists the server reads.
static func payload() -> Dictionary:
	var m := _read()
	return {"facts": m["facts"], "episodes": m["episodes"]}


## Atomic: write a sibling file, then rename over the old one, so a kill
## mid-write leaves the previous file whole.
static func _save(m: Dictionary) -> bool:
	var tmp := path + TMP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(m))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	return true


static func _now() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


static func _fit(text: String) -> String:
	var t := " ".join(text.split(" ", false)).strip_edges()
	return t.substr(0, LIMIT) if t.length() > LIMIT else t


static func _index(rows: Array, id: String) -> int:
	for i in rows.size():
		if rows[i]["id"] == id:
			return i
	return -1


## One `memory` frame {op, id, text}. add and update replace in place when the
## id exists (keeping `since`), else append; episode is the same upsert keyed
## by id (keeping `at`); forget drops the fact or episode with that id. A
## frame with no id, an unknown op, or empty text on a write is ignored.
static func apply(msg: Dictionary) -> void:
	var op: Variant = msg.get("op")
	var id: Variant = msg.get("id")
	if not (op is String) or not (id is String) or id == "":
		return
	if op == "forget":
		forget(id)
		return
	if op != "add" and op != "update" and op != "episode":
		return
	var raw: Variant = msg.get("text")
	var text := _fit(raw) if raw is String else ""
	if text == "":
		return
	var m := _read()
	var key := "episodes" if op == "episode" else "facts"
	var field := "summary" if op == "episode" else "text"
	var stamp := "at" if op == "episode" else "since"
	var rows: Array = m[key]
	var i := _index(rows, id)
	if i >= 0:
		rows[i][field] = text
	else:
		rows.append({"id": id, field: text, stamp: _now()})
	_save(m)


static func forget(id: String) -> void:
	var m := _read()
	var before: int = m["facts"].size() + m["episodes"].size()
	m["facts"] = m["facts"].filter(func(r): return r["id"] != id)
	m["episodes"] = m["episodes"].filter(func(r): return r["id"] != id)
	if m["facts"].size() + m["episodes"].size() != before:
		_save(m)


static func clear() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + TMP_SUFFIX))
