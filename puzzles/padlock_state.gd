extends RefCounted

## Padlock's rules (spec docs/superpowers/specs/2026-11-04-padlock-design.md).
## A combination padlock with a row of letter dials, one per letter of the
## band's word length. Each dial is a strip of letters that slides behind a
## window; the window row is the word dialled. When it spells a word the
## lock knows, that word's letters light on their dials and stay lit; light
## every letter on every dial and the lock opens.
##
## The locks are banked (tools/build_padlock.py,
## content/insane/padlock*.json): the dials, the window as dealt, every word
## the dials spell (`words`), the fair ones the bulb offers (`fair`) and the
## par, the fewest fair words that light every letter (`min`). A word counts
## for the stars only when it lights a new letter; `fewest_from` solves the
## fewest still needed over every word the lock credits, so a rarer word can
## beat par.
##
## On Insane (Rusty Lock) one dial, the deepest, only turns down; pushed
## past its last letter it comes round to its first.

## The bank each band's locks come from.
const BANKS := ["padlock_easy", "padlock_medium", "padlock_hard", "padlock"]
## The bulb, by band.
const HINTS := [3, 2, 2, 1]
## Stars: three within STAR_THREE words over par, two within STAR_TWO, one
## after. Three stars allow one over par because dials are turned one at a
## time and the window may spell a word on the way (CHILL on the way to
## CHILI); that word lights letters and counts, and the player could not
## avoid it.
const STAR_THREE := 1
const STAR_TWO := 3
## Should a bank be missing, a lock every language can dial (folded).
const SPARE_DAY := {
	"dials": ["mlt", "aio", "rns", "ek"],
	"start": [1, 2, 0, 1],
	"words": ["lane", "late", "mare", "mate", "mine", "mite", "tine", "tire", "tone", "tore"],
	"fair": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
	"min": 3,
}

var band := 0
## The letters of each dial, top to bottom (folded), and where each stands
## in the window.
var dials: Array[String] = []
var pos: Array[int] = []
## Every word the dials spell that the lock credits, the fair ones (indices)
## and each word's letters as a mask (bit = a dial's letter).
var words: Array[String] = []
var fair: Array[int] = []
var masks: Array[int] = []
var _index := {}
var _shown := {}
## Bit offsets of each dial's first letter, and every letter's bit.
var offsets: Array[int] = []
var full := 0
## The par: the fewest fair words that light every letter.
var par := 0
## The letters lit, the words found (folded, in order) and the ones that
## counted (lit something new, by hand).
var lit := 0
var found: Array[String] = []
var counted := 0
## Words the bulb dialled (free).
var helped := 0
## The story of the day for the share: per word that lit something, which
## dials it lit a letter on.
var story: Array = []
## The rusty dial (Insane), -1 when none.
var rusty := -1
## The fewest words still needed from where the lock stands (kept, read
## once a word).
var to_go := 0
var _memo := {}
var _memo_fair := {}
var _start: Array[int] = []

func deal(_rng: RandomNumberGenerator, the_band: int, bank_step := 0) -> void:
	band = clampi(the_band, 0, 3)
	var day: Dictionary = InsaneBank.pick(BANKS[band], bank_step)
	if day.is_empty():
		push_error("Padlock: no locks in %s" % BANKS[band])
		day = SPARE_DAY
	load_day(day)

func load_day(day: Dictionary) -> void:
	dials.clear()
	for d in day.get("dials", []):
		dials.append(String(d))
	words.clear()
	_index = {}
	for w in day.get("words", []):
		_index[String(w)] = words.size()
		words.append(String(w))
	fair.clear()
	for i in day.get("fair", []):
		fair.append(int(i))
	_shown = day.get("shown", {})
	offsets.clear()
	var at := 0
	for d in dials:
		offsets.append(at)
		at += d.length()
	full = (1 << at) - 1
	masks.clear()
	for w in words:
		masks.append(mask_of(w))
	_start.clear()
	for k in dials.size():
		var s: Array = day.get("start", [])
		_start.append(clampi(int(s[k]) if k < s.size() else 0, 0, dials[k].length() - 1))
	rusty = -1
	if band == 3:
		var deep := 0
		for k in dials.size():
			if dials[k].length() > deep:
				deep = dials[k].length()
				rusty = k
	_memo = {}
	_memo_fair = {}
	par = int(day.get("min", 0))
	restart()
	if par <= 0:
		par = to_go

## The lock as dealt, nothing lit.
func restart() -> void:
	pos = _start.duplicate()
	lit = 0
	found.clear()
	counted = 0
	helped = 0
	story.clear()
	to_go = fewest_from(0)

func length() -> int:
	return dials.size()

## The letter dial `k` holds at `i`.
func letter(k: int, i: int) -> String:
	return dials[k][i] if k >= 0 and k < dials.size() and i >= 0 and i < dials[k].length() else ""

func bit(k: int, i: int) -> int:
	return 1 << (offsets[k] + i)

func is_lit(k: int, i: int) -> bool:
	return lit & bit(k, i) != 0

## The letters of `w` as a mask, 0 when a dial does not hold its letter.
func mask_of(w: String) -> int:
	if w.length() != dials.size():
		return 0
	var m := 0
	for k in dials.size():
		var i := dials[k].find(w[k])
		if i < 0:
			return 0
		m |= bit(k, i)
	return m

## The word in the window.
func window() -> String:
	var out := ""
	for k in dials.size():
		out += letter(k, pos[k])
	return out

## A word as written (accents), from the bank.
func written(w: String) -> String:
	var i: int = _index.get(w, -1)
	if i >= 0 and _shown.has(str(i)):
		return String(_shown[str(i)])
	return w

func knows(w: String) -> bool:
	return _index.has(w)

func dark_count() -> int:
	var n := 0
	var m := full & ~lit
	while m != 0:
		m &= m - 1
		n += 1
	return n

func letter_count() -> int:
	return offsets[-1] + dials[-1].length() if not dials.is_empty() else 0

func solved() -> bool:
	return full != 0 and lit == full

## Whether dial `k` may move from where it stands to `to` (Rusty Lock: the
## rusty dial only turns down, or comes round from its last to its first).
func can_turn(k: int, to: int) -> bool:
	if k < 0 or k >= dials.size() or to < 0 or to >= dials[k].length():
		return false
	if k != rusty:
		return true
	return to >= pos[k] or (pos[k] == dials[k].length() - 1 and to == 0)

## Sets dial `k` to letter `i` (no word is read; `read` does that).
func turn(k: int, i: int) -> bool:
	if not can_turn(k, i):
		return false
	pos[k] = i
	return true

## Reads the window. Empty when it is no word. Else {"word", "new": mask of
## letters newly lit, "again": found before, "counted": it counts}.
## `free`: the bulb dialled it.
func read(free := false) -> Dictionary:
	var w := window()
	if not knows(w):
		return {}
	if found.has(w):
		return {"word": w, "new": 0, "again": true, "counted": false}
	found.append(w)
	var m := mask_of(w)
	var fresh := m & ~lit
	lit |= m
	var counts := fresh != 0 and not free
	if counts:
		counted += 1
	elif fresh != 0:
		helped += 1
	if fresh != 0:
		var row: Array[bool] = []
		for k in dials.size():
			row.append(fresh & bit(k, pos[k]) != 0)
		story.append(row)
	to_go = fewest_from(lit)
	return {"word": w, "new": fresh, "again": false, "counted": counts}

## The fewest words (any the lock credits) that light what `from` leaves
## dark: branch on the lowest dark letter, every word that lights it.
func fewest_from(from: int) -> int:
	return _cover(full & ~from, masks, _memo)

func _fewest_fair(left: int) -> int:
	var fm: Array[int] = []
	for i in fair:
		fm.append(masks[i])
	return _cover(left, fm, _memo_fair)

func _cover(left: int, ms: Array[int], memo: Dictionary) -> int:
	if left == 0:
		return 0
	if memo.has(left):
		return int(memo[left])
	# what each word still lights here, once each
	var parts := {}
	for m in ms:
		var r := m & left
		if r != 0:
			parts[r] = true
	# branch on the dark letter the fewest of them light
	var low := 0
	var fewest := 1 << 30
	var rest := left
	while rest != 0:
		var b := rest & -rest
		rest &= rest - 1
		var n := 0
		for r: int in parts:
			if r & b != 0:
				n += 1
		if n < fewest:
			fewest = n
			low = b
	var best := 99
	for r: int in parts:
		if r & low != 0:
			best = mini(best, 1 + _cover(left & ~r, ms, memo))
	memo[left] = best
	return best

## The stars the way stands at: words counted and the fewest still to go,
## against par.
func stars() -> int:
	var way := counted + to_go
	if way <= par + STAR_THREE:
		return 3
	if way <= par + STAR_TWO:
		return 2
	return 1

## The bulb's word: a fair word not found, on a fewest path through the
## fair words, lighting the most. "" when there is none.
func hint_word() -> String:
	var left := full & ~lit
	if left == 0:
		return ""
	var need := _fewest_fair(left)
	var best := ""
	var most := -1
	for i in fair:
		var w := words[i]
		if found.has(w):
			continue
		var m := masks[i]
		var fresh := m & left
		if fresh == 0:
			continue
		if 1 + _fewest_fair(left & ~m) != need and need < 99:
			continue
		var n := 0
		var f := fresh
		while f != 0:
			f &= f - 1
			n += 1
		if n > most:
			most = n
			best = w
	return best

## Every dial turned so the window reads `w` (the bulb's second press, a
## restore). Ignores the rust: the bulb's hand is free.
func dial_to(w: String) -> void:
	for k in mini(w.length(), dials.size()):
		var i := dials[k].find(w[k])
		if i >= 0:
			pos[k] = i

## Every letter lit (a restored day).
func finish() -> void:
	lit = full
	to_go = 0

## The day's line on the share: the words against par, and a row per word
## that lit something: a gold square on each dial it lit.
func share_glyphs() -> String:
	var out := "%d/%d\n" % [counted + helped, par]
	for row: Array in story:
		for on in row:
			out += "🟨" if on else "⬜"
		out += "\n"
	return out.strip_edges()

## The brain score: par against the words it took (the bulb's count here),
## nothing for an unsolved lock.
func quality() -> float:
	if not solved():
		return 0.0
	return clampf(float(par) / float(maxi(par, counted + helped)), 0.0, 1.0)
