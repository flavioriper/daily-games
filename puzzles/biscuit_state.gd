extends RefCounted

## Biscuit Tin's rules (spec docs/superpowers/specs/2026-11-04-biscuit-tin-design.md).
## A tin of broken biscuit pieces, two to four letters each. Five long words
## (three on Easy) were each broken into four pieces and the pieces mixed.
## Pieces are laid on a plate in order, four at most; whenever the plate
## spells a word the tin knows (four letters or more) it is found and
## scores by the pieces it takes: 1, 2, 4, 8. Four pieces that spell one of
## the long words make a whole biscuit: it leaves the tin for the lid. Every
## biscuit whole is the solve.
##
## The tins are banked (tools/build_biscuit.py, content/insane/biscuit*.json):
## the pieces, each biscuit's four pieces in order, every word the pieces
## spell with the most pieces it takes, the fair ones, and the line three
## stars ask for. On Insane (Crumbs) four more pieces, a sixth word the tin
## never takes whole, are mixed in.

## The bank each band's tins come from.
const BANKS := ["biscuit_easy", "biscuit_medium", "biscuit_hard", "biscuit"]
## The bulb, by band.
const HINTS := [2, 2, 2, 1]
## A word's points by the pieces it takes.
const POINTS := [0, 1, 2, 4, 8]
## Two stars at this share of the line.
const TWO := 0.6
## The most pieces on the plate.
const PLATE := 4
## Should a bank be missing, a tin every language can spell (folded).
const SPARE_DAY := {
	"pieces": ["ca", "ram", "ra", "ral", "ane", "pi", "ma", "nos"],
	"biscuits": [[0, 1, 2, 3]],
	"words": [["caramelo", 3], ["carambola", 3]],
	"fair": [0],
	"line": 8,
}

var band := 0
var pieces: Array[String] = []
## Each biscuit's pieces in order, and its word.
var biscuits: Array = []
var biscuit_words: Array[String] = []
## Every word the tin credits (folded) -> the most pieces it takes.
var _words := {}
var word_list: Array[String] = []
var fair: Array[int] = []
var line := 0
var _shown := {}
## Pieces that belong to no biscuit (Insane's crumbs).
var crumbs: Array[int] = []

## The plate, pieces in order; the pieces gone from the tin (in a whole
## biscuit, or swept); the biscuits whole, in the order made; the words
## found (folded, in order); the points; the biscuits the bulb laid.
var plate: Array[int] = []
var gone := {}
var whole: Array[int] = []
var found: Array[String] = []
var points := 0
var helped := 0
## The bulb's biscuits, by index.
var by_bulb := {}

func deal(_rng: RandomNumberGenerator, the_band: int, bank_step := 0) -> void:
	band = clampi(the_band, 0, 3)
	var day: Dictionary = InsaneBank.pick(BANKS[band], bank_step)
	if day.is_empty():
		push_error("Biscuit Tin: no tins in %s" % BANKS[band])
		day = SPARE_DAY
	load_day(day)

func load_day(day: Dictionary) -> void:
	pieces.clear()
	for p in day.get("pieces", []):
		pieces.append(String(p))
	biscuits.clear()
	biscuit_words.clear()
	var in_biscuit := {}
	for b in day.get("biscuits", []):
		var row: Array[int] = []
		var w := ""
		for i in b:
			row.append(int(i))
			in_biscuit[int(i)] = true
			w += pieces[int(i)]
		biscuits.append(row)
		biscuit_words.append(w)
	crumbs.clear()
	for i in pieces.size():
		if not in_biscuit.has(i):
			crumbs.append(i)
	_words = {}
	word_list.clear()
	for e in day.get("words", []):
		var w := String(e[0]) if e is Array else String(e)
		_words[w] = int(e[1]) if e is Array else 1
		word_list.append(w)
	fair.clear()
	for i in day.get("fair", []):
		fair.append(int(i))
	_shown = day.get("shown", {})
	line = int(day.get("line", 0))
	if line <= 0:
		line = POINTS[4] * biscuits.size()
	restart()

## The tin as dealt, nothing found.
func restart() -> void:
	plate.clear()
	gone = {}
	whole.clear()
	found.clear()
	points = 0
	helped = 0
	by_bulb = {}

## The pieces still in the tin (not in a whole biscuit, not swept), in the
## tin's order; a piece on the plate is still in the tin's count.
func in_tin() -> Array[int]:
	var out: Array[int] = []
	for i in pieces.size():
		if not gone.has(i):
			out.append(i)
	return out

func on_plate(i: int) -> bool:
	return plate.has(i)

## What the plate spells (folded).
func plate_word() -> String:
	var out := ""
	for i in plate:
		out += pieces[i]
	return out

## A word as written (accents), from the bank.
func written(w: String) -> String:
	var i := word_list.find(w)
	if i >= 0 and _shown.has(str(i)):
		return String(_shown[str(i)])
	return w

func knows(w: String) -> bool:
	return _words.has(w)

## The biscuit `w` is, -1 when none.
func biscuit_of(w: String) -> int:
	return biscuit_words.find(w)

## Lays piece `i` at the end of the plate. False when it cannot go (gone,
## already there, the plate full).
func add(i: int) -> bool:
	if i < 0 or i >= pieces.size() or gone.has(i) or plate.has(i) or plate.size() >= PLATE:
		return false
	plate.append(i)
	return true

## Takes piece `i` and every piece after it off the plate, back to the
## tin. Returns the pieces taken, in plate order.
func back(i: int) -> Array[int]:
	var out: Array[int] = []
	var at := plate.find(i)
	if at < 0:
		return out
	while plate.size() > at:
		out.push_front(plate.pop_back())
	return out

## Every piece off the plate.
func clear_plate() -> Array[int]:
	var out := plate.duplicate()
	plate.clear()
	return out

## Reads the plate. Empty when it spells nothing the tin takes. Else
## {"word", "pieces": how many, "points", "again": found before,
## "biscuit": its index or -1}. A biscuit's four pieces leave the tin and
## the plate; `free`: the bulb laid it (no points).
func read(free := false) -> Dictionary:
	var w := plate_word()
	var n := plate.size()
	var b := biscuit_of(w)
	if b >= 0 and n == PLATE and not whole.has(b):
		var gain := 0 if free else POINTS[PLATE]
		points += gain
		if not found.has(w):
			found.append(w)
		whole.append(b)
		if free:
			helped += 1
			by_bulb[b] = true
		for i in plate:
			gone[i] = true
		plate.clear()
		if solved():
			for c in crumbs:
				gone[c] = true
		return {"word": w, "pieces": n, "points": gain, "again": false, "biscuit": b}
	# a biscuit's word counts only whole
	if b >= 0 or not knows(w):
		return {}
	if found.has(w):
		return {"word": w, "pieces": n, "points": 0, "again": true, "biscuit": -1}
	found.append(w)
	var got: int = POINTS[mini(n, PLATE)]
	points += got
	return {"word": w, "pieces": n, "points": got, "again": false, "biscuit": -1}

func solved() -> bool:
	return not biscuits.is_empty() and whole.size() == biscuits.size()

## The stars the points stand at: 3 at the line, 2 at TWO of it, else 1
## (the solve is always reached).
func stars() -> int:
	return stars_at(points)

func stars_at(p: int) -> int:
	if p >= line:
		return 3
	if p >= two_line():
		return 2
	return 1

func two_line() -> int:
	return ceili(line * TWO)

## The bulb's biscuit: the first not whole, -1 when none.
func hint_biscuit() -> int:
	for b in biscuits.size():
		if not whole.has(b):
			return b
	return -1

## The brain score: the points against the line, nothing for an unsolved
## tin.
func quality() -> float:
	if not solved():
		return 0.0
	return clampf(float(points) / float(maxi(1, line)), 0.0, 1.0)

## The day's line on the share: the points against the line, a biscuit a
## biscuit made (a bulb for one the bulb laid), the words found.
func share_glyphs() -> String:
	var out := "%d/%d\n" % [points, line]
	for b in whole:
		out += "💡" if by_bulb.has(b) else "🍪"
	out += " +%d" % maxi(0, found.size() - whole.size())
	return out

## Every biscuit whole (a restored day).
func finish() -> void:
	plate.clear()
	for b in biscuits.size():
		if not whole.has(b):
			whole.append(b)
		for i in biscuits[b]:
			gone[int(i)] = true
		if not found.has(biscuit_words[b]):
			found.append(biscuit_words[b])
	for c in crumbs:
		gone[c] = true
