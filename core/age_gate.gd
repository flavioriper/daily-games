extends RefCounted

## The player's birth year, asked once at first launch on a phone
## (ui/hud/age_screen.gd) and kept only on this device, so the ads asked
## for suit the player's age: Brazil's ECA Digital (Lei 15.211/2025) and
## the EU's DSA forbid profiling-based ads to minors, and COPPA treats an
## under-13 as a child. Only the band ever leaves the device.
## Plan docs/superpowers/plans/2026-09-29-fair-ads.md, task 1.

const UNKNOWN := -1
const CHILD := 0
const TEEN := 1
const ADULT := 2

static var path := "user://age.cfg"
static var _year := -1

static func birth_year() -> int:
	if _year < 0:
		var cfg := ConfigFile.new()
		cfg.load(path)
		_year = int(cfg.get_value("age", "year", 0))
	return _year

static func set_birth_year(year: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("age", "year", year)
	cfg.save(path)
	_year = year

static func known() -> bool:
	return birth_year() > 0

## A birth year allows two ages; the younger one is taken, so a doubt always
## falls on the protective side.
static func band(year_now: int = int(Time.get_datetime_dict_from_system(true).year)) -> int:
	var y := birth_year()
	if y <= 0:
		return UNKNOWN
	var age := year_now - y - 1
	if age < 13:
		return CHILD
	if age < 18:
		return TEEN
	return ADULT

static func band_name(b: int) -> String:
	return ["child", "teen", "adult"][b] if b >= 0 and b <= 2 else "unknown"

## Forget what was read (a probe that has just pointed `path` elsewhere). Not called reload: that is Script.reload(), which recompiles and resets `path`.
static func forget() -> void:
	_year = -1
