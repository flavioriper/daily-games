extends RefCounted

## Stepping Stones' rules (spec docs/superpowers/specs/2026-11-04-stepping-stones-design.md).
## A brook between two banks, a word on each. A stone is a word one letter
## from the one before (same length, one letter changed in place; on Insane,
## Slippery, also two letters side by side swapped). Lay stones from the near
## bank until one is a step from the far bank's word: the crossing is made.
##
## The crossings are banked (tools/build_stones.py,
## content/insane/stones*.json): the banks' words, the par (the fewest stones
## over the fair words), one shortest route and Easy's given middle stone.
## Any word the brook knows may be a stone (content/stones_<n>.json, and
## Hidden Word's accept list for five letters); the fewest still to go and
## the bulb walk on the fair words only.

## The bank each band's crossings come from.
const BANKS := ["stones_easy", "stones_medium", "stones_hard", "stones"]
const LENGTH := [4, 4, 5, 5]
const HINTS := [3, 2, 2, 2]
const WORDS := "res://content/stones_%d.json"
const ACCEPT := "res://content/hidden_word_accept.txt"
## Stars: three up to par and this many stones more, two up to TWO more.
const THREE := 1
const TWO := 3
const FAR := 99
## Should a bank be missing, a crossing every language's list can walk.
const SPARE_DAY := {"from": "mala", "to": "pelo", "par": 2, "given": "", "route": ["mela", "melo"], "ways": 1}

## What a typed line came to.
enum Said { SHORT, UNKNOWN, FAR_OFF, USED, LAID, CROSSED }

var band := 0
var n := 4
var from := ""
var to := ""
var par := 0
var given := ""
var route: Array[String] = []
var ways := 0
var swaps := false
## The stones laid, near bank to far: [{"word", "kind"}], kind "hand", "bulb"
## or "given" (Easy's middle stone, called in by the stone before it).
var way: Array = []
var crossed := false
## Stones the bulb laid, all told (lifted ones too).
var helped := 0
## The fewest steps from a fair word to the far bank (the far bank 0).
var _dist := {}
## The same to Easy's given stone.
var _dist_given := {}
var _lex: Dictionary = {}

## The words of one length in the player's language, read once a session:
## {"fair": PackedStringArray (commonest first), "rank": {word: i},
## "known": {word: true}, "shown": {word: accented}, "buckets": {pattern:
## [fair words]}}.
static var _cache := {}

static func words_of(length: int) -> Dictionary:
	var path := Locale.content(WORDS % length)
	var key := "%s|%d" % [path, length]
	if _cache.has(key):
		return _cache[key]
	var out := {"fair": PackedStringArray(), "rank": {}, "known": {}, "shown": {}, "buckets": {}}
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if doc is Dictionary:
		var fair := PackedStringArray(doc.get("fair", []))
		out.fair = fair
		for i in fair.size():
			var w := fair[i]
			out.rank[w] = i
			out.known[w] = true
			for k in length:
				var p := w.substr(0, k) + "_" + w.substr(k + 1)
				if not out.buckets.has(p):
					out.buckets[p] = []
				out.buckets[p].append(w)
		for w in doc.get("more", []):
			out.known[String(w)] = true
		out.shown = doc.get("shown", {})
	else:
		push_error("Stepping Stones: no words at %s" % path)
	if length == 5:
		var accept := Locale.content(ACCEPT)
		if FileAccess.file_exists(accept):
			for line in FileAccess.get_file_as_string(accept).split("\n", false):
				var w := Locale.fold(line.strip_edges())
				if w.length() == 5:
					out.known[w] = true
	_cache[key] = out
	return out

func deal(_rng: RandomNumberGenerator, the_band: int, bank_step := 0) -> void:
	band = clampi(the_band, 0, 3)
	var day: Dictionary = InsaneBank.pick(BANKS[band], bank_step)
	if day.is_empty():
		push_error("Stepping Stones: no crossings in %s" % BANKS[band])
		day = SPARE_DAY
	load_day(day)

func load_day(day: Dictionary) -> void:
	from = Locale.fold(String(day.get("from", SPARE_DAY.from)))
	to = Locale.fold(String(day.get("to", SPARE_DAY.to)))
	n = from.length()
	swaps = band == 3
	_lex = words_of(n)
	given = Locale.fold(String(day.get("given", ""))) if band == 0 else ""
	route.clear()
	for w in day.get("route", []):
		route.append(Locale.fold(String(w)))
	ways = int(day.get("ways", 1))
	_dist = _bfs(to)
	_dist_given = _bfs(given) if given != "" else {}
	par = int(day.get("par", 0))
	if par <= 0:
		par = maxi(0, dist(from) - 1)
	restart()

## The crossing as dealt, no stone laid.
func restart() -> void:
	way.clear()
	crossed = false

# --- words ---

func knows(w: String) -> bool:
	return _lex.known.has(w) or w == from or w == to or w == given

func is_fair(w: String) -> bool:
	return _lex.rank.has(w)

func rank(w: String) -> int:
	return int(_lex.rank.get(w, 1 << 30))

## A word as written, with its accents where it has them.
func written(w: String) -> String:
	return String(_lex.shown.get(w, w))

## The positions where `a` and `b` differ.
static func diff(a: String, b: String) -> Array[int]:
	var out: Array[int] = []
	for i in mini(a.length(), b.length()):
		if a[i] != b[i]:
			out.append(i)
	return out

static func is_swap(a: String, b: String) -> bool:
	var d := diff(a, b)
	return d.size() == 2 and d[1] == d[0] + 1 and a[d[0]] == b[d[1]] and a[d[1]] == b[d[0]]

## Whether `b` may follow `a`: one letter changed, or (Slippery) two side by
## side swapped.
func step_ok(a: String, b: String) -> bool:
	if a.length() != b.length() or a == b:
		return false
	var d := diff(a, b)
	return d.size() == 1 or (swaps and is_swap(a, b))

## The fair words one step from `w`.
func neighbours(w: String) -> Array:
	var out := []
	for k in w.length():
		var p := w.substr(0, k) + "_" + w.substr(k + 1)
		for y in _lex.buckets.get(p, []):
			if y != w:
				out.append(y)
	if swaps:
		for k in w.length() - 1:
			var s := w.substr(0, k) + w[k + 1] + w[k] + w.substr(k + 2)
			if s != w and _lex.rank.has(s):
				out.append(s)
	return out

## Steps from every fair word to `target`, over the fair words.
func _bfs(target: String) -> Dictionary:
	var d := {target: 0}
	var q: Array = [target]
	var at := 0
	while at < q.size():
		var x: String = q[at]
		at += 1
		var k: int = d[x] + 1
		for y in neighbours(x):
			if not d.has(y):
				d[y] = k
				q.append(y)
	return d

## Steps from `w` to the far bank (FAR when there is no way over the fair
## words): a word that is not fair reads through its fair neighbours.
func dist(w: String) -> int:
	return _dist_of(w, _dist, to)

func _dist_of(w: String, d: Dictionary, target: String) -> int:
	if d.has(w):
		return int(d[w])
	if step_ok(w, target):
		return 1
	var best := FAR
	for y in neighbours(w):
		if d.has(y):
			best = mini(best, int(d[y]) + 1)
	return best

# --- the way ---

func last() -> String:
	return String(way[-1].word) if not way.is_empty() else from

func stones() -> int:
	return way.size()

func given_in() -> bool:
	if given == "":
		return false
	for s: Dictionary in way:
		if String(s.word) == given:
			return true
	return false

func used(w: String) -> bool:
	if w == from or w == to:
		return true
	for s: Dictionary in way:
		if String(s.word) == w:
			return true
	return false

## The fewest stones still to lay from the last (0 once a step from the far
## bank), FAR at a dead end.
func to_go() -> int:
	if crossed:
		return 0
	var d := dist(last())
	return FAR if d >= FAR else maxi(0, d - 1)

## A typed line offered: {"said", "word", "joined" (Easy's given called in),
## "crossed", "off" (letters that differ from the last stone)}.
func offer(typed: String, kind := "hand") -> Dictionary:
	var w := Locale.fold(typed.strip_edges())
	var out := {"said": Said.SHORT, "word": w, "joined": false, "crossed": false, "off": 0}
	if crossed:
		return out
	if w.length() != n:
		return out
	var prev := last()
	out.off = diff(prev, w).size()
	if w == to:
		if step_ok(prev, w):
			crossed = true
			out.said = Said.CROSSED
			out.crossed = true
		else:
			out.said = Said.FAR_OFF
		return out
	if used(w):
		out.said = Said.USED
		return out
	if not knows(w):
		out.said = Said.UNKNOWN
		return out
	if not step_ok(prev, w):
		out.said = Said.FAR_OFF
		return out
	way.append({"word": w, "kind": kind})
	if kind == "bulb":
		helped += 1
	out.said = Said.LAID
	# a stone a step from the far bank crosses, even one a step from the
	# given too: the given never steals a crossing earned
	if step_ok(w, to):
		crossed = true
		out.crossed = true
		return out
	if given != "" and not given_in() and step_ok(w, given):
		way.append({"word": given, "kind": "given"})
		out.joined = true
	if step_ok(last(), to):
		crossed = true
		out.crossed = true
	return out

## The last stone lifted (and Easy's given with the stone that called it):
## the words lifted, last first.
func undo() -> Array:
	var out := []
	if way.is_empty() or crossed:
		return out
	var s: Dictionary = way.pop_back()
	out.append(s.word)
	# the given came in with the stone that called it, and goes with it
	if s.kind == "given" and not way.is_empty():
		out.append(way.pop_back().word)
	return out

func can_undo() -> bool:
	return not way.is_empty() and not crossed

# --- the bulb ---

## The bulb's next stone from where the way stands: {"keep": stones to keep
## (fewer than laid at a dead end), "word": the stone, "at": the letter it
## changes}. Empty when there is none.
func hint_step() -> Dictionary:
	if crossed:
		return {}
	for keep in range(way.size(), -1, -1):
		# never back between the given and the stone that called it
		if keep > 0 and keep < way.size() and way[keep].kind == "given":
			continue
		var at: String = String(way[keep - 1].word) if keep > 0 else from
		var d := dist(at)
		if d >= FAR:
			continue
		var target := to
		var dm := _dist
		if given != "" and not _given_before(keep):
			var dg := _dist_of(at, _dist_given, given)
			if dg < FAR and dg + int(_dist.get(given, FAR)) == d:
				target = given
				dm = _dist_given
				d = dg
		var best := ""
		if target == given and d == 1:
			best = given
		else:
			for y in neighbours(at):
				if y == to or not dm.has(y) or int(dm[y]) != d - 1:
					continue
				if _used_before(y, keep):
					continue
				if best == "" or rank(y) < rank(best):
					best = y
		if best == "":
			continue
		var ch := diff(at, best)
		return {"keep": keep, "word": best, "at": ch[0] if not ch.is_empty() else 0, "from": at}
	return {}

func _given_before(keep: int) -> bool:
	for i in keep:
		if String(way[i].word) == given:
			return true
	return false

func _used_before(w: String, keep: int) -> bool:
	if w == from or w == to:
		return true
	for i in keep:
		if String(way[i].word) == w:
			return true
	return false

## Stones lifted until `keep` are left (the bulb's way back from a dead end).
func cut_to(keep: int) -> Array:
	var out := []
	while way.size() > keep:
		out.append(way.pop_back().word)
	return out

# --- the score ---

## The stars the way stands at: the stones laid and the fewest still to go.
func stars() -> int:
	var go := to_go()
	var all := stones() + (go if go < FAR else 2)
	return stars_for(all)

func stars_for(all: int) -> int:
	if all <= par + THREE:
		return 3
	if all <= par + TWO:
		return 2
	return 1

## The brain score: par over the stones, a bulb's stone counted twice.
func quality() -> float:
	if not crossed:
		return 0.0
	return clampf(float(par) / float(maxi(par, stones() + helped)), 0.0, 1.0)

## The day's line on the share: the stones against par, a square a stone:
## green within par, yellow past it, the bulb's blue.
func share_glyphs() -> String:
	var out := "%d/%d\n" % [stones(), par]
	for i in way.size():
		var s: Dictionary = way[i]
		if s.kind == "bulb":
			out += "🟦"
		elif i < par:
			out += "🟩"
		else:
			out += "🟨"
	return out.strip_edges()

## A finished day laid back as it was crossed (or the route, when the record
## has none).
func finish(words: Array) -> void:
	restart()
	var src: Array = words if not words.is_empty() else route
	for w in src:
		if w is Dictionary:
			way.append({"word": String(w.word), "kind": String(w.get("kind", "hand"))})
		else:
			way.append({"word": String(w), "kind": "hand"})
	crossed = true
