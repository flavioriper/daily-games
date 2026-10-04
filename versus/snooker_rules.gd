extends RefCounted

## A frame of snooker between two players, refereed after every shot from
## what the table says happened (versus/snooker_sim.gd: the first ball the
## cue ball touched and every ball that dropped). WPBSA rules, as far as a
## frame against the computer needs them:
##
## - Reds and colours alternate while reds remain: a red is on, then after a
##   red is potted any colour is on. There is no spoken nomination: the
##   colour struck first is the one nominated, which is how every digital
##   snooker plays it. A colour potted while reds remain is re-spotted.
## - With the reds gone the colours are on in order, yellow to black, and
##   stay down.
## - A foul gives the opponent the value of the ball on, of the highest ball
##   involved, or four, whichever is highest, and ends the turn: hitting
##   nothing, hitting a ball not on first, potting a ball not on, or the cue
##   ball in a pocket (the opponent then has it in hand in the D).
## - After a foul, a player snookered on every ball on gets a free ball: any
##   ball may be played as the ball on, and potted scores as the ball on.
## - The frame ends when the black is potted, or fouled, as the last ball; a
##   tie then re-spots the black and the next player is drawn at random.
##
## Left out on purpose, as most club play does: the miss rule (the offender
## is never put back), the choice to make the offender play again, touching
## ball and concession.

const Sim = preload("res://versus/snooker_sim.gd")

const RED := "red"
const COLOUR := "colour"
const SEQUENCE := "sequence"

var sim: RefCounted
var turn := 0
var scores := [0, 0]
var phase := RED
var in_hand := true
var free_ball := false
var breaks := [0, 0]
var high_break := [0, 0]
var over := false
var winner := -1
var respotted_black := false
## Who broke off, so the next frame's break goes to the other player.
var breaker := 0
## The last shot, for the screen: {"foul", "penalty", "scored", "pots",
## "free_ball", "nominated", "reason", "player"}.
var last := {}

func _init(the_sim: RefCounted, first := 0) -> void:
	sim = the_sim
	breaker = first
	turn = first

# --- the whole of it, for a game online ---

## Everything the referee holds, as plain numbers, words and lists, so it
## survives a trip as JSON: a game online sends this after every shot and the
## other end takes it as sent (versus/snooker_screen.gd). `flip` swaps the two
## players, since each end calls itself player 0.
func to_dict(flip := false) -> Dictionary:
	var a := 1 if flip else 0
	var l := {}
	if not last.is_empty():
		l = {"foul": bool(last.foul), "penalty": int(last.penalty), "scored": int(last.scored),
			"pots": (last.pots as Array).duplicate(), "cue_in": bool(last.cue_in),
			"free_ball": bool(last.free_ball), "nominated": int(last.nominated),
			"reason": String(last.reason), "player": int(last.player) ^ a,
			"free_next": bool(last.get("free_next", false))}
	return {
		"turn": turn ^ a, "scores": [scores[a], scores[1 - a]], "phase": phase,
		"in_hand": in_hand, "free_ball": free_ball,
		"breaks": [breaks[a], breaks[1 - a]], "high": [high_break[a], high_break[1 - a]],
		"over": over, "winner": winner if winner < 0 else winner ^ a,
		"respot": respotted_black, "breaker": breaker ^ a, "last": l,
	}

## Takes a state `to_dict` made, whole, and answers true; one that is not
## such a state is refused and nothing here changes. Numbers may come back
## from JSON as floats.
func from_dict(d: Dictionary, flip := false) -> bool:
	var a := 1 if flip else 0
	var ints := {}
	for k in ["turn", "winner", "breaker"]:
		ints[k] = _whole(d.get(k))
	var pairs := {}
	for k in ["scores", "breaks", "high"]:
		var v: Variant = d.get(k)
		if typeof(v) != TYPE_ARRAY or (v as Array).size() != 2:
			return false
		var x := _whole(v[a])
		var y := _whole(v[1 - a])
		if x < 0 or y < 0:
			return false
		pairs[k] = [x, y]
	for k in ["in_hand", "free_ball", "over", "respot"]:
		if typeof(d.get(k)) != TYPE_BOOL:
			return false
	if not (ints.turn == 0 or ints.turn == 1) or not (ints.breaker == 0 or ints.breaker == 1) \
			or ints.winner < -1 or ints.winner > 1 or (bool(d.over) != (ints.winner >= 0)):
		return false
	if typeof(d.get("phase")) != TYPE_STRING or not [RED, COLOUR, SEQUENCE].has(d.phase):
		return false
	var l: Variant = d.get("last")
	if typeof(l) != TYPE_DICTIONARY:
		return false
	var the_last := {}
	if not (l as Dictionary).is_empty():
		for k in ["foul", "cue_in", "free_ball", "free_next"]:
			if typeof(l.get(k)) != TYPE_BOOL:
				return false
		var pots: Array = []
		if typeof(l.get("pots")) != TYPE_ARRAY or typeof(l.get("reason")) != TYPE_STRING:
			return false
		for v: Variant in l.pots:
			var id := _whole(v)
			if id < 1 or id >= Sim.COUNT:
				return false
			pots.append(id)
		var who := _whole(l.get("player"))
		var penalty := _whole(l.get("penalty"))
		var scored := _whole(l.get("scored"))
		var nominated := _whole(l.get("nominated"), -2)
		if not (who == 0 or who == 1) or penalty < 0 or scored < 0 or nominated < -1 or nominated >= Sim.COUNT:
			return false
		if l.reason != "" and not ["SNK_FOUL_MISS", "SNK_FOUL_FIRST", "SNK_FOUL_POT", "SNK_FOUL_IN_OFF"].has(l.reason):
			return false
		the_last = {"foul": l.foul, "penalty": penalty, "scored": scored, "pots": pots, "cue_in": l.cue_in,
			"free_ball": l.free_ball, "nominated": nominated, "reason": String(l.reason),
			"player": who ^ a, "free_next": l.free_next}
	turn = ints.turn ^ a
	scores = pairs.scores
	phase = d.phase
	in_hand = d.in_hand
	free_ball = d.free_ball
	breaks = pairs.breaks
	high_break = pairs.high
	over = d.over
	winner = ints.winner if ints.winner < 0 else ints.winner ^ a
	respotted_black = d.respot
	breaker = ints.breaker ^ a
	last = the_last
	return true

## A whole number out of JSON (which hands every number back as a float), or
## `bad` for anything else.
static func _whole(v: Variant, bad := -9) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v) and absf(v) < 1e6:
		return int(v)
	return bad

## The balls that are on right now.
func balls_on() -> Array[int]:
	var out: Array[int] = []
	match phase:
		RED:
			for id in range(1, Sim.REDS + 1):
				if sim.on[id]:
					out.append(id)
		COLOUR:
			for id in range(Sim.YELLOW, Sim.BLACK + 1):
				if sim.on[id]:
					out.append(id)
		SEQUENCE:
			var n := next_colour()
			if n != -1:
				out.append(n)
	return out

## The balls a legal first contact may be: the balls on, or with a free ball
## anything but the cue ball.
func legal_first() -> Array[int]:
	if not free_ball:
		return balls_on()
	var out: Array[int] = []
	for id in range(1, Sim.COUNT):
		if sim.on[id]:
			out.append(id)
	return out

func next_colour() -> int:
	for id in range(Sim.YELLOW, Sim.BLACK + 1):
		if sim.on[id]:
			return id
	return -1

## Points still on the table for one player clearing it from here.
func remaining() -> int:
	var reds: int = sim.reds_left()
	var total := reds * 8
	if phase == COLOUR:
		total += 7
	for id in range(Sim.YELLOW, Sim.BLACK + 1):
		if sim.on[id]:
			total += Sim.value(id)
	return total

## Referees the shot that just stopped and moves the frame on. Re-spots
## whatever has to come back. Returns `last`.
func judge() -> Dictionary:
	var fh: int = sim.first_hit
	var pots: Array = sim.potted.duplicate()
	var cue_in := pots.has(Sim.CUE)
	pots.erase(Sim.CUE)
	var was_free := free_ball
	# The table as it stood when the shot was played: the pots are already
	# off it, and the colour on is the lowest of what is left plus them.
	var want := next_colour_before(pots)
	var black_alone := phase == SEQUENCE and want == Sim.BLACK
	var on_val := 1 if phase == RED else (Sim.value(want) if want != -1 else 7)
	var nominated := -1
	var foul := false
	var reason := ""
	var involved := [on_val]
	var scored := 0
	# Which ball stands in as "on" for a free ball: whatever was hit first,
	# when it is not already on.
	var free_id := -1
	if was_free and fh > 0 and phase != COLOUR:
		var was_on := Sim.is_red(fh) if phase == RED else fh == want
		if not was_on:
			free_id = fh

	if fh == -1:
		foul = true
		reason = "SNK_FOUL_MISS"
	else:
		match phase:
			RED:
				if not Sim.is_red(fh) and fh != free_id:
					foul = true
					reason = "SNK_FOUL_FIRST"
					involved.append(Sim.value(fh))
				for id in pots:
					if Sim.is_red(id) or id == free_id:
						scored += 1
					else:
						foul = true
						reason = "SNK_FOUL_POT" if reason == "" else reason
						involved.append(Sim.value(id))
			COLOUR:
				if Sim.is_colour(fh):
					nominated = fh
					on_val = Sim.value(fh)
					involved.append(on_val)
				else:
					foul = true
					reason = "SNK_FOUL_FIRST"
				for id in pots:
					if id == nominated:
						scored += Sim.value(id)
					else:
						foul = true
						reason = "SNK_FOUL_POT" if reason == "" else reason
						involved.append(Sim.value(id))
			SEQUENCE:
				if fh != want and fh != free_id:
					foul = true
					reason = "SNK_FOUL_FIRST"
					involved.append(Sim.value(fh))
				for id in pots:
					if id == want or id == free_id:
						scored += on_val
					else:
						foul = true
						reason = "SNK_FOUL_POT" if reason == "" else reason
						involved.append(Sim.value(id))
	if cue_in:
		foul = true
		reason = "SNK_FOUL_IN_OFF" if reason == "" else reason
	var penalty := 0
	if foul:
		penalty = 4
		for v in involved:
			penalty = maxi(penalty, int(v))
		scored = 0

	# --- back on the table ---
	var respot: Array = []
	for id in pots:
		if not Sim.is_colour(id):
			continue
		var stays_down: bool = not foul and phase == SEQUENCE and id == want and id != free_id
		if not stays_down:
			respot.append(id)
	respot.sort()
	respot.reverse()
	for id in respot:
		sim.respot(id)

	var player := turn
	free_ball = false
	in_hand = false
	last = {"foul": foul, "penalty": penalty, "scored": scored, "pots": pots, "cue_in": cue_in,
		"free_ball": was_free, "nominated": nominated, "reason": reason, "player": player}

	if foul:
		scores[1 - player] += penalty
		_end_break(player)
		turn = 1 - player
		in_hand = cue_in
		if cue_in:
			sim.on[Sim.CUE] = true
			sim.pos[Sim.CUE] = Sim.D_CENTRE + Vector2(0.0, Sim.D_R * 0.5)
		phase = RED if sim.reds_left() > 0 else SEQUENCE
		if black_alone or (phase == SEQUENCE and next_colour() == -1):
			_finish()
		elif not in_hand and snookered():
			free_ball = true
		last["free_next"] = free_ball
		return last

	if scored > 0:
		scores[player] += scored
		breaks[player] += scored
		high_break[player] = maxi(high_break[player], breaks[player])
		match phase:
			RED:
				phase = COLOUR
			COLOUR:
				phase = RED if sim.reds_left() > 0 else SEQUENCE
			SEQUENCE:
				if next_colour() == -1:
					_finish()
		return last

	_end_break(player)
	turn = 1 - player
	phase = RED if sim.reds_left() > 0 else SEQUENCE
	return last

## The colour that was on before this shot's pots were taken off the table:
## the lowest of what is still on plus what just went down.
func next_colour_before(pots: Array) -> int:
	for id in range(Sim.YELLOW, Sim.BLACK + 1):
		if sim.on[id] or pots.has(id):
			return id
	return -1

func _end_break(player: int) -> void:
	breaks[player] = 0

func _finish() -> void:
	if scores[0] == scores[1]:
		# Re-spotted black: on its spot, the cue ball in hand, and the player
		# to go first drawn at random.
		respotted_black = true
		sim.respot(Sim.BLACK)
		phase = SEQUENCE
		in_hand = true
		turn = randi() % 2
		sim.pos[Sim.CUE] = Sim.D_CENTRE + Vector2(0.0, Sim.D_R * 0.5)
		return
	over = true
	winner = 0 if scores[0] > scores[1] else 1

## Whether the cue ball, where it lies, cannot hit both extreme edges of any
## ball on in a straight line -- the test for a free ball.
func snookered() -> bool:
	var c: Vector2 = sim.pos[Sim.CUE]
	for id in balls_on():
		var o: Vector2 = sim.pos[id]
		var to := (o - c).normalized()
		var across := Vector2(-to.y, to.x) * Sim.R * 1.96
		var both := true
		for edge in [across, -across]:
			if not sim.lane_clear(c, o + edge, [Sim.CUE, id]):
				both = false
				break
		if both:
			return false
	return true
