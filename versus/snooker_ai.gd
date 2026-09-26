extends RefCounted

## The computer's cue arm, and the hint's. It thinks the way a club player
## does: find every ball on that has a clear line to a pocket, cut it in off
## the ghost ball, pick a pace that gets it there, and among the few that
## look best play each one out on a copy of the table (versus/snooker_sim.gd
## is deterministic, so a copy is a rehearsal) to see which one pots and
## leaves the next ball on. With no pot worth taking it plays safe: it tries
## a spread of contacts on the balls on and keeps whichever leaves the
## opponent the least.
##
## `plan()` touches nothing but the copy it is handed, so the screen runs it
## on a worker thread. The level is how much the arm shakes when it plays:
## the choice is the same, the delivery is not.

const Sim = preload("res://versus/snooker_sim.gd")
const Rules = preload("res://versus/snooker_rules.gd")

## Aim wobble (radians, one standard deviation) and pace wobble (fraction).
const AIM_NOISE := [0.020, 0.008, 0.0028]
const PACE_NOISE := [0.10, 0.06, 0.03]
## How many of the geometrically best pots are rehearsed, and the tips and
## paces each is tried with.
const REHEARSE := 5
const TIPS := [Vector2(0.0, 0.1), Vector2(0.0, 0.42), Vector2(0.0, -0.45)]
const PACES := [1.0, 1.45]
const MAX_CUT := deg_to_rad(80.0)
## How long a plan may think, ms: past it the rehearsals stop and the best so
## far is played, so a crowded table never keeps the other player waiting.
const BUDGET := 1800

static var _deadline := 0

static func _late() -> bool:
	return Time.get_ticks_msec() > _deadline

## The shot to play: {"dir", "speed", "tip", "cue_at" (in hand only), "kind"
## ("break", "pot", "safety")}. `state` is the referee's view: phase,
## free_ball, in_hand, and whether this is the break-off.
static func plan(sim: RefCounted, state: Dictionary, level: int) -> Dictionary:
	var table: RefCounted = sim.copy()
	_deadline = Time.get_ticks_msec() + BUDGET
	var shot := {}
	if bool(state.get("break_off", false)):
		shot = _break_off(table)
	else:
		if bool(state.get("in_hand", false)):
			table.pos[Sim.CUE] = _place(table, state)
		shot = _best_pot(table, state, level)
		if shot.is_empty():
			shot = _safety(table, state)
		shot["cue_at"] = table.pos[Sim.CUE]
	return shot

## The shot as the arm actually delivers it at `level`.
static func deliver(shot: Dictionary, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var out := shot.duplicate()
	var lv := clampi(level, 0, 2)
	var a := rng.randfn(0.0, AIM_NOISE[lv])
	# The break-off is a thin contact on the pack's corner: a wobble scaled
	# for a pot would miss the pack, so it gets a third.
	if String(shot.get("kind", "")) == "break":
		a *= 0.35
	out.dir = (shot.dir as Vector2).rotated(a)
	out.speed = clampf(float(shot.speed) * (1.0 + rng.randfn(0.0, PACE_NOISE[lv])), 0.3, Sim.MAX_SPEED)
	return out

# --- the break-off ---

## The standard break: from beside the yellow, a thin contact on the back
## red on the right of the pack, so the cue ball runs off the top and side
## cushions back into baulk and the pack barely opens.
static func _break_off(table: RefCounted) -> Dictionary:
	var cue := Sim.D_CENTRE + Vector2(Sim.D_R * 0.62, 0.0)
	table.pos[Sim.CUE] = cue
	var red: Vector2 = table.pos[11]
	for id in range(1, Sim.REDS + 1):
		if table.pos[id].x > red.x + 0.001 or (absf(table.pos[id].x - red.x) < 0.001 and table.pos[id].y > red.y):
			red = table.pos[id]
	# The last red of the second-from-back row on the right, hit about a
	# quarter ball.
	var to := (red - cue).normalized()
	var aim := red + Vector2(-to.y, to.x).normalized() * Sim.R * 1.55
	if aim.x < red.x:
		aim = red - Vector2(-to.y, to.x).normalized() * Sim.R * 1.55
	return {"dir": (aim - cue).normalized(), "speed": 3.9, "tip": Vector2(0.3, 0.0), "cue_at": cue, "kind": "break"}

# --- in hand ---

static func _place(table: RefCounted, state: Dictionary) -> Vector2:
	var best := Sim.D_CENTRE + Vector2(0.0, Sim.D_R * 0.5)
	var best_score := -1.0
	for k in 13:
		var a := PI * float(k) / 12.0
		for r in [0.35, 0.8]:
			var p: Vector2 = Sim.D_CENTRE + Vector2(cos(a), sin(a)) * Sim.D_R * r
			if not table.free_at(p, Sim.CUE):
				continue
			table.pos[Sim.CUE] = p
			var s := ease_from(table, state)
			if s > best_score:
				best_score = s
				best = p
	return best

# --- pots ---

## Every pot on the table as {"id", "pocket", "dir", "speed", "ease"}, the
## easiest first. Only straight lines: nothing off a cushion.
static func pots(table: RefCounted, state: Dictionary) -> Array:
	var out: Array = []
	var cue: Vector2 = table.pos[Sim.CUE]
	for id in _targets(table, state):
		var o: Vector2 = table.pos[id]
		for k in table.pockets.size():
			var pk: Dictionary = table.pockets[k]
			var mouth: Vector2 = pk.at + (pk.out as Vector2) * Sim.R * (1.0 if k == 2 or k == 3 else 0.4)
			var e := mouth - o
			var d_obj := e.length()
			if d_obj < 0.001:
				continue
			e /= d_obj
			# A middle pocket takes nothing that comes at it too shallow.
			if (k == 2 or k == 3) and absf(e.x) < 0.42:
				continue
			var ghost := o - e * 2.0 * Sim.R
			var a := ghost - cue
			var d_cue := a.length()
			if d_cue < 0.001:
				continue
			a /= d_cue
			var cut := acos(clampf(a.dot(e), -1.0, 1.0))
			if cut > MAX_CUT:
				continue
			if ghost.x < Sim.R or ghost.x > Sim.W - Sim.R or ghost.y < Sim.R or ghost.y > Sim.L - Sim.R:
				continue
			if not table.lane_clear(cue, ghost, [Sim.CUE, id]):
				continue
			if not table.lane_clear(o, mouth, [Sim.CUE, id]):
				continue
			var c := cos(cut)
			var ease := c * c / (1.0 + d_cue * 0.6 + d_obj * 1.4)
			out.append({"id": id, "pocket": k, "dir": a, "speed": _pace(d_cue, d_obj, c), "ease": ease})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.ease > y.ease)
	return out

## The balls a shot may aim to pot.
static func _targets(table: RefCounted, state: Dictionary) -> Array[int]:
	var out: Array[int] = []
	match String(state.get("phase", Rules.RED)):
		Rules.RED:
			for id in range(1, Sim.REDS + 1):
				if table.on[id]:
					out.append(id)
		Rules.COLOUR:
			for id in range(Sim.YELLOW, Sim.BLACK + 1):
				if table.on[id]:
					out.append(id)
		_:
			for id in range(Sim.YELLOW, Sim.BLACK + 1):
				if table.on[id]:
					out.append(id)
					break
	return out

## A pace that gets the object ball to the pocket with a little to spare:
## it leaves the contact sliding and keeps 5/7 of its speed once it rolls.
static func _pace(d_cue: float, d_obj: float, cut_cos: float) -> float:
	var drag := Sim.MU_ROLL * Sim.G
	var v_obj := sqrt(2.0 * drag * d_obj) * 1.4 + 0.35
	var v_hit := v_obj / maxf(0.2, cut_cos * (1.0 + Sim.E_BALL) * 0.5)
	return clampf(sqrt(v_hit * v_hit + 2.0 * drag * d_cue) * 1.1, 0.5, Sim.MAX_SPEED)

## How good the position is for whoever plays next from here: the best
## pot's ease, with a little for having more than one.
static func ease_from(table: RefCounted, state: Dictionary) -> float:
	var list := pots(table, state)
	if list.is_empty():
		return 0.0
	var s: float = list[0].ease
	if list.size() > 1:
		s += float(list[1].ease) * 0.25
	return s

static func _best_pot(table: RefCounted, state: Dictionary, level: int) -> Dictionary:
	var list := pots(table, state)
	if list.is_empty():
		return {}
	var best := {}
	var best_score := -INF
	for n in mini(REHEARSE, list.size()):
		var cand: Dictionary = list[n]
		if n > 0 and _late():
			break
		for tip in TIPS:
			for pace in PACES:
				var speed := clampf(float(cand.speed) * pace, 0.4, Sim.MAX_SPEED)
				var score := _rehearse(table, state, cand.dir, speed, tip, int(cand.id))
				# A long cut asks more of the arm than the rehearsal knows.
				score += float(cand.ease) * 4.0
				if score > best_score:
					best_score = score
					best = {"dir": cand.dir, "speed": speed, "tip": tip, "kind": "pot"}
	# An easy computer does not see the pot that only just goes.
	var floor_score: float = [2.0, 1.0, 0.5][clampi(level, 0, 2)]
	if best_score < floor_score:
		return {}
	return best

## Plays the shot out on a copy: a legal pot scores its value and the next
## ball's ease; a foul costs its penalty; otherwise nothing much.
static func _rehearse(table: RefCounted, state: Dictionary, dir: Vector2, speed: float, tip: Vector2, target: int) -> float:
	var t: RefCounted = table.copy()
	var rules: RefCounted = Rules.new(t)
	rules.phase = String(state.get("phase", Rules.RED))
	rules.free_ball = bool(state.get("free_ball", false))
	t.strike(dir, speed, tip)
	t.settle(20.0, Sim.DT * 2.0)
	var potted_target: bool = t.potted.has(target)
	var res: Dictionary = rules.judge()
	if bool(res.foul):
		return -float(res.penalty) * 1.5
	if not potted_target and int(res.scored) == 0:
		return -1.0
	var next := {"phase": rules.phase, "free_ball": false}
	return float(res.scored) + 1.5 + ease_from(t, next) * 12.0

# --- safety ---

## No pot worth taking: touch a ball on and leave the other player as little
## as possible, never fouling if a legal contact exists.
static func _safety(table: RefCounted, state: Dictionary) -> Dictionary:
	var cue: Vector2 = table.pos[Sim.CUE]
	var targets: Array = _targets(table, state)
	if bool(state.get("free_ball", false)):
		targets = []
		for id in range(1, Sim.COUNT):
			if table.on[id]:
				targets.append(id)
	targets.sort_custom(func(a: int, b: int) -> bool:
		return table.pos[a].distance_squared_to(cue) < table.pos[b].distance_squared_to(cue))
	var best := {}
	var best_score := -INF
	var tried := 0
	for id in targets:
		if tried >= 6 or (tried > 0 and _late()):
			break
		var o: Vector2 = table.pos[id]
		var to := (o - cue).normalized()
		var across := Vector2(-to.y, to.x)
		var visible := false
		for off in [0.0, 1.5, -1.5]:
			var aim: Vector2 = o + across * Sim.R * off
			if not table.lane_clear(cue, aim, [Sim.CUE, id]):
				continue
			visible = true
			for speed in [0.9, 1.7, 2.8]:
				var s := _rehearse_safe(table, state, (aim - cue).normalized(), speed)
				if s > best_score:
					best_score = s
					best = {"dir": (aim - cue).normalized(), "speed": speed, "tip": Vector2(0.0, -0.1), "kind": "safety"}
		if visible:
			tried += 1
	if best.is_empty() or best_score < -5.0:
		# Snookered: go round, off one cushion or two, at two paces, and
		# keep the escape that hits a ball on and leaves the least.
		for k in 64:
			if _late() and not best.is_empty():
				break
			var dir := Vector2.from_angle(TAU * k / 64.0)
			for speed in [1.8, 3.0]:
				var s := _rehearse_safe(table, state, dir, speed)
				if s > best_score:
					best_score = s
					best = {"dir": dir, "speed": speed, "tip": Vector2(0.0, -0.1), "kind": "safety"}
	if best.is_empty():
		var o: Vector2 = table.pos[targets[0]] if not targets.is_empty() else Vector2(Sim.W * 0.5, Sim.L * 0.3)
		best = {"dir": (o - cue).normalized(), "speed": 2.5, "tip": Vector2.ZERO, "kind": "safety"}
	return best

static func _rehearse_safe(table: RefCounted, state: Dictionary, dir: Vector2, speed: float) -> float:
	var t: RefCounted = table.copy()
	var rules: RefCounted = Rules.new(t)
	rules.phase = String(state.get("phase", Rules.RED))
	rules.free_ball = bool(state.get("free_ball", false))
	t.strike(dir, speed, Vector2(0.0, -0.1))
	t.settle(20.0, Sim.DT * 2.0)
	var res: Dictionary = rules.judge()
	if bool(res.foul):
		return -10.0 - float(res.penalty)
	if int(res.scored) > 0:
		return float(res.scored) + 5.0
	# The opponent's view: how easy their best pot is, and how far the cue
	# ball sits from the balls they want.
	var theirs := {"phase": rules.phase, "free_ball": false}
	var s := -ease_from(t, theirs) * 30.0
	var cue: Vector2 = t.pos[Sim.CUE]
	var near := INF
	for id in _targets(t, theirs):
		near = minf(near, cue.distance_to(t.pos[id]))
	if near < INF:
		s += minf(near, 2.0) * 0.8
	return s
