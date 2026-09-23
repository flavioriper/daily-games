extends RefCounted

## Hidden Word's rules, scene-free, so the board draws them and nothing else
## knows them. The five-letter answer comes from content/hidden_word.json by
## the day's seed; a guess is accepted against content/hidden_word_accept.txt,
## which is far larger on purpose (spec section 4).
##
## The keyboard's colours are **derived** from the committed rows on every
## call and never stored, the way Queens' crosses are: best mark wins, so a
## letter amber on row one and green on row three stays green.
## Spec: docs/superpowers/specs/2026-09-19-hidden-word-flat-design.md.

const WORDS := "res://content/hidden_word.json"
const ACCEPT := "res://content/hidden_word_accept.txt"

const HIT := 0
const NEAR := 1
const MISS := 2

const OK := 0
const SHORT := 1
const UNKNOWN := 2
const REPEAT := 3

const ROWS := 6
const LEN := 5
const HINTS := 2

const GLYPH := ["🟩", "🟨", "⬜"]

## The word folded to what the keyboard types (CORAÇÃO is CORACAO), which is
## what every rule compares against; `written` keeps its accents for the
## reveal.
var answer := ""
var written := ""
var rows: Array[String] = []
var marks: Array = []
var typed := ""
var given: Array[int] = []
var hints_left := HINTS

## The accept list, read once per language and shared by every instance in
## the process: 15,921 keys is a few ms and half a megabyte, and a harness
## that builds ten boards should pay for it once. The lists follow
## Locale.current() (content/hidden_word.pt.json and its siblings), and a
## change of language is read on the next board, never under an open one.
static var _lang := ""
static var _accept: Dictionary = {}
static var _answers: Array = []
static var _bands: Array = []

static func _load() -> void:
	if not _accept.is_empty() and _lang == Locale.current():
		return
	_lang = Locale.current()
	_accept = {}
	for word in FileAccess.get_file_as_string(Locale.content(ACCEPT)).split("\n", false):
		_accept[Locale.fold(word.strip_edges())] = true
	var doc = JSON.parse_string(FileAccess.get_file_as_string(Locale.content(WORDS)))
	_answers = []
	_bands = []
	if typeof(doc) == TYPE_DICTIONARY:
		_answers = doc.get("answers", [])
		_bands = doc.get("bands", [])
	# The board must never refuse its own word. A test asserts the two lists
	# already agree; this is the belt to that brace, and it is free.
	for w in _answers:
		_accept[Locale.fold(String(w))] = true

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	_load()
	rows = []
	marks = []
	typed = ""
	given = []
	hints_left = HINTS
	var band := int(_bands[clampi(difficulty, 0, _bands.size() - 1)]) if not _bands.is_empty() else _answers.size()
	written = String(_answers[rng.randi() % maxi(band, 1)]) if not _answers.is_empty() else "mossy"
	answer = Locale.fold(written)

func accepts(word: String) -> bool:
	_load()
	return _accept.has(word)

## The two-pass rule, and the one thing implementations get wrong. Greens
## first, each striking its letter off a tally of the answer; then, left to
## right, a remaining position is amber only while the tally still has a copy
## to spend. See the spec's SASSY-against-MOSSY case.
static func mark_guess(guess: String, word: String) -> Array[int]:
	var out: Array[int] = [MISS, MISS, MISS, MISS, MISS]
	var tally: Dictionary = {}
	for i in LEN:
		if guess[i] == word[i]:
			out[i] = HIT
		else:
			tally[word[i]] = int(tally.get(word[i], 0)) + 1
	for i in LEN:
		if out[i] == HIT:
			continue
		var n := int(tally.get(guess[i], 0))
		if n > 0:
			out[i] = NEAR
			tally[guess[i]] = n - 1
	return out

func type_letter(letter: String) -> bool:
	if is_solved() or is_over() or typed.length() >= LEN:
		return false
	if letter.length() != 1:
		return false
	var lower := letter.to_lower()
	if not Locale.alphabet().contains(lower):
		return false
	typed += lower
	return true

func erase() -> bool:
	if typed.is_empty():
		return false
	typed = typed.substr(0, typed.length() - 1)
	return true

func commit() -> int:
	if is_solved() or is_over():
		return SHORT
	if typed.length() < LEN:
		return SHORT
	if rows.has(typed):
		return REPEAT
	if not accepts(typed):
		return UNKNOWN
	marks.append(mark_guess(typed, answer))
	rows.append(typed)
	typed = ""
	return OK

## Derived on every call. -1 is a letter never guessed.
func key_mark(letter: String) -> int:
	var best := -1
	for r in rows.size():
		var word: String = rows[r]
		for i in LEN:
			if word[i] != letter:
				continue
			var m: int = marks[r][i]
			if best == -1 or m < best:
				best = m
	return best

## The leftmost position the player has not greened and no hint has given.
func hint() -> int:
	if hints_left <= 0 or is_solved() or is_over():
		return -1
	var green: Array[bool] = [false, false, false, false, false]
	for r in rows.size():
		for i in LEN:
			if marks[r][i] == HIT:
				green[i] = true
	for i in LEN:
		if not green[i] and not given.has(i):
			given.append(i)
			hints_left -= 1
			return i
	return -1

## Replays the same word from the first row. A hint is not a move to take
## back: `hints_left` and `given` are untouched, or Reset would let a hint,
## Reset, hint, Reset spell the answer out a letter at a time (spec section
## 10, Queens' own rule -- what was given stays given).
func reset() -> void:
	rows = []
	marks = []
	typed = ""

func is_solved() -> bool:
	if marks.is_empty():
		return false
	for m in marks[marks.size() - 1]:
		if int(m) != HIT:
			return false
	return true

func is_over() -> bool:
	return rows.size() >= ROWS and not is_solved()

func share_glyphs() -> String:
	var out: Array[String] = []
	for row in marks:
		var line := ""
		for m in row:
			line += GLYPH[int(m)]
		out.append(line)
	return "\n".join(out)
