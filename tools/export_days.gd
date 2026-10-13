extends SceneTree

## Deals every board's day as the game does and writes what was dealt, one
## day document a board, date and level, for tools/dashboard.src.html
## (docs/superpowers/specs/2026-10-13-day-documents-dashboard-design.md).
##
##     godot --headless --path . --script res://tools/export_days.gd -- \
##         from=2026-10-13 days=30 [boards=sudoku,binairo] [levels=0,1,2,3]
##
## A board is instanced under the root and started with the seed the host
## mixes (ui/flat/flat_host.gd: seed_for(seed_as or id, level)), so its own
## level table deals; its day_dict() says what came out. Nothing here starts
## Analytics, Backend or Ads, and Progress is pointed at a harness file.

const Daily = preload("res://core/daily.gd")
const OUT := "res://tools/days/"
## Frames a board is given after start() before it is read, and how long one
## that answers {"pending": true} is waited for.
const SETTLE := 3
const PATIENCE := 240

var _jobs: Array = []
var _at := 0
var _board: Node
var _job: Dictionary
var _frames := 0
var _t0 := 0
var _docs: Dictionary = {}
var _dates: Array = []
var _levels: Array = [0, 1, 2, 3]
var _errors := 0
var _warm: Dictionary = {}

func _initialize() -> void:
	var from := Time.get_date_string_from_system(true)
	var days := 14
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"from": from = kv[1]
			"days": days = int(kv[1])
			"boards": only = Array(kv[1].split(","))
			"levels":
				_levels = []
				for l in kv[1].split(","):
					_levels.append(int(l))
	var progress = load("res://core/progress.gd")
	progress.path = "user://progress_harness.cfg"
	var start := int(Time.get_unix_time_from_datetime_string(from + "T00:00:00"))
	for i in days:
		_dates.append(Time.get_datetime_dict_from_unix_time(start + i * 86400))
	for e in load("res://ui/registry.gd").all():
		if not e.has("script") or e.get("soon", false):
			continue
		if not only.is_empty() and not only.has(String(e.id)):
			continue
		_docs[String(e.id)] = []
		for dt in _dates:
			for level in _levels:
				if (e.get("difficulties", [0, 1, 2, 3]) as Array).has(level):
					_jobs.append({"entry": e, "dt": dt, "level": level})
	print("export_days: %d documents" % _jobs.size())

func _process(_delta: float) -> bool:
	if _board == null:
		if _at >= _jobs.size():
			_write()
			return true
		_job = _jobs[_at]
		_at += 1
		_open()
		return false
	_frames += 1
	if _frames < SETTLE:
		return false
	var got: Dictionary = _board.day_dict() if is_instance_valid(_board) else {"error": "the board went away"}
	if got.get("pending", false) and _frames < PATIENCE:
		return false
	_close(got)
	return false

func _open() -> void:
	var e: Dictionary = _job.entry
	var dt: Dictionary = _job.dt
	var unix := int(Time.get_unix_time_from_datetime_dict(dt))
	load("res://core/insane_bank.gd").day_override = unix / 86400
	var the_seed := Daily.seed_for(String(e.get("seed_as", e.id)), _job.level, dt)
	_job["seed"] = the_seed
	var rng := RandomNumberGenerator.new()
	# A board's first deal pays for its scripts and banks being read: one is
	# dealt and thrown away, so gen_ms is the deal's own.
	if not _warm.has(e.id):
		_warm[e.id] = true
		var first: Node = (load(e.script) as GDScript).new()
		root.add_child(first)
		rng.seed = the_seed
		first.start(rng, _job.level)
		first.queue_free()
	_board = (load(e.script) as GDScript).new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_board)
	rng.seed = the_seed
	_board.bank_step = 0
	_t0 = Time.get_ticks_usec()
	_board.start(rng, _job.level)
	_job["gen_ms"] = (Time.get_ticks_usec() - _t0) / 1000.0
	_board.daily_key = Daily.date_key(dt)
	_frames = 0

func _close(got: Dictionary) -> void:
	var e: Dictionary = _job.entry
	var doc := {
		"board": String(e.id),
		"seed_as": String(e.get("seed_as", e.id)),
		"date": Daily.date_key(_job.dt),
		"level": _job.level,
		"seed": _job.seed,
		"gen_ms": snappedf(_job.gen_ms, 0.1),
	}
	if got.is_empty():
		doc["error"] = "no day_dict"
	elif got.get("pending", false):
		doc["error"] = "the deal never landed"
	doc.merge(_plain(got))
	doc.erase("pending")
	if doc.has("error"):
		_errors += 1
	_docs[String(e.id)].append(doc)
	if is_instance_valid(_board):
		_board.queue_free()
	_board = null

## Godot's own types as JSON has them: vectors as arrays, packed arrays as
## arrays, anything else by its string.
func _plain(v):
	match typeof(v):
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = _plain(v[k])
			return d
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY:
			var a := []
			for x in v:
				a.append(_plain(x))
			return a
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [v.x, v.y]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [v.x, v.y, v.z]
		TYPE_VECTOR4, TYPE_VECTOR4I:
			return [v.x, v.y, v.z, v.w]
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return v
		TYPE_STRING_NAME:
			return String(v)
	return str(v)

func _write() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var boards: Array = []
	for e in load("res://ui/registry.gd").all():
		var id := String(e.id)
		if not _docs.has(id):
			continue
		boards.append({"id": id, "title": String(e.get("title", id)), "levels": e.get("levels", [])})
		var f := FileAccess.open(OUT + id + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify(_docs[id]))
		f.close()
	var dates: Array = []
	for dt in _dates:
		dates.append(Daily.date_key(dt))
	var head: Array = []
	OS.execute("git", ["rev-parse", "--short", "HEAD"], head)
	var index := FileAccess.open(OUT + "index.json", FileAccess.WRITE)
	index.store_string(JSON.stringify({
		"boards": boards, "dates": dates, "levels": _levels,
		"exported": Time.get_datetime_string_from_system(true),
		"commit": String(head[0]).strip_edges() if not head.is_empty() else "",
	}))
	index.close()
	_gallery()
	print("export_days: %d documents, %d with an error, in %s" % [_jobs.size(), _errors, OUT])

## Every picture the picture boards deal from, for the page's Gallery: the
## bead bank's four bands (Pixel Garden, Button Box, Toy Cannons), Button
## Box's own Hard band, and Gumdrop's moulds, each with the levels that read
## it. The colours are the game's (Palette.PG_BEADS, Sim.FLAVOURS).
func _gallery() -> void:
	var beads := {}
	var named: Dictionary = load("res://core/palette.gd").PG_BEADS
	var sets: Array = []
	var bank = JSON.parse_string(FileAccess.get_file_as_string("res://content/pixel_garden.json"))
	if bank is Dictionary:
		for ch in bank.palette:
			beads[ch] = "#" + (named.get(bank.palette[ch], Color.MAGENTA) as Color).to_html(false)
		# The levels that read a band: Pixel Garden its own, Button Box its own
		# but Hard, Toy Cannons by Train's BANDS.
		var train: Array = load("res://puzzles/train_state.gd").BANDS
		for k in (bank.bands as Array).size():
			var users: Array = [["pixelgarden", k]]
			if k != 2:
				users.append(["buttons", k])
			for level in train.size():
				if int(train[level]) == k:
					users.append(["train", level])
			var side := (bank.bands[k][0].rows as Array).size() if not (bank.bands[k] as Array).is_empty() else 0
			sets.append({"title": "Bead bank, %d × %d" % [side, side], "file": "content/pixel_garden.json, band %d" % k,
				"kind": "pixels", "users": users, "pictures": _pixel_pictures(bank.bands[k])})
	var hard = JSON.parse_string(FileAccess.get_file_as_string("res://content/buttons_hard.json"))
	if hard is Dictionary:
		sets.append({"title": "Button Box Hard, 16 × 16", "file": "content/buttons_hard.json", "kind": "pixels",
			"users": [["buttons", 2]], "pictures": _pixel_pictures(hard.pictures)})
	var mould = load("res://puzzles/gumdrop_mould.gd")
	var flavours: Array = []
	for c: Color in load("res://puzzles/gumdrop_sim.gd").FLAVOURS:
		flavours.append("#" + c.to_html(false))
	var shapes: Array = []
	for r in (mould.PICTURES as Array).size():
		var m: Dictionary = mould.build(mould.PICTURES[r])
		var cells: Array = []
		for poly: PackedVector2Array in m.get("cells", []):
			var pts: Array = []
			for p in poly:
				pts.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
			cells.append(pts)
		var levels: Array = []
		for band in (mould.BANDS as Array).size():
			if r >= int(mould.BANDS[band].rows[0]) and r <= int(mould.BANDS[band].rows[1]):
				levels.append(band)
		shapes.append({"id": mould.PICTURES[r], "key": mould.PICTURES[r], "cells": cells, "want": m.get("want", []),
			"levels": levels})
	sets.append({"title": "Gumdrop moulds", "file": "puzzles/gumdrop_mould.gd", "kind": "shapes",
		"users": [["gumdrop", 0], ["gumdrop", 1], ["gumdrop", 2], ["gumdrop", 3]], "pictures": shapes,
		"flavours": flavours, "side": mould.SIDE})
	var f := FileAccess.open(OUT + "gallery.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"beads": beads, "sets": sets}))
	f.close()

## `key` is what a day document calls the picture: Pixel Garden its id, the
## other two its name.
func _pixel_pictures(list: Array) -> Array:
	var out: Array = []
	for pic in list:
		out.append({"id": String(pic.get("id", "")), "key": String(pic.get("name", "")), "rows": pic.get("rows", [])})
	return out
