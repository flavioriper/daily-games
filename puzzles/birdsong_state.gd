extends RefCounted

## Birdsong's rules, scene-free (spec
## docs/superpowers/specs/2026-10-22-birdsong-design.md). A little bird sings
## a tune on the drums under its branch; the player plays it back. Each
## round the tune is one note longer, and the day's whole tune played back
## is the solve.
##
## The tune is the day's, dealt from the host's rng: `length` notes over the
## band's drums, never the same drum three times running. A round starts at
## `START` notes and grows to `length`. A slip is never punished beyond the
## round: the bird sings it again and the player starts it over. Insane
## (Whisper) has the bird sing only the round's new note once the first
## round is past; a slip, or the bulb, has it sing the whole tune so far.
##
## Nothing here knows time or the screen: the board asks `heard(drum)` and
## acts on what it answers.

enum Heard { RIGHT, ROUND, SOLVED, SLIP, IGNORED }

## Per band, Easy to Insane: the drums on the branch (Parts.band_drum kinds,
## Drumbeat's DRUM_KINDS for three: big, hand, tongue; four adds the jingle
## drum), the tune's length, the first round's length, the seconds between
## two sung notes, and how many times the bulb has the bird sing again.
const DRUMS := [[0, 1, 3], [0, 1, 2, 3], [0, 1, 2, 3], [0, 1, 2, 3]]
const LENGTH := [5, 7, 9, 9]
const START := [1, 2, 3, 3]
const GAP := [0.62, 0.55, 0.46, 0.5]
const HINTS := [3, 2, 1, 1]
## Insane's rule: from the second round the bird sings the new note alone.
const WHISPER := [false, false, false, true]

var band := 0
var tune: Array[int] = []
## The round being played: how many notes of the tune it asks for, and how
## many of them the player has played back so far.
var round_len := 0
var pos := 0
## Slips this round, slips in all, and the rounds played back without one.
var slips_round := 0
var slips := 0
var clean := 0
## Each round played back, the slips it took.
var history: Array[int] = []

func deal(rng: RandomNumberGenerator, the_band: int) -> void:
	band = clampi(the_band, 0, LENGTH.size() - 1)
	var n: int = drums()
	tune.clear()
	for i in int(LENGTH[band]):
		var d := rng.randi_range(0, n - 1)
		# never three of one drum running: two are a little rhythm, three
		# are a drone
		while i >= 2 and d == tune[i - 1] and d == tune[i - 2]:
			d = rng.randi_range(0, n - 1)
		tune.append(d)
	restart()

## The day from the top: the first round, nothing played back.
func restart() -> void:
	round_len = int(START[band])
	pos = 0
	slips_round = 0
	slips = 0
	clean = 0
	history.clear()

func drums() -> int:
	return (DRUMS[band] as Array).size()

## The Parts.band_drum kind of drum `d` on the branch.
func kind(d: int) -> int:
	return int(DRUMS[band][d])

func rounds() -> int:
	return int(LENGTH[band]) - int(START[band]) + 1

## The round being played, from 1.
func round_no() -> int:
	return round_len - int(START[band]) + 1

func gap() -> float:
	return float(GAP[band])

func whisper() -> bool:
	return bool(WHISPER[band])

func solved() -> bool:
	return round_len > tune.size()

## The notes the bird sings for this round: the whole round, or under
## Whisper past the first round only its last, new note. `full` (a slip,
## the bulb) is always the whole round.
func sung(full := false) -> Array[int]:
	var out: Array[int] = []
	var from := 0
	if whisper() and not full and round_len > int(START[band]):
		from = round_len - 1
	for i in range(from, mini(round_len, tune.size())):
		out.append(tune[i])
	return out

## The player struck drum `d`.
func heard(d: int) -> Heard:
	if solved():
		return Heard.IGNORED
	if d != tune[pos]:
		slips += 1
		slips_round += 1
		pos = 0
		return Heard.SLIP
	pos += 1
	if pos < round_len:
		return Heard.RIGHT
	if slips_round == 0:
		clean += 1
	history.append(slips_round)
	slips_round = 0
	pos = 0
	round_len += 1
	return Heard.SOLVED if solved() else Heard.ROUND

## The share of rounds played back without a slip (the brain report).
func quality() -> float:
	return clampf(float(clean) / float(maxi(1, rounds())), 0.0, 1.0)

## A finished day, put back from its record.
func finish(the_history: Array) -> void:
	round_len = tune.size() + 1
	pos = 0
	history.clear()
	clean = 0
	slips = 0
	for n in the_history:
		history.append(int(n))
		slips += int(n)
		if int(n) == 0:
			clean += 1

## The day for the share line: a round a square, green played back clean,
## yellow after a slip.
func share_glyphs() -> String:
	var out := ""
	for n in history:
		out += "🟩" if n == 0 else "🟨"
	return out
