extends RefCounted

## Hidden Word's rules, scene-free, so the board draws them and nothing else
## knows them. The five-letter answer comes from content/hidden_word.json by
## the day's seed; a guess is accepted against content/hidden_word_accept.txt,
## which is far larger on purpose (spec section 4).
##
## The keyboard's colours are **derived** from the committed rows on every
## call and never stored, the way Queens' crosses are: best mark wins, so a
## letter amber on row one and green on row three stays green.
## Spec: docs/superpowers/specs/2026-09-19-hidden-word-flat-design.md; the
## bands, the clue rule and Snail Mail are 2026-09-30-hidden-word-polish-design.md.
##
## The bands (polish spec, section 1):
##
## | band | words | hints | Reset clears | clue rule | colours |
## |---|---|---|---|---|---|
## | Easy (0) | the 217 commonest | 2 | every row | no | at once |
## | Medium (1) | the first 467 | 2 | every row | no | at once |
## | Hard (2) | all 968 | 1 | **the row being typed** | **yes** | at once |
## | Insane (3) | the Snail Mail bank | 0 | the row being typed | yes | **a row late** |

const WORDS := "res://content/hidden_word.json"
const ACCEPT := "res://content/hidden_word_accept.txt"

const HIT := 0
const NEAR := 1
const MISS := 2

const OK := 0
const SHORT := 1
const UNKNOWN := 2
const REPEAT := 3
## The clue rule's two refusals (Hard and Insane): a green left out of its
## place, and a letter the rows found left out of the word. `broken` names
## which letter and where.
const KEEP_GREEN := 4
const USE_LETTER := 5

## The rows a word gets, and the most it can have once the out-of-rows card's
## one more row has been bought.
const ROWS := 6
const MAX_ROWS := 7
const LEN := 5
const HINTS := 2
const HINTS_BY_BAND := [2, 2, 1, 0]

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
## True on Insane, where no hint is given at all (capabilities() reads it).
var no_hints := false
## How many rows this word gets: ROWS, or MAX_ROWS once one is bought.
var tries := ROWS
## Hard and Insane: a committed row is ink. Reset only clears the row being
## typed, so rows once read cannot be wiped and read again for free.
var keeps_rows := false
## Hard and Insane: every clue the delivered rows gave must be used -- a green
## stays in its place, and an amber or green letter is in the next guess.
var strict := false
## Insane, Snail Mail: a row's colours arrive when the next row is committed
## (or at once when the row is the answer, or when the rows run out).
var snail := false
## The clue rule's last refusal: {"letter", "at"} (at is -1 for USE_LETTER).
var broken: Dictionary = {}
## Snail Mail: how many rows the snail has brought (see delivered()).
var sent := 0
## How many rows the board has actually shown in colour, which trails
## delivered() while a row is still turning; -1 (no board) means as many as
## are delivered. The clue rule and the hint read it, so a refusal can never
## name a green that is still face-down or sealed.
var seen := -1

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

## `banked` is Insane's word out of the Snail Mail bank (the board picks it
## through InsaneBank); empty, the word comes off the list's bands as ever.
func setup(rng: RandomNumberGenerator, difficulty: int, banked := "") -> void:
	_load()
	rows = []
	marks = []
	typed = ""
	given = []
	broken = {}
	sent = 0
	seen = -1
	tries = ROWS
	hints_left = HINTS_BY_BAND[clampi(difficulty, 0, HINTS_BY_BAND.size() - 1)]
	no_hints = difficulty >= 3
	keeps_rows = difficulty >= 2
	strict = difficulty >= 2
	snail = difficulty >= 3
	var band := int(_bands[clampi(difficulty, 0, _bands.size() - 1)]) if not _bands.is_empty() else _answers.size()
	written = String(_answers[rng.randi() % maxi(band, 1)]) if not _answers.is_empty() else "mossy"
	if not banked.is_empty():
		written = banked
	answer = Locale.fold(written)
	# A banked word has to be one the board would never refuse.
	_accept[answer] = true

## The out-of-rows card's one more row, once a word.
func add_row() -> bool:
	if tries >= MAX_ROWS or is_solved():
		return false
	tries += 1
	return true

## How many committed rows show their colours. Every row, except on Insane,
## where the newest waits for the snail -- until it is the answer, or the
## last row there is. Kept rather than derived, because a row bought after the
## last one was shown must not take that row's colours back.
func delivered() -> int:
	return rows.size() if not snail else mini(sent, rows.size())

## Brings Snail Mail's count up to date after a commit, and never back down.
## The rows the clue rule and the hint may read: delivered and on screen.
func clue_rows() -> int:
	return delivered() if seen < 0 else mini(seen, delivered())

func _post() -> void:
	var due := rows.size() if is_solved() or rows.size() >= tries else maxi(0, rows.size() - 1)
	sent = maxi(sent, due)

## Whether `word` keeps every clue the delivered rows gave: each green letter
## in its place, and each letter a row marked green or amber there as many
## times as that row found it. Sets `broken` for the toast, leftmost first.
func keeps_clues(word: String) -> int:
	broken = {}
	for r in clue_rows():
		var row: String = rows[r]
		for i in LEN:
			if int(marks[r][i]) == HIT and word[i] != row[i]:
				broken = {"letter": row[i], "at": i}
				return KEEP_GREEN
	for r in clue_rows():
		var row: String = rows[r]
		var need: Dictionary = {}
		for i in LEN:
			if int(marks[r][i]) != MISS:
				need[row[i]] = int(need.get(row[i], 0)) + 1
		for i in LEN:
			var ch := row[i]
			if need.has(ch) and word.count(ch) < int(need[ch]):
				broken = {"letter": ch, "at": -1}
				return USE_LETTER
	return OK

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
	if strict:
		var kept := keeps_clues(typed)
		if kept != OK:
			return kept
	marks.append(mark_guess(typed, answer))
	rows.append(typed)
	typed = ""
	_post()
	return OK

## Derived on every call. -1 is a letter never guessed -- or, on Insane, one
## whose row the snail has not brought yet.
func key_mark(letter: String) -> int:
	var best := -1
	for r in delivered():
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
	for r in clue_rows():
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
## 10, Queens' own rule -- what was given stays given). On Hard and Insane
## the rows are ink and only the row being typed goes.
func reset() -> void:
	typed = ""
	broken = {}
	if keeps_rows:
		return
	rows = []
	marks = []
	sent = 0
	seen = mini(seen, 0)

func is_solved() -> bool:
	if marks.is_empty():
		return false
	for m in marks[marks.size() - 1]:
		if int(m) != HIT:
			return false
	return true

func is_over() -> bool:
	return rows.size() >= tries and not is_solved()

func share_glyphs() -> String:
	var out: Array[String] = []
	for row in marks:
		var line := ""
		for m in row:
			line += GLYPH[int(m)]
		out.append(line)
	return "\n".join(out)
