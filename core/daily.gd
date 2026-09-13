class_name Daily
extends RefCounted

## Deterministic per-day seeding. Every player on a given date gets the same
## puzzle, which is the whole point of a daily. Seeds are derived from the
## UTC date so the puzzle rolls over at the same instant worldwide.

static func date_key(dt: Dictionary = {}) -> int:
	var d := dt if not dt.is_empty() else Time.get_datetime_dict_from_system(true)
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)

static func seed_for(puzzle_id: String, round_index: int, dt: Dictionary = {}) -> int:
	# Mix the date, the puzzle identity and the round so two puzzles on the
	# same day never share a generator stream.
	var h := hash("%d|%s|%d" % [date_key(dt), puzzle_id, round_index])
	return abs(h)

static func rng(puzzle_id: String, round_index: int, dt: Dictionary = {}) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_for(puzzle_id, round_index, dt)
	return r
