extends RefCounted

## Honeycomb's words (spec docs/superpowers/specs/2026-10-22-honeycomb-design.md),
## read from content/honeycomb.json in the player's language
## (`Locale.content`) and kept for the session per language. Built by
## tools/build_honeycomb.py from wordfreq: every word a player may make,
## folded the way Hidden Word folds (accents off, Ñ kept in Spanish), four
## letters or more, no S, seven different letters at most. Each word has a
## letter mask over `alphabet` and a tier: 0 common, 1 and 2 rarer (the band
## from which it is one of the day's words), 3 a real word the hive takes and
## scores but never counts or hints. A shy word (a name or a place too, by
## the dictionaries) is counted when found and never shown by the bulb.

const PATH := "res://content/honeycomb.json"
## The tier a band's day's words come from (Easy, Medium, Hard, Insane).
const BAND_TIER := [0, 1, 2, 2]

static var _cache: Dictionary = {}

var alphabet := ""
var words: PackedStringArray = []
var masks: PackedInt64Array = []
var tiers := ""
var written: Dictionary = {}
var shy: Dictionary = {}
## folded word -> its index
var index: Dictionary = {}

## The list in the player's language, read once a session.
static func current():
	var path := Locale.content(PATH)
	if _cache.has(path):
		return _cache[path]
	var out = (load("res://puzzles/honeycomb_words.gd") as GDScript).new()
	out._read(path)
	_cache[path] = out
	return out

func _read(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Honeycomb: no word list at %s" % path)
		return
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not doc is Dictionary:
		push_error("Honeycomb: %s is not a word list" % path)
		return
	alphabet = String(doc.get("alphabet", "abcdefghijklmnopqrstuvwxyz"))
	words = PackedStringArray(doc.get("words", []))
	var ms: Array = doc.get("masks", [])
	masks.resize(ms.size())
	for i in ms.size():
		masks[i] = int(ms[i])
	tiers = String(doc.get("tiers", ""))
	written = doc.get("written", {})
	for i in doc.get("shy", []):
		shy[int(i)] = true
	for i in words.size():
		index[words[i]] = i

## The mask of a string of letters over this list's alphabet; -1 when a
## letter is not in it.
func mask_of(letters: String) -> int:
	var m := 0
	for ch in letters:
		var at := alphabet.find(ch)
		if at < 0:
			return -1
		m |= 1 << at
	return m

func tier(i: int) -> int:
	return int(tiers.unicode_at(i)) - 48

## How a word is shown: with its accents back, upper case.
func shown(i: int) -> String:
	return String(written.get(str(i), words[i])).to_upper()

func find(word: String) -> int:
	return int(index.get(word, -1))

## The indices of every word the hive `hive` (a mask) makes that holds the
## letter `queen` (a mask), of tier `most` or below.
func inside(hive: int, queen: int, most := 3) -> PackedInt32Array:
	var out := PackedInt32Array()
	var outside := ~hive
	for i in masks.size():
		var m := masks[i]
		if m & outside == 0 and m & queen != 0 and tier(i) <= most:
			out.append(i)
	return out

## A word's honey: one a letter, seven more for a word that uses all seven
## letters (a full comb). A four-letter word poured one until 2026-10-28,
## and a player finding the short words first, as players do, filled the
## jar a drop at a time.
static func points(word: String, full: bool) -> int:
	return word.length() + (7 if full else 0)
