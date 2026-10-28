extends RefCounted

## Honeycomb's rules (spec docs/superpowers/specs/2026-10-22-honeycomb-design.md).
## Seven letters in a comb, one in the middle cell where the queen sits.
## Spell words of four letters or more from them, letters used as often as
## you like, every word holding the queen's letter. Each word found pours
## honey: one a letter, seven more for a full comb (a word with all seven
## letters). The day is done when the jar is
## filled to the band's line, a share of all the honey the day's words hold.
## On Insane (Wandering Queen) the queen flies to another letter every
## FLIGHT words found, so the words after must hold her new letter.

const Words = preload("res://puzzles/honeycomb_words.gd")

## The bulb, by band.
const HINTS := [3, 2, 1, 1]
## The jar's line, as a share of the honey the day's words hold. Lowered
## 2026-10-28 with the honey rule (the board read as a slog): the line is
## about 5-7 words on Easy, 8-10 on Medium and 11-15 on Hard, the fewer for
## a player sending the day's words in any order, the more for one sending
## the shortest first (tests/_probe_hc_pace.gd).
const SHARE := [0.18, 0.2, 0.24, 0.24]
## The ranks on the way to the line, as shares of it: three named steps
## the strip lights before the jar is full.
const RANKS := [0.25, 0.5, 0.75]
## Insane: words found between the queen's flights.
const FLIGHT := 4
const SHORTEST := 4
const LONGEST := 19
## The bank each band's hives come from (content/insane/, tools/build_honeycomb.py).
const BANKS := ["honeycomb_easy", "honeycomb_medium", "honeycomb_hard", "honeycomb"]
## Should a bank be missing, a hive every language holds words in.
const SPARE := {"letters": "adeglnr", "queen": "a", "flight": "dlegrn"}

## How an entry was heard.
enum Said { WORD, FULL, SHORT, NO_QUEEN, NOT_WORD, FOUND, EMPTY }

var band := 0
var words = null
## The seven letters as dealt, the queen's first, and the flight order.
var letters := ""
var first_queen := ""
var flight := ""
## The queen's letter now and how many times she has flown.
var queen := ""
var flights := 0
## The six letters round the middle, in the order the cells show them.
var ring: Array[String] = []
var hive_mask := 0
## The day's words for the first queen (indices), and their honey.
var answers := PackedInt32Array()
var total := 0
var goal := 0
## Words found (folded, in the order found) and the honey in the jar.
var found: Array[String] = []
var honey := 0
var fulls := 0
## The letters typed so far.
var entry := ""
## Entries refused as no word at all (the brain score's misses).
var misses := 0
## Words the bulb began, folded.
var hinted: Array[String] = []

func deal(_rng: RandomNumberGenerator, the_band: int, bank_step := 0) -> void:
	band = clampi(the_band, 0, 3)
	var day: Dictionary = InsaneBank.pick(BANKS[band], bank_step)
	# a few days a year two bands' shuffles meet on one comb's letters: the
	# higher band takes its next hive, so a day's four combs always differ
	var below := {}
	for b in band:
		below[String(InsaneBank.pick(BANKS[b], 0).get("letters", ""))] = true
	var on := 0
	while not day.is_empty() and below.has(String(day.letters)) and on < 8:
		on += 1
		day = InsaneBank.pick(BANKS[band], bank_step + on)
	if day.is_empty():
		push_error("Honeycomb: no hives in %s" % BANKS[band])
		day = SPARE
	load_day(day)

func load_day(day: Dictionary) -> void:
	words = Words.current()
	letters = String(day.letters)
	first_queen = String(day.queen)
	flight = String(day.get("flight", ""))
	hive_mask = words.mask_of(letters)
	answers = words.inside(hive_mask, words.mask_of(first_queen), Words.BAND_TIER[band])
	total = 0
	for i in answers:
		total += Words.points(words.words[i], _full(words.words[i]))
	goal = maxi(1, ceili(total * float(SHARE[band])))
	restart()

## The jar empty, the queen home, the ring as dealt.
func restart() -> void:
	queen = first_queen
	flights = 0
	ring.clear()
	for ch in letters:
		if ch != queen:
			ring.append(ch)
	found.clear()
	honey = 0
	fulls = 0
	entry = ""
	misses = 0
	hinted.clear()

func wandering() -> bool:
	return band == 3 and flight.length() > 0

func _full(word: String) -> bool:
	return words.mask_of(word) == hive_mask

func type(ch: String) -> bool:
	if entry.length() >= LONGEST:
		return false
	entry += ch
	return true

func delete() -> bool:
	if entry.is_empty():
		return false
	entry = entry.left(-1)
	return true

## The entry as it would be heard, without taking it.
func judge(word: String) -> int:
	if word.is_empty():
		return Said.EMPTY
	if word.length() < SHORTEST:
		return Said.SHORT
	if not word.contains(queen):
		return Said.NO_QUEEN
	if found.has(word):
		return Said.FOUND
	var i: int = words.find(word)
	if i < 0 or words.masks[i] & ~hive_mask != 0:
		return Said.NOT_WORD
	return Said.FULL if _full(word) else Said.WORD

## The entry sent: what it was heard as. A word goes in the jar.
func submit() -> int:
	var word := entry
	entry = ""
	var said := judge(word)
	match said:
		Said.NOT_WORD:
			misses += 1
		Said.WORD, Said.FULL:
			found.append(word)
			honey += Words.points(word, said == Said.FULL)
			if said == Said.FULL:
				fulls += 1
	return said

## Insane: whether the word just found sends the queen on: every FLIGHT
## words, and whenever her letter has no day's word left to find.
func flies_now() -> bool:
	if not wandering() or solved() or found.is_empty():
		return false
	return found.size() % FLIGHT == 0 or _spent()

func _spent() -> bool:
	for i in open_words():
		if not found.has(words.words[i]):
			return false
	return true

## The queen flies to the next letter of her flight: the ring cell that
## held it, which now holds her old letter.
func fly() -> int:
	var next := flight[(flights) % flight.length()]
	var cell := ring.find(next)
	if cell < 0:
		return -1
	ring[cell] = queen
	queen = next
	flights += 1
	return cell

func solved() -> bool:
	return honey >= goal

## The ranks reached: 0 none yet, RANKS.size() the last before the line.
func rank() -> int:
	return rank_at(honey)

func rank_at(h: int) -> int:
	var n := 0
	for share in RANKS:
		if h >= rank_honey(n):
			n += 1
	return n

## The honey rank `n` (0-based) asks for.
func rank_honey(n: int) -> int:
	return maxi(1, ceili(goal * float(RANKS[n])))

## Per letter of the hive, how many of the day's words still to find begin
## with it (with the queen as she is now).
func starts() -> Dictionary:
	var out := {}
	for ch in letters:
		out[ch] = 0
	for i in open_words():
		var w: String = words.words[i]
		if not found.has(w):
			out[w[0]] = int(out.get(w[0], 0)) + 1
	return out

## The day's full combs not found yet.
func fulls_left() -> int:
	var n := 0
	for i in open_words():
		var w: String = words.words[i]
		if words.masks[i] == hive_mask and not found.has(w):
			n += 1
	return n

## The ring in a new order.
func shuffle(rng: RandomNumberGenerator) -> void:
	for i in range(ring.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := ring[i]
		ring[i] = ring[j]
		ring[j] = t

## The day's words the hive makes with the queen as she is now, of the
## band's tier.
func open_words() -> PackedInt32Array:
	if queen == first_queen:
		return answers
	return words.inside(hive_mask, words.mask_of(queen), Words.BAND_TIER[band])

## The bulb's word: a day's word not found, never shy, the commonest and
## then the shortest; "" when none is left.
func hint_word() -> String:
	var best := ""
	var best_key := INF
	for i in open_words():
		var w: String = words.words[i]
		if found.has(w) or hinted.has(w) or words.shy.has(i):
			continue
		var key: float = words.tier(i) * 100.0 + w.length()
		if key < best_key:
			best_key = key
			best = w
	return best

## How many of the bulb's word's letters it spells: half, two at least.
static func hint_letters(word: String) -> int:
	return maxi(2, word.length() / 2)

## The brain score: words found over words tried, refusals of no word at
## all being the misses.
func quality() -> float:
	var n := found.size()
	if n + misses == 0:
		return 0.0
	return clampf(float(n) / float(n + misses), 0.0, 1.0)

## A green square a word found (twelve at most), a red one a miss (five at
## most).
func share_glyphs() -> String:
	var out := ""
	for i in mini(found.size(), 12):
		out += "🟨" if i < fulls else "🟩"
	for i in mini(misses, 5):
		out += "🟥"
	return out

## A finished day reopened: the words as they were found.
func finish(list: Array, missed: int) -> void:
	restart()
	for w in list:
		var word := String(w)
		if wandering() and not word.contains(queen):
			continue
		entry = word
		var said := submit()
		if (said == Said.WORD or said == Said.FULL) and flies_now():
			fly()
	if not solved():
		# a record that does not fill the jar is filled from the day's words
		for i in open_words():
			if solved():
				break
			entry = words.words[i]
			if submit() != Said.FOUND and flies_now():
				fly()
	entry = ""
	misses = missed
