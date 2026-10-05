extends RefCounted

## Peapod as pure data (spec
## docs/superpowers/specs/2026-10-04-arcade-peapod-design.md): a pea cannon
## on a cart at the foot of a garden, firing on its own, and numbered crates
## coming down on it. The screen (arcade/peapod_screen.gd) sets `target_x`
## (or `axis`), calls `step()` at the fixed DT and drains `events`.
##
## The rules of the genre, kept: the cannon only slides and never stops
## firing; a crate takes as many peas as its number; gift crates drop a
## token that must be caught (one more pea a volley, a quicker gun, a
## heavier pea, a helper cart for a while); a firecracker crate takes its
## neighbours with it; and whatever reaches the cart's line ends the run.
## (The tokens, the gun's gifts and the helper went with the fourth pass.)
## Two waves of crates in a wall, five across, then one of a millipede
## winding down a path -- every plate a number, the head worth six of them,
## and a plate shot off knocks the whole of it back.
##
## The second pass (2026-10-04): three pods held for a while (a fan of peas,
## a pea that goes through three, a pea that bursts on its neighbours),
## three more gifts (a magnet for the gifts, a frost on whatever is coming,
## a shove back up) and an iron crate that takes one a pea whatever the pea
## weighs. The helper is a short one now, and the millipede quickens as it
## shortens.
##
## The third pass (2026-10-05): the rotten gift is gone (a gift that took
## something back made no sense). A wave holds more gifts and more crates,
## and its gifts are planned together (`_plan_gifts`), not drawn one by one:
## the gun's own come first and are half of them at least, and a magnet
## only comes with gifts right behind it to pull.
##
## The fourth pass (2026-10-05, the user's design): nothing falls and nothing
## is caught. A gift crate's gift is had the moment the crate breaks, so the
## magnet is gone, and with it the gun's three gifts and the helper. The gun
## is one pea a volley and grows in a shop between waves: every crate pays
## energy, and energy buys a heavier pea, a quicker gun, a pea that now and
## then lands three times as hard, or more energy a crate. A price climbs
## with each one bought and with the size of the walls (`price`), so a card
## left for later is never the cheaper for it. Two more pods, held one at a
## time like the rest: lightning that jumps on from what it hit, and a flame
## that leaves it burning. A hit says what it took (`dmg`, `crit`, `how`),
## for the numbers the screen floats off it.
##
## The fifth pass (2026-10-05, the user: "since upgrades don't stack, a wave
## with an electric shot and a burst makes one of them useless", and "instead
## of auto activate the buff, keep the last two on screen so the user can
## activate anytime, and new buffs replace the old one"). A gift is kept, not
## started: it goes to one of two places (`held`), a newer gift taking the
## older one's, and `use(slot)` starts it. And the pods are two kinds that
## run together: how the peas go (`shape`: Fan, Dart, Burst) and what they
## are made of (`element`: lightning, flame), one of each at once, each with
## its own ten seconds. A wave's second pod is of the other kind than its
## first.
##
## The sixth pass (2026-10-05, the user's four asks). The shop sells a pea
## more a volley, dear (`Card.SHOTS`), and a volley's peas leave one after
## another up the same lane (side by side since the eighth). The crit's chance no longer
## grows a level: it is CRIT_CHANCE from the first one bought (none before)
## and a level makes the crit land harder (`crit_mult`), the chance going up
## a little every CRIT_EVERY levels. The crit and the quicker gun cost more.
## And no gift is lost to a newer one: past the two places a gift waits its
## turn (`queue`), first in first out: the two places are the head of one
## line, and a gift started lets everything behind it move up one.
##
## The seventh pass (2026-10-05, the user's four asks). A price climbs only
## with each one bought, no longer with the walls ("the price increase should
## only be applied when the player buys it"). The shapes run all together,
## each with its own time, and only the elements take each other's place
## ("only elemental should not stack"). A pea of an element is the same pea in
## the element's colour (the screen's). And a new gift goes to the head of the
## line, not its end.
##
## The eighth pass (2026-10-05, the user: "instead of buffs being a queue,
## make them available at screen since beginning but as 0", and "change +1
## pea to be parallel instead of sequential"). There is no line of gifts: the
## run counts how many of each it has (`stock`), every one of the seven there
## from the start at none, and `use(kind)` starts one of a kind. A gift
## started while its like is running adds its time to what is left. And a
## volley's peas leave together, side by side.

## SHOP: a wave is cleared and the shop is open; nothing moves until
## `leave_shop()`.
enum Phase { READY, PLAY, OVER, SHOP }
enum Wave { WALL, MILLI }
## What a crate or a plate is. FAN to SHOVE hold a gift (`holds_gift`); FAN
## to FLAME are the pods (`is_pod`): FAN to BURST are how the peas go
## (`is_shape`), ZAP and FLAME what they are made of (`is_element`).
enum Kind { CRATE, GOLD, BOMB, HEAD, FAN, PIERCE, BURST, ZAP, FLAME, FROST, SHOVE, IRON }
## How a pea in flight is shaped; its element (`el`) is its colour.
enum Shot { PEA, PIERCE, BURST }
## What the shop sells.
enum Card { DAMAGE, SPEED, CRIT, ENERGY, SHOTS }
## What a number came off by: the pea itself, a splash or a jump of it, a
## firecracker, a burn.
enum Hit { PEA, SIDE, BOOM, BURN }

const DT := 1.0 / 60.0
const W := 300.0
const H := 460.0
const COLS := 5
const CELL_W := W / COLS
const CELL_H := 40.0
## The grass the cart stands on, the cart's axle and the line nothing may
## reach.
const GROUND := 432.0
const CART_Y := 414.0
const DANGER := 380.0
const CART_HALF := 22.0
const CART_SPEED := 1400.0
const READY_TIME := 1.6
const GAP_TIME := 1.5
const PEA_SPEED := 540.0
## The quicker gun: volleys a second at first, what a level adds, and the
## levels it takes (the shots in the air are what the phone pays for).
const RATE_BASE := 5.0
const RATE_STEP := 1.0
const MAX_RATE := 8
## The crit: with none bought no pea is lucky. From the first level a pea
## has CRIT_CHANCE of landing CRIT_MULT times as hard, and every level after
## adds CRIT_MULT_STEP to that; the chance itself only goes up CRIT_CHANCE_STEP
## every CRIT_EVERY levels, to CRIT_CHANCE_MAX.
const CRIT_CHANCE := 0.1
const CRIT_CHANCE_STEP := 0.05
const CRIT_CHANCE_MAX := 0.5
const CRIT_EVERY := 5
const CRIT_MULT := 3
const CRIT_MULT_STEP := 1
## The peas more a volley the shop sells at most, and how far apart the
## peas of a volley leave, side by side.
const MAX_SHOTS := 3
const PEA_GAP := 10.0
## Energy is counted in orbs, ORBS of them to one energy: a crate drops an
## orb for every quarter of what it is worth, so one worth 1.5 drops six.
## A crate is worth ENERGY_CRATE (a golden one GOLD_WORTH times), and a
## level of the Energy card adds ENERGY_STEP of that.
const ORBS := 4
const ENERGY_CRATE := 1.0
const ENERGY_STEP := 0.1
## A card's price in energy with none bought, and how much of that each one
## bought adds. Nothing else moves a price.
const PRICE := [11, 14, 14, 12, 80]
const PRICE_STEP := [0.7, 0.9, 0.9, 0.6, 1.5]
## The beat between the shop closing and the next wave.
const SHOP_GAP := 0.5
## The gifts there are, FAN to SHOVE: `stock` counts each.
const GIFTS := 7
const POD_TIME := 10.0
## Lightning: the jumps on from what a pea hit, and how far one reaches.
const ZAP_JUMPS := 4
const ZAP_REACH := 90.0
## A flame: how long a thing burns, how often it is bitten, and the share
## of the pea's weight a second it takes.
const BURN_TIME := 3.0
const BURN_TICK := 0.5
const BURN_RATE := 1.0
const FROST_TIME := 5.0
const FROST := 0.35
const SHOVE_WALL := 60.0
const SHOVE_MILLI := 200.0
## The fan's two side peas lean this far off straight up (as vx).
const FAN_VX := 135.0
const PIERCES := 3
## A wall still high up comes down quickly, so a cleared sky never waits.
const RUSH_Y := 150.0
const RUSH := 5.0
const GOLD_WORTH := 5
## The millipede's path: rows ROW apart between X0 and X1, a half circle at
## each end, entered from off the left edge.
const PATH_FROM := -26.0
const X0 := 40.0
const X1 := W - 40.0
const Y0 := 34.0
const ROW := 46.0
const TURN_R := ROW * 0.5
const PATH_ROWS := 8
const SPACING := 31.0
const SEG_R := 15.0
const HEAD_R := 19.0
const HEAD_WORTH := 6
## A wall's rows on wave 1 (one more every other wave) and at its most, the
## chance a cell is left empty (the lowest row's is its own), and a
## millipede's plates before the wave's number is added.
const WALL_ROWS := 6
const WALL_ROWS_MAX := 12
const WALL_GAP := 0.1
const WALL_GAP_LOW := 0.25
const MILLI_PLATES := 9
const MILLI_PLATES_MAX := 26
const KNOCK := 9.0
## With every plate gone but the head it runs this much quicker.
const MILLI_HURRY := 0.6
const CATCH_UP := 5.0
## Kills this close together are one streak.
const STREAK_GAP := 0.7

var rng := RandomNumberGenerator.new()
var phase := Phase.READY
var phase_t := 0.0
var t := 0.0
var score := 0
var wave := 0
var wave_kind := Wave.WALL
## Seconds until the next wave is dealt (0: one is on).
var gap_t := 0.0
var x := W * 0.5
## Where the finger wants the cart (NAN: where it is), or the keys' axis.
var target_x := NAN
var axis := 0.0
## The gun: a pea's weight, the rate's level and the crit's, the peas a
## volley (one, and one more a SHOTS card) and the level of the Energy card. `bought` is how many of each card the shop has sold
## (a booster's head start is not one of them, so it does not raise a price).
var power := 1
var rate_lv := 0
var crit_lv := 0
var peas := 1
var energy_lv := 0
var bought := [0, 0, 0, 0, 0]
## Energy held and all the run has made, both in orbs (`ORBS` to one
## energy), and the part of an orb the crates so far have left over.
var energy := 0
var earned := 0
var _orb_part := 0.0
## The gifts had and not yet used: how many of each, by `kind - Kind.FAN`
## (`has`). All seven are there from the start, at none.
var stock: Array = [0, 0, 0, 0, 0, 0, 0]
## What is running: the seconds left of each shape (FAN, PIERCE, BURST, in
## that order: `has_shape`), all of which run together; one element (0:
## none, else ZAP or FLAME) and its seconds; the frost's.
var shape_t: Array = [0.0, 0.0, 0.0]
var element := 0
var element_t := 0.0
var frost_t := 0.0
var _cool := 0.0
var shots: Array = []
## How much sky the screen shows over the field's top, in field units (a
## phone is taller than the field): a pea flies on to the top of it, and
## lands on whatever of a wall it meets up there.
var sky := 0.0
## Seconds until the last thing lit has burnt out.
var _burning := 0.0
var _shopped := false
var _last_pod := -1
## The crits' own dice, so a wave is dealt the same however the peas land.
var _luck := RandomNumberGenerator.new()
## The wall, lowest row first: each row COLS cells, null or {kind, hp, max,
## id}. `wall_y` is the lowest row's bottom edge.
var rows: Array = []
var wall_y := 0.0
var wall_speed := 8.0
## The millipede, head first: {kind, hp, max, s, id, dying}.
var segs: Array = []
var milli_speed := 24.0
var milli_n := 1
var _push := 0.0
## Where each plate is, worked out once a step and again when one goes: a
## pea asking the path for every plate it passed was most of a step.
var _seg_pos := PackedVector2Array()
var _seg_dirty := true
var _seg_top := 0.0
var _seg_low := 0.0
var events: Array = []
var kills := 0
## Gift crates broken, and gifts used.
var caught := 0
var used := 0
var fired := 0
var streak := 0
var best_streak := 0
var _streak_t := 0.0
var _warned := false
var _next_id := 1

func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_luck.seed = rng.randi()
	events.append({"type": "ready"})

func is_over() -> bool:
	return phase == Phase.OVER

## Volleys a second.
func rate() -> float:
	return RATE_BASE + RATE_STEP * rate_lv

## The chance a pea is lucky, at crit level `lv`: none before the first.
static func crit_chance(lv: int) -> float:
	if lv <= 0:
		return 0.0
	return minf(CRIT_CHANCE + CRIT_CHANCE_STEP * int(lv / float(CRIT_EVERY)), CRIT_CHANCE_MAX)

## How many times as hard a lucky pea lands, at crit level `lv`.
static func crit_mult(lv: int) -> int:
	return CRIT_MULT + CRIT_MULT_STEP * maxi(0, lv - 1)

func crit() -> float:
	return crit_chance(crit_lv)

## A crate's number on wave `w`, before its row and its luck.
static func hp_base(w: int) -> float:
	return 2.4 * pow(1.32, mini(w, 10) - 1) * pow(1.3, maxi(0, w - 10))

static func holds_gift(kind: int) -> bool:
	return kind >= Kind.FAN and kind <= Kind.SHOVE

static func is_pod(kind: int) -> bool:
	return kind >= Kind.FAN and kind <= Kind.FLAME

static func is_shape(kind: int) -> bool:
	return kind >= Kind.FAN and kind <= Kind.BURST

## Whether shape `kind` (FAN, PIERCE or BURST) is running.
func has_shape(kind: int) -> bool:
	return float(shape_t[kind - Kind.FAN]) > 0.0

static func is_element(kind: int) -> bool:
	return kind == Kind.ZAP or kind == Kind.FLAME

## About how many crates wave `w`'s wall holds: what a wave pays is this
## many crates' worth, a millipede's too (its head pays the difference).
static func wave_crates(w: int) -> float:
	return mini(WALL_ROWS + int(w / 2.0), WALL_ROWS_MAX) * COLS * (1.0 - WALL_GAP)

# --- the shop ---

## What `card` costs now, in orbs (a whole number of energy): more for each
## one bought and for nothing else, so a card not bought costs on wave 10
## what it did on wave 1.
func price(card: int) -> int:
	var p: float = PRICE[card] * (1.0 + PRICE_STEP[card] * int(bought[card]))
	return maxi(1, roundi(p)) * ORBS

## A card at its most is not sold.
func maxed(card: int) -> bool:
	return (card == Card.SPEED and rate_lv >= MAX_RATE) or (card == Card.SHOTS and peas > MAX_SHOTS)

func can_buy(card: int) -> bool:
	return not maxed(card) and energy >= price(card)

func buy(card: int) -> bool:
	if not can_buy(card):
		return false
	energy -= price(card)
	bought[card] = int(bought[card]) + 1
	match card:
		Card.DAMAGE:
			power += 1
		Card.SPEED:
			rate_lv += 1
		Card.CRIT:
			crit_lv += 1
		Card.ENERGY:
			energy_lv += 1
		Card.SHOTS:
			peas += 1
	events.append({"type": "buy", "card": card})
	return true

## The shop is shut and the next wave is on its way.
func leave_shop() -> void:
	if phase != Phase.SHOP:
		return
	phase = Phase.PLAY
	phase_t = 0.0
	_shopped = true
	gap_t = SHOP_GAP

## An iron crate's number: the peas it takes, whatever they weigh.
static func iron_hp(w: int) -> int:
	return 10 + 4 * w

static func path_len() -> float:
	return (X1 - PATH_FROM) + (PATH_ROWS - 1) * (PI * TURN_R + X1 - X0)

## The path at `s` along it.
static func path_at(s: float) -> Vector2:
	var first := X1 - PATH_FROM
	if s <= first:
		return Vector2(PATH_FROM + s, Y0)
	s -= first
	var straight := X1 - X0
	var leg := PI * TURN_R + straight
	var k := mini(int(s / leg), PATH_ROWS - 2)
	var r := s - k * leg
	var right := k % 2 == 0
	var top := Y0 + k * ROW
	if r < PI * TURN_R:
		var a := r / TURN_R
		var out := sin(a) * TURN_R
		return Vector2(X1 + out if right else X0 - out, top + TURN_R - cos(a) * TURN_R)
	r = minf(r - PI * TURN_R, straight)
	return Vector2(X1 - r if right else X0 + r, top + ROW)

## How near the end is, 0 (far) to 1 (on the line): the screen's warning.
func danger() -> float:
	if phase != Phase.PLAY:
		return 0.0
	if wave_kind == Wave.WALL:
		if rows.is_empty():
			return 0.0
		return clampf((wall_y - (DANGER - 110.0)) / 110.0, 0.0, 1.0)
	if segs.is_empty():
		return 0.0
	var left: float = path_len() - float(segs[0].s)
	return clampf(1.0 - left / 420.0, 0.0, 1.0)

## Where a cell's centre is.
func cell_pos(row: int, col: int) -> Vector2:
	return Vector2((col + 0.5) * CELL_W, wall_y - (row + 0.5) * CELL_H)

func step() -> void:
	phase_t += DT
	match phase:
		Phase.READY:
			_move()
			if phase_t >= READY_TIME:
				phase = Phase.PLAY
				phase_t = 0.0
				events.append({"type": "go"})
				_deal()
		Phase.PLAY:
			t += DT
			_move()
			_tick_gifts()
			_fire()
			_step_shots()
			_step_burns()
			if gap_t > 0.0:
				gap_t -= DT
				if gap_t <= 0.0:
					gap_t = 0.0
					_after_gap()
			elif wave_kind == Wave.WALL:
				_step_wall()
			else:
				_step_milli()
			_streak_t -= DT
			if _streak_t <= 0.0:
				streak = 0
			var d := danger()
			if d > 0.35 and not _warned:
				_warned = true
				events.append({"type": "warn"})
			elif d < 0.15:
				_warned = false
		Phase.OVER:
			_step_shots()

## The beat after a cleared wave is over: the shop, when there is energy for
## anything in it, and then the next wave.
func _after_gap() -> void:
	if not _shopped:
		for card in Card.size():
			if can_buy(card):
				phase = Phase.SHOP
				phase_t = 0.0
				events.append({"type": "shop"})
				return
	_shopped = false
	_deal()

func _move() -> void:
	var want := x
	if not is_nan(target_x):
		want = target_x
	elif axis != 0.0:
		want = x + axis * 260.0 * DT
	x = move_toward(x, clampf(want, CART_HALF, W - CART_HALF), CART_SPEED * DT)

## The shape, the element and the frost run down.
func _tick_gifts() -> void:
	for i in shape_t.size():
		if float(shape_t[i]) > 0.0:
			shape_t[i] = float(shape_t[i]) - DT
			if float(shape_t[i]) <= 0.0:
				shape_t[i] = 0.0
				events.append({"type": "pod_off", "kind": Kind.FAN + i})
	if element_t > 0.0:
		element_t -= DT
		if element_t <= 0.0:
			element_t = 0.0
			events.append({"type": "pod_off", "kind": element})
			element = 0
	if frost_t > 0.0:
		frost_t -= DT
		if frost_t <= 0.0:
			frost_t = 0.0
			events.append({"type": "frost_off"})

## What the frost leaves of a speed.
func _slow() -> float:
	return FROST if frost_t > 0.0 else 1.0

## A volley leaves all at once, from wherever the cart is.
func _fire() -> void:
	_cool -= DT
	if _cool > 0.0:
		return
	_cool += 1.0 / rate()
	_volley(x)
	events.append({"type": "shot", "x": x})
	fired += 1

## How far off the cart's middle pea `i` of a volley of `n` leaves: side by
## side, PEA_GAP apart, the volley's middle over the cart's.
static func pea_off(i: int, n: int) -> float:
	return (i - (n - 1) * 0.5) * PEA_GAP

## A volley as the shapes and the element running make it: its peas side by
## side, straight up. A pea carries how it lands (`left` targets to go
## through, `burst`, `el`: its element); `k` is its shape (Shot), a berry
## before a dart when it is both. The Fan's side peas are plain ones of the
## same element, flung out from either end of the row.
func _volley(from: float) -> void:
	var burst := has_shape(Kind.BURST)
	var pierce := has_shape(Kind.PIERCE)
	var look := Shot.BURST if burst else (Shot.PIERCE if pierce else Shot.PEA)
	for i in peas:
		shots.append({"x": clampf(from + pea_off(i, peas), 3.0, W - 3.0), "y": CART_Y - 34.0, "vx": 0.0, "k": look,
			"left": PIERCES - 1 if pierce else 0, "last": -1, "burst": burst, "el": element})
	if has_shape(Kind.FAN):
		var out := pea_off(peas - 1, peas) + 6.0
		for side in [-1.0, 1.0]:
			shots.append({"x": clampf(from + side * out, 3.0, W - 3.0), "y": CART_Y - 34.0, "vx": side * FAN_VX, "k": Shot.PEA, "left": 0, "last": -1, "burst": false, "el": element})

func _step_shots() -> void:
	var keep: Array = []
	_seg_dirty = true
	var live := phase == Phase.PLAY and gap_t <= 0.0
	for p: Dictionary in shots:
		p.y -= PEA_SPEED * DT
		if p.y < -sky - 8.0:
			continue
		if p.vx != 0.0:
			p.x += float(p.vx) * DT
			# a pea flung sideways comes back off the garden's side
			if p.x < 3.0 or p.x > W - 3.0:
				p.x = clampf(p.x, 3.0, W - 3.0)
				p.vx = -float(p.vx)
		if live and _strike(p):
			continue
		keep.append(p)
	shots = keep

## Where every plate is, and the band of the field they are in.
func _place_segs() -> void:
	_seg_dirty = false
	var n := segs.size()
	_seg_pos.resize(n)
	_seg_top = INF
	_seg_low = -INF
	for i in n:
		var at := path_at(segs[i].s)
		_seg_pos[i] = at
		_seg_top = minf(_seg_top, at.y)
		_seg_low = maxf(_seg_low, at.y)

## A pea against whatever is over it. True when it is spent.
func _strike(p: Dictionary) -> bool:
	var px: float = p.x
	var py: float = p.y
	if wave_kind == Wave.WALL:
		if py > wall_y or rows.is_empty() or px < 0.0 or px >= W:
			return false
		var r := int((wall_y - py) / CELL_H)
		var c := clampi(int(px / CELL_W), 0, COLS - 1)
		if r >= rows.size() or rows[r][c] == null:
			return false
		var cell: Dictionary = rows[r][c]
		if int(cell.id) == int(p.last):
			return false
		var lucky := _lucky()
		var dmg := power * (crit_mult(crit_lv) if lucky else 1)
		var half := maxi(1, int(dmg / 2.0))
		_hurt_cell(r, c, dmg, Vector2(px, wall_y - r * CELL_H), Hit.PEA, lucky)
		if bool(p.burst):
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0)]:
				var rr: int = r + d.x
				var cc: int = c + d.y
				if rr < rows.size() and cc >= 0 and cc < COLS and rows[rr][cc] != null:
					_hurt_cell(rr, cc, half, cell_pos(rr, cc), Hit.SIDE)
		match int(p.el):
			Kind.ZAP:
				_zap_wall(r, c, half)
			Kind.FLAME:
				_light(rows[r][c])
		return _spent(p, int(cell.id))
	if _seg_dirty:
		_place_segs()
	if py < _seg_top - HEAD_R - 2.0 or py > _seg_low + HEAD_R + 2.0:
		return false
	for i in segs.size():
		var sg: Dictionary = segs[i]
		if sg.dying >= 0.0 or float(sg.s) < 0.0:
			continue
		var at := _seg_pos[i]
		var rad := (HEAD_R if sg.kind == Kind.HEAD else SEG_R) + 2.0
		if absf(at.x - px) < rad and absf(at.y - py) < rad:
			var id: int = sg.id
			if id == int(p.last):
				continue
			var lucky := _lucky()
			var dmg := power * (crit_mult(crit_lv) if lucky else 1)
			var half := maxi(1, int(dmg / 2.0))
			var beside: Array = []
			if bool(p.burst):
				for j in [i - 1, i + 1]:
					if j >= 0 and j < segs.size():
						beside.append(segs[j].id)
			_hurt_seg(i, dmg, Vector2(px, at.y + rad * 0.7), Hit.PEA, lucky)
			for other: int in beside:
				var j := _seg_index(other)
				if j >= 0 and float(segs[j].dying) < 0.0 and float(segs[j].s) >= 0.0:
					_hurt_seg(j, half, path_at(segs[j].s), Hit.SIDE)
			if int(p.el) == Kind.ZAP:
				_zap_milli(id, at, half)
			elif int(p.el) == Kind.FLAME:
				var lit := _seg_index(id)
				if lit >= 0:
					_light(segs[lit])
			return _spent(p, id)
	return false

## A pea that has landed on `id`: a piercing one with targets left goes on.
func _spent(p: Dictionary, id: int) -> bool:
	if int(p.left) <= 0:
		return true
	p.left = int(p.left) - 1
	p.last = id
	return false

func _lucky() -> bool:
	return crit_lv > 0 and _luck.randf() < crit()

## Lightning off the crate at (`r`, `c`): on to the nearest crate in reach,
## and from that to the next, ZAP_JUMPS times, none of them twice.
func _zap_wall(r: int, c: int, dmg: int) -> void:
	var at := cell_pos(r, c)
	var pts := [at]
	var done := {Vector2i(r, c): true}
	for jump in ZAP_JUMPS:
		var best := Vector2i(-1, -1)
		var near := ZAP_REACH * ZAP_REACH
		for rr in rows.size():
			# nothing still up over the top of the sky is reached
			if wall_y - (rr + 0.5) * CELL_H < -sky:
				break
			for cc in COLS:
				if rows[rr][cc] == null or done.has(Vector2i(rr, cc)):
					continue
				var d := cell_pos(rr, cc).distance_squared_to(at)
				if d < near:
					near = d
					best = Vector2i(rr, cc)
		if best.x < 0:
			break
		done[best] = true
		at = cell_pos(best.x, best.y)
		pts.append(at)
		_hurt_cell(best.x, best.y, dmg, at, Hit.SIDE)
	if pts.size() > 1:
		events.append({"type": "zap", "pts": pts})

## The same along the millipede, off the plate `id` at `at`.
func _zap_milli(id: int, at: Vector2, dmg: int) -> void:
	var pts := [at]
	var done := {id: true}
	for jump in ZAP_JUMPS:
		if segs.is_empty() or segs[0].kind != Kind.HEAD:
			break
		var best := -1
		var near := ZAP_REACH * ZAP_REACH
		var where := at
		for j in segs.size():
			var sg: Dictionary = segs[j]
			if done.has(int(sg.id)) or float(sg.dying) >= 0.0 or float(sg.s) < 0.0:
				continue
			var q := path_at(sg.s)
			var d := q.distance_squared_to(at)
			if d < near:
				near = d
				best = j
				where = q
		if best < 0:
			break
		done[int(segs[best].id)] = true
		at = where
		pts.append(at)
		_hurt_seg(best, dmg, at, Hit.SIDE)
	if pts.size() > 1:
		events.append({"type": "zap", "pts": pts})

## A flame's pea has landed on `cell` (null: it is gone): it burns from now,
## as hard as the heaviest pea that lit it.
func _light(cell) -> void:
	if cell == null or int(cell.hp) <= 0:
		return
	if float(cell.burn_t) <= 0.0:
		cell.burn_c = BURN_TICK
	cell.burn_t = BURN_TIME
	cell.burn = maxi(int(cell.burn), power)
	_burning = BURN_TIME

## What is alight is bitten every BURN_TICK until it burns out.
func _step_burns() -> void:
	if _burning <= 0.0 or gap_t > 0.0:
		return
	_burning -= DT
	if wave_kind == Wave.WALL:
		for r in rows.size():
			for c in COLS:
				var cell = rows[r][c]
				if cell != null and _burn(cell):
					_hurt_cell(r, c, _bite(cell), cell_pos(r, c), Hit.BURN)
		return
	for i in range(segs.size() - 1, -1, -1):
		if i >= segs.size() or segs[0].kind != Kind.HEAD:
			continue
		var sg: Dictionary = segs[i]
		if float(sg.dying) < 0.0 and float(sg.s) >= 0.0 and _burn(sg):
			_hurt_seg(i, _bite(sg), path_at(sg.s), Hit.BURN)

## True when `cell` is to be bitten this step.
func _burn(cell: Dictionary) -> bool:
	if float(cell.burn_t) <= 0.0:
		return false
	cell.burn_t = float(cell.burn_t) - DT
	cell.burn_c = float(cell.burn_c) - DT
	if float(cell.burn_c) > 0.0:
		return false
	cell.burn_c = float(cell.burn_c) + BURN_TICK
	return true

static func _bite(cell: Dictionary) -> int:
	return maxi(1, roundi(int(cell.burn) * BURN_RATE * BURN_TICK))

func _seg_index(id: int) -> int:
	for i in segs.size():
		if int(segs[i].id) == id:
			return i
	return -1

## `how` is what it came off by (Hit): iron takes a firecracker's whole and
## one of anything else's, and a splash, a jump or a burn lands `quiet`,
## without a sound of its own. `lucky` is a crit.
func _hurt_cell(r: int, c: int, dmg: int, at: Vector2, how := Hit.PEA, lucky := false) -> void:
	var cell: Dictionary = rows[r][c]
	if cell.kind == Kind.IRON and how != Hit.BOOM:
		dmg = 1
	cell.hp = int(cell.hp) - dmg
	var quiet := how == Hit.SIDE or how == Hit.BURN
	events.append({"type": "hit", "pos": at, "id": cell.id, "kind": cell.kind, "hp": maxi(0, cell.hp), "quiet": quiet,
		"dmg": dmg, "crit": lucky, "how": how})
	if cell.hp > 0:
		return
	var pos := cell_pos(r, c)
	rows[r][c] = null
	_killed(cell, pos)
	if cell.kind == Kind.BOMB:
		events.append({"type": "boom", "pos": pos})
		var blast := maxi(2, int(ceilf(hp_base(wave) * 3.0)))
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				var rr: int = r + dr
				var cc: int = c + dc
				if rr >= 0 and rr < rows.size() and cc >= 0 and cc < COLS and rows[rr][cc] != null:
					_hurt_cell(rr, cc, blast, cell_pos(rr, cc), Hit.BOOM)

func _hurt_seg(i: int, dmg: int, at: Vector2, how := Hit.PEA, lucky := false) -> void:
	var sg: Dictionary = segs[i]
	if sg.kind == Kind.IRON:
		dmg = 1
	sg.hp = int(sg.hp) - dmg
	var quiet := how == Hit.SIDE or how == Hit.BURN
	events.append({"type": "hit", "pos": at, "id": sg.id, "kind": sg.kind, "hp": maxi(0, sg.hp), "quiet": quiet,
		"dmg": dmg, "crit": lucky, "how": how})
	if sg.hp > 0:
		return
	_seg_dirty = true
	var pos := path_at(sg.s)
	if sg.kind == Kind.HEAD:
		# the head gone, the rest goes off plate by plate
		segs.remove_at(i)
		_killed(sg, pos)
		for k in segs.size():
			segs[k].dying = 0.12 + 0.07 * k
		return
	segs.remove_at(i)
	_killed(sg, pos)
	_push += KNOCK
	events.append({"type": "knock"})

## A crate or a plate gone: the score, the streak, its energy, and one more
## of a gift crate's gift, kept for when it is wanted.
func _killed(cell: Dictionary, pos: Vector2, popped := false) -> void:
	var kind: int = cell.kind
	var worth: int = int(cell.max)
	var pay := ENERGY_CRATE
	if kind == Kind.GOLD:
		worth *= GOLD_WORTH
		pay *= GOLD_WORTH
	elif kind == Kind.HEAD:
		# a millipede is fewer plates than a wall is crates: its head makes
		# the wave up to a wall's worth
		pay *= maxf(1.0, wave_crates(wave) - milli_n)
	# in orbs; what is short of one is kept for the next crate
	_orb_part += pay * (1.0 + ENERGY_STEP * energy_lv) * ORBS
	var got := int(_orb_part)
	_orb_part -= got
	energy += got
	earned += got
	score += worth
	kills += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	_streak_t = STREAK_GAP
	events.append({"type": "kill", "pos": pos, "kind": kind, "points": worth, "max": cell.max, "id": cell.id,
		"streak": streak, "popped": popped, "energy": got})
	if holds_gift(kind):
		_take(kind, pos)

## A gift crate broken: one more of its gift is had (`count`: how many
## now). Nothing starts until `use()`.
func _take(kind: int, at: Vector2) -> void:
	caught += 1
	stock[kind - Kind.FAN] = int(stock[kind - Kind.FAN]) + 1
	events.append({"type": "gift", "pos": at, "kind": kind, "count": has(kind)})

## How many of gift `kind` are had and not used.
func has(kind: int) -> int:
	return int(stock[kind - Kind.FAN]) if holds_gift(kind) else 0

## Whether a gift of `kind` can be started now: there is one, and a wave is
## on to use it against.
func can_use(kind: int) -> bool:
	return phase == Phase.PLAY and gap_t <= 0.0 and has(kind) > 0

## Starts one gift of `kind` (`left`: how many are still had). A shape runs
## with whatever else is running; an element takes the place of the other
## element. One started while its like is running adds its time to what is
## left, so none is ever spent for nothing.
func use(kind: int) -> bool:
	if not can_use(kind):
		return false
	stock[kind - Kind.FAN] = int(stock[kind - Kind.FAN]) - 1
	used += 1
	match kind:
		Kind.FROST:
			frost_t += FROST_TIME
		Kind.SHOVE:
			_shove()
		Kind.ZAP, Kind.FLAME:
			element_t = element_t + POD_TIME if element == kind else POD_TIME
			element = kind
		_:
			shape_t[kind - Kind.FAN] = float(shape_t[kind - Kind.FAN]) + POD_TIME
	events.append({"type": "use", "kind": kind, "left": has(kind)})
	return true

## Everything coming goes back a way: the wall up, the millipede along
## its path.
func _shove() -> void:
	if wave_kind == Wave.WALL:
		wall_y = maxf(wall_y - SHOVE_WALL, minf(wall_y, RUSH_Y))
	elif not segs.is_empty() and segs[0].kind == Kind.HEAD:
		var s: float = segs[0].s
		segs[0].s = maxf(s - SHOVE_MILLI, minf(s, 260.0))
		for i in range(1, segs.size()):
			segs[i].s = minf(float(segs[i].s), float(segs[i - 1].s) - SPACING)

# --- the waves ---

func _deal() -> void:
	wave += 1
	wave_kind = Wave.MILLI if wave % 3 == 0 else Wave.WALL
	if wave_kind == Wave.WALL:
		_deal_wall()
	else:
		_deal_milli()
	events.append({"type": "wave", "wave": wave, "kind": wave_kind})

## How many gift crates (or plates) wave `w` holds.
static func gift_count(w: int) -> int:
	return mini(1 + int(w / 3.0), 4)

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held = a[i]
		a[i] = a[j]
		a[j] = held

## A pod that is not `last`.
func _a_pod(last: int) -> int:
	var pods := [Kind.FAN, Kind.PIERCE, Kind.BURST, Kind.ZAP, Kind.FLAME]
	pods.erase(last)
	return pods[rng.randi_range(0, pods.size() - 1)]

## A pod that runs together with `pod`: an element for a shape, a shape for
## an element.
func _a_match(pod: int) -> int:
	var pods := [Kind.ZAP, Kind.FLAME] if is_shape(pod) else [Kind.FAN, Kind.PIERCE, Kind.BURST]
	return pods[rng.randi_range(0, pods.size() - 1)]

## What a wave's `count` gifts are, in the order they are met: a pod first,
## never the one the wave before began with, and after it the frost (from
## wave 3), the shove (from wave 4) and one more pod, in any order. The
## second pod is one that runs together with the first, so no wave holds two
## pods of which one is wasted.
func _plan_gifts(count: int) -> Array:
	var first := _a_pod(_last_pod)
	_last_pod = first
	var extras: Array = [_a_match(first)]
	if wave >= 3:
		extras.append(Kind.FROST)
	if wave >= 4:
		extras.append(Kind.SHOVE)
	_shuffle(extras)
	extras.resize(clampi(count - 1, 0, extras.size()))
	extras.push_front(first)
	return extras

## Where a wave's gifts go among `n` places (a wall's rows over the lowest,
## a millipede's plates), in the order they are met: spread along them, each
## on a place of its own.
func _gift_places(plan: Array, n: int) -> Array:
	var count := plan.size()
	var places: Array = []
	for i in count:
		var at := int((i + rng.randf()) * n / count)
		var low: int = 0 if i == 0 else int(places[i - 1]) + 1
		places.append(clampi(at, low, n - count + i))
	return places

## How many iron crates wave `w` holds.
static func iron_count(w: int) -> int:
	return 0 if w < 5 else mini(1 + int((w - 5) / 4.0), 4)

func _cell(kind: int, hp: int) -> Dictionary:
	_next_id += 1
	return {"kind": kind, "hp": maxi(1, hp), "max": maxi(1, hp), "id": _next_id - 1, "burn_t": 0.0, "burn_c": 0.0, "burn": 0}

## A wall: rows of crates, the higher the heavier, with gaps, one to four
## gifts up it, a firecracker from wave four and a golden crate now and then.
func _deal_wall() -> void:
	rows.clear()
	var n := mini(WALL_ROWS + int(wave / 2.0), WALL_ROWS_MAX)
	var base := hp_base(wave)
	for r in n:
		var row: Array = []
		for c in COLS:
			var gap := WALL_GAP if r > 0 else WALL_GAP_LOW
			if rng.randf() < gap:
				row.append(null)
				continue
			var hp := base * (1.0 + 0.3 * r) * rng.randf_range(0.7, 1.3)
			if rng.randf() < 0.08:
				hp *= 2.0
			row.append(_cell(Kind.CRATE, roundi(hp)))
		rows.append(row)
	var plan := _plan_gifts(gift_count(wave))
	var at := _gift_places(plan, n - 1)
	for i in plan.size():
		var r: int = int(at[i]) + 1
		rows[r][rng.randi_range(0, COLS - 1)] = _cell(plan[i], roundi(base * (0.5 + 0.12 * r)))
	if wave >= 4:
		_scatter(1 + int(wave >= 9), n, func(r: int) -> Dictionary: return _cell(Kind.BOMB, roundi(base * (0.8 + 0.2 * r))))
	if wave >= 2 and rng.randf() < 0.6:
		_scatter(1, n, func(r: int) -> Dictionary: return _cell(Kind.GOLD, roundi(base * (1.6 + 0.3 * r))))
	_scatter(iron_count(wave), n, func(_r: int) -> Dictionary: return _cell(Kind.IRON, iron_hp(wave)))
	wall_y = 0.0
	wall_speed = 6.5 + 0.45 * mini(wave, 20)

## Puts `count` cells made by `make` on rows of their own, clear of the
## lowest and of each other.
func _scatter(count: int, n: int, make: Callable) -> void:
	for i in count:
		for tries in 12:
			var r := rng.randi_range(1 if n > 1 else 0, n - 1)
			var c := rng.randi_range(0, COLS - 1)
			var here = rows[r][c]
			if here == null or int(here.kind) == Kind.CRATE:
				rows[r][c] = make.call(r)
				break

func _step_wall() -> void:
	while not rows.is_empty() and _row_empty(rows[0]):
		rows.pop_front()
		wall_y -= CELL_H
	if rows.is_empty():
		_cleared()
		return
	wall_y += wall_speed * (RUSH if wall_y < RUSH_Y else _slow()) * DT
	if wall_y >= DANGER:
		_end("wall")

static func _row_empty(row: Array) -> bool:
	for c in row:
		if c != null:
			return false
	return true

## The millipede: a head and so many plates behind it, its gifts spread
## down its length.
func _deal_milli() -> void:
	segs.clear()
	_push = 0.0
	var n := mini(MILLI_PLATES + wave, MILLI_PLATES_MAX)
	var plan := _plan_gifts(gift_count(wave))
	var at := _gift_places(plan, n)
	var base := hp_base(wave) * 1.5
	var head := _cell(Kind.HEAD, roundi(base * HEAD_WORTH))
	head.s = 0.0
	head.dying = -1.0
	segs.append(head)
	for i in n:
		var kind := Kind.CRATE
		if at.has(i):
			kind = plan[at.find(i)]
		elif i % 7 == 5:
			kind = Kind.GOLD
		elif i % 5 == 3 and wave >= 9:
			kind = Kind.IRON
		var hp := base * rng.randf_range(0.7, 1.3) * (0.5 if holds_gift(kind) else (1.6 if kind == Kind.GOLD else 1.0))
		if kind == Kind.IRON:
			hp = iron_hp(wave) * 0.5
		var sg := _cell(kind, roundi(hp))
		sg.s = -(i + 1) * SPACING
		sg.dying = -1.0
		segs.append(sg)
	milli_n = n
	milli_speed = 20.0 + 0.7 * mini(wave, 24)

func _step_milli() -> void:
	if segs.is_empty():
		_cleared()
		return
	# the tail going off after the head
	if segs[0].kind != Kind.HEAD:
		var i := 0
		while i < segs.size():
			var sg: Dictionary = segs[i]
			sg.dying = float(sg.dying) - DT
			if sg.dying <= 0.0:
				segs.remove_at(i)
				_killed(sg, path_at(sg.s), true)
			else:
				i += 1
		return
	var head: Dictionary = segs[0]
	# the shorter it is, the quicker it runs
	var hurry := 1.0 + MILLI_HURRY * (1.0 - float(segs.size() - 1) / maxf(1.0, milli_n))
	var speed := milli_speed * (RUSH if float(head.s) < 260.0 else hurry * _slow())
	var back := minf(_push, 150.0 * DT)
	_push -= back
	head.s = maxf(0.0, float(head.s) + speed * DT - back)
	for i in range(1, segs.size()):
		var sg: Dictionary = segs[i]
		var want: float = float(segs[i - 1].s) - SPACING
		if float(sg.s) > want:
			sg.s = want
		else:
			sg.s = minf(want, float(sg.s) + speed * CATCH_UP * DT)
	if float(head.s) >= path_len():
		_end("milli")

func _cleared() -> void:
	var bonus := 50 * wave
	score += bonus
	events.append({"type": "clear", "wave": wave, "bonus": bonus, "kind": wave_kind})
	gap_t = GAP_TIME

func _end(why: String) -> void:
	phase = Phase.OVER
	phase_t = 0.0
	events.append({"type": "over", "why": why})

## The Second chance (arcade/boosters.gd): the wall is shoved back up four
## rows, the millipede a long way back along its path.
func revive() -> void:
	if phase != Phase.OVER:
		return
	phase = Phase.PLAY
	phase_t = 0.0
	_warned = false
	if wave_kind == Wave.WALL:
		wall_y = minf(wall_y, DANGER) - CELL_H * 4.5
	elif not segs.is_empty():
		segs[0].s = maxf(float(segs[0].s) - 700.0, 260.0)
	events.append({"type": "revive"})
