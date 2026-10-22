extends RefCounted

## Five Clues' rules, scene-free (spec
## docs/superpowers/specs/2026-10-22-clues-design.md). Rounds of a hidden
## idea: five clue cards that all belong to it are turned one at a time, the
## least telling first, and the player types the idea. A wrong line turns
## the next card; Enter on an empty line turns it without a guess. A line
## said with every card up and wrong loses the round. On Insane (Three
## Tries) a round also ends at its third wrong line. The score is the cards
## a round needed.
##
## A day is written at night by a model and named blind by a second
## (server/functions/src/clues.ts); a phone that never reached it, and a
## board dealt from New, deals from the bank (content/clues.json) in the
## same order the server takes it.

const Daily = preload("res://core/daily.gd")

enum Said { RIGHT, WRONG, LOST, TURNED, REPEAT, EMPTY, IGNORED }

const BANK := "res://content/clues.json"
const GAME := "clues"
const LANGS := ["en", "pt", "es"]
const ROUNDS := [3, 3, 4, 4]
const TIER := [0, 1, 2, 2]
const CLUES := 5
## Insane's rule: wrong lines a round.
const TRIES := [0, 0, 0, 3]
const HINTS := [3, 2, 1, 1]
const CONTAINS_MIN := 4
const TYPE_MAX := 22
const FOLD := {
	"á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "å": "a",
	"é": "e", "è": "e", "ê": "e", "ë": "e",
	"í": "i", "ì": "i", "î": "i", "ï": "i",
	"ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o", "ø": "o",
	"ú": "u", "ù": "u", "û": "u", "ü": "u",
	"ç": "c", "ñ": "n", "ý": "y", "ß": "ss", "æ": "ae", "œ": "oe",
}

static var _tiers: Array = []
static var _read := false

var band := 0
## The day's rounds, each in the screen's language: {"id", "label",
## "clues": [5], "accept": [...]}.
var rounds: Array = []
var index := 0
## This round's cards up (1..5), wrong lines, lines said.
var shown := 1
var wrongs := 0
var said: Array[String] = []
## Per round finished: the cards it needed (1..5), or 0 when it was lost.
var results: Array[int] = []
## Per round: the label's letters the bulb has shown.
var hinted := 0
var source := "bank"
var _key := 0

# --- words ---

static func norm(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		if ch >= "a" and ch <= "z":
			out += ch
		elif FOLD.has(ch):
			out += FOLD[ch]
	return out

## Whether `line` names the idea: one of its phrases folded, or holding one
## of CONTAINS_MIN letters or more; a phrase's last "s" may be left off. As
## server/functions/src/clues.ts accepts().
static func accepts(accept: Array, line: String) -> bool:
	var typed := norm(line)
	if typed == "":
		return false
	for a in accept:
		var f := norm(String(a))
		var forms := [f]
		if f.length() > CONTAINS_MIN and f.ends_with("s"):
			forms.append(f.substr(0, f.length() - 1))
		for form: String in forms:
			if form == "":
				continue
			if typed == form or (form.length() >= CONTAINS_MIN and typed.contains(form)):
				return true
	return false

# --- the bank ---

static func _load() -> void:
	if _read:
		return
	_read = true
	var doc = JSON.parse_string(FileAccess.get_file_as_string(BANK)) if FileAccess.file_exists(BANK) else null
	if not (doc is Dictionary):
		return
	for tier in doc.get("tiers", []):
		var kept := []
		if tier is Array:
			for r in tier:
				if valid(r):
					kept.append(r)
		_tiers.append(kept)

static func tiers() -> Array:
	_load()
	return _tiers

static func _valid_wording(w) -> bool:
	if not (w is Dictionary) or not (w.get("label") is String) or not (w.get("clues") is Array) or not (w.get("accept") is Array):
		return false
	if (w.clues as Array).size() != CLUES or (w.accept as Array).is_empty():
		return false
	for c in w.clues:
		if not (c is String) or String(c).strip_edges() == "":
			return false
	return true

static func valid(r) -> bool:
	if not (r is Dictionary) or not (r.get("id") is String):
		return false
	for lang: String in LANGS:
		if not _valid_wording(r.get(lang)):
			return false
	return true

## A tier in `key`'s order, as server/functions/src/clues.ts orders it.
static func ordered(tier: Array, key: int) -> Array:
	var keyed := []
	for r: Dictionary in tier:
		keyed.append([Daily.fnv1a(str(Daily.fnv1a("%s|%d|%s" % [GAME, key, r.id]))), str(r.id), r])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var out := []
	for e: Array in keyed:
		out.append(e[2])
	return out

## The bank's rounds for `difficulty` under `key`: its tier's head, Insane
## the hard tier's tail.
static func bank_band(key: int, difficulty: int) -> Array:
	var all := tiers()
	var b := clampi(difficulty, 0, 3)
	var t: int = TIER[b]
	if all.size() <= t:
		return []
	var o := ordered(all[t], key)
	var n: int = ROUNDS[b]
	return o.slice(maxi(0, o.size() - n)) if b == 3 else o.slice(0, n)

static func wording(r: Dictionary) -> Dictionary:
	var w = r.get(TranslationServer.get_locale().substr(0, 2))
	return w if w is Dictionary else r.get("en", {})

# --- a deal ---

func setup(key: int, difficulty: int) -> bool:
	var list := bank_band(key, difficulty)
	if list.is_empty():
		return false
	_begin(list, key, difficulty, "bank")
	return true

func setup_day(doc: Dictionary, key: int, difficulty: int) -> bool:
	var b := clampi(difficulty, 0, 3)
	var bands = doc.get("bands")
	if not (bands is Array) or bands.size() <= b or not (bands[b] is Array):
		return false
	var list: Array = bands[b]
	if list.is_empty():
		return false
	for r in list:
		if not valid(r):
			return false
	_begin(list, key, b, str(doc.get("source", "model")))
	return true

func setup_fixed(list: Array, difficulty: int) -> void:
	_begin(list, 0, difficulty, "bank")

func _begin(list: Array, key: int, difficulty: int, from: String) -> void:
	band = clampi(difficulty, 0, 3)
	source = from
	_key = key
	rounds = []
	for r: Dictionary in list:
		var w := wording(r)
		var clues: Array[String] = []
		for c in w.clues:
			clues.append(String(c).strip_edges())
		rounds.append({"id": String(r.id), "label": String(w.label).strip_edges(), "clues": clues, "accept": Array(w.accept)})
	restart()

func restart() -> void:
	index = 0
	results.clear()
	_fresh_round()

func _fresh_round() -> void:
	shown = 1
	wrongs = 0
	hinted = 0
	said.clear()

func count() -> int:
	return rounds.size()

func round_now() -> Dictionary:
	return rounds[mini(index, rounds.size() - 1)] if not rounds.is_empty() else {}

func solved() -> bool:
	return not rounds.is_empty() and results.size() >= rounds.size()

## Whether the round in hand is over (right or lost) and waits for Next.
func round_over() -> bool:
	return results.size() > index

func tries() -> int:
	return int(TRIES[band])

func tries_left() -> int:
	return tries() - wrongs if tries() > 0 else -1

## The player's line.
func offer(line: String) -> Said:
	if solved() or round_over():
		return Said.IGNORED
	var typed := norm(line)
	if typed == "":
		return turn()
	if said.has(typed):
		return Said.REPEAT
	said.append(typed)
	var r := round_now()
	if accepts(r.accept, line):
		results.append(shown)
		return Said.RIGHT
	wrongs += 1
	if shown >= CLUES or (tries() > 0 and wrongs >= tries()):
		results.append(0)
		return Said.LOST
	shown += 1
	return Said.WRONG

## Enter on an empty line: the next card turns, no guess spent.
func turn() -> Said:
	if solved() or round_over():
		return Said.IGNORED
	if shown >= CLUES:
		return Said.EMPTY
	shown += 1
	return Said.TURNED

## The next round's cards.
func next_round() -> void:
	if not round_over():
		return
	index += 1
	_fresh_round()

## The bulb: one more letter of the idea's name shown. -1 when nothing is left.
func hint() -> int:
	if solved() or round_over():
		return -1
	var label: String = round_now().label
	var letters := 0
	for ch in label:
		if ch != " ":
			letters += 1
	if hinted >= letters - 1:
		return -1
	hinted += 1
	return hinted

## The idea's name as the bulb shows it: its first `hinted` letters, the
## rest blanks, a letter a slot and the words apart.
func hint_line() -> String:
	var label: String = round_now().label
	var slots := PackedStringArray()
	var n := 0
	for ch in label.to_upper():
		if ch == " ":
			slots.append(" ")
			continue
		slots.append(ch if n < hinted else "_")
		n += 1
	return " ".join(slots)

## The brain report: per round, the cards it did not need, out of four.
func quality() -> float:
	if results.is_empty():
		return -1.0
	var sum := 0.0
	for n in results:
		sum += 0.0 if n == 0 else float(CLUES - n) / float(CLUES - 1)
	return clampf(sum / results.size(), 0.0, 1.0)

func finish(the_results: Array) -> void:
	results.clear()
	for n in the_results:
		results.append(int(n))
	while results.size() < rounds.size():
		results.append(0)
	index = rounds.size() - 1
	shown = CLUES

## The share line: a row a round, a square a card needed, the last green;
## a lost round all red.
func share_glyphs() -> String:
	var lines := PackedStringArray()
	for n in results:
		if n == 0:
			lines.append("🟥".repeat(CLUES))
		else:
			lines.append("⬜".repeat(n - 1) + "🟩")
	return "\n".join(lines)
