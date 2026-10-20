class_name Daily
extends RefCounted

## Deterministic per-day seeding. Every player on a given date gets the same
## puzzle, which is the whole point of a daily. Seeds are derived from the
## UTC date so the puzzle rolls over at the same instant worldwide.

## The day held back (2026-10-20, the user, whose 21:00 BRT open found no
## theme: "make sure the game challenges only switch when next theme is
## fully done"). While world/main.gd has not yet got the new UTC day's
## themed pictures and vistas onto this phone, date_key() answers `held`,
## the day before; it lets go as soon as both are held or known not to
## exist, and by itself HOLD_S past 00:00 UTC, so an offline phone still
## rolls over (publishDay's 03:00 repair has run by then, and submitTurn
## takes yesterday's turns all day). 0 is no hold: the suite and every
## harness never set one.
const HOLD_S := 3 * 3600 + 1800
static var held := 0

static func date_key(dt: Dictionary = {}) -> int:
	if dt.is_empty():
		return held if holding() else utc_key()
	return int(dt.year) * 10000 + int(dt.month) * 100 + int(dt.day)

## The UTC day `offset` days from now, whatever is held.
static func utc_key(offset := 0) -> int:
	return date_key(Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + offset * 86400))

## Whether date_key() is answering the day before today's UTC one.
static func holding() -> bool:
	return held != 0 and held < utc_key() and int(Time.get_unix_time_from_system()) % 86400 < HOLD_S

static func seed_for(puzzle_id: String, round_index: int, dt: Dictionary = {}) -> int:
	# Mix the date, the puzzle identity and the round so two puzzles on the
	# same day never share a generator stream.
	var h := hash("%d|%s|%d" % [date_key(dt), puzzle_id, round_index])
	return abs(h)

static func rng(puzzle_id: String, round_index: int, dt: Dictionary = {}) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_for(puzzle_id, round_index, dt)
	return r

## FNV-1a, 32 bit. server/functions/src/index.ts computes the same hash over
## the same string, so a phone that has never reached the network derives the
## same day's content as the one that was published.
static func fnv1a(s: String) -> int:
	var h := 0x811c9dc5
	for b in s.to_utf8_buffer():
		h ^= b
		h = (h * 0x01000193) & 0xFFFFFFFF
	return h
