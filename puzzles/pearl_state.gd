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
## Seconds a prompt is given. Insane has Hard's (the user, 2026-10-12: no
## time limit shaped for Insane; asked, they chose Hard's clock): the one
## tank of One Breath is left below, on no band (`tank()`).
const SECONDS := [30.0, 25.0, 20.0, 20.0]
## The first band on the single tank: none.
const TANK_FROM := 4
## How many of each level the bank's One Breath takes, easy to hard.
const BREATH := [3, 3, 2]
const HINTS_BY := [2, 1, 1, 1]
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
## A line that holds a listed form whole, or is held whole by one, counts as
## that answer when the shorter is at least WHOLE_FROM letters and WHOLE_SHARE
## of the longer ("goldengatebridge" is the Golden Gate). 2026-10-29.
const WHOLE_FROM := 5
const WHOLE_SHARE := 0.6
## A line two slips from a listed form, from CLOSE_FROM letters up, is "so
## close": said, and free (2026-10-29, as Five Clues' since 2026-10-28).
const CLOSE_FROM := 6
## Stars by the share of the floor the dive reached (`stars`).
const STAR_SHARES := [0.2, 0.4, 0.6]
## A run: answers in a row from this tier down (rare, deep, the Pearl).
const RUN_TIER := 2

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
## Per prompt, what the bulb told of its Pearl: 0 nothing, 1 its first
## letter and length, 2 every other letter too (the second press, free).
var hinted: Array = []
## Lines offered this prompt that the list did not hold, normalised: one
## offered again is said and costs nothing.
var tried: Array = []
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
	tried = []
	out = false
	hinted = []
	for i in prompts.size():
		hinted.append(0)
	_own = []
	_other = []
	_lang = ""
	time_left = AIR if tank() else float(SECONDS[band])

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
	var answers: Array = prompts[index].answers
	var whole := _whole(n, own)
	if whole < 0:
		whole = _whole(n, other)
	if whole >= 0:
		return whole
	if n.length() < NEAR_FROM:
		return -1
	var best := -1
	for f: String in own:
		if near(n, f):
			var a := int(own[f])
			if best < 0 or int(answers[a].t) < int(answers[best].t):
				best = a
	return best

## The answer whose form `n` holds whole or is held by (`WHOLE_FROM`,
## `WHOLE_SHARE`), the longest such form; -1 when none.
func _whole(n: String, forms: Dictionary) -> int:
	var best := -1
	var best_len := 0
	for f: String in forms:
		var short := mini(f.length(), n.length())
		if short < WHOLE_FROM or float(short) < WHOLE_SHARE * float(maxi(f.length(), n.length())):
			continue
		var held := n.begins_with(f) or n.ends_with(f) if f.length() <= n.length() \
			else f.begins_with(n) or f.ends_with(n)
		if held and f.length() > best_len:
			best = int(forms[f])
			best_len = f.length()
	return best

## Whether `text` is two slips from a form of the prompt on the card in the
## screen's language (`CLOSE_FROM` letters up): a fair try misspelt.
func close(text: String) -> bool:
	if index >= prompts.size():
		return false
	_index(index)
	var n := norm(text)
	if n.length() < CLOSE_FROM:
		return false
	for f: String in _own[index]:
		if absi(f.length() - n.length()) <= 2 and _slips(n, f) <= 2:
			return true
	return false

## The edit distance of `a` and `b` (letters wrong, missing or extra).
static func _slips(a: String, b: String) -> int:
	var row: Array = range(b.length() + 1)
	for i in a.length():
		var prev: int = row[0]
		row[0] = i + 1
		for j in b.length():
			var keep: int = row[j + 1]
			row[j + 1] = mini(mini(row[j + 1] + 1, row[j] + 1), prev + (0 if a[i] == b[j] else 1))
			prev = keep
	return int(row[b.length()])

## Answers in a row, up to the last, of RUN_TIER or deeper.
func run() -> int:
	var n := 0
	for k in range(results.size() - 1, -1, -1):
		if int(results[k].t) < RUN_TIER:
			break
		n += 1
	return n

## The longest such run of the dive.
func best_run() -> int:
	var best := 0
	var n := 0
	for r: Dictionary in results:
		n = n + 1 if int(r.t) >= RUN_TIER else 0
		best = maxi(best, n)
	return best

## Stars, 0 to 3, by the share of the floor reached (`STAR_SHARES`).
func stars() -> int:
	var floor_m := floor_depth()
	if floor_m <= 0:
		return 0
	var share := float(depth()) / float(floor_m)
	var n := 0
	for s: float in STAR_SHARES:
		if share >= s - 0.0001:
			n += 1
	return n

## One answer of each tier of prompt `i`, shallow to the Pearl, for the
## ladder shown after it: the player's own in its tier, else one picked by
## the day's key (the same for everybody), "" for a tier the list lacks.
func ladder(i := -1) -> Array:
	var at := index if i < 0 else i
	var out_l := ["", "", "", "", ""]
	if at < 0 or at >= prompts.size():
		return out_l
	var given := int(results[at].a) if at < results.size() else -1
	var answers: Array = prompts[at].answers
	var keys := [1 << 62, 1 << 62, 1 << 62, 1 << 62, 1 << 62]
	for a in answers.size():
		var t := clampi(int(answers[a].t), 0, PEARL)
		var k := Daily.fnv1a("%s|%d|%s|rung|%d" % [GAME, _key, prompts[at].id, a])
		if a == given:
			k = -1
		if k < int(keys[t]):
			keys[t] = k
			out_l[t] = answer_name(at, a)
	return out_l

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

## Whether the day is one tank of air for every prompt (One Breath).
func tank() -> bool:
	return band >= TANK_FROM

func _run_dry() -> void:
	if tank():
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
		var n := norm(text)
		if tried.has(n):
			return {"hit": false, "short": false, "again": true}
		if close(text):
			return {"hit": false, "short": false, "close": true}
		tried.append(n)
		misses += 1
		time_left = maxf(0.0, time_left - MISS_COST)
		var ran := time_left <= 0.0
		if ran:
			_run_dry()
		return {"hit": false, "short": false, "ran": ran}
	var t := int(prompts[index].answers[a].t)
	var air := 0.0
	if tank():
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
	tried = []
	if not tank():
		time_left = float(SECONDS[band])
	return true

## The bulb: the Pearl's first letter and how many letters it has. {} when
## this prompt has been told already or is over.
func tell() -> Dictionary:
	if answered() or out or index >= prompts.size() or bool(hinted[index]):
		return {}
	hinted[index] = 1
	return told()

## The bulb's second press on a prompt it has told: every other letter of
## the Pearl as well. Free. {} when it has not told it yet, or told this.
func tell_more() -> Dictionary:
	if answered() or out or index >= prompts.size() or int(hinted[index]) != 1:
		return {}
	hinted[index] = 2
	return told()

## What the bulb told of the prompt on the card, {} when it did not.
func told() -> Dictionary:
	if index >= hinted.size() or not bool(hinted[index]):
		return {}
	var n := norm(pearl_name())
	var shown := ""
	if int(hinted[index]) >= 2:
		for k in n.length():
			shown += (n[k].to_upper() if k % 2 == 0 else "_") + (" " if k + 1 < n.length() else "")
	return {"first": n.substr(0, 1).to_upper(), "letters": n.length(), "more": shown}

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
