extends RefCounted

## Four Shelves' rules, scene-free (spec
## docs/superpowers/specs/2026-10-22-shelves-design.md). Words on jars,
## every one belonging to exactly one hidden shelf of four. Pick four and
## shelve them: four of one shelf go up together; anything else costs a
## heart, and three of one shelf are said to be close. A shelf a band: Easy
## hides three, Medium and Hard four, Insane five (Crowded Pantry).
##
## A day is written at night by a model and reviewed blind
## (server/functions/src/shelves.ts); a phone that never reached the network,
## and a board dealt from New, deals from the bank the game ships
## (content/shelves.json), picked exactly as the server picks it.

const Daily = preload("res://core/daily.gd")

enum Said { SHELVED, CLOSE, WRONG, REPEAT, SOLVED, OUT, IGNORED }

const BANK := "res://content/shelves.json"
const GAME := "shelves"
const LANGS := ["en", "pt", "es"]
## Per band, Easy to Insane: the shelves hidden, the hearts, the bulbs.
const GROUPS := [3, 4, 4, 5]
const HEARTS := 4
const HINTS := [3, 2, 1, 1]
const WORD_MAX := 12
const LABEL_MAX := 34

static var _tiers: Array = []
static var _read := false

var band := 0
## The day's shelves in the screen's language, most obvious first:
## [{"label", "words": [4]}].
var groups: Array = []
## The jars still on the counter, in the order they stand.
var tiles: Array[String] = []
## The shelves filled, in the order they went up, by index into groups.
var shelved: Array[int] = []
## The jars picked, at most four.
var picked: Array[String] = []
var hearts := HEARTS
var mistakes := 0
## Every guess, as the shelves its four words came from (for the share line
## and the record), and their keys, so a guess is never charged twice.
var guesses: Array = []
var _tried := {}
## Shelves the bulb pointed at: [group, words shown].
var hinted := {}
## Shelves that went up by themselves (Show the shelves), not by the player.
var shown: Array[int] = []
var source := "bank"
var id := ""
var _key := 0

# --- the bank ---

static func _load() -> void:
	if _read:
		return
	_read = true
	var doc = JSON.parse_string(FileAccess.get_file_as_string(BANK)) if FileAccess.file_exists(BANK) else null
	if not (doc is Dictionary):
		return
	var b := 0
	for tier in doc.get("tiers", []):
		var kept := []
		if tier is Array:
			for p in tier:
				if valid(p, b):
					kept.append(p)
		_tiers.append(kept)
		b += 1

static func tiers() -> Array:
	_load()
	return _tiers

static func _valid_wording(w, count: int) -> bool:
	if not (w is Dictionary) or not (w.get("groups") is Array) or (w.groups as Array).size() != count:
		return false
	var seen := {}
	for g in w.groups:
		if not (g is Dictionary) or not (g.get("label") is String) or not (g.get("words") is Array):
			return false
		var label: String = g.label
		if label.strip_edges() == "" or label.length() > LABEL_MAX or (g.words as Array).size() != 4:
			return false
		for word in g.words:
			if not (word is String):
				return false
			var n := norm(word)
			if n == "" or n.length() > WORD_MAX or " " in n:
				return false
			seen[n] = true
	return seen.size() == count * 4

## Whether `p` is a puzzle band `b` can deal, in every language.
static func valid(p, b: int) -> bool:
	if not (p is Dictionary) or not (p.get("id") is String):
		return false
	for lang: String in LANGS:
		if not _valid_wording(p.get(lang), int(GROUPS[clampi(b, 0, 3)])):
			return false
	return true

static func norm(w: String) -> String:
	return w.strip_edges().to_upper()

## The tier's puzzle for `key`: the one whose hash of the key and its id is
## least, as server/functions/src/shelves.ts bankPick picks it.
static func bank_pick(tier: Array, key: int) -> Dictionary:
	var best: Dictionary = {}
	var low := -1
	for p: Dictionary in tier:
		var k := Daily.fnv1a(str(Daily.fnv1a("%s|%d|%s" % [GAME, key, p.id])))
		if low < 0 or k < low or (k == low and String(p.id) < String(best.id)):
			low = k
			best = p
	return best

## `p` in the language the screen is in, English when it has no such wording.
static func wording(p: Dictionary) -> Dictionary:
	var w = p.get(TranslationServer.get_locale().substr(0, 2))
	return w if w is Dictionary else p.get("en", {})

# --- a deal ---

## A board dealt from the bank: `key` is the day for a daily nobody
## published, anything else for a board dealt from New.
func setup(key: int, difficulty: int) -> bool:
	var all := tiers()
	var b := clampi(difficulty, 0, 3)
	if all.size() <= b or (all[b] as Array).is_empty():
		return false
	_begin(bank_pick(all[b], key), key, b, "bank")
	return true

## A daily from its published document; false (and nothing dealt) when the
## document cannot be played.
func setup_day(doc: Dictionary, key: int, difficulty: int) -> bool:
	var b := clampi(difficulty, 0, 3)
	var bands = doc.get("bands")
	if not (bands is Array) or bands.size() <= b or not valid(bands[b], b):
		return false
	_begin(bands[b], key, b, str(doc.get("source", "model")))
	return true

## A hand-picked puzzle, for the tutorial and the probes.
func setup_fixed(p: Dictionary, difficulty: int, key := 0) -> void:
	_begin(p, key, clampi(difficulty, 0, 3), "bank")

func _begin(p: Dictionary, key: int, b: int, from: String) -> void:
	band = b
	source = from
	id = String(p.get("id", ""))
	_key = key
	groups = []
	for g: Dictionary in wording(p).groups:
		var words: Array[String] = []
		for w in g.words:
			words.append(norm(w))
		groups.append({"label": String(g.label).strip_edges(), "words": words})
	restart()

## Every jar back on the counter, nothing shelved, all hearts.
func restart() -> void:
	tiles.clear()
	for g: Dictionary in groups:
		for w: String in g.words:
			tiles.append(w)
	var rng := RandomNumberGenerator.new()
	rng.seed = Daily.fnv1a("%s|%d|%s|order" % [GAME, _key, id])
	for i in range(tiles.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := tiles[i]
		tiles[i] = tiles[j]
		tiles[j] = t
	shelved.clear()
	picked.clear()
	hearts = HEARTS
	mistakes = 0
	guesses.clear()
	_tried.clear()
	hinted.clear()
	shown.clear()

func count() -> int:
	return groups.size()

func solved() -> bool:
	return not groups.is_empty() and shelved.size() >= groups.size()

func out() -> bool:
	return hearts <= 0 and not solved()

## The shelf `word` belongs to.
func group_of(word: String) -> int:
	for g in groups.size():
		if (groups[g].words as Array).has(word):
			return g
	return -1

## A jar tapped: picked, or put back when it already was.
func toggle(word: String) -> bool:
	if solved() or out() or not tiles.has(word):
		return false
	if picked.has(word):
		picked.erase(word)
		return true
	if picked.size() >= 4:
		return false
	picked.append(word)
	return true

func clear_picks() -> void:
	picked.clear()

## The jars stood in a new order, the shelved ones left out.
func shuffle(rng: RandomNumberGenerator) -> void:
	for i in range(tiles.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := tiles[i]
		tiles[i] = tiles[j]
		tiles[j] = t

static func _key_of(words: Array) -> String:
	var s := words.duplicate()
	s.sort()
	return "|".join(s)

## The four picked jars shelved: a shelf when they are one, else a heart.
func submit() -> Said:
	if picked.size() != 4 or solved() or out():
		return Said.IGNORED
	var key := _key_of(picked)
	if _tried.has(key):
		return Said.REPEAT
	_tried[key] = true
	var from: Array[int] = []
	var counts := {}
	for w in picked:
		var g := group_of(w)
		from.append(g)
		counts[g] = int(counts.get(g, 0)) + 1
	guesses.append(from)
	if counts.size() == 1:
		_shelve(from[0])
		return Said.SOLVED if solved() else Said.SHELVED
	hearts -= 1
	mistakes += 1
	if hearts <= 0:
		return Said.OUT
	for g in counts:
		if int(counts[g]) == 3:
			return Said.CLOSE
	return Said.WRONG

func _shelve(g: int) -> void:
	shelved.append(g)
	for w: String in groups[g].words:
		tiles.erase(w)
		picked.erase(w)
	picked.clear()
	hinted.erase(g)

## The bulb: the most obvious shelf still down shows one more of its words
## (picked for the player, the rest put back). -1 when nothing is left to show.
func hint() -> int:
	if solved() or out():
		return -1
	for g in groups.size():
		if shelved.has(g):
			continue
		var n: int = int(hinted.get(g, 0)) + 1
		if n > 3:
			continue
		hinted[g] = n
		picked.clear()
		for k in n:
			picked.append(groups[g].words[k])
		return g
	return -1

## One more heart (the card's video), once a board.
func add_heart() -> void:
	hearts += 1

## Show the shelves: the next one still down goes up by itself. -1 when all are up.
func reveal_next() -> int:
	for g in groups.size():
		if not shelved.has(g):
			shown.append(g)
			_shelve(g)
			return g
	return -1

## The brain report: a mistake costs a quarter.
func quality() -> float:
	if not shown.is_empty():
		return 0.0
	return clampf(1.0 - 0.25 * float(mistakes), 0.0, 1.0)

## A finished day, put back from its record.
func finish(the_guesses: Array, the_shown: Array) -> void:
	guesses.clear()
	mistakes = 0
	for g in the_guesses:
		var from: Array[int] = []
		for x in g:
			from.append(int(x))
		guesses.append(from)
		var first := from[0]
		if from.count(first) != 4:
			mistakes += 1
	hearts = maxi(0, HEARTS - mistakes)
	shown.clear()
	for g in the_shown:
		shown.append(int(g))
	shelved.clear()
	for g in groups.size():
		if not shown.has(g):
			shelved.append(g)
	shelved.append_array(shown)
	tiles.clear()
	picked.clear()

## The colours of a guess's squares: one a word, by the shelf it came from.
const SQUARES := ["🟨", "🟩", "🟦", "🟪", "🟥"]

func share_glyphs() -> String:
	var lines := PackedStringArray()
	for g: Array in guesses:
		var row := ""
		for x in g:
			row += SQUARES[int(x) % SQUARES.size()]
		lines.append(row)
	return "\n".join(lines)
