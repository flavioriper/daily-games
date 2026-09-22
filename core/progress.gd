class_name Progress
extends RefCounted

## The player's progress on disk: how many distinct days they have opened a
## puzzle on (the HUD's "Day N") and a themed island name per date. Kept in
## its own file so it never races the motion settings.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 6.

static var path: String = "user://progress.cfg"

const ISLANDS := [
	"Sunlit Cliffs", "Moss Harbour", "Lantern Cove", "Driftwood Point",
	"Heron Shallows", "Fernwater Isle", "Pebble Reach", "Windmere Rock",
	"Tidepool Terrace", "Quiet Anchorage", "Bramble Key", "Saltgrass Hollow",
	"Kestrel Ledge", "Cinder Shoal", "Lily Landing", "Foxglove Cay",
	"Willow Strand", "Marigold Bank", "Otter Narrows", "Copper Cliffs",
	"Starling Rise", "Seagrass Flats", "Birch Haven", "Puffin Steps",
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
