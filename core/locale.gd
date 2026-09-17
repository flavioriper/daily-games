class_name Locale
extends RefCounted

## Which of the three languages the game is speaking, and the number
## formatting that goes with it. Strings themselves go through
## TranslationServer (locale/turn.csv); this is the part TranslationServer
## does not do.
##
## Only the turn flow is keyed so far. The twelve boards keep their hardcoded
## English until their own pass.
## Spec: docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md,
## section 6.

const CODES: Array[String] = ["en", "pt", "es"]
const NAMES := {"en": "English", "pt": "Português", "es": "Español"}
const PATH := "user://player.cfg"

## Resolved once and cached: current() is called from Analytics.track() on
## every gameplay event, and a disk read per event is not acceptable.
## set_current() and apply() both keep this in step.
static var _current := ""

## The phone's language when it is one of ours, the saved override when there
## is one, English otherwise.
static func current() -> String:
	if not _current.is_empty():
		return _current
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	var saved := str(cfg.get_value("player", "locale", ""))
	if saved in CODES:
		_current = saved
		return _current
	var sys := OS.get_locale_language()
	_current = sys if sys in CODES else "en"
	return _current

## Applies `code` to TranslationServer and remembers it.
static func set_current(code: String) -> void:
	var c := code if code in CODES else "en"
	_current = c
	TranslationServer.set_locale(c)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("player", "locale", c)
	cfg.save(PATH)

## Reads the saved or detected language and applies it. Called once, from
## world/main.gd, before anything draws.
static func apply() -> void:
	TranslationServer.set_locale(current())

## A number as this language writes it: 1,234.5 in English, 1.234,5 in
## Portuguese and Spanish.
static func number(n: float, decimals: int = 0) -> String:
	var s := String.num(absf(n), decimals)
	var parts := s.split(".")
	var whole := parts[0]
	var grouped := ""
	for i in whole.length():
		if i > 0 and (whole.length() - i) % 3 == 0:
			grouped += " "
		grouped += whole[i]
	var thousands := "," if current() == "en" else "."
	var point := "." if current() == "en" else ","
	grouped = grouped.replace(" ", thousands)
	var out := grouped if parts.size() == 1 else "%s%s%s" % [grouped, point, parts[1]]
	return "-" + out if n < 0.0 else out

## The inverse: reads a number written in any of the three.
static func parse_number(s: String) -> float:
	var t := s.strip_edges().replace(" ", "")
	if current() == "en":
		t = t.replace(",", "")
	else:
		t = t.replace(".", "").replace(",", ".")
	return float(t)
