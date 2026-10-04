extends RefCounted

## Knight's rules as the board plays them, scene-free, as every flat board's
## are. The board (puzzles/knight2d.gd) draws this and nothing else.
##
## One move: hop your knight in an L. Landing on the king wins at once; land
## on a rose knight and it is taken; then the rose knights answer
## (knight_gen.gd's `step`). **A catch is never kept**: the position stays
## where it was and the board shows the catch and slides back. No band has
## hearts since 2026-10-04; Insane counts moves instead (`moves_budget`).
## Insane is Brambles: every square you hop off grows a bramble (`mask`) and
## a rose knight fenced in by them naps.
## Spec: docs/superpowers/specs/2026-09-26-knight-flat-design.md, section 6,
## and 2026-10-01-knight-polish-design.md.

const Gen = preload("res://puzzles/knight_gen.gd")
const InsaneBank = preload("res://core/insane_bank.gd")

## Per band: hints and hearts (0 = nothing can be lost). No band has hearts
## since 2026-10-04: a catch and being boxed in cost nothing of their own.
const HINTS_BY := [3, 3, 2, 0]
const HEARTS_BY := [0, 0, 0, 0]
## Insane's spare moves over the board's shortest line (`moves_budget`):
## every hop costs one, a caught one too. The spare is a quarter of the
## line, and never less than this.
const MOVES_SLACK := [0, 0, 0, 3]
## `lost()`'s search budget: a position whose proof needs more than this is
## taken to be alive (measured: a live Hard position proves in a few hundred).
const LOST_NODES := 6000

## The generated board (knight_gen.gd's dictionary), read by the board.
var g := {}
var difficulty := 0
var w := 0
var king := -1
var you := -1
## Each rose knight's square; -1 once taken; plus Gen.NAP while napping.
var foes := PackedInt32Array()
## The brambles, bit c for square c (Brambles only; 0 elsewhere).
var mask := 0
## Every position before a kept move, for Undo: {"you", "foes", "mask"}.
var history: Array[Dictionary] = []
var won := false

static func hints_for(band: int) -> int:
	return HINTS_BY[clampi(band, 0, HINTS_BY.size() - 1)]

static func hearts_for(band: int) -> int:
	return HEARTS_BY[clampi(band, 0, HEARTS_BY.size() - 1)]

## Insane reads a mined Brambles board from the bank; without one it deals
## Hard's board live.
func build(rng: RandomNumberGenerator, band: int, bank_step := 0) -> void:
	difficulty = band
	g = {}
	if band >= 3:
		g = Gen.from_bank(InsaneBank.pick("knight", bank_step))
	if g.is_empty():
		g = Gen.generate(rng, mini(band, 2))
	w = g.w
	king = g.king
	reset_board()

func size() -> int:
	return w * w

func brambles() -> bool:
	return bool(g.get("brambles", false))

func is_bramble(c: int) -> bool:
	return c >= 0 and (mask >> c) & 1 == 1

func opt() -> int:
	return int(g.get("opt", 0))

func budget() -> int:
	return int(g.get("budget", 0))

## The moves a band hands out: the shortest line (the bank's, which the
## miner proved shortest; `opt`) and its slack, or 0 on a band that does not
## count them. Not `budget()`, the old Insane's hard cap inside the state.
func moves_budget() -> int:
	var slack: int = MOVES_SLACK[clampi(difficulty, 0, MOVES_SLACK.size() - 1)]
	if slack <= 0 or opt() <= 0:
		return 0
	return opt() + maxi(slack, opt() / 4)

## Moves left under a budget, or -1 on a level with none (every level now:
## the old Insane's budget gave way to Brambles).
func moves_left() -> int:
	if budget() <= 0:
		return -1
	return maxi(0, budget() - history.size())

func legal() -> PackedInt32Array:
	return Gen.moves(g, you, mask)

## Every square an awake rose knight reaches right now: land on one and it
## takes you.
func reach() -> Dictionary:
	var out := {}
	for f in foes:
		if f >= 0 and not Gen.napping(f):
			for m in Gen.hops(w, f):
				out[m] = true
	return out

## The square a rose knight stands on (-1 once taken).
func foe_square(i: int) -> int:
	return Gen.sq(foes[i])

func napping(i: int) -> bool:
	return Gen.napping(foes[i])

## The squares you have stood on, the opening first.
func route() -> PackedInt32Array:
	var out := PackedInt32Array()
	for h: Dictionary in history:
		out.append(int(h.you))
	out.append(you)
	return out

## What a hop to `to` would do from here, kept or not: Gen.step's result.
func peek(to: int) -> Dictionary:
	var nm := mask | (1 << you) if brambles() else 0
	return Gen.step(g, you, foes, to, nm)

## Plays one hop and returns Gen.step's result, or {} when the hop is not
## legal or the budget is spent. A catch is returned but not kept.
func play(to: int) -> Dictionary:
	if won or not legal().has(to) or moves_left() == 0:
		return {}
	var nm := mask | (1 << you) if brambles() else 0
	var r := Gen.step(g, you, foes, to, nm)
	if int(r.caught) >= 0:
		return r
	history.append({"you": you, "foes": foes.duplicate(), "mask": mask})
	r["grew"] = you if brambles() else -1
	you = r.you
	foes = r.foes
	mask = nm
	won = r.won
	return r

func can_undo() -> bool:
	return not history.is_empty() and not won

func undo() -> bool:
	if not can_undo():
		return false
	var h: Dictionary = history.pop_back()
	you = h.you
	foes = h.foes
	mask = int(h.get("mask", 0))
	return true

## Back to the opening: every rose knight back, taken ones too, and every
## bramble gone.
func reset_board() -> void:
	you = g.you
	foes = (g.foes as PackedInt32Array).duplicate()
	mask = 0
	history.clear()
	won = false

## Whether every hop from here is a catch (or there is none at all): the
## position is over, whatever the search says.
func trapped() -> bool:
	if won:
		return false
	for m in legal():
		if int(peek(m).caught) < 0:
			return false
	return true

## Whether no line reaches the king from here. A search that runs past
## LOST_NODES says no: a position is only called lost when proved so.
func lost() -> bool:
	if won:
		return false
	if trapped():
		return true
	var cap := moves_left() if moves_left() > 0 else 64
	var line := Gen.solve(g, you, foes, cap, LOST_NODES, mask)
	return line.is_empty() and Gen.last_nodes < LOST_NODES

## The next hop of the shortest line from here, or -1 when there is none
## (or, under a budget, none inside the moves left).
func hint_move() -> int:
	if won or moves_left() == 0:
		return -1
	var cap := moves_left() if moves_left() > 0 else 64
	var line := Gen.solve(g, you, foes, cap, 0, mask)
	return -1 if line.is_empty() else line[0]

## A lost position -- no line from here -- undone back to the most recent one
## in history that still has a line. Returns how many moves it undid: 0 when
## the position already has a line or when none behind it does (which the
## opening always has).
func rewind_to_live() -> int:
	if won or hint_move() >= 0:
		return 0
	for j in range(history.size() - 1, -1, -1):
		var h: Dictionary = history[j]
		if _has_line(int(h.you), h.foes, int(h.get("mask", 0)), j):
			var n := history.size() - j
			while history.size() > j:
				undo()
			return n
	return 0

## Whether the position after `kept` kept moves has a line within its budget.
func _has_line(at: int, fs: PackedInt32Array, mk: int, kept: int) -> bool:
	var cap := 64
	if budget() > 0:
		cap = budget() - kept
		if cap <= 0:
			return false
	return not Gen.solve(g, at, fs, cap, 0, mk).is_empty()

func is_solved() -> bool:
	return won
