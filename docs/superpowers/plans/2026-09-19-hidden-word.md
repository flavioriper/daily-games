# Hidden Word Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Hidden Word, the eleventh flat board — five letters, six rows, one word a day, with an on-screen keyboard.

**Architecture:** A scene-free state class owns the rules; a drawn board owns the grid and its flip; a new tray row owns the keyboard. The board is the hybrid precedent (Tents): the grid is drawn off `core/motion.gd`'s curve readers into one `ArrayMesh`, the keys are `Button`s in slots taking the recipes. Two word lists ship in `content/` and are already committed.

**Tech Stack:** Godot 4.7, GDScript, gl_compatibility renderer. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-19-hidden-word-flat-design.md` — read it before Task 1 and keep it open; every task argues from it.

## Global Constraints

- **The name is never "Wordle".** Not in a file name, an identifier, a comment, a string or a doc. The board is **Hidden Word**, id `hiddenword`, script `puzzles/hidden_word2d.gd`.
- **Motion goes through the vocabulary.** `core/motion.gd` and `docs/art/flat-motion.md`. A board keeps only its own signature as constants of its own; a number that must differ goes through a recipe's parameter, never a copied constant. Rings, puffs and sparkles come from `ui/fx2d.gd` alone.
- **A card that moves inside a container needs a slot.** Every key is a child of a plain `Control` slot, never a direct child of the container.
- **A canvas command holds a mesh by RID.** A board that rebuilds a cached `ArrayMesh` every frame keeps the mesh its last `_draw` handed over (`_shown`) until the next one replaces it, or the renderer draws a freed RID.
- **Faces are code, never images**, and nothing is ever baked to a PNG.
- **`Analytics` and `Backend` are untouched.** The host already fires `puzzle_start` / `puzzle_complete` / `hint_used`; no new event.
- **Suite must stay green.** `godot --headless --path . --script tests/run_tests.gd` reports 2406 checks, 0 failures today; the number only grows.
- **Colours are `core/palette.gd` constants**, never literals in a board.
- **The two content files are already committed** at `content/hidden_word.json` (968 answers, `bands` `[217, 467, 968]`) and `content/hidden_word_accept.txt` (15,921 words, one a line). `content/*` is already in `export_presets.cfg`'s `include_filter`. Do not regenerate them.

---

### Task 1: The concept tab

The house rule (reaffirmed 2026-09-18): a reworked puzzle or screen gets a **playable** tab in `docs/brainstorm/concepts.html` before any Godot code, even with a spec and a mock in hand. Nothing in Tasks 2–9 may start before this one is reviewed.

**Files:**
- Modify: `docs/brainstorm/concepts.html` — one `<button data-tab="hiddenword">` in the nav after Queens, one `<section class="tab-panel" id="tab-hiddenword">`, and its mock's JS in the second `<script>` block
- Read first: the `tab-queens` section (line ~1519) and its JS — it is the template for structure, prose voice, the `?`-param harness and the demo controls

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-09-19-hidden-word-flat-design.md`, `docs/art/concept-hidden-word.png`
- Produces: the numbers the Godot board is ported from. Sizes named in the tab must be the sizes in the spec's section 5, drawn in the game's own 1080-wide design space and scaled to the 390×720 canvas.

- [ ] **Step 1: Read the Queens tab end to end**

Read `docs/brainstorm/concepts.html` from the `tab-queens` section through its JS. Match its structure exactly: `<h2>` with a `pill`, a `lede`, a `hero` with `refs` figures and a `demo` with a `<canvas>` plus `demo-controls`, a `note` block saying what is decided and what is proposed, then numbered `<h3>` sections, then a closing paragraph listing the `?` params.

- [ ] **Step 2: Build the playable mock**

One canvas, `id="hw"`, `width="390" height="720"`. It draws the **whole screen** in the 1080-wide design space, scaled: top bar (180), day card (120), board card (1140), keyboard (340), with the host's 40 margins and 20 gaps.

It must actually play, from a physical keyboard **and** from taps on the drawn keys:
- typing appends a letter to the working row, backspace erases, Enter commits
- a commit flips the row's five tiles in sequence, `FLIP_STEP` 0.16 s apart, `FLIP_TIME` 0.42 s each, each taking its colour at the halfway point
- the drawn keyboard repaints only when the last tile of the row lands
- a guess that is not in the accept list, or is short, shivers the row and raises the toast; nothing commits
- six wrong rows ends it with the reveal; five `HIT`s wins

Load the real lists with `fetch('../../content/hidden_word.json')` and `fetch('../../content/hidden_word_accept.txt')` so the mock plays the shipping words. Guard the fetch: if the page is opened over `file://` the fetch fails, so fall back to a small inline list of 40 answers and log it in the caption rather than showing a blank board.

- [ ] **Step 3: The marking rule, in the mock**

Implement the two-pass rule (spec section 3) here first, because this is where it gets reviewed:

```js
function mark(guess, answer) {
  const out = new Array(5).fill(MISS);
  const tally = {};
  for (let i = 0; i < 5; i++) {
    if (guess[i] === answer[i]) out[i] = HIT;
    else tally[answer[i]] = (tally[answer[i]] || 0) + 1;
  }
  for (let i = 0; i < 5; i++) {
    if (out[i] === HIT) continue;
    if (tally[guess[i]] > 0) { out[i] = NEAR; tally[guess[i]]--; }
  }
  return out;
}
```

- [ ] **Step 4: Demo controls and `?` params**

Buttons: `Reduce motion: off`, `Easy · common` / `Medium` / `Hard` (cycling), `New puzzle`, `Hint`, `Reveal the word`, `Reset`, and `Show the answer` (a debug line in the caption — the mock is for judging, not for keeping a secret).

Params, matching the Queens tab's harness: `?t=` seconds in, `?d=0|1|2`, `?seed=`, `?rm=1`, `?guess=plant,grass` for rows already committed, `?typed=mos` for a partial row, `?commit=slate` to commit that word at `?at=` (0.2 by default), `?bad=1` to commit a non-word, `?hint=1`, `?reset=1`, `?win=1`, `?over=1`, `?freeze=1` to hold the clock at `?t=` so a frame mid-flip can be shot. Pick the tab with `#hiddenword`.

- [ ] **Step 5: Verify with screenshots**

Per the house method: headless Chrome at 2× then a PIL crop, run from the repo directory.

```bash
cd /Users/flavioriper/dev/daily
run=(/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --headless --disable-gpu --force-device-scale-factor=2 --window-size=440,780)
for shot in "idle:" "mid:?guess=plant,grass&commit=slate&at=0.4&t=0.62&freeze=1" "bad:?typed=zzzzz&bad=1&t=0.5&freeze=1" "over:?over=1&t=2" "win:?win=1&t=2" "rm:?rm=1&guess=plant&t=1"; do
  name="${shot%%:*}"; q="${shot#*:}"
  "${run[@]}" --screenshot=/tmp/hw_$name.png "file://$PWD/docs/brainstorm/concepts.html$q#hiddenword"
done
ls -la /tmp/hw_*.png
```

Crop each to the phone with PIL from the repo directory (never `sips -c`, which crops centred), and look at all six. Expected: the idle grid is six empty rows with big tiles; `mid` catches a row part-flipped with the later tiles still cream; `bad` shows the toast over the grid; `over` shows the sprout and the word; `win` shows the green row lit and the rest dimmed; `rm` shows a committed row fully coloured with no flip in progress.

- [ ] **Step 6: Commit**

```bash
git add docs/brainstorm/concepts.html
git commit -m "docs(hiddenword): the concept tab, playable"
```

---

### Task 2: The state class

**Files:**
- Create: `puzzles/hidden_word_state.gd`
- Create: `tests/test_hidden_word.gd`
- Modify: `tests/run_tests.gd` — one line in the suite dictionary

**Interfaces:**
- Consumes: `content/hidden_word.json`, `content/hidden_word_accept.txt`
- Produces, and every later task depends on these exact names:
  - `const HIT := 0`, `NEAR := 1`, `MISS := 2`
  - `const OK := 0`, `SHORT := 1`, `UNKNOWN := 2`, `REPEAT := 3`
  - `const ROWS := 6`, `const LEN := 5`, `const HINTS := 2`
  - `var answer: String`, `var rows: Array[String]`, `var marks: Array`, `var typed: String`, `var given: Array[int]`
  - `func setup(rng: RandomNumberGenerator, difficulty: int) -> void`
  - `func type_letter(letter: String) -> bool`
  - `func erase() -> bool`
  - `func commit() -> int`
  - `func key_mark(letter: String) -> int`
  - `func hint() -> int` — returns the position revealed, or `-1`
  - `func reset() -> void`
  - `func is_solved() -> bool`
  - `func is_over() -> bool`
  - `func share_glyphs() -> String`
  - `static func mark_guess(guess: String, answer: String) -> Array[int]`

- [ ] **Step 1: Write the failing test**

Create `tests/test_hidden_word.gd`:

```gdscript
extends RefCounted

## Hidden Word's rules (puzzles/hidden_word_state.gd): the two-pass marking
## rule and its double-letter cases, the derived keyboard, the accept list's
## coverage of every answer, the bands, and that a seed reproduces a day.

const State = preload("res://puzzles/hidden_word_state.gd")

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
	h.reset()
	t.eq(h.rows.size(), 0, "reset clears the rows")
	t.eq(h.typed, "", "reset clears the working row")

static func _rng(s: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return rng
```

Register it in `tests/run_tests.gd`, in the suite dictionary beside `"queens"`:

```gdscript
		"hidden_word": "res://tests/test_hidden_word.gd",
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /Users/flavioriper/dev/daily
godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -20
```

Expected: failures naming `hidden_word`, because `puzzles/hidden_word_state.gd` does not exist.

- [ ] **Step 3: Write the state class**

Create `puzzles/hidden_word_state.gd`. The doc comment says what it is; the code is below it.

```gdscript
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

var answer := ""
var rows: Array[String] = []
var marks: Array = []
var typed := ""
var given: Array[int] = []
var hints_left := HINTS

## The accept list, read once per board and shared by every instance in the
## process: 15,921 keys is a few ms and half a megabyte, and a harness that
## builds ten boards should pay for it once.
static var _accept: Dictionary = {}
static var _answers: Array = []
static var _bands: Array = []

static func _load() -> void:
	if not _accept.is_empty():
		return
	for word in FileAccess.get_file_as_string(ACCEPT).split("\n", false):
		_accept[word.strip_edges()] = true
	var doc = JSON.parse_string(FileAccess.get_file_as_string(WORDS))
	if typeof(doc) == TYPE_DICTIONARY:
		_answers = doc.get("answers", [])
		_bands = doc.get("bands", [])
	# The board must never refuse its own word. A test asserts the two lists
	# already agree; this is the belt to that brace, and it is free.
	for w in _answers:
		_accept[String(w)] = true

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	_load()
	rows = []
	marks = []
	typed = ""
	given = []
	hints_left = HINTS
	var band := int(_bands[clampi(difficulty, 0, _bands.size() - 1)]) if not _bands.is_empty() else _answers.size()
	answer = String(_answers[rng.randi() % maxi(band, 1)]) if not _answers.is_empty() else "mossy"

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
	typed += letter.to_lower()
	return true

func erase() -> bool:
	if typed.is_empty():
		return false
	typed = typed.substr(0, typed.length() - 1)
	return true

func commit() -> int:
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

func reset() -> void:
	rows = []
	marks = []
	typed = ""
	given = []
	hints_left = HINTS

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
```

- [ ] **Step 4: Run the tests and make them pass**

```bash
cd /Users/flavioriper/dev/daily
godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -20
```

Expected: 0 failures, and the total up from 2406 by this file's checks. If `_test_lists`' plural check fires, do **not** loosen the check — the list is wrong and the word comes out.

- [ ] **Step 5: Commit**

```bash
git add puzzles/hidden_word_state.gd tests/test_hidden_word.gd tests/run_tests.gd
git commit -m "feat(hiddenword): the rules, and the two-pass marking rule under test"
```

---

### Task 3: Colour, and a letter on a tile

**Files:**
- Modify: `core/palette.gd` — three constants
- Modify: `ui/faces/mosaic_tile.gd` — one new static, nothing else moves
- Modify: `tests/test_hidden_word.gd` — one palette check

**Interfaces:**
- Produces: `Pal.WORD_NEAR`, `Pal.WORD_MISS`, `Pal.KEY_FACE`, and
  `Mosaic.letter(b, at: Vector2, s: float, ch: String, grow: Vector2, col: Color, font: Font, alpha := 1.0) -> void`

- [ ] **Step 1: Add the colours**

In `core/palette.gd`, beside the other board groups, with the comment saying what they are for:

```gdscript
## Hidden Word's three marks. GOOD is the green; the amber is its own rather
## than SUN_RAY, which is a brighter lemon and reads as the sun; the grey is
## warm, because a cool grey goes muddy on cream. KEY_FACE is a shade above
## SURFACE so the keyboard reads as a slab and not as six more cards.
const WORD_NEAR   := Color("e9ba55")
const WORD_MISS   := Color("8a8078")
const KEY_FACE    := Color("fffaf0")
```

- [ ] **Step 2: Add the letter to the tile**

`ui/faces/mosaic_tile.gd` already draws a socket, a tile and a pebble as builder shapes and already takes a `Vector2` scale. Add one static beside them that draws a letter centred in the cell, taking the same `grow` so a flipping tile's letter squashes with it:

```gdscript
## A letter centred on `at`, taking the piece's own `grow` so it squashes with
## the tile it is on. Hidden Word's only addition to this file.
##
## `at` is the cell's CENTRE, like `tile` and `pebble` and unlike `socket`,
## which takes the top-left corner -- this file has carried both conventions
## since Nonogram, and a letter follows the piece it is drawn on. `b` here is
## the board's own CanvasItem, not the Face.Builder its neighbours take: a
## letter is a draw command, never baked into the mesh.
const LETTER_SIZE := 0.56
static func letter(b, at: Vector2, s: float, ch: String, grow: Vector2,
		col: Color, font: Font, alpha := 1.0) -> void:
	if ch.is_empty() or alpha <= 0.0 or grow.x <= 0.0 or grow.y <= 0.0:
		return
	var size := int(s * LETTER_SIZE)
	var mid := at
	var text := ch.to_upper()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var h := font.get_height(size)
	var where := Vector2(-w * 0.5, h * 0.5 - font.get_descent(size))
	b.draw_set_transform(mid, 0.0, grow)
	font.draw_string(b.get_canvas_item(), where, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, alpha))
	b.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
```

This is Nonogram's clue-number technique (one `draw_set_transform` per line) applied to a tile.

- [ ] **Step 3: Check the palette in the test**

Append to `_test_lists` in `tests/test_hidden_word.gd`:

```gdscript
	const Pal = preload("res://core/palette.gd")
	for pair in [[Pal.GOOD, Pal.WORD_NEAR], [Pal.WORD_NEAR, Pal.WORD_MISS], [Pal.GOOD, Pal.WORD_MISS]]:
		var d: float = absf(pair[0].get_luminance() - pair[1].get_luminance())
		t.check(d > 0.06, "the three marks are told apart by luminance alone")
```

(Move the `const Pal` line to the top of the file with the other preloads — a `const` inside a function is not legal GDScript.)

- [ ] **Step 4: Run the suite**

```bash
cd /Users/flavioriper/dev/daily
godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -10
```

Expected: 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/palette.gd ui/faces/mosaic_tile.gd tests/test_hidden_word.gd
git commit -m "feat(hiddenword): the three marks, and a letter on a mosaic tile"
```

---

### Task 4: The keyboard tray

**Files:**
- Create: `ui/flat/key_board.gd`
- Read first: `ui/flat/tile_tray.gd` and `ui/flat/friend_tray.gd` — a tray's shape, its `HEIGHT`, how it stands on `ui/hud/panel.gd` and how its entrance is played

**Interfaces:**
- Consumes: `Pal.GOOD`, `Pal.WORD_NEAR`, `Pal.WORD_MISS`, `Pal.KEY_FACE`; `HiddenWordState.HIT/NEAR/MISS`
- Produces:
  - `const HEIGHT := 340.0`
  - `signal key(letter: String)`, `signal enter`, `signal erase`
  - `func set_marks(marks: Dictionary) -> void` — letter → `HIT`/`NEAR`/`MISS`; a letter absent is untouched
  - `func bump(letters: Array) -> void` — the named keys take `Motion.bump_scale`
  - `func slide_out(time: float) -> void` — for the reveal

- [ ] **Step 1: Build it**

`extends "res://ui/hud/panel.gd"`, the way every other tray does. Three rows in a `VBoxContainer` with a 14 separation:

```
QWERTYUIOP     10 keys
 ASDFGHJKL      9 keys, centred
⌫ZXCVBNM Enter  7 letters between two wide keys
```

Constants:

```gdscript
const HEIGHT := 340.0
const KEY := Vector2(91.0, 100.0)
const GAP := 10.0
const ROW_GAP := 14.0
const WIDE_BACK := 126.0
const WIDE_ENTER := 157.0
const RADIUS := 16.0
const ROWS := ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
```

**Every key stands in a slot.** A key is a `Button` inside a plain `Control` of `KEY` size; the slot goes in the row container, the button is positioned inside the slot, and the button is what presses and bumps. A key that wrote its own position straight into an `HBoxContainer` would be moved back on the next sort — the lesson Balance's weight cards paid for.

A key wears its own `StyleBoxFlat` (it must not take `CozyTheme.dress()`'s shared paper), face `Pal.KEY_FACE`, corner `RADIUS`, a 6 bottom edge in a darker shade, lettering in `Pal.TEXT` at 44. Enter is `Pal.GOOD` with `Pal.PAPER` lettering and reads `Enter`; ⌫ draws the backspace glyph.

- [ ] **Step 2: Colour and motion**

`set_marks` repaints each named key's stylebox face and switches its lettering to `Pal.PAPER` for `HIT`, `NEAR` and `MISS` alike. `bump` runs `Motion.bump_scale` on the slotted buttons. Press is `Motion.press_scale` at 0.94 on `button_down`, released on `button_up`. `slide_out` is `Motion.slide` on the tray's own position with a fade, and it is not a queue_free — Reset brings it back.

Entrance: the tray already gets the flat host's row entrance from `ui/hud/panel.gd`; on top of it, the three rows slide up 0.03 apart, and under `Motion.reduce` they are simply there.

- [ ] **Step 3: See it**

There is no board yet, so check it alone with a throwaway harness (throwaway, not a suite entry — delete it in step 5):

```bash
cd /Users/flavioriper/dev/daily
cat > /tmp/_kb.gd <<'EOF'
extends SceneTree
func _process(_d):
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = preload("res://ui/theme.gd").make()
	get_root().add_child(root)
	var kb = preload("res://ui/flat/key_board.gd").new()
	kb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	root.add_child(kb)
	await process_frame
	kb.set_marks({"a": 0, "s": 1, "t": 2, "n": 2, "l": 2})
	await process_frame
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png("/tmp/kb.png")
	quit()
EOF
godot --path . --resolution 1080x1920 --script /tmp/_kb.gd
```

Open `/tmp/kb.png` and look: three rows centred, A green, S amber, T/N/L grey, Enter wide and green, nothing clipped at either margin, the tray 340 tall.

Run one render harness at a time — never overlap windowed runs.

- [ ] **Step 4: Run the suite**

```bash
godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -6
```

Expected: 0 failures (this task adds no test; it must not break one).

- [ ] **Step 5: Commit**

```bash
rm -f /tmp/_kb.gd
git add ui/flat/key_board.gd
git commit -m "feat(hiddenword): the keyboard tray"
```

---

### Task 5: The shell wiring

**Files:**
- Modify: `core/puzzle_base.gd` — a signal and a method
- Modify: `ui/puzzle_host.gd:144` — connect the new signal
- Modify: `ui/flat/flat_host.gd` — a `"keys"` tray branch and a `"tip"` flag
- Modify: `ui/registry.gd` — the `hiddenword` entry; Horse Pen's `soon` card leaves the grid

**Interfaces:**
- Consumes: `KeyBoard.HEIGHT`, `KeyBoard.key/enter/erase`
- Produces: `PuzzleBase.ended` signal, `PuzzleBase.finish_unsolved()`; the host forwards `key`, `enter` and `erase` to the puzzle by calling `_puzzle.type_letter(l)`, `_puzzle.commit_row()` and `_puzzle.erase_letter()` when those methods exist

- [ ] **Step 1: The base gains an ending that is not a solve**

In `core/puzzle_base.gd`, beside `solved`:

```gdscript
## A board that can run out ends without a solve. Hidden Word is the only one
## (spec 2026-09-19-hidden-word-flat-design.md, section 8): six wrong rows and
## the word is revealed. The clock stops and the chrome greys exactly as a
## solve does, but `solved` never fires, so the host raises no win screen.
signal ended

func finish_unsolved() -> void:
	if _done:
		return
	_done = true
	_running = false
	ended.emit()
```

In `ui/puzzle_host.gd`, beside line 144's `_puzzle.solved.connect(_on_solved)`:

```gdscript
	_puzzle.ended.connect(_refresh)
```

- [ ] **Step 2: The flat host builds the keyboard and can drop the tip card**

In `ui/flat/flat_host.gd`'s `match` over `"tray"`, after the `"queens"` branch:

```gdscript
		"keys":
			# Hidden Word types: the tray is a keyboard, and the board takes
			# its three signals directly rather than through a brush.
			tray = KeyBoard.new()
			tray.key.connect(func(l: String) -> void:
				if is_instance_valid(_puzzle) and _puzzle.has_method("type_letter"):
					_puzzle.type_letter(l))
			tray.enter.connect(func() -> void:
				if is_instance_valid(_puzzle) and _puzzle.has_method("commit_row"):
					_puzzle.commit_row())
			tray.erase.connect(func() -> void:
				if is_instance_valid(_puzzle) and _puzzle.has_method("erase_letter"):
					_puzzle.erase_letter())
			rows.append(KeyBoard.HEIGHT)
```

with `const KeyBoard = preload("res://ui/flat/key_board.gd")` beside the other tray preloads.

The board also has to reach the keyboard, to repaint and bump its keys when a
row lands. The host hands it over once, after the board is spawned. In
`ui/flat/flat_host.gd`, wherever the host first refreshes a newly spawned
puzzle, add:

```gdscript
	# The one board that talks back to its tray: Hidden Word paints the keys
	# from the row it has just marked. Every other tray is driven by the host.
	if tray != null and is_instance_valid(_puzzle) and _puzzle.has_method("set_tray"):
		_puzzle.set_tray(tray)
```

and on the board, `func set_tray(t: Control) -> void: _tray = t`, with
`var _tray: Control = null` beside it, so a board built by a harness with no
tray still runs.

Then the tip card becomes optional, the same shape `"actions": false` already is. Replace the unconditional block:

```gdscript
	if bool(_entry.get("tip", true)):
		tip_card = TipCard.new()
		tip_card.name = "TipCard"
		tip_card.open.connect(_open_rules)
		_bottom_stack.add_child(tip_card)
		rows.append(TipCard.HEIGHT)
```

Every later use of `tip_card` in this file must be guarded with `if tip_card != null`. Find them all:

```bash
grep -n "tip_card" ui/flat/flat_host.gd
```

- [ ] **Step 3: The registry**

In `ui/registry.gd`, after the `queens` entry and before the `soon` block:

```gdscript
	{
		"id": "hiddenword",
		"kind": "puzzle",
		"title": "Hidden Word",
		"blurb": "Five letters, six tries. A new word every day.",
		"short": "Five letters,\nsix tries.",
		"motto": "Find the hidden word",
		"footer": "Type · Guess · Find",
		# It types, so its tray is a keyboard; every Enter is the check, so
		# there is no actions row and Reset rides in the top bar; and it is
		# the first board built with no tip card at all.
		"script": "res://puzzles/hidden_word2d.gd",
		"shell": "flat",
		"tray": "keys",
		"actions": false,
		"tip": false,
		"difficulties": [0, 1, 2],
	},
```

Delete the `horse` entry from `PUZZLES` (the `soon` card, around line 181 — **not** `horse_island` in `LEGACY`, which stays exactly as it is, `seed_as` still `"horse"`). Update the header comment at the top of the file: the grid is now eleven live cards and one `soon`, and say that Horse Pen's card left on 2026-09-19 for Hidden Word the way Snake Apple's left for Queens.

- [ ] **Step 4: Check the grid still draws**

```bash
cd /Users/flavioriper/dev/daily
godot --path . --resolution 1080x1920 --script tests/_shot_menu.gd
```

Open the shot it writes. Expected: twelve slots, eleven live cards, Pipes alone and dimmed in the last slot of the last row, nothing overlapping, the bottom bar still on screen. Note the draw-call count it prints — it is the baseline Task 9 measures against.

- [ ] **Step 5: Run the suite and commit**

```bash
godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -6
git add core/puzzle_base.gd ui/puzzle_host.gd ui/flat/flat_host.gd ui/registry.gd
git commit -m "feat(hiddenword): the keys tray, a board with no tip card, and an ending that is not a solve"
```

---

### Task 6: The board — the grid, typing and the flip

**Files:**
- Create: `puzzles/hidden_word2d.gd`
- Read first: `puzzles/nonogram2d.gd` — the closest board: drawn pieces, one `ArrayMesh`, `_shown`, the curve readers

**Interfaces:**
- Consumes: `HiddenWordState` (Task 2), `Mosaic.letter` and the three palette colours (Task 3), `KeyBoard` (Task 4), the host wiring (Task 5)
- Produces, called by the host and the tray:
  - `func type_letter(l: String) -> void`, `func erase_letter() -> void`, `func commit_row() -> void`
  - `func puzzle_id() -> String` → `"hiddenword"`, `title()` → `"Hidden Word"`
  - `func capabilities() -> Array[String]` → `["hint"]`
  - `func card_height(available: float) -> float`, `func card_centred() -> bool` → `true`
  - `func flat_win() -> Dictionary`, `win_delay()`, `share_glyphs()`, `reset_board()`, `hint()`, `hints_left()`

- [ ] **Step 1: The board's skeleton and its grid**

`extends "res://core/puzzle_base.gd"`. Constants of its own, and only these three are new numbers:

```gdscript
const FLIP_STEP := 0.16
const FLIP_TIME := 0.42
const TOAST_HOLD := 1.2
const GAP := 14.0     # between tiles, and between keyboard rows
const INSET := 28.0
const ENTER_DELAY := 0.18
const WIN_WAIT := 1.6
```

`build()` makes the state, calls `setup(rng, difficulty)` and sizes the grid:

```gdscript
const BAND := 120.0   # the scenery band at the card's foot
func _cell() -> float:
	var w := size.x - INSET * 2.0
	var h := size.y - INSET * 2.0 - BAND
	return minf((w - GAP * (State.LEN - 1)) / State.LEN, (h - GAP * (State.ROWS - 1)) / State.ROWS)
```

At 1080x1920 that is a **149** tile, the grid 801 wide of the 944 available, with 143 of side air — measured on the concept tab, which also corrected the spec's first arithmetic (at 169 the grid filled the card's inner height exactly and left the scenery nowhere to go).

`card_height(available)` returns the block plus the band plus the inset. `card_centred()` is `true`, but say so honestly in its comment: height binds in a 9:16 slot, so **its slack is zero on this phone and the call does nothing there**; it earns its keep only on a squarer screen, where the width binds instead.

- [ ] **Step 2: Draw it as one mesh**

`_draw` builds a `SurfaceTool` over every tile: `Mosaic.socket` for the bed, the tile's face in its mark's colour (`Pal.SURFACE_HI` while empty, `Pal.GOOD`/`Pal.WORD_NEAR`/`Pal.WORD_MISS` once flipped), then `Mosaic.letter` for the character. Thirty tiles go into one mesh and one `draw_mesh`.

**Keep the mesh the last `_draw` handed over** in a `_shown` member until the next one replaces it — a canvas command holds a mesh by RID, and dropping it leaves the renderer drawing a freed RID ("Parameter mesh is null", an empty card) on any frame rendered without the queued redraw flushed. `lightup2d.gd` does exactly this; copy its shape.

The scenery band (`ui/flat/scenery.gd`) goes into the same mesh under the grid: clouds and tufts, the way Balance lays them. The mock's sign, bushes and sprout do **not** stand beside the card — there is no outside at 40 px margins (spec section 5).

- [ ] **Step 3: Typing and the flip**

`type_letter` and `erase_letter` call the state, pop or shrink the tile off `Motion.pop_in_scale` / the quarter turn, and `queue_redraw`.

`commit_row` calls `state.commit()`:
- `OK` — start the flip. Record `_flip_at = _now()` and `_flip_row = rows.size() - 1`. A tile's `grow.y` is read every frame from the seconds since `_flip_at + i * FLIP_STEP` over `FLIP_TIME`: `abs(cos(PI * u))` shaped, and the tile takes its **colour at `u >= 0.5`**, edge-on, so the answer arrives with the turn. When the last tile lands, call `_tray.set_marks(m)` with a `Dictionary` of letter → mark for the five letters of that row and `_tray.bump(letters)` with those letters — **not before**, or the keyboard gives the row away. Then `note_move()`.
- `SHORT`, `UNKNOWN`, `REPEAT` — raise the toast (Task 7) and shiver the row with `Motion.shiver_offset`, 2 px over 0.2 s. Nothing commits, nothing counts.

`_animating()` must return true while **any** wave is running — the flip, the entrance, the toast, the reveal — not only the entrance. One Line froze two lines at four fifths of their fade by asking about one wave only; it showed on a rendered frame and in no test.

Under `Motion.reduce`, a committed row takes its colours in one frame with no flip and the keyboard repaints at once.

- [ ] **Step 4: Shoot it**

A probe must let a frame pass between poking the board and `force_draw()` — `queue_redraw` is flushed on the next idle frame, so a probe that pokes and shoots in the same frame photographs the state before the poke. Set `Motion.reduce` right before the board opens, never after.

```bash
cd /Users/flavioriper/dev/daily
godot --path . --resolution 1080x1920 --script tests/_shot_anim.gd -- hiddenword
```

Look at every frame it writes: the empty grid, a row part-flipped, a row landed. Expected: 169-ish tiles, five across centred, six down filling the card, letters legible, the flip caught mid-turn on at least one frame.

- [ ] **Step 5: Run the suite and commit**

```bash
godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -6
git add puzzles/hidden_word2d.gd
git commit -m "feat(hiddenword): the board, and the row that flips"
```

---

### Task 7: The board — the toast, the hint, Reset, the win and the reveal

**Files:**
- Modify: `puzzles/hidden_word2d.gd`

**Interfaces:**
- Consumes: everything Task 6 produced
- Produces: `hint()`, `hints_left()`, `reset_board()`, `flat_win()`, `win_delay()`, `share_glyphs()`

- [ ] **Step 1: The toast**

A pill drawn in the board's own `_draw`, over the top of the grid: `Pal.TEXT` at 0.92, lettering in `Pal.PAPER`, corner 20, its scale read off `Motion.pop_in_scale` for the first 0.18 s and `Motion.pop_out_scale` for the last 0.18 s of `TOAST_HOLD`. Three lines, and no others: `"Not a word"`, `"Five letters"`, `"You guessed that already"`. Under `Motion.reduce` it appears and goes with no scale.

- [ ] **Step 2: The hint**

```gdscript
func hints_left() -> int:
	return state.hints_left

func hint() -> bool:
	var at := state.hint()
	if at < 0:
		return false
	# It is a given, not a guess: the player still types it, and it never
	# spends a row. A ring over the column, the letter dropping in ghosted,
	# sparkles in leaf, and that key greens with a bump.
	var cell := _cell()
	var mid := _origin() + Vector2(at * (cell + GAP), state.rows.size() * (cell + GAP)) + Vector2(cell, cell) * 0.5
	if not Motion.reduce:
		# `fx` is the board's own Fx2D node, as on every flat board; its
		# methods are instance methods, not statics.
		fx.ring(mid, cell * 0.6, Pal.LEAF)
		for i in 5:
			fx.sparkle(mid + Vector2(randf() - 0.5, randf() - 0.5) * cell * 0.8, Pal.LEAF)
		_given_at[at] = _now()
	if _tray != null:
		_tray.set_marks({state.answer[at]: State.HIT})
		_tray.bump([state.answer[at]])
	hints_used += 1
	queue_redraw()
	check_solved()
	return true
```

The given letter draws ghosted at 0.55 in its own column of the working row whenever that column is still empty. `Fx2d` supplies the ring and the sparkles; nothing else may.

- [ ] **Step 3: Reset**

`reset_board()` calls `state.reset()`, brings the keyboard back if the reveal took it (`tray.slide_out` is reversible), clears its colours, and shrinks the committed tiles out in a wave from the last row up, 0.03 a tile. It replays the same day; the gear's New puzzle is what gives a fresh one.

- [ ] **Step 4: The win and the reveal**

On a solve: the winning row's tiles hop 10 letter by letter, 0.04 apart after 0.25, with sparkles in gold, and the rows above fade to 0.3.

```gdscript
func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": "Found it."}
```

The win screen shows no cast: five green tiles spelling the word are what stays on the card under it, the way Nonogram leaves its picture.

On `state.is_over()`: call `finish_unsolved()`, slide the keyboard out over 0.25, dim the rows to 0.4, and raise the sprout (`ui/faces/sprout_face.gd`) from the bottom of the card over 0.35 with `The word was MOSSY.` on a small card beside it. No red and no "you lost". `solved` never fires, so no win screen comes.

- [ ] **Step 5: Shoot all four**

```bash
cd /Users/flavioriper/dev/daily
godot --path . --resolution 1080x1920 --script tests/_shot_anim.gd -- hiddenword
```

Expected frames: the toast over the grid; a hint's ghost letter and its greened key; the solve with the row lit and the rest dim; the reveal with the sprout, the word, and no keyboard. Check the reduce-motion frames too — two frames 1.5 s apart must come out pixel-identical.

- [ ] **Step 6: Win harness**

`tests/_win.gd` silently reports 0/0 headless — run it **windowed**.

```bash
godot --path . --resolution 1080x1920 --script tests/_win.gd
```

Expected: 11/11, Hidden Word among them. If it reports 10/11, the solve path is wrong, not the harness.

- [ ] **Step 7: Run the suite and commit**

```bash
godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -6
git add puzzles/hidden_word2d.gd tests/_win.gd tests/_shot_anim.gd
git commit -m "feat(hiddenword): the toast, the hint, Reset, the win and the reveal"
```

---

### Task 8: The menu card

**Files:**
- Modify: `ui/menu/card_art.gd` — one `_build` branch and one `_draw` branch

**Interfaces:**
- Consumes: `Pal.GOOD`, `Pal.WORD_NEAR`, `Pal.WORD_MISS`, `Scenery`

- [ ] **Step 1: Draw it**

In `_build`'s `match id`, a `"hiddenword"` branch; in `_draw`'s, a `_draw_letters()`. Three letter tiles in a row in the 320 by 118 box — one `Pal.GOOD`, one `Pal.WORD_NEAR`, one `Pal.WORD_MISS`, lettered `H`, `I`, `D` — seated on the shared scenery band drawn under them. Drawn, never a `SubViewport` and never an image. A new card costs one branch of `_build` and one of `_draw`, and this one has no cast, so it costs no node.

- [ ] **Step 2: Shoot the menu**

```bash
cd /Users/flavioriper/dev/daily
godot --path . --resolution 1080x1920 --script tests/_shot_menu.gd
```

Expected: the Hidden Word card reads at card size — three tiles, three colours, the name under them — and the draw-call count has not moved far from Task 5's baseline. Queens' picture cost 12; this one has no faces and should cost less.

- [ ] **Step 3: Commit**

```bash
git add ui/menu/card_art.gd
git commit -m "feat(hiddenword): the card's picture"
```

---

### Task 9: Measure it, and put it on the record

**Files:**
- Modify: `docs/art/flat-motion.md` — the Hidden Word row
- Modify: `CLAUDE.md` — eleven flat boards, one `soon`, the keyboard tray, the first board with no tip card and the first that can end unsolved
- Modify: `docs/superpowers/specs/2026-09-19-hidden-word-flat-design.md` — an "Amendments from the build" section
- Modify: `ui/registry.gd` — only if a measured number contradicts a comment

- [ ] **Step 1: Measure**

Run these **one at a time** — never overlap windowed render harnesses, and take two sequential readings, because the first run pays for shader compilation.

```bash
cd /Users/flavioriper/dev/daily
godot --path . --resolution 1080x1920 --script tests/_shot_menu.gd
godot --path . --resolution 1080x1920 --script tests/_shot_anim.gd -- hiddenword
```

Record: the menu's draw calls before and after (Task 5's baseline against Task 8's), the board's draw calls idle and mid-flip, and the mean idle in ms. One odd reading is an outlier — take the second.

- [ ] **Step 2: Check it on the phone's real driver**

The mobile-only class of defect reproduces on this Mac under ANGLE:

```bash
godot --path . --resolution 1080x1920 --rendering-driver opengl3_angle --script tests/_shot_anim.gd -- hiddenword
```

Expected: identical frames. If the letters or the tiles come out wrong here and right on the default driver, something has reintroduced an `instance uniform` — the buffer is sixteen instances, not 256, and a desktop driver hides the overrun.

- [ ] **Step 3: The motion doc**

Add Hidden Word's row to `docs/art/flat-motion.md`, naming what it took from the vocabulary and what is its own: the flip is its signature, and it is the first board whose one irreversible move is a commit.

- [ ] **Step 4: CLAUDE.md**

Update "The flat screens": eleven boards, not ten; the ten bottom-slot heights become eleven, with Hidden Word's being the keyboard alone at 340; the tray list gains `"keys"`; note that Hidden Word is the first board built with **no tip card** (`"tip": false`) and the first that can end without a solve (`finish_unsolved`, `ended`). Update "The first screen": twelve cards, eleven live and **one** `soon`, and say Horse Pen's card left on 2026-09-19. Add the new draw-call and idle numbers, honestly labelled — if a figure is at the 120 Hz vsync cap, say it is a ceiling and not a measurement.

- [ ] **Step 5: Amend the spec**

Append an "Amendments from the build, 2026-09-19" section to the spec with everything that came out different: the measured cell size if it is not 169, the real draw-call cost, anything section 12's calls settled, and any number the concept tab and the board disagreed on.

- [ ] **Step 6: Final check and commit**

```bash
godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -6
godot --path . --resolution 1080x1920 --script tests/_win.gd
git status --porcelain
git add -A
git commit -m "docs(hiddenword): the eleventh flat board on the record, measured"
```

Then stop and hand back. `git checkout project.godot` first if Godot has re-saved it with a header comment after the windowed runs — that is noise, not a change. **The merge and the push are the user's call**, not this plan's.
