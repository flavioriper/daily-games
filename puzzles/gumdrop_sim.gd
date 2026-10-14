extends RefCounted

## Gumdrop as data (specs
## docs/superpowers/specs/2026-10-10-arcade-gumdrop-design.md and
## 2026-10-11-gumdrop-daily-design.md): the day, the jelly, the pots, the
## needle and the judge's words. The table (puzzles/gumdrop_table.gd)
## hands it `pick()`, `aim()`, `squeeze()` and `serve()`, calls `step()` at
## the fixed DT and drains `events`.
##
## The syrup itself is not here since 2026-10-11 (the user: "I want a real
## high volume liquid effect of coloring"): it is a fluid on the GPU
## (puzzles/gumdrop_fluid.gd), which the screen drives from this sim's tip
## and squeeze and reads back when a mould is served. This sim says what a
## colour means: a bit of jelly shows the hue of its pigments' shares at
## the strength of their sum (1 - exp(-c / C0), the card's shade at
## C_FULL), deeper than the card past that, and its match to the card is
## how near its colour is as a share of the way from clear to the card's
## colour. The fluid's shaders carry the same maths word for word
## (shaders/gumdrop/fluid.gdshaderinc).
##
## A day is a band's few moulds, one after the other, with no clock
## (`set_day`). Served, a mould settles SETTLE_T and the sim asks to be
## judged (`judge` event); the table answers `judge()` with each cell's
## match and the verdict follows. At the mark or over, the next mould is
## set down, and the last one served is the day done. Under it the mould
## is emptied and poured again, on every band: no day can be lost (Insane
## counted its serves until 2026-10-12, when the user took every move limit
## off Insane; the count's leftovers went on 2026-10-14). The match is not
## shown while the mould is played.

const Mould = preload("res://puzzles/gumdrop_mould.gd")

enum Phase { READY, PLAY, SETTLE, SHOW, DONE }

const DT := 1.0 / 60.0
## Squares a side of the grid that says which cell the tip is over, and
## mould units a square.
const N := 36
const CELL := Mould.SIDE / N
## Concentration: at C0 a bit of jelly is 63% of the way to the card's
## shade, at C_FULL it is the card's shade, and at 2 x C_FULL it is DEEP
## darker.
const C0 := 0.5
const C_FULL := 1.25
const DEEP := 0.3
const NEAR_FREE := 0.1
const NEAR_GONE := 0.8
## What a chunk under the needle gains a second, in amounts (the card's
## shade is C_FULL), as this sim reckons it until the table says what the
## fluid holds (`learn`); and the amount a chunk is dry under.
const RATE := 0.5
const WET := 0.02
## The mark a mould has to be served at when no day says (a tutorial
## page's), and the match a mould is called perfect at.
const MARK := 60
const PERFECT := 95

## Seconds: the syrup left to settle before it is judged, and the verdict
## shown.
const SETTLE_T := 0.9
const SHOW_T := 2.4
## The six flavours' colours, in Mould.Flavour's order, and all three
## pigments at once.
const FLAVOURS := [Color("e2495a"), Color("f39237"), Color("f4d44a"), Color("79c94f"), Color("4a86df"), Color("9a62d2")]
const MUD := Color("7a5a48")

var phase := Phase.READY
var phase_t := 0.0
## Seconds played.
var t := 0.0
## The day: its moulds, which of them is on the tray, the mark each is
## served at, and each one's match once it passed.
var moulds: Array = []
var index := 0
var need := MARK
var marks: Array = []
## The serves made.
var serves := 0
## The last verdict: {pct, need, pass, perfect}.
var verdict := {}
var events: Array = []

var mould := {}
## The pots: {flavour}. They never run dry.
var pots: Array = []
var picked := 0
## The needle's tip, in mould units, whether it is being squeezed, and
## whether syrup is being drawn back out of the chunk under it (the grey
## button, 2026-10-14: the one tool that takes tint out).
var tip := Vector2(Mould.SIDE, Mould.SIDE) * 0.5
var squeezing := false
var draining := false
## What each chunk holds, in amounts: this sim's reckoning of the
## squeezes and drains, put right by the table from the fluid's meter
## (`learn`), so an emptied chunk is dry again and a mould drawn fully
## out cannot be served. `poured` is the most of them.
var poured := 0.0
var tank := PackedFloat32Array()
## Which cell each square is in (-1 the tray), and how many squares each
## cell has.
var reg := PackedInt32Array()
var count := PackedInt32Array()
## Each cell's match, 0 to 1, and the whole mould's, as of the last
## `judge()`.
var cell_match := PackedFloat32Array()
var match_all := 0.0
## Cells a tutorial page wants coloured before it starts: {cell, pigment}.
## The screen drains them into the fluid.
var prefill: Array = []
var _asked := false

## A sim with the first picture on its tray, until `set_day` or `deal`
## says otherwise.
func _init() -> void:
	var m := Mould.build(Mould.PICTURES[0])
	m.pots = Mould.flavours(m)
	set_day([m], MARK)

## The day: these moulds, each served at `mark_at`.
func set_day(list: Array, mark_at: int) -> void:
	moulds = list
	need = mark_at
	restart()

## A band's day off the day's seed, the day's themed jellies first when
## there are any (Mould.day).
func deal_day(band: int, from: RandomNumberGenerator, themed: Array = []) -> void:
	var spec: Dictionary = Mould.BANDS[clampi(band, 0, Mould.BANDS.size() - 1)]
	set_day(Mould.day(band, from, themed), int(spec.mark))

## The day from its first mould, the serves from zero.
func restart() -> void:
	index = 0
	serves = 0
	marks.clear()
	verdict = {}
	t = 0.0
	phase = Phase.READY
	phase_t = 0.0
	deal(moulds[0])

func is_done() -> bool:
	return phase == Phase.DONE

func mark() -> int:
	return need

## Moulds still to pass.
func moulds_left() -> int:
	return moulds.size() - index

# --- the colour ---

## The hue of red, yellow and blue pigment in these parts: each flavour
## where it is alone or half and half with its neighbour, and mud in the
## middle, where all three meet.
static func hue(r: float, y: float, b: float) -> Color:
	var top := maxf(r, maxf(y, b))
	if top <= 0.0:
		return Color.WHITE
	r /= top
	y /= top
	b /= top
	var c00: Color = Color.WHITE.lerp(FLAVOURS[0], r)
	var c10: Color = FLAVOURS[2].lerp(FLAVOURS[1], r)
	var c01: Color = FLAVOURS[4].lerp(FLAVOURS[5], r)
	var c11: Color = FLAVOURS[3].lerp(MUD, r)
	return c00.lerp(c10, y).lerp(c01.lerp(c11, y), b)

## How strong a concentration shows: 0 clear, 1 the card's shade.
static func strength(c: float) -> float:
	return minf(1.0, (1.0 - exp(-c / C0)) / (1.0 - exp(-C_FULL / C0)))

## How much deeper than the card a concentration past C_FULL goes, 0 to 1.
static func deep(c: float) -> float:
	return clampf((c - C_FULL) / C_FULL, 0.0, 1.0) * DEEP

## The colour a bit of jelly shows with this pigment in it: the hue at
## its strength, deepened past the card's shade. Alpha is the strength.
static func colour(r: float, y: float, b: float) -> Color:
	var c := r + y + b
	if c <= 0.0:
		return Color(1, 1, 1, 0)
	var s := strength(c)
	var h := hue(r, y, b)
	var d := deep(c)
	if d > 0.0:
		h = h.lerp(h * h, d)
	return Color(h.r, h.g, h.b, s)

## How near a colour is to a flavour's, 1 at it, 0 clear: its distance to
## the flavour against the way from clear to the flavour. NEAR_FREE of
## the way off is still a full match (the eye calls it the same colour),
## at NEAR_GONE of the way off the match is nothing.
static func nearness(col: Color, flavour: int) -> float:
	var want: Color = FLAVOURS[flavour]
	var shown := Color.WHITE.lerp(Color(col.r, col.g, col.b), col.a)
	var way := Vector3(1.0 - want.r, 1.0 - want.g, 1.0 - want.b).length()
	var off := Vector3(shown.r - want.r, shown.g - want.g, shown.b - want.b).length()
	return 1.0 - clampf((off / way - NEAR_FREE) / (NEAR_GONE - NEAR_FREE), 0.0, 1.0)

# --- a mould ---

## `m` set down on the tray, clear.
func deal(m: Dictionary) -> void:
	mould = m
	_lay()
	events.append({"type": "deal", "index": index})

## The mould on the tray emptied, to be poured again.
func empty() -> void:
	if phase != Phase.READY and phase != Phase.PLAY:
		return
	_lay()
	events.append({"type": "again"})

func _lay() -> void:
	var cells: Array = mould.cells
	reg.resize(N * N)
	count.resize(cells.size())
	count.fill(0)
	for i in N * N:
		var found := Mould.cell_at(mould, Vector2((i % N) + 0.5, (i / N) + 0.5) * CELL)
		reg[i] = found
		if found >= 0:
			count[found] += 1
	cell_match.resize(cells.size())
	cell_match.fill(0.0)
	match_all = 0.0
	pots.clear()
	for f: int in mould.pots:
		pots.append({"flavour": f})
	picked = 0
	tip = centre_of(0)
	squeezing = false
	draining = false
	poured = 0.0
	tank.resize(cells.size())
	tank.fill(0.0)
	prefill.clear()
	_asked = false

## The square a point of the mould lies in.
static func square(p: Vector2) -> int:
	return clampi(int(p.x / CELL), 0, N - 1) + clampi(int(p.y / CELL), 0, N - 1) * N

static func at(i: int) -> Vector2:
	return Vector2((i % N) + 0.5, (i / N) + 0.5) * CELL

## The chunk of jelly the tip is in, -1 the tray: the tint goes into that
## chunk and stays in it.
func tip_cell() -> int:
	return Mould.cell_at(mould, tip)

## The point of a chunk furthest from its edges: where a careful hand
## puts the needle. The middle of the squares about it that are all the
## chunk's.
func centre_of(c: int) -> Vector2:
	var best := -1
	var far := -1
	for i in N * N:
		if reg[i] != c:
			continue
		var x := i % N
		var y := i / N
		var ring := 0
		var whole := true
		while whole and ring < N:
			ring += 1
			for k in range(-ring, ring + 1):
				for q: Vector2i in [Vector2i(x + k, y - ring), Vector2i(x + k, y + ring), Vector2i(x - ring, y + k), Vector2i(x + ring, y + k)]:
					if q.x < 0 or q.y < 0 or q.x >= N or q.y >= N or reg[q.x + q.y * N] != c:
						whole = false
		if ring > far:
			far = ring
			best = i
	return at(best) if best >= 0 else (mould.cells[c] as PackedVector2Array)[0]

## A cell coloured before play, a tutorial page's: `part` of the way to
## the card's shade of a flavour.
func filled(c: int, flavour: int, part: float) -> void:
	var pig: Vector3 = Mould.PIGMENT[flavour]
	prefill.append({"cell": c, "pigment": pig * part * C_FULL})
	_tally(c, part * C_FULL)
	if phase == Phase.READY:
		phase = Phase.PLAY

# --- the hand ---

func pick(i: int) -> void:
	if i >= 0 and i < pots.size() and (phase == Phase.READY or phase == Phase.PLAY):
		picked = i

func aim(p: Vector2) -> void:
	tip = p.clamp(Vector2.ONE * CELL * 0.5, Vector2.ONE * (Mould.SIDE - CELL * 0.5))

func squeeze(on: bool) -> void:
	if not on or phase == Phase.READY or phase == Phase.PLAY:
		squeezing = on

## The grey button: syrup drawn back out of the chunk under the tip for
## as long as it is held.
func drain(on: bool) -> void:
	if not on or phase == Phase.READY or phase == Phase.PLAY:
		draining = on

## Syrup into (or, under zero, out of) a chunk's tally.
func _tally(c: int, amount: float) -> void:
	if c < 0 or c >= tank.size():
		return
	tank[c] = maxf(0.0, tank[c] + amount)
	poured = 0.0
	for v in tank:
		poured = maxf(poured, v)

## What the fluid's meter read in a chunk, in amounts: the truth over this
## sim's reckoning.
func learn(c: int, amount: float) -> void:
	if c < 0 or c >= tank.size():
		return
	tank[c] = maxf(0.0, amount)
	poured = 0.0
	for v in tank:
		poured = maxf(poured, v)

## Whether anything is in the mould: some chunk holds more than a trace.
func wet() -> bool:
	return poured > WET

func can_serve() -> bool:
	return phase == Phase.PLAY and wet()

func serve() -> void:
	if not can_serve():
		return
	squeezing = false
	draining = false
	serves += 1
	phase = Phase.SETTLE
	phase_t = 0.0
	_asked = false
	events.append({"type": "serve"})

# --- a step ---

func step() -> void:
	phase_t += DT
	match phase:
		Phase.READY, Phase.PLAY:
			var c := tip_cell()
			if squeezing and c >= 0:
				if phase == Phase.READY:
					phase = Phase.PLAY
					phase_t = 0.0
					events.append({"type": "go"})
				_tally(c, RATE * DT)
			elif draining and c >= 0:
				_tally(c, -RATE * DT)
			if phase == Phase.PLAY:
				t += DT
		Phase.SETTLE:
			if phase_t >= SETTLE_T and not _asked:
				_asked = true
				events.append({"type": "judge"})
		Phase.SHOW:
			if phase_t >= SHOW_T:
				_after()

## The answer to a `judge` event: each cell's match, 0 to 1, as the fluid
## measured it. The verdict follows; the day's last mould passed is the
## day done, there and then.
func judge(near: PackedFloat32Array, all: float) -> void:
	if phase != Phase.SETTLE:
		return
	for c in mini(near.size(), cell_match.size()):
		cell_match[c] = near[c]
	match_all = clampf(all, 0.0, 1.0)
	var pct := int(round(match_all * 100.0))
	var passed := pct >= mark()
	var perfect := pct >= PERFECT
	verdict = {"pct": pct, "need": mark(), "pass": passed, "perfect": perfect}
	phase = Phase.SHOW
	phase_t = 0.0
	events.append({"type": "served", "pct": pct, "need": mark(), "pass": passed, "perfect": perfect})
	if passed:
		marks.append(pct)
		if index >= moulds.size() - 1:
			phase = Phase.DONE
			events.append({"type": "done"})

func _after() -> void:
	if bool(verdict.get("pass", false)):
		index += 1
		deal(moulds[index])
		phase = Phase.PLAY
		phase_t = 0.0
	else:
		_lay()
		phase = Phase.PLAY
		phase_t = 0.0
		events.append({"type": "again"})

## A finished day put back: its last mould on the tray, filled as the card
## has it, and the numbers it was served at.
func finish(pcts: Array) -> void:
	index = moulds.size() - 1
	deal(moulds[index])
	for c in mould.want.size():
		filled(c, int(mould.want[c]), 1.0)
	marks = pcts.duplicate()
	var last := int(pcts[-1]) if not pcts.is_empty() else 100
	verdict = {"pct": last, "need": mark(), "pass": true, "perfect": last >= PERFECT}
	phase = Phase.DONE
	phase_t = SHOW_T
