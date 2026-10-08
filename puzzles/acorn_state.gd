extends RefCounted

## Golden Acorn's rules as the board plays them, scene-free, as every flat
## board's are. The board (puzzles/acorn2d.gd) draws this and nothing else.
##
## A day is a list of questions, each with four answers and one of them
## right. The player picks one and locks it; a lock is never taken back. Then
## the right answer is shown, with a line about it, and the next is asked.
##
## Nothing here can be lost up to Hard: the day ends when the last question
## is locked, and the count of right answers is the result. Insane is the
## Climb: ten questions that rise from easy to what one in ten knows, with
## hearts, spent on a wrong lock (one move a question, so hearts and not a
## move counter: docs/agents/flat-screens.md, "Insane counts moves").
##
## Where the questions come from. A daily's are the day's document, written
## by a model and published by the backend (server/functions/src/acorn.ts);
## the board hands them to `setup_day`. Everything else -- a phone that never
## reached the network, a board dealt from New, a second try at the Climb --
## is dealt from the bank the game ships (content/acorn.json), by the same
## arithmetic the server uses for a day the model could not write, so the two
## agree on what an unwritten day asks.

const Daily = preload("res://core/daily.gd")

const BANK := "res://content/acorn.json"
const GAME := "acorn"
const LANGS := ["en", "pt", "es"]

## Questions a band asks: Easy, Medium, Hard, and the Climb.
const ASKS := [7, 7, 7, 10]
## How many of each tier the bank's Climb takes, easy to expert.
const CLIMB := [3, 3, 2, 2]
## The bulb takes two wrong answers away.
const HINTS_BY := [2, 1, 1, 0]
const HEARTS_BY := [0, 0, 0, 2]
## The longest a line may be and still be shown (the server's limits).
const Q_MAX := 120
const ANSWER_MAX := 30
const WHY_MAX := 130

static var _tiers: Array = []
static var _read := false

var band := 0
## The day's questions, each as the contract has it (tools/acorn/CONTRACT.md).
var questions: Array = []
## Per question, the order its four answers are shown in: indices into
## [right, wrong 0, wrong 1, wrong 2].
var orders: Array = []
## Per question, the shown places the bulb took away.
var cuts: Array = []
var index := 0
## What each locked question came to: {"pick": shown place, "right": bool}.
var results: Array = []
var hearts := 0
## "model", "mixed" or "bank": who wrote the day.
var source := "bank"
## What the deal was keyed by, for the shuffles and for a second try.
var _key := 0

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
			for q in tier:
				if valid(q):
					kept.append(q)
		_tiers.append(kept)

static func tiers() -> Array:
	_load()
	return _tiers

static func _valid_wording(w) -> bool:
	if not (w is Dictionary):
		return false
	var q = w.get("q")
	var why = w.get("why")
	var wrong = w.get("wrong")
	if not (q is String) or q.strip_edges() == "" or q.length() > Q_MAX:
		return false
	if not (why is String) or why.length() > WHY_MAX:
		return false
	if not (wrong is Array) or wrong.size() != 3:
		return false
	var seen := {}
	for a in [w.get("right")] + wrong:
		if not (a is String) or a.strip_edges() == "" or a.length() > ANSWER_MAX:
			return false
		seen[a.strip_edges().to_lower()] = true
	return seen.size() == 4

## Whether `q` is a question the board can ask: the contract's shape, in
## every language, within what fits the card.
static func valid(q) -> bool:
	if not (q is Dictionary) or not (q.get("id") is String):
		return false
	for lang: String in LANGS:
		if not _valid_wording(q.get(lang)):
			return false
	return true

## A tier in `key`'s order: by the hash of the key and the question's id,
## as server/functions/src/acorn.ts sorts it.
static func ordered(tier: Array, key: int) -> Array:
	var keyed := []
	for q: Dictionary in tier:
		# Hashed twice: FNV's last byte barely stirs the top bits, so ids that
		# differ in their last digit would otherwise sort side by side.
		keyed.append([Daily.fnv1a(str(Daily.fnv1a("%s|%d|%s" % [GAME, key, q.id]))), str(q.id), q])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var out := []
	for e: Array in keyed:
		out.append(e[2])
	return out

## The bank's questions for `difficulty` under `key`: a band is the head of
## its tier's order and the Climb the tail of every tier's, so the four bands
## of one day never share a question.
static func bank_band(key: int, difficulty: int) -> Array:
	var all := tiers()
	if all.size() < 4:
		return []
	if difficulty < 3:
		return ordered(all[difficulty], key).slice(0, ASKS[difficulty])
	var out := []
	for t in CLIMB.size():
		var o := ordered(all[t], key)
		out.append_array(o.slice(o.size() - int(CLIMB[t])))
	return out

## The questions of `difficulty` in a day's document, or [] when the
## document is not one the board can play whole.
static func day_band(doc: Dictionary, difficulty: int) -> Array:
	var bands = doc.get("bands")
	if not (bands is Array) or bands.size() <= difficulty or not (bands[difficulty] is Array):
		return []
	var out := []
	for q in bands[difficulty]:
		if not valid(q):
			return []
		out.append(q)
	return out if out.size() >= 3 else []

# --- a deal ---

## A board dealt from the bank: `key` is the day for a daily nobody published,
## anything else for a board dealt from New.
func setup(key: int, difficulty: int) -> void:
	_begin(bank_band(key, clampi(difficulty, 0, 3)), key, difficulty, "bank")

## A daily from its published document; false (and nothing dealt) when the
## document cannot be played.
func setup_day(doc: Dictionary, key: int, difficulty: int) -> bool:
	var list := day_band(doc, clampi(difficulty, 0, 3))
	if list.is_empty():
		return false
	_begin(list, key, difficulty, str(doc.get("source", "model")))
	return true

## Hand-picked questions, for the tutorial and the probes. `right_at` puts
## every right answer at that shown place (-1 shuffles as a deal does).
func setup_fixed(difficulty: int, list: Array, right_at := -1) -> void:
	_begin(list, 0, difficulty, "bank")
	if right_at >= 0:
		for i in orders.size():
			var o: Array = [1, 2, 3]
			o.insert(clampi(right_at, 0, 3), 0)
			orders[i] = o

func _begin(list: Array, key: int, difficulty: int, from: String) -> void:
	band = clampi(difficulty, 0, 3)
	questions = list
	source = from
	_key = key
	orders = []
	for q: Dictionary in questions:
		var rng := RandomNumberGenerator.new()
		rng.seed = Daily.fnv1a("%s|%d|%s|order" % [GAME, key, q.id])
		var o := [0, 1, 2, 3]
		for i in range(3, 0, -1):
			var j := rng.randi_range(0, i)
			var held: int = o[i]
			o[i] = o[j]
			o[j] = held
		orders.append(o)
	restart()

## The same questions from the first, nothing answered.
func restart() -> void:
	index = 0
	results = []
	cuts = []
	for i in questions.size():
		cuts.append([])
	hearts = HEARTS_BY[band]

## A second try at a Climb that was lost is a new Climb: the first one's
## answers have all been seen. From the bank, keyed off this deal and the try.
func redeal(attempt: int) -> void:
	var key := Daily.fnv1a("%s|%d|try|%d" % [GAME, _key, attempt])
	_begin(bank_band(key, band), key, band, "bank")

# --- reading it ---

func count() -> int:
	return questions.size()

func question() -> Dictionary:
	return questions[mini(index, questions.size() - 1)] if not questions.is_empty() else {}

## `q` in the language the screen is in, English when it has no such wording.
static func wording(q: Dictionary) -> Dictionary:
	var w = q.get(TranslationServer.get_locale().substr(0, 2))
	return w if w is Dictionary else q.get("en", {})

## The four answers of question `i` as they are shown.
func answers(i := -1) -> Array:
	var at := index if i < 0 else i
	if at >= questions.size():
		return []
	var w := wording(questions[at])
	var all: Array = [w.get("right", "")] + (w.get("wrong", []) as Array)
	var out := []
	for k: int in orders[at]:
		out.append(str(all[k]))
	return out

## The shown place of question `i`'s right answer.
func right_place(i := -1) -> int:
	var at := index if i < 0 else i
	return (orders[at] as Array).find(0) if at < orders.size() else -1

func locked() -> bool:
	return index < results.size()

func is_cut(place: int) -> bool:
	return index < cuts.size() and (cuts[index] as Array).has(place)

func rights() -> int:
	var n := 0
	for r: Dictionary in results:
		if bool(r.right):
			n += 1
	return n

## Every question locked, and on the Climb a heart still in hand.
func is_solved() -> bool:
	if questions.is_empty() or results.size() < questions.size():
		return false
	return HEARTS_BY[band] == 0 or hearts > 0

## Not one wrong.
func perfect() -> bool:
	return results.size() == questions.size() and rights() == questions.size()

# --- playing it ---

## Locks shown place `place` as the answer. {} when there is nothing to lock.
func lock(place: int) -> Dictionary:
	if locked() or index >= questions.size() or place < 0 or place > 3 or is_cut(place):
		return {}
	var right := place == right_place()
	var missed: bool = not right and HEARTS_BY[band] > 0
	if missed:
		hearts = maxi(0, hearts - 1)
	var res := {"pick": place, "right": right, "missed": missed}
	results.append(res)
	return res

## On to the next question; false when this was the last or is not locked.
func advance() -> bool:
	if not locked() or index + 1 >= questions.size():
		return false
	index += 1
	return true

## The bulb: two of the wrong answers still standing go. Returns their shown
## places, [] when there is nothing to take.
func cut_two() -> Array:
	if locked() or index >= questions.size() or not (cuts[index] as Array).is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = Daily.fnv1a("%s|%d|%s|cut" % [GAME, _key, question().id])
	var wrong := []
	for place in 4:
		if place != right_place():
			wrong.append(place)
	wrong.remove_at(rng.randi_range(0, 2))
	cuts[index] = wrong
	return wrong

## A solved day put back from what was kept of it: the shown place picked at
## each question (-1 where it was not kept) and whether it was right.
func finish(picks: Array, was_right: Array) -> void:
	results = []
	for i in questions.size():
		var right := bool(was_right[i]) if i < was_right.size() else true
		var pick := int(picks[i]) if i < picks.size() else -1
		if pick < 0 or pick > 3 or (pick == right_place(i)) != right:
			pick = right_place(i) if right else -1
		results.append({"pick": pick, "right": right, "missed": false})
	index = maxi(0, questions.size() - 1)
	hearts = maxi(1, hearts)

## What names this deal: a completed daily is put back onto the same
## questions or not at all.
func set_id() -> int:
	var ids := ""
	for q: Dictionary in questions:
		ids += str(q.id) + ","
	return Daily.fnv1a(ids)

## A square a question: green for right, red for wrong.
func share_glyphs() -> String:
	var out := ""
	for r: Dictionary in results:
		out += "🟩" if bool(r.right) else "🟥"
	return out
