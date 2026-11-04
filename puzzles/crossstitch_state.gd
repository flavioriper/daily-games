extends RefCounted

## Cross Stitch's rules (spec docs/superpowers/specs/2026-11-04-cross-stitch-design.md).
## A sampler of six five-letter words on a 5 by 5 linen with four holes:
## three across (rows 0, 2, 4) and three down (columns 0, 2, 4), sharing
## the nine crossings. Its 21 letters are dealt in the wrong places; swap
## any two to put them back. A letter in its place is stitched (green) and
## stays put; one in the right word but the wrong place is on the right
## thread (amber); the rest are strays (grey). The swaps are counted
## against the band's budget, the fewest that stitch the sampler plus a
## few; every letter stitched within it is the solve.
##
## On Insane (Loose Thread) there is no amber: a letter is stitched or not.
##
## The samplers are banked (tools/build_crossstitch.py,
## content/insane/crossstitch*.json), each with the fewest swaps that stitch
## it, solved exactly on the Mac; `fewest_from` solves it here again for
## the stars the way stands at and for the bulb.

## The four holes, row by row.
const HOLES := [6, 8, 16, 18]
## The bank each band's samplers come from.
const BANKS := ["crossstitch_easy", "crossstitch_medium", "crossstitch_hard", "crossstitch"]
## The swaps a band allows over the fewest.
const SPARE := [6, 5, 5, 6]
## The bulb, by band.
const HINTS := [3, 2, 1, 1]
## Swaps bought when the budget runs out (One more try, a rewarded video).
const MORE := 3
## Stars: three for the fewest swaps, two within STAR_TWO more, one after.
const STAR_TWO := 2
## Should a bank be missing, a sampler every language can spell (folded).
const SPARE_DAY := {
	"words": ["blend", "otter", "diary", "blood", "extra", "dirty"],
	"shown": ["blend", "otter", "diary", "blood", "extra", "dirty"],
	"start": "", "min": 0,
}

enum Mark { STITCHED, NEAR, STRAY }

var band := 0
## The six words, folded (across 0/2/4 then down 0/2/4), and as written.
var words: Array[String] = []
var shown: Array[String] = []
## The 25 cells as they should be and as they are ("" a hole).
var goal: Array[String] = []
var cells: Array[String] = []
var start := ""
## The fewest swaps that stitch the sampler as dealt.
var fewest := 0
## Swaps made by hand, and swaps bought.
var used := 0
var bought := 0
## Swaps the bulb made (free).
var helped := 0
## The marks the cells show, read after every swap.
var marks: Array[int] = []
## The words stitched whole, by slot.
var done_words: Array[bool] = [false, false, false, false, false, false]
## The fewest swaps from where the cells stand now (kept, read once a swap).
var to_go := 0
var _memo := {}

func deal(_rng: RandomNumberGenerator, the_band: int, bank_step := 0) -> void:
	band = clampi(the_band, 0, 3)
	var day: Dictionary = InsaneBank.pick(BANKS[band], bank_step)
	if day.is_empty():
		push_error("Cross Stitch: no samplers in %s" % BANKS[band])
		day = SPARE_DAY
	load_day(day)

func load_day(day: Dictionary) -> void:
	words.clear()
	shown.clear()
	for w in day.get("words", []):
		words.append(String(w))
	for w in day.get("shown", day.get("words", [])):
		shown.append(String(w))
	goal.clear()
	goal.resize(25)
	goal.fill("")
	for s in 6:
		var cs := cells_of(s)
		for k in 5:
			goal[cs[k]] = words[s][k] if s < words.size() else "a"
	start = String(day.get("start", ""))
	if start.length() != 25:
		# a sampler with no shuffle (the spare): turn it a cell along
		var letters: Array[String] = []
		for i in 25:
			if is_letter(i):
				letters.append(goal[i])
		letters.push_back(letters.pop_front())
		var s2 := ""
		var k := 0
		for i in 25:
			if is_letter(i):
				s2 += letters[k]
				k += 1
			else:
				s2 += "."
		start = s2
	restart()
	fewest = int(day.get("min", 0))
	if fewest <= 0:
		fewest = to_go

## The cells as dealt, nothing spent.
func restart() -> void:
	cells.clear()
	cells.resize(25)
	for i in 25:
		var ch := start[i] if i < start.length() else "."
		cells[i] = "" if ch == "." or not is_letter(i) else ch
	used = 0
	bought = 0
	helped = 0
	# a word dealt whole (Easy's given two) is stitched from the start
	done_words = [false, false, false, false, false, false]
	for s in 6:
		done_words[s] = _whole(s)
	_memo = {}
	_read()

static func is_letter(i: int) -> bool:
	return i >= 0 and i < 25 and not HOLES.has(i)

## The five cells of word `slot`: 0..2 across rows 0/2/4, 3..5 down
## columns 0/2/4.
static func cells_of(slot: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if slot < 3:
		var r := slot * 2
		for c in 5:
			out.append(r * 5 + c)
	else:
		var c := (slot - 3) * 2
		for r in 5:
			out.append(r * 5 + c)
	return out

## The words cell `i` stands in (one, or two at a crossing).
static func slots_of(i: int) -> Array[int]:
	var out: Array[int] = []
	var r := i / 5
	var c := i % 5
	if r % 2 == 0:
		out.append(r / 2)
	if c % 2 == 0:
		out.append(3 + c / 2)
	return out

func loose() -> bool:
	return band == 3

func stitched(i: int) -> bool:
	return is_letter(i) and cells[i] == goal[i]

func budget() -> int:
	return fewest + int(SPARE[band]) + bought

func left() -> int:
	return maxi(0, budget() - used)

func out() -> bool:
	return left() <= 0 and not solved()

func solved() -> bool:
	for i in 25:
		if is_letter(i) and cells[i] != goal[i]:
			return false
	return true

func can_swap(a: int, b: int) -> bool:
	return a != b and is_letter(a) and is_letter(b) and not stitched(a) and not stitched(b) \
		and not solved() and left() > 0

## Swaps cells `a` and `b`. `free`: the bulb's, not counted. What it did:
## {"stitched": cells newly in place, "words": slots newly whole}.
func swap(a: int, b: int, free := false) -> Dictionary:
	if not can_swap(a, b) and not (free and a != b and is_letter(a) and is_letter(b) and not stitched(a) and not stitched(b)):
		return {}
	var t := cells[a]
	cells[a] = cells[b]
	cells[b] = t
	if free:
		helped += 1
	else:
		used += 1
	var now: Array[int] = []
	for i in [a, b]:
		if stitched(i):
			now.append(i)
	var whole: Array[int] = []
	for s in 6:
		if not done_words[s] and _whole(s):
			done_words[s] = true
			whole.append(s)
	_read()
	return {"stitched": now, "words": whole}

func _whole(s: int) -> bool:
	for i in cells_of(s):
		if cells[i] != goal[i]:
			return false
	return true

## Every cell's mark: stitched first, then, word by word, a letter the word
## still needs where it is not yet stitched is on the right thread (as many
## times as the word needs it, reading the word from its start); a crossing
## is on the thread of either of its words. Insane shows no thread.
func _read() -> void:
	marks.clear()
	marks.resize(25)
	marks.fill(Mark.STRAY)
	var near := {}
	for i in 25:
		if stitched(i):
			marks[i] = Mark.STITCHED
	if not loose():
		for s in 6:
			var need := {}
			var cs := cells_of(s)
			for i in cs:
				if not stitched(i):
					need[goal[i]] = int(need.get(goal[i], 0)) + 1
			for i in cs:
				if stitched(i):
					continue
				var n := int(need.get(cells[i], 0))
				if n > 0:
					need[cells[i]] = n - 1
					near[i] = true
		for i in near:
			marks[i] = Mark.NEAR
	to_go = fewest_from(cells)

## The fewest swaps that stitch `from`: the misplaced letters less the most
## rings their letter graph (each misplaced cell an arrow from the letter it
## holds to the letter it wants) splits into.
func fewest_from(from: Array[String]) -> int:
	var edges := {}
	var m := 0
	for i in 25:
		if is_letter(i) and from[i] != goal[i]:
			var k := from[i] + goal[i]
			edges[k] = int(edges.get(k, 0)) + 1
			m += 1
	if m == 0:
		return 0
	var keys: Array = edges.keys()
	keys.sort()
	var counts: Array[int] = []
	for k in keys:
		counts.append(int(edges[k]))
	return m - _most_rings(counts, keys)

func _most_rings(counts: Array[int], keys: Array) -> int:
	var first := -1
	for i in counts.size():
		if counts[i] > 0:
			first = i
			break
	if first < 0:
		return 0
	var memo_key := "%s|%s" % [str(keys), str(counts)]
	if _memo.has(memo_key):
		return int(_memo[memo_key])
	# a ring through the first arrow left: every way back to where it began
	var a: String = String(keys[first])[0]
	var b: String = String(keys[first]).substr(1)
	var best := 0
	var paths: Array = []
	_walk(b, a, {a: true, b: true}, [first], counts, keys, paths)
	for path: Array in paths:
		var c: Array[int] = counts.duplicate()
		for e in path:
			c[e] -= 1
		best = maxi(best, 1 + _most_rings(c, keys))
	_memo[memo_key] = best
	return best

func _walk(at: String, home: String, seen: Dictionary, path: Array, counts: Array[int], keys: Array, out: Array) -> void:
	if at == home:
		out.append(path.duplicate())
		return
	for e in keys.size():
		var key := String(keys[e])
		if key[0] != at:
			continue
		var nxt := key.substr(1)
		if seen.has(nxt) and nxt != home:
			continue
		if counts[e] - path.count(e) <= 0:
			continue
		var s2 := seen.duplicate()
		s2[nxt] = true
		path.append(e)
		_walk(nxt, home, s2, path, counts, keys, out)
		path.pop_back()

## The stars the way stands at: the swaps made and the fewest still to go,
## against the sampler's fewest.
func stars() -> int:
	var way := used + to_go
	if way <= fewest:
		return 3
	if way <= fewest + STAR_TWO:
		return 2
	return 1

## Whether the swaps left can still stitch it.
func reachable() -> bool:
	return to_go <= left()

## The bulb's swap: two letters that each go where the other stands, else
## one put in its place by a swap that keeps the fewest falling by one.
## Vector2i(-1, -1) when there is none.
func hint_swap() -> Vector2i:
	var open: Array[int] = []
	for i in 25:
		if is_letter(i) and not stitched(i):
			open.append(i)
	for a in open:
		for b in open:
			if b > a and cells[a] == goal[b] and cells[b] == goal[a]:
				return Vector2i(a, b)
	var fallback := Vector2i(-1, -1)
	for a in open:
		for b in open:
			if b == a or cells[b] != goal[a]:
				continue
			if fallback.x < 0:
				fallback = Vector2i(b, a)
			var trial: Array[String] = cells.duplicate()
			trial[a] = cells[b]
			trial[b] = cells[a]
			if fewest_from(trial) == to_go - 1:
				return Vector2i(b, a)
	return fallback

## Every letter put back where it belongs (Show the sampler, a restore).
func finish() -> void:
	for i in 25:
		cells[i] = goal[i]
	for s in 6:
		done_words[s] = true
	_read()

## The day's line on the share: the swaps against the fewest, and the
## sampler's colours as the player leaves it.
func share_glyphs() -> String:
	var out := "%d/%d\n" % [used + helped, fewest]
	for r in 5:
		for c in 5:
			var i := r * 5 + c
			if not is_letter(i):
				out += "⬜"
			elif marks[i] == Mark.STITCHED:
				out += "🟩"
			elif marks[i] == Mark.NEAR:
				out += "🟨"
			else:
				out += "⬛"
		out += "\n"
	return out.strip_edges()

## The brain score: the fewest against the swaps it took (the bulb's count
## as swaps here), nothing for a sampler shown.
func quality() -> float:
	if not solved():
		return 0.0
	return clampf(float(fewest) / float(maxi(fewest, used + helped)), 0.0, 1.0)
