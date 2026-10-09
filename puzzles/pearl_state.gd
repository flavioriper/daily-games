extends RefCounted

## Pearl Dive's rules as the board plays them, scene-free, as every flat
## board's are. The board (puzzles/pearl2d.gd) draws this and nothing else.
##
## A day is a list of prompts. A prompt names a kind of thing ("a kind of
## cheese") and holds every answer the game knows for it, each with how rare
## it is. The player types one answer against a clock; the first one the list
## holds ends the prompt, and the rarer it is the deeper the dive goes. One
## answer of every prompt is its Pearl, the deepest there is. An answer the
## list does not hold costs a little of the clock and the prompt goes on; a
## clock that runs out leaves the prompt dry.
##
## Nothing here can be lost up to Hard: the day ends when the last prompt is
## answered or dry, and the depth is the result. Insane is One Breath: the
## clock is one tank of air for the whole dive, a right answer gives some
## back by how rare it was, and the air running out is the end.
##
## Where the prompts come from. A daily's are the day's document, written by
## a model and published by the backend (server/functions/src/pearl.ts); the
## board hands them to `setup_day`. Everything else -- a phone that never
## reached the network, a board dealt from New, a second try at One Breath --
## is dealt from the bank the game ships (content/pearl.json), by the same
## arithmetic the server uses for a day the model could not write.

const Daily = preload("res://core/daily.gd")

const BANK := "res://content/pearl.json"
const GAME := "pearl"
const LANGS := ["en", "pt", "es"]

## Prompts a band asks: Easy, Medium, Hard, and One Breath.
const ASKS := [5, 6, 7, 8]
## Seconds a prompt is given; One Breath has its tank instead.
const SECONDS := [30.0, 25.0, 20.0, 0.0]
## How many of each level the bank's One Breath takes, easy to hard.
const BREATH := [3, 3, 2]
const HINTS_BY := [2, 1, 1, 0]
## Metres an answer dives by its tier: common, known, rare, deep, the Pearl.
const METRES := [1, 3, 6, 8, 10]
const PEARL := 4
## What an answer the list does not hold costs.
const MISS_COST := 3.0
## One Breath: the tank, what a right answer gives back by its tier, and
## what the card's video gives.
const AIR := 45.0
const AIR_BACK := [3.0, 6.0, 9.0, 12.0, 15.0]
const AIR_GIFT := 20.0
## The limits a prompt is held to (the server's, tools/pearl/CONTRACT.md).
const ASK_MAX := 64
const NAME_MAX := 26
const FORM_MIN := 2
const FORM_MAX := 22
const ANSWERS_MIN := 14
## The most letters the line takes.
const TYPE_MAX := 22
## A slip of one letter is forgiven from this many letters up.
const NEAR_FROM := 5

## Letters the keyboard cannot type, as the ones it can.
const FOLD := {
	"á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "å": "a",
	"é": "e", "è": "e", "ê": "e", "ë": "e",
	"í": "i", "ì": "i", "î": "i", "ï": "i",
	"ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o", "ø": "o",
	"ú": "u", "ù": "u", "û": "u", "ü": "u",
	"ç": "c", "ñ": "n", "ý": "y", "ß": "ss", "æ": "ae", "œ": "oe",
}

static var _levels: Array = []
static var _read := false

var band := 0
## The day's prompts, each as the contract has it.
var prompts: Array = []
var index := 0
## What each finished prompt came to: {"a": the answer's index or -1 for a
## dry one, "t": its tier or -1, "m": metres}.
var results: Array = []
## Seconds left on the prompt, or of air on One Breath.
var time_left := 0.0
## Answers the list did not hold, this prompt.
var misses := 0
## Per prompt, whether the bulb told its Pearl's first letter.
var hinted: Array = []
## One Breath ran out of air.
var out := false
## "model", "mixed" or "bank": who wrote the day.
var source := "bank"
var _key := 0
## Per prompt, form -> answer index: in the screen's language, and in the
## other two (a name typed in another language is still the thing).
var _own: Array = []
var _other: Array = []
var _lang := ""

# --- words ---

## `s` as the keyboard could have typed it: lower case, no accents, letters only.
static func norm(s: String) -> String:
	var out_s := ""
	for ch in s.to_lower():
		if ch >= "a" and ch <= "z":
			out_s += ch
		elif FOLD.has(ch):
			out_s += str(FOLD[ch])
	return out_s

## Whether `a` is `b` but for one slip: a letter wrong, missing, extra, or
## two neighbours swapped.
static func near(a: String, b: String) -> bool:
	var la := a.length()
	var lb := b.length()
	if absi(la - lb) > 1:
		return false
	var i := 0
	while i < la and i < lb and a[i] == b[i]:
		i += 1
	if i == la and i == lb:
		return true
	if la == lb:
		if a.substr(i + 1) == b.substr(i + 1):
			return true
		return i + 1 < la and a[i] == b[i + 1] and a[i + 1] == b[i] and a.substr(i + 2) == b.substr(i + 2)
	if la < lb:
		return a.substr(i) == b.substr(i + 1)
	return a.substr(i + 1) == b.substr(i)

static func lang() -> String:
	var l := TranslationServer.get_locale().substr(0, 2)
	return l if l in LANGS else "en"

# --- the bank ---

static func _load() -> void:
	if _read:
		return
	_read = true
	var doc = JSON.parse_string(FileAccess.get_file_as_string(BANK)) if FileAccess.file_exists(BANK) else null
	if not (doc is Dictionary):
		return
	for level in doc.get("levels", []):
		var kept := []
		if level is Array:
			for p in level:
				if valid(p):
					kept.append(p)
		_levels.append(kept)

static func levels() -> Array:
	_load()
	return _levels

## Whether `p` is a prompt the board can ask: the contract's shape, in every
## language, within what fits the card and the keyboard.
static func valid(p) -> bool:
	if not (p is Dictionary) or not (p.get("id") is String):
		return false
	for l: String in LANGS:
		var w = p.get(l)
		if not (w is Dictionary) or not (w.get("ask") is String):
			return false
		var ask: String = w.ask
		if ask.strip_edges() == "" or ask.length() > ASK_MAX:
			return false
	var answers = p.get("answers")
	if not (answers is Array) or answers.size() < ANSWERS_MIN:
		return false
	var pearls := 0
	for a in answers:
		if not (a is Dictionary):
			return false
		var t := int(a.get("t", -1))
		if t < 0 or t > PEARL:
			return false
		if t == PEARL:
			pearls += 1
		for l: String in LANGS:
			var forms = a.get(l)
			if not (forms is Array) or forms.is_empty():
				return false
			for f in forms:
				if not (f is String):
					return false
			if (forms[0] as String).length() > NAME_MAX:
				return false
			var n := norm(forms[0])
			if n.length() < FORM_MIN or n.length() > FORM_MAX:
				return false
	return pearls == 1

## A level in `key`'s order: by the hash of the key and the prompt's id, as
## server/functions/src/pearl.ts sorts it (hashed twice, Golden Acorn's
## reason: FNV's last byte barely stirs the top bits).
static func ordered(level: Array, key: int) -> Array:
	var keyed := []
	for p: Dictionary in level:
		keyed.append([Daily.fnv1a(str(Daily.fnv1a("%s|%d|%s" % [GAME, key, p.id]))), str(p.id), p])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var out_list := []
	for e: Array in keyed:
		out_list.append(e[2])
	return out_list

## The bank's prompts for `difficulty` under `key`: a band is the head of its
## level's order and One Breath the tail of every level's, so the four bands
## of one day never share a prompt.
static func bank_band(key: int, difficulty: int) -> Array:
	var all := levels()
	if all.size() < 3:
		return []
	if difficulty < 3:
		return ordered(all[difficulty], key).slice(0, ASKS[difficulty])
	var out_list := []
	for l in BREATH.size():
		var o := ordered(all[l], key)
		out_list.append_array(o.slice(maxi(0, o.size() - int(BREATH[l]))))
	return out_list

## The prompts of `difficulty` in a day's document, or [] when the document
## is not one the board can play whole.
static func day_band(doc: Dictionary, difficulty: int) -> Array:
	var bands = doc.get("bands")
	if not (bands is Array) or bands.size() <= difficulty or not (bands[difficulty] is Array):
		return []
	var out_list := []
	for p in bands[difficulty]:
		if not valid(p):
			return []
		out_list.append(p)
	return out_list if out_list.size() >= 3 else []

# --- a deal ---

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

## Hand-picked prompts, for the tutorial and the probes.
func setup_fixed(difficulty: int, list: Array) -> void:
	_begin(list, 0, difficulty, "bank")

func _begin(list: Array, key: int, difficulty: int, from: String) -> void:
	band = clampi(difficulty, 0, 3)
	prompts = list
	source = from
	_key = key
	restart()

## The same prompts from the first, nothing answered.
func restart() -> void:
	index = 0
	results = []
	misses = 0
	out = false
	hinted = []
	for i in prompts.size():
		hinted.append(false)
	_own = []
	_other = []
	_lang = ""
	time_left = AIR if band >= 3 else float(SECONDS[band])

## A second try at One Breath is a new dive: the first one's answers have all
## been shown. From the bank, keyed off this deal and the try.
func redeal(attempt: int) -> void:
	var key := Daily.fnv1a("%s|%d|try|%d" % [GAME, _key, attempt])
	_begin(bank_band(key, band), key, band, "bank")

# --- reading it ---

func count() -> int:
	return prompts.size()

func prompt() -> Dictionary:
	return prompts[mini(index, prompts.size() - 1)] if not prompts.is_empty() else {}

## What prompt `i` asks, in the screen's language.
func ask(i := -1) -> String:
	var at := index if i < 0 else i
	if at >= prompts.size():
		return ""
	var w = prompts[at].get(lang())
	return str((w as Dictionary).get("ask", "")) if w is Dictionary else ""

## Answer `a` of prompt `i` as it is shown.
func answer_name(i: int, a: int) -> String:
	if i < 0 or i >= prompts.size():
		return ""
	var answers: Array = prompts[i].answers
	if a < 0 or a >= answers.size():
		return ""
	return str((answers[a][lang()] as Array)[0])

func pearl_at(i := -1) -> int:
	var at := index if i < 0 else i
	if at >= prompts.size():
		return -1
	var answers: Array = prompts[at].answers
	for a in answers.size():
		if int(answers[a].t) == PEARL:
			return a
	return -1

func pearl_name(i := -1) -> String:
	var at := index if i < 0 else i
	return answer_name(at, pearl_at(at))

## Up to `n` of prompt `i`'s deep answers that the player did not give, for
## the line under the Pearl: the same ones for everybody that day.
func deep_names(i: int, n: int) -> Array:
	if i < 0 or i >= prompts.size():
		return []
	var given := int(results[i].a) if i < results.size() else -1
	var answers: Array = prompts[i].answers
	var keyed := []
	for a in answers.size():
		if int(answers[a].t) == PEARL - 1 and a != given:
			keyed.append([Daily.fnv1a(str(Daily.fnv1a("%s|%d|%s|%d" % [GAME, _key, prompts[i].id, a]))), a])
	keyed.sort()
	var out_list := []
	for e: Array in keyed.slice(0, n):
		out_list.append(answer_name(i, int(e[1])))
	return out_list

func answered() -> bool:
	return index < results.size()

## Metres so far.
func depth() -> int:
	var m := 0
	for r: Dictionary in results:
		m += int(r.m)
	return m

## The deepest this dive could go: a Pearl a prompt.
func floor_depth() -> int:
	return prompts.size() * int(METRES[PEARL])

func pearls() -> int:
	var n := 0
	for r: Dictionary in results:
		if int(r.t) == PEARL:
			n += 1
	return n

func dry_count() -> int:
	var n := 0
	for r: Dictionary in results:
		if int(r.a) < 0:
			n += 1
	return n

## Every prompt finished, and on One Breath air still in the tank.
func is_solved() -> bool:
	return not prompts.is_empty() and results.size() >= prompts.size() and not out

## The forms of prompt `i`, indexed once a language.
func _index(i: int) -> void:
	if _lang != lang():
		_lang = lang()
		_own = []
		_other = []
		for k in prompts.size():
			_own.append(null)
			_other.append(null)
	if _own[i] != null:
		return
	var own := {}
	var other := {}
	var answers: Array = prompts[i].answers
	for l: String in LANGS:
		var into := own if l == _lang else other
		for a in answers.size():
			for f in answers[a][l]:
				var n := norm(str(f))
				if n.length() >= FORM_MIN and not into.has(n):
					into[n] = a
	_own[i] = own
	_other[i] = other

## The answer of the prompt on the card that `text` names, -1 when none: the
## form itself in the screen's language, then in the other two, then one slip
## away from a form in the screen's language (the commoner answer when two
## are that near).
func find(text: String) -> int:
	if index >= prompts.size():
		return -1
	_index(index)
	var n := norm(text)
	var own: Dictionary = _own[index]
	if own.has(n):
		return int(own[n])
	var other: Dictionary = _other[index]
	if other.has(n):
		return int(other[n])
	if n.length() < NEAR_FROM:
		return -1
	var best := -1
	var answers: Array = prompts[index].answers
	for f: String in own:
		if near(n, f):
			var a := int(own[f])
			if best < 0 or int(answers[a].t) < int(answers[best].t):
				best = a
	return best

# --- playing it ---

## The clock, while a prompt stands unanswered. True when it ran out: the
## prompt is dry, or on One Breath the dive is over.
func tick(delta: float) -> bool:
	if answered() or out or index >= prompts.size():
		return false
	time_left = maxf(0.0, time_left - delta)
	if time_left > 0.0:
		return false
	_run_dry()
	return true

func _run_dry() -> void:
	if band >= 3:
		out = true
	else:
		results.append({"a": -1, "t": -1, "m": 0})

## The typed line, offered. {"hit": true, "a", "t", "m", "air"} when the list
## holds it; {"hit": false, "short": true} for a line too short to be
## anything; otherwise a miss, which costs the clock ("ran" when that was the
## last of it).
func guess(text: String) -> Dictionary:
	if answered() or out or index >= prompts.size():
		return {}
	if norm(text).length() < FORM_MIN:
		return {"hit": false, "short": true}
	var a := find(text)
	if a < 0:
		misses += 1
		time_left = maxf(0.0, time_left - MISS_COST)
		var ran := time_left <= 0.0
		if ran:
			_run_dry()
		return {"hit": false, "short": false, "ran": ran}
	var t := int(prompts[index].answers[a].t)
	var air := 0.0
	if band >= 3:
		air = float(AIR_BACK[t])
		time_left += air
	var res := {"a": a, "t": t, "m": int(METRES[t])}
	results.append(res)
	return {"hit": true, "a": a, "t": t, "m": int(METRES[t]), "air": air}

## On to the next prompt; false when this was the last or is not finished.
func advance() -> bool:
	if not answered() or index + 1 >= prompts.size():
		return false
	index += 1
	misses = 0
	if band < 3:
		time_left = float(SECONDS[band])
	return true

## The bulb: the Pearl's first letter and how many letters it has. {} when
## this prompt has been told already or is over.
func tell() -> Dictionary:
	if answered() or out or index >= prompts.size() or bool(hinted[index]):
		return {}
	hinted[index] = true
	return told()

## What the bulb told of the prompt on the card, {} when it did not.
func told() -> Dictionary:
	if index >= hinted.size() or not bool(hinted[index]):
		return {}
	var n := norm(pearl_name())
	return {"first": n.substr(0, 1).to_upper(), "letters": n.length()}

## One Breath's video: air back in the tank and the dive goes on.
func more_air() -> void:
	out = false
	time_left = AIR_GIFT

## A finished day put back from what was kept of it: the answer given at each
## prompt (-1 dry) and its tier, the tier alone when the prompts are not the
## ones that were answered.
func finish(given: Array, tiers: Array) -> void:
	results = []
	for i in prompts.size():
		var t := int(tiers[i]) if i < tiers.size() else 0
		var a := int(given[i]) if i < given.size() else -1
		var answers: Array = prompts[i].answers
		if t < 0:
			results.append({"a": -1, "t": -1, "m": 0})
			continue
		t = mini(t, PEARL)
		if a < 0 or a >= answers.size() or int(answers[a].t) != t:
			a = -2  # an answer of that tier, no longer known which
		results.append({"a": a, "t": t, "m": int(METRES[t])})
	index = maxi(0, prompts.size() - 1)
	out = false

## What names this deal: a completed daily is put back onto the same prompts
## or not at all.
func set_id() -> int:
	var ids := ""
	for p: Dictionary in prompts:
		ids += str(p.id) + ","
	return Daily.fnv1a(ids)

## A mark a prompt, shallow to deep, a cross for a dry one.
func share_glyphs() -> String:
	var marks := ["⚪", "🟢", "🔵", "🟣", "🦪"]
	var out_s := ""
	for r: Dictionary in results:
		out_s += "✖️" if int(r.t) < 0 else str(marks[int(r.t)])
	return out_s
