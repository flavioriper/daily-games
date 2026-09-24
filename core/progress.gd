class_name Progress
extends RefCounted

## The player's progress on disk: how many distinct days they have opened a
## puzzle on (the HUD's "Day N") and a themed island name per date. Kept in
## its own file so it never races the motion settings.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 6.

static var path: String = "user://progress.cfg"

## Keys into locale/ui.csv (ISLAND_0 is "Sunlit Cliffs", and so on); the
## Label that shows one translates it.
const ISLANDS := [
	"ISLAND_0", "ISLAND_1", "ISLAND_2", "ISLAND_3", "ISLAND_4", "ISLAND_5",
	"ISLAND_6", "ISLAND_7", "ISLAND_8", "ISLAND_9", "ISLAND_10", "ISLAND_11",
	"ISLAND_12", "ISLAND_13", "ISLAND_14", "ISLAND_15", "ISLAND_16", "ISLAND_17",
	"ISLAND_18", "ISLAND_19", "ISLAND_20", "ISLAND_21", "ISLAND_22", "ISLAND_23",
]

## Records that the player opened a puzzle on `date_key` (a Daily.date_key
## value) and returns the day number. Only a date different from the last
## recorded one counts.
static func touch(date_key: int = Daily.date_key()) -> int:
	var cfg := ConfigFile.new()
	cfg.load(path)  # a missing file is fine
	var days := int(cfg.get_value("progress", "days", 0))
	var last := int(cfg.get_value("progress", "last_date", 0))
	if date_key != last:
		days += 1
		cfg.set_value("progress", "days", days)
		cfg.set_value("progress", "last_date", date_key)
		cfg.save(path)
	return days

## The day number on disk; 0 before the first touch.
static func day() -> int:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return int(cfg.get_value("progress", "days", 0))

## Whether the player has dismissed a one-time tutorial. Tutorials live in the
## same small progress file so they survive a restart without adding another
## persistence format.
static func tutorial_seen(id: String) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return bool(cfg.get_value("tutorials", id, false))

static func mark_tutorial_seen(id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("tutorials", id, true)
	cfg.save(path)

## The island name for a date, the same for everyone on that date.
static func island_name(date_key: int = Daily.date_key()) -> String:
	return ISLANDS[posmod(hash(str(date_key)), ISLANDS.size())]

## Records that the player solved puzzle `puzzle_id` on `date_key`. Completion
## belongs to the daily, not to the puzzle's current generated round, so a
## card can keep its done state after the player leaves and reopens the app.
## The optional stats are kept with that completion so the finished screen can
## show the result of the solve when the daily is reopened.
static func mark_completed(puzzle_id: String, date_key: int = Daily.date_key(), stats: Dictionary = {}) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	var key := "%d_%s" % [date_key, puzzle_id]
	cfg.set_value("completed", key, true)
	if not stats.is_empty():
		cfg.set_value("completed_stats", key, stats)
	cfg.save(path)

static func completed(puzzle_id: String, date_key: int = Daily.date_key()) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return bool(cfg.get_value("completed", "%d_%s" % [date_key, puzzle_id], false))

static func completed_stats(puzzle_id: String, date_key: int = Daily.date_key()) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(path)
	var value = cfg.get_value("completed_stats", "%d_%s" % [date_key, puzzle_id], {})
	return value if value is Dictionary else {}

## Clears a daily's completion so a player can replay it from the finished
## screen. The result stats belong to the same completion and must go with it.
static func clear_completed(puzzle_id: String, date_key: int = Daily.date_key()) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	var key := "%d_%s" % [date_key, puzzle_id]
	cfg.erase_section_key("completed", key)
	cfg.erase_section_key("completed_stats", key)
	cfg.save(path)

## --- the solve log (docs/superpowers/specs/2026-09-24-stats-streak-design.md, section 2) ---
## One record per board and difficulty per day, appended on a solve and never
## erased: clear_completed (the replay button) does not touch it, so a replay
## solved again cannot count twice or inflate a best time. Streak and Stats
## are derived from it (core/streak.gd, core/player_stats.gd).

static func log_solve(id: String, difficulty: int, stats: Dictionary = {}, date_key: int = Daily.date_key()) -> bool:
	var cfg := ConfigFile.new()
	if not _readable(cfg.load(path)):
		return false
	_migrate(cfg)
	var key := str(date_key)
	var day: Array = cfg.get_value("log", key, [])
	if _has_record(day, id, difficulty):
		return false
	day.append({
		"id": id, "d": difficulty,
		"t": float(stats.get("seconds", 0.0)),
		"m": int(stats.get("moves", 0)),
		"h": int(stats.get("hints", 0)),
	})
	cfg.set_value("log", key, day)
	cfg.save(path)
	return true

## Every day's records, keyed by the int date key.
static func solve_log() -> Dictionary:
	var cfg := ConfigFile.new()
	if not _readable(cfg.load(path)):
		return {}
	_migrate(cfg)
	var out := {}
	if cfg.has_section("log"):
		for key in cfg.get_section_keys("log"):
			var day = cfg.get_value("log", key, [])
			if key.is_valid_int() and day is Array:
				out[int(key)] = day
	return out

## Today's hearts: distinct boards solved, up to three.
static func hearts(date_key: int = Daily.date_key()) -> int:
	return Streak.hearts(solve_log().get(date_key, []))

## Which difficulty Stats shows, remembered between visits.
static func stats_difficulty() -> int:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return clampi(int(cfg.get_value("stats", "difficulty", 0)), 0, 3)

static func set_stats_difficulty(d: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("stats", "difficulty", clampi(d, 0, 3))
	cfg.save(path)

## A missing file is an empty save; any other load error is a file that
## failed to parse, and it is left exactly as it is rather than saved over.
static func _readable(err: Error) -> bool:
	return err == OK or err == ERR_FILE_NOT_FOUND

static func _has_record(day: Array, id: String, difficulty: int) -> bool:
	for r in day:
		if String(r.get("id", "")) == id and int(r.get("d", -1)) == difficulty:
			return true
	return false

## Folds the completions saved before the log existed into it, once. A key
## is `<date>_<progress_id>`; a progress_id ending `_<digit>` carries its
## difficulty. The menu also marks the plain id, so a plain record is dropped
## when a suffixed one for the same board and day exists. Saves only when it
## ran. Only ever handed a cfg whose load passed `_readable`, so a file that
## failed to parse is never saved over.
static func _migrate(cfg: ConfigFile) -> void:
	if bool(cfg.get_value("log_meta", "migrated", false)):
		return
	var by_date := {}
	if cfg.has_section("completed"):
		for k in cfg.get_section_keys("completed"):
			var cut := k.find("_")
			if cut <= 0 or not k.substr(0, cut).is_valid_int():
				continue
			var date := k.substr(0, cut)
			var id := k.substr(cut + 1)
			var d := -1
			var tail := id.rfind("_")
			if tail > 0 and id.length() - tail == 2 and id.substr(tail + 1).is_valid_int():
				d = int(id.substr(tail + 1))
				id = id.substr(0, tail)
			var st = cfg.get_value("completed_stats", k, {})
			if not st is Dictionary:
				st = {}
			(by_date.get_or_add(date, []) as Array).append({
				"id": id, "d": d,
				"t": float(st.get("seconds", 0.0)),
				"m": int(st.get("moves", 0)),
				"h": int(st.get("hints", 0)),
			})
	for date in by_date:
		var found: Array = by_date[date]
		var day: Array = cfg.get_value("log", date, [])
		for r in found:
			if int(r.d) == -1 and _has_suffixed(found, String(r.id)):
				continue
			if not _has_record(day, String(r.id), int(r.d)):
				day.append(r)
		if not day.is_empty():
			cfg.set_value("log", date, day)
	cfg.set_value("log_meta", "migrated", true)
	cfg.save(path)

static func _has_suffixed(records: Array, id: String) -> bool:
	for r in records:
		if String(r.id) == id and int(r.d) >= 0:
			return true
	return false
