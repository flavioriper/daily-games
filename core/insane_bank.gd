extends RefCounted
class_name InsaneBank

## Insane boards mined on the Mac (tools/mine_insane.gd) and shipped as
## content, one file a board: content/insane/<puzzle_id>.json, shaped
## {"version": 1, "note": "...", "boards": [ {...}, ... ]}. A word board's
## file follows the player's language through Locale.content().
##
## A day picks through one fixed shuffle of the pool, so nothing repeats
## until the whole pool has been played; `step` is how many times New has
## been pressed since the board opened. An absent or unreadable bank is an
## empty dict, and the board falls back to its live band 3.

const DIR := "res://content/insane/"

static var _cache: Dictionary = {}

static func path_for(puzzle_id: String) -> String:
	return Locale.content(DIR + puzzle_id + ".json")

static func boards(puzzle_id: String) -> Array:
	var path := path_for(puzzle_id)
	if _cache.has(path):
		return _cache[path]
	var out: Array = []
	if FileAccess.file_exists(path):
		var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
		if doc is Dictionary and doc.get("boards") is Array:
			out = doc.boards
		else:
			push_warning("InsaneBank: %s is not a bank" % path)
	_cache[path] = out
	return out

static func size(puzzle_id: String) -> int:
	return boards(puzzle_id).size()

## Whole UTC days since the epoch: the same instant the daily rolls over.
static func day_ordinal() -> int:
	return int(Time.get_unix_time_from_system()) / 86400

static func pick(puzzle_id: String, step: int) -> Dictionary:
	var pool := boards(puzzle_id)
	if pool.is_empty():
		return {}
	var order: Array = range(pool.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = Daily.fnv1a("insane|" + puzzle_id)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]; order[i] = order[j]; order[j] = t
	return pool[order[(day_ordinal() + step) % order.size()]]
