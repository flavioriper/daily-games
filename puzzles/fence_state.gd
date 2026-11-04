extends RefCounted

## Garden Fence's rules (spec docs/superpowers/specs/2026-11-04-garden-fence-design.md).
## A ring of fence posts round a garden bed, three a side, a letter on each.
## Twine is strung post to post to spell a word: three letters at least,
## never two letters in a row from one side. A word tied off, the next one
## starts on the post it ended on. Every post used is the solve; letters may
## be used again. On Insane (Gate) the last word must end on the gate post.
##
## The fences are banked (tools/build_fence.py, content/insane/fence*.json):
## the posts, the sides, the par (the fewest words, proved by search), one
## fewest route and Insane's gate. Any word the garden knows that the fence
## can string is a word (content/fence_words.json, read once a session and
## filtered by the fence at load); the fewest still to go and the bulb walk
## on the common ones only.

## The bank each band's fences come from.
const BANKS := ["fence_easy", "fence_medium", "fence_hard", "fence"]
const HINTS := [3, 2, 2, 2]
const WORDS := "res://content/fence_words.json"
## A word's fewest letters.
const SHORTEST := 3
## Stars: three up to par and this many words more, two up to TWO more.
const THREE := 1
const TWO := 3
## The fewest still to go is searched this deep, then said to be one more.
const DEEP := 2
const HINT_DEEP := 3
## The three-word search gives up after this many middle words.
const BUDGET := 1200
## Should a bank be missing, a triangle its route can always string
## (METAL, LINDO: the route is always a word, whatever the language).
const SPARE_DAY := {"posts": "aeimnodlt", "sides": 3, "gate": -1, "par": 2, "route": ["metal", "lindo"]}

## What a tie came to.
enum Said { SHORT, UNKNOWN, AGAIN, TIED, SOLVED, OPEN }

var band := 0
var sides := 4
var posts: PackedStringArray = []
var gate := -1
var par := 2
var route: Array[String] = []
## The words tied, in order: [{"word", "kind"}], kind "hand" or "bulb".
var tied: Array = []
## The posts strung for the word being made, in order. While a word is
## tied the first is the post it ended on.
var trail: Array[int] = []
## Words the bulb strung, all told (untied ones too).
var helped := 0
## Words the bulb has backed out of as dead ends: it never offers them
## again this day.
var _dead := {}
## How much each post is worth to a word that reaches it: one over how many
## common words do (a post few words touch is the one to aim for).
var _rare: PackedFloat32Array = []

## The fence's words: word -> mask of the posts it uses; the common ones
## by first letter, commonest first: letter -> [[word, mask]].
var _mask := {}
var _fair := {}
var _fair_set := {}
var _post_of := {}
var _full := 0
var _shown := {}
## The rarer words by first letter, sorted (PackedStringArray).
var _more := {}
var _words_n := 0

## The words in the player's language, read once a session:
## {"fair": {letter: PackedStringArray}, "more": {...}, "shown": {}}.
static var _cache := {}

static func words_doc() -> Dictionary:
	var path := Locale.content(WORDS)
	if _cache.has(path):
		return _cache[path]
	var out := {"fair": {}, "more": {}, "shown": {}}
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if doc is Dictionary:
		for kind in ["fair", "more"]:
			var groups: Dictionary = doc.get(kind, {})
			for k in groups:
				out[kind][String(k)] = String(groups[k]).split(" ", false)
		out.shown = doc.get("shown", {})
	else:
		push_error("Garden Fence: no words at %s" % path)
	_cache[path] = out
	return out

func deal(_rng: RandomNumberGenerator, the_band: int, bank_step := 0) -> void:
	band = clampi(the_band, 0, 3)
	var day: Dictionary = InsaneBank.pick(BANKS[band], bank_step)
	if day.is_empty():
		push_error("Garden Fence: no fences in %s" % BANKS[band])
		day = SPARE_DAY
	load_day(day)

func load_day(day: Dictionary) -> void:
	var letters := Locale.fold(String(day.get("posts", SPARE_DAY.posts)))
	posts = PackedStringArray()
	for ch in letters:
		posts.append(ch)
	sides = maxi(3, int(day.get("sides", posts.size() / 3)))
	gate = int(day.get("gate", -1)) if band == 3 else -1
	if gate >= posts.size():
		gate = -1
	route.clear()
	for w in day.get("route", []):
		route.append(Locale.fold(String(w)))
	par = maxi(1, int(day.get("par", route.size())))
	_post_of = {}
	for i in posts.size():
		_post_of[posts[i]] = i
	_full = (1 << posts.size()) - 1
	_words_n = int(day.get("words", 0))
	_lex()
	restart()

## The fence's common words out of the language's (the bulb and the
## fewest-to-go walk on them). The rarer ones are looked up as they are
## tied (`knows`): filtering them all at load took twice as long.
func _lex() -> void:
	var doc := words_doc()
	_mask = {}
	_fair = {}
	_fair_set = {}
	_shown = doc.shown
	_more = doc.more
	var groups: Dictionary = doc.fair
	for p in posts:
		if not groups.has(p):
			continue
		var row: Array = []
		for w: String in groups[p]:
			var m := mask_of(w)
			if m < 0:
				continue
			_mask[w] = m
			row.append([w, m])
			_fair_set[w] = true
		_fair[p] = row
	var count := PackedInt32Array()
	count.resize(posts.size())
	for p in _fair:
		for e: Array in _fair[p]:
			var m: int = e[1]
			for i in posts.size():
				if m & (1 << i) != 0:
					count[i] += 1
	_rare.resize(posts.size())
	for i in posts.size():
		_rare[i] = 1.0 / maxf(1.0, count[i])
	# the route is always a word (a bank built from an older list)
	for w in route:
		var m := mask_of(w)
		if m >= 0 and not _mask.has(w):
			_mask[w] = m
			_fair_set[w] = true
			var first := w.substr(0, 1)
			if not _fair.has(first):
				_fair[first] = []
			_fair[first].push_front([w, m])

## The fence as dealt, no twine.
func restart() -> void:
	tied.clear()
	trail.clear()

# --- the fence ---

func side_of(post: int) -> int:
	return post / 3

func post_of(letter: String) -> int:
	return int(_post_of.get(letter, -1))

## The posts `w` uses as a mask, or -1 when the fence cannot string it
## (a letter not on a post, two in a row from one side, too short).
func mask_of(w: String) -> int:
	if w.length() < SHORTEST:
		return -1
	var m := 0
	var prev := -1
	for ch in w:
		var p := int(_post_of.get(ch, -1))
		if p < 0 or side_of(p) == prev:
			return -1
		prev = side_of(p)
		m |= 1 << p
	return m

func knows(w: String) -> bool:
	if _mask.has(w):
		return true
	var group = _more.get(w.substr(0, 1))
	if group == null or mask_of(w) < 0:
		return false
	var at: int = (group as PackedStringArray).bsearch(w)
	return at < group.size() and group[at] == w

func is_fair(w: String) -> bool:
	return _fair_set.has(w)

## How many words the fence takes, all told (the bank says).
func word_count() -> int:
	return _words_n if _words_n > 0 else _mask.size()

## A word as written, with its accents where it has them.
func written(w: String) -> String:
	return String(_shown.get(w, w))

## The posts every tied word has used.
func used() -> int:
	var m := 0
	for t: Dictionary in tied:
		m |= int(_mask.get(String(t.word), mask_of(String(t.word))))
	return m

## The posts the tied words and the trail have used.
func used_with_trail() -> int:
	var m := used()
	for p in trail:
		m |= 1 << p
	return m

func is_used(post: int) -> bool:
	return used() & (1 << post) != 0

func posts_left() -> int:
	var m := used()
	var n := 0
	for i in posts.size():
		if m & (1 << i) == 0:
			n += 1
	return n

## The letter the next word starts on ("" before the first).
func joint() -> String:
	if tied.is_empty():
		return ""
	var w: String = tied[-1].word
	return w.substr(w.length() - 1)

## The posts the trail must keep (the joint).
func base() -> int:
	return 0 if tied.is_empty() else 1

func trail_word() -> String:
	var out := ""
	for p in trail:
		out += posts[p]
	return out

## Whether post `p` may be strung next: any post to start the first word,
## else never one from the side of the last.
func can_add(p: int) -> bool:
	if p < 0 or p >= posts.size() or solved():
		return false
	if trail.is_empty():
		return true
	return side_of(p) != side_of(trail[-1])

func add(p: int) -> bool:
	if not can_add(p):
		return false
	trail.append(p)
	return true

## Takes the last letter off the trail (never the joint). False when there
## is none.
func back() -> bool:
	if trail.size() <= base():
		return false
	trail.pop_back()
	return true

## Unties the last word: its twine comes off and the trail starts again on
## the post the word before ended on. The word, or "".
func untie() -> String:
	if tied.is_empty():
		return ""
	var w: String = tied.pop_back().word
	_rejoin()
	return w

## Every word untied, the trail empty.
func clear() -> void:
	tied.clear()
	trail.clear()

func _rejoin() -> void:
	trail.clear()
	if not tied.is_empty():
		trail.append(post_of(joint()))

## Ties the trail off. A word the fence knows, not tied before, is tied:
## the next starts on its last post. The trail stays when it is refused.
func tie(kind := "hand") -> Said:
	var w := trail_word()
	if w.length() < SHORTEST:
		return Said.SHORT
	if not knows(w):
		return Said.UNKNOWN
	for t: Dictionary in tied:
		if t.word == w:
			return Said.AGAIN
	tied.append({"word": w, "kind": kind})
	if kind == "bulb":
		helped += 1
	_rejoin()
	if solved():
		trail.clear()
		return Said.SOLVED
	return Said.OPEN if used() == _full else Said.TIED

## Strings `w` from the joint (the bulb, the tutorial): the trail is laid
## for it. False when the fence cannot.
func string_word(w: String) -> bool:
	var m := mask_of(w)
	if m < 0 or (not tied.is_empty() and w.substr(0, 1) != joint()):
		return false
	trail.clear()
	for ch in w:
		trail.append(post_of(ch))
	return true

func solved() -> bool:
	if tied.is_empty() or used() != _full:
		return false
	return gate < 0 or ends_on_gate()

func ends_on_gate() -> bool:
	return gate >= 0 and not tied.is_empty() and joint() == posts[gate]

# --- the fewest still to go ---

func _ends_ok(w: String) -> bool:
	return gate < 0 or w.substr(w.length() - 1) == posts[gate]

## The first word of a fewest chain of at most `depth` words from the tied
## words that uses every post (and, on Insane, ends on the gate), or "".
## `out_len` gets how many words the chain takes.
func _finish(m: int, last: String, depth: int, out_len: Array) -> String:
	var starts: Array = []
	if last == "":
		for p in posts:
			starts.append_array(_fair.get(p, []))
	else:
		starts = _fair.get(last, [])
	starts = starts.filter(func(e: Array) -> bool: return not _dead.has(e[0]) and not _was_tied(e[0]))
	# one word
	for e: Array in starts:
		if m | int(e[1]) == _full and _ends_ok(e[0]):
			out_len.append(1)
			return e[0]
	if depth < 2:
		return ""
	for e: Array in starts:
		var m1 := m | int(e[1])
		var w1: String = e[0]
		if m1 == m and gate < 0:
			continue
		for f: Array in _fair.get(w1.substr(w1.length() - 1), []):
			if m1 | int(f[1]) == _full and _ends_ok(f[0]):
				out_len.append(2)
				return w1
	if depth < 3:
		return ""
	# three words: the starts that string the most new posts first, and a
	# budget (a pentagon has a hundred words a letter)
	var order := starts.duplicate()
	order.sort_custom(func(a: Array, b: Array) -> bool: return _bits(int(a[1]) & ~m) > _bits(int(b[1]) & ~m))
	var budget := BUDGET
	for e: Array in order:
		var m1 := m | int(e[1])
		var w1: String = e[0]
		if m1 == m and gate < 0:
			continue
		for f: Array in _fair.get(w1.substr(w1.length() - 1), []):
			var m2 := m1 | int(f[1])
			var w2: String = f[0]
			if m2 == m1 and gate < 0:
				continue
			for g: Array in _fair.get(w2.substr(w2.length() - 1), []):
				if m2 | int(g[1]) == _full and _ends_ok(g[0]):
					out_len.append(3)
					return w1
			budget -= 1
			if budget <= 0:
				return ""
	return ""

## The fewest words still to go from the tied words (DEEP + 1 when more).
func to_go() -> int:
	if solved():
		return 0
	if tied.is_empty():
		return par
	var n: Array = []
	_finish(used(), joint(), DEEP, n)
	return int(n[0]) if not n.is_empty() else DEEP + 1

## The stars the fence stands at: the words tied and the fewest to go.
func stars() -> int:
	return stars_at(tied.size() + to_go())

func stars_at(words: int) -> int:
	if words <= par + THREE:
		return 3
	if words <= par + TWO:
		return 2
	return 1

## The bulb's word: {"word"} the next word of a fewest way on from the tied
## words, or {"back": k} when the tied words lead nowhere and the bulb would
## untie down to k words first. Empty when solved.
func hint_word() -> Dictionary:
	if solved():
		return {}
	if tied.is_empty():
		if not route.is_empty():
			return {"word": route[0]}
		var n0: Array = []
		var w0 := _finish(0, "", HINT_DEEP, n0)
		return {"word": w0} if w0 != "" else {}
	# a way on at all? if no chain from here can reach the posts left, back
	# up to the last word after which one can
	if not _can_finish(used(), joint()):
		var k := tied.size() - 1
		while k > 0:
			var m0 := 0
			for j in k:
				m0 |= int(_mask.get(String(tied[j].word), mask_of(String(tied[j].word))))
			var w0: String = tied[k - 1].word
			if _can_finish(m0, w0.substr(w0.length() - 1)):
				break
			k -= 1
		return {"back": k}
	var n: Array = []
	var w := _finish(used(), joint(), HINT_DEEP, n)
	if w != "":
		return {"word": w}
	# no way within reach: the word from here worth most, its new posts
	# weighed by how few words reach them, then the one after it likewise
	var best := ""
	var worth := 0.0
	var m := used()
	for e: Array in _fair.get(joint(), []):
		if _was_tied(e[0]) or _dead.has(e[0]):
			continue
		var m1 := m | int(e[1])
		var v := _worth(m1 & ~m)
		if v <= 0.0:
			continue
		var w1: String = e[0]
		var after := 0.0
		for f: Array in _fair.get(w1.substr(w1.length() - 1), []):
			after = maxf(after, _worth(int(f[1]) & ~m1))
		if v + after > worth:
			worth = v + after
			best = w1
	if best != "":
		return {"word": best}
	# a dead end: go back to before the last word, and never offer it again
	_dead[String(tied[-1].word)] = true
	return {"back": tied.size() - 1}

## Whether any chain of common words from `last` could still reach every
## post `m` lacks (and, on Insane, end on the gate): the letters a chain can
## get to from `last`, and every post their words touch.
func _can_finish(m: int, last: String) -> bool:
	var seen := {last: true}
	var todo: Array = [last]
	var cover := m
	var gate_end := gate < 0
	while not todo.is_empty():
		var at: String = todo.pop_back()
		for e: Array in _fair.get(at, []):
			cover |= int(e[1])
			var w: String = e[0]
			var end := w.substr(w.length() - 1)
			if gate >= 0 and end == posts[gate]:
				gate_end = true
			if not seen.has(end):
				seen[end] = true
				todo.append(end)
	return cover == _full and gate_end

func _was_tied(w: String) -> bool:
	for t: Dictionary in tied:
		if t.word == w:
			return true
	return false

func _worth(gain: int) -> float:
	var v := 0.0
	for i in posts.size():
		if gain & (1 << i) != 0:
			v += 1.0 + 20.0 * _rare[i]
	return v

static func _bits(m: int) -> int:
	var n := 0
	while m != 0:
		m &= m - 1
		n += 1
	return n

## The brain score: par over the words (a word the bulb strung counted
## twice), nothing for an unsolved fence.
func quality() -> float:
	if not solved():
		return 0.0
	var cost := 0
	for t: Dictionary in tied:
		cost += 2 if t.kind == "bulb" else 1
	return clampf(float(par) / float(maxi(1, cost)), 0.0, 1.0)

## The day's line on the share: the words against the par, a flower a word
## (a bulb for one the bulb strung).
func share_glyphs() -> String:
	var out := "%d/%d\n" % [tied.size(), par]
	for t: Dictionary in tied:
		out += "💡" if t.kind == "bulb" else "🌼"
	return out

## The route tied (a restored day whose words were not kept).
func finish() -> void:
	if solved():
		return
	tied.clear()
	for w in route:
		tied.append({"word": w, "kind": "hand"})
	trail.clear()
