extends RefCounted

## Hidden Word's rules (puzzles/hidden_word_state.gd): the two-pass marking
## rule and its double-letter cases, the derived keyboard, the accept list's
## coverage of every answer, the bands, and that a seed reproduces a day.

const State = preload("res://puzzles/hidden_word_state.gd")
const Pal = preload("res://core/palette.gd")

static func run(t) -> void:
	_test_marking(t)
	_test_lists(t)
	_test_play(t)

## The rule every naive implementation gets wrong. A guess's second copy of a
## letter is grey once the answer's copies are spent on greens and earlier
## ambers.
static func _test_marking(t) -> void:
	# Every expectation below was computed from the rule and checked by hand.
	# Do not "fix" one to match an implementation -- if the code disagrees with
	# a row here, the code is wrong.
	var cases := [
		# guess,   answer,  expected
		["plant", "plant", [State.HIT, State.HIT, State.HIT, State.HIT, State.HIT]],
		["zzzzz", "plant", [State.MISS, State.MISS, State.MISS, State.MISS, State.MISS]],
		# The case the whole rule exists for. MOSSY has two S; SWISS spends one
		# on the green at 3 and one on the amber at 0, so the S at 4 is GREY.
		# A one-pass implementation paints it amber and lies.
		["swiss", "mossy", [State.NEAR, State.MISS, State.MISS, State.HIT, State.MISS]],
		# A near miss of the above: SASSY shares a third letter with MOSSY, so
		# it never exhausts the tally. Kept to prove the greens come first.
		["sassy", "mossy", [State.MISS, State.MISS, State.HIT, State.HIT, State.HIT]],
		# ABIDE's one I is free after the greens, so EERIE's I at 3 is amber
		# while both its E's before the green at 4 are grey.
		["eerie", "abide", [State.MISS, State.MISS, State.MISS, State.NEAR, State.HIT]],
		# LEVEL's two L's: one is spent on the green at 0, so LLAMA's second L
		# takes the last one as amber and its A's find nothing.
		["llama", "level", [State.HIT, State.NEAR, State.MISS, State.MISS, State.MISS]],
		# Every letter present, none in place.
		["stone", "notes", [State.NEAR, State.NEAR, State.NEAR, State.NEAR, State.NEAR]],
		# SHEET has two E; GEESE spends one green at 2 and one amber at 1, so
		# the E at 3 takes the last and the E at 4 is grey.
		["geese", "sheet", [State.MISS, State.NEAR, State.HIT, State.NEAR, State.MISS]],
	]
	for c in cases:
		var got: Array[int] = State.mark_guess(c[0], c[1])
		t.eq(str(got), str(c[2]), "%s against %s marks %s" % [c[0], c[1], c[2]])

## The accept list must contain every answer, or the game would refuse its own
## word. The bands must be inside the list and rising.
static func _test_lists(t) -> void:
	var s := State.new()
	s.setup(_rng(1), 0)
	t.check(s.answer.length() == State.LEN, "an answer is five letters")
	t.check(s.accepts(s.answer), "the day's answer is an accepted guess")
	var doc = JSON.parse_string(FileAccess.get_file_as_string("res://content/hidden_word.json"))
	t.check(typeof(doc) == TYPE_DICTIONARY, "the word file parses")
	var answers: Array = doc.get("answers", [])
	var bands: Array = doc.get("bands", [])
	t.eq(bands.size(), 3, "three difficulty bands")
	t.check(int(bands[0]) < int(bands[1]) and int(bands[1]) <= int(bands[2]), "the bands rise")
	t.eq(int(bands[2]), answers.size(), "the last band is the whole list")
	var bad := 0
	var plural := 0
	for w in answers:
		var word := String(w)
		if word.length() != State.LEN:
			bad += 1
		else:
			for i in State.LEN:
				if word.unicode_at(i) < 97 or word.unicode_at(i) > 122:
					bad += 1
					break
		if word.ends_with("s") and not "suioa".contains(word[3]):
			plural += 1
		if not s.accepts(word):
			bad += 1
	t.eq(bad, 0, "every answer is five lower-case letters and accepted")
	t.eq(plural, 0, "no answer is a plain -S plural")
	# The same day and difficulty is the same word on every device.
	var a := State.new(); a.setup(_rng(42), 1)
	var b := State.new(); b.setup(_rng(42), 1)
	t.eq(a.answer, b.answer, "a seed reproduces its word")
	# The three marks must be told apart by luminance alone, not just hue.
	for pair in [[Pal.GOOD, Pal.WORD_NEAR], [Pal.WORD_NEAR, Pal.WORD_MISS], [Pal.GOOD, Pal.WORD_MISS]]:
		var d: float = absf(pair[0].get_luminance() - pair[1].get_luminance())
		t.check(d > 0.06, "the three marks are told apart by luminance alone")

static func _test_play(t) -> void:
	var s := State.new()
	s.setup(_rng(7), 0)
	s.answer = "mossy"
	# Typing stops at five, erase takes one back.
	for ch in ["p", "l", "a", "n", "t", "x"]:
		s.type_letter(ch)
	t.eq(s.typed, "plant", "typing stops at five letters")
	t.check(s.erase(), "erase takes a letter back")
	t.eq(s.typed, "plan", "four letters left")
	t.eq(s.commit(), State.SHORT, "four letters will not commit")
	s.type_letter("t")
	t.eq(s.commit(), State.OK, "a real word commits")
	t.eq(s.rows.size(), 1, "the row is kept")
	t.eq(s.typed, "", "the working row is cleared")
	# The keyboard is derived: T is in MOSSY nowhere, S is.
	t.eq(s.key_mark("p"), State.MISS, "P was guessed and missed")
	t.eq(s.key_mark("z"), -1, "an unguessed letter has no mark")
	# The same row again is refused.
	for ch in ["p", "l", "a", "n", "t"]:
		s.type_letter(ch)
	t.eq(s.commit(), State.REPEAT, "the same guess twice is refused")
	s.typed = ""
	# A word that is not a word.
	for ch in ["z", "q", "x", "j", "v"]:
		s.type_letter(ch)
	t.eq(s.commit(), State.UNKNOWN, "a non-word is refused")
	s.typed = ""
	# Best mark wins on the keyboard: S is NEAR from GRASS, then HIT from MOSSY.
	for ch in ["g", "r", "a", "s", "s"]:
		s.type_letter(ch)
	t.eq(s.commit(), State.OK, "GRASS commits")
	t.eq(s.key_mark("s"), State.HIT, "S is green once it lands in place")
	# Solving.
	for ch in ["m", "o", "s", "s", "y"]:
		s.type_letter(ch)
	t.eq(s.commit(), State.OK, "the answer commits")
	t.check(s.is_solved(), "five greens is a solve")
	t.check(not s.is_over(), "a solve is not an over")
	t.check(s.share_glyphs().split("\n").size() >= 3, "the share block has a line a row")
	# Running out: six wrong rows, no solve.
	var o := State.new()
	o.setup(_rng(9), 0)
	o.answer = "mossy"
	for i in State.ROWS:
		for ch in ["p", "l", "a", "n", "t"]:
			o.type_letter(ch)
		o.rows.append(o.typed)
		o.marks.append(State.mark_guess(o.typed, o.answer))
		o.typed = ""
	t.check(o.is_over(), "six rows with no solve is over")
	t.check(not o.is_solved(), "and it is not a solve")
	# Hints reveal a position and never commit a row.
	var h := State.new()
	h.setup(_rng(3), 0)
	var before := h.rows.size()
	var at := h.hint()
	t.check(at >= 0 and at < State.LEN, "a hint names a position")
	t.check(h.given.has(at), "the position is remembered")
	t.eq(h.rows.size(), before, "a hint commits no row")
	var hints_before := h.hints_left
	h.reset()
	t.eq(h.rows.size(), 0, "reset clears the rows")
	t.eq(h.typed, "", "reset clears the working row")
	# Reset replays the same word, so a hint already spent stays spent -- else
	# hint, Reset, hint, Reset would spell the answer out a letter at a time.
	t.eq(h.hints_left, hints_before, "reset does not refund a hint")
	t.check(h.given.has(at), "reset leaves the given position given")

static func _rng(s: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return rng
