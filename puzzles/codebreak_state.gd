extends RefCounted

## Code Break's rules, with no scene in them: the hidden code, the rows
## played so far and their scores, the row being filled, and every move that
## changes one of those. The flat board (puzzles/codebreak2d.gd) draws this
## and nothing else; the island board (puzzles/codebreak3d.gd) still carries
## its own copy of the same rules until the trial is decided, and whichever
## screen survives, this is the one truth to keep.
##
## The rules are the island's, move for move, so the two boards can be judged
## as screens rather than as games: eight rows, three hints that lock the
## leftmost unrevealed seat, Reset that clears the whole board, and row eight
## ending the day whether or not the code was cracked.
## Spec: docs/superpowers/specs/2026-09-18-codebreak-flat-design.md, section 2.

const Gen = preload("res://puzzles/mastermind_gen.gd")

const TRIES := 8
## Not refunded by reset, as on every other board.
const HINTS := 3

## What the row's seats are worth, once the row is scored. The pouch only
## ever shows how many of each; a seat's own kind is drawn on nobody's face
## until the game is over and the code is on the table.
enum Kind { MISS, COLOUR, EXACT }

var length := 4
var palette_size := 6
var repeats := false
## Insane trims this to 7; every other band keeps TRIES.
var tries := TRIES
## The hidden row.
var code: Array = []
## The rows played, oldest first, and their scores as
## {"exact": int, "colour": int, "kinds": Array[Kind]}.
var guesses: Array = []
var marks: Array = []
## The row being filled: a friend index per seat, -1 empty.
var row: Array = []
## Per seat: filled by a hint and fixed for the rest of the game.
var locked: Array = []
## Places and pops in the active row, newest last; undo takes one back.
var history: Array = []
var hints_used := 0
var lost := false

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	match difficulty:
		0: length = 4; palette_size = 6; repeats = false; tries = TRIES
		1: length = 4; palette_size = 6; repeats = true; tries = TRIES
		3: length = 5; palette_size = 7; repeats = true; tries = 7
		_: length = 5; palette_size = 7; repeats = true; tries = TRIES
	code = Gen.make_code(rng, length, palette_size, repeats)
	guesses = []
	marks = []
	hints_used = 0
	lost = false
	_fresh_row()

func _fresh_row() -> void:
	row = []
	locked = []
	history = []
	for _s in length:
		row.append(-1)
		locked.append(false)

## Which row is being filled; it is also how many have been played.
func active() -> int:
	return guesses.size()

## The board takes picks, pops, undos and hints: not cracked, not out of tries.
func open() -> bool:
	return not is_solved() and not lost

func is_solved() -> bool:
	return not marks.is_empty() and int(marks[-1].exact) == length

## The leftmost empty seat no hint has claimed, or -1 when the row is full.
func free_slot() -> int:
	for s in length:
		if row[s] == -1 and not locked[s]:
			return s
	return -1

func full() -> bool:
	for s in length:
		if row[s] == -1:
			return false
	return true

## Seats friend `v` in the first free seat. Returns the seat, or -1 when the
## row has no room (the board nudges instead).
func place(v: int) -> int:
	if not open() or v < 0 or v >= palette_size:
		return -1
	var slot := free_slot()
	if slot < 0:
		return -1
	row[slot] = v
	history.append({"op": "place", "slot": slot, "colour": v})
	return slot

## Sends the friend in seat `s` back. Returns the friend, or -1 when the seat
## was empty or a hint locked it.
func pop(s: int) -> int:
	if not open() or s < 0 or s >= length or row[s] == -1 or locked[s]:
		return -1
	var was: int = row[s]
	row[s] = -1
	history.append({"op": "pop", "slot": s, "colour": was})
	return was

func can_undo() -> bool:
	return open() and not history.is_empty()

## Takes back the last place or pop. Played rows stay: their feedback is
## information the player has already seen. Returns {"slot": s, "colour": v}
## with the seat's new contents (-1 empty), or {} when there was nothing.
func undo() -> Dictionary:
	if not can_undo():
		return {}
	var last: Dictionary = history.pop_back()
	var s: int = int(last.slot)
	row[s] = -1 if last.op == "place" else int(last.colour)
	return {"slot": s, "colour": row[s]}

func hints_left() -> int:
	return HINTS - hints_used

## Seats the code's own friend in the leftmost seat no hint has claimed and
## locks it, as the island's `_locked` does, so every later row starts with
## it in place. Returns the seat, or -1. Costs no move.
func hint() -> int:
	if not open() or hints_left() <= 0:
		return -1
	var slot := -1
	for s in length:
		if not locked[s]:
			slot = s
			break
	if slot < 0:
		return -1
	locked[slot] = true
	row[slot] = code[slot]
	# A place or pop in that seat can no longer be taken back: the hint owns it.
	var kept: Array = []
	for h in history:
		if int(h.slot) != slot:
			kept.append(h)
	history = kept
	hints_used += 1
	return slot

## What the row in hand would score, without playing it.
func peek_score() -> Dictionary:
	return _score(row)

## Plays the row: it joins the history with its score, and the next row opens
## unless the code was cracked or that was row eight. Returns the score, or
## {} when the row is not full or the game is over.
func commit() -> Dictionary:
	if not open() or not full():
		return {}
	var m := _score(row)
	guesses.append(row.duplicate())
	marks.append(m)
	if int(m.exact) < length and guesses.size() >= tries:
		lost = true
	if open():
		_fresh_row()
	else:
		history = []
	return m

## The standard Mastermind score, plus which seat earned what: the counts are
## what the pouch shows, and the kinds are read only once the code is on the
## table.
func _score(guess: Array) -> Dictionary:
	var m: Dictionary = Gen.score(guess, code)
	var kinds: Array = []
	var left: Dictionary = {}
	for i in length:
		if guess[i] == code[i]:
			kinds.append(Kind.EXACT)
		else:
			kinds.append(Kind.MISS)
			left[code[i]] = int(left.get(code[i], 0)) + 1
	for i in length:
		if kinds[i] == Kind.EXACT:
			continue
		if int(left.get(guess[i], 0)) > 0:
			kinds[i] = Kind.COLOUR
			left[guess[i]] = int(left[guess[i]]) - 1
	m["kinds"] = kinds
	return m

## Reset clears the board, the way the island's does and every other board's:
## the played rows go, the lids come back, and the day starts again. Hints
## already spent stay spent.
func reset() -> void:
	guesses = []
	marks = []
	lost = false
	_fresh_row()

## Wordle's exact share grid, with no language in it.
func share_glyphs() -> String:
	var out := ""
	for m in marks:
		out += "🟩".repeat(int(m.exact)) + "🟨".repeat(int(m.colour))
		out += "⬛".repeat(length - int(m.exact) - int(m.colour)) + "\n"
	return out
