extends "res://core/puzzle_base.gd"

## Gumdrop as a daily board (spec
## docs/superpowers/specs/2026-10-11-gumdrop-daily-design.md): a band's few
## moulds of clear jelly, each tinted with a needle of syrup to match
## its card and served. It was the eleventh Arcade game for a day; the
## user, 2026-10-11: "convert gumdrop into a daily game not arcade".
##
## **The table is the whole screen** (`"bleed": true` in ui/registry.gd):
## the flat host lays this board full rect under its rows and says what
## they cover (`set_clear`). The table is puzzles/gumdrop_table.gd, which
## draws, takes the fingers and drives the fluid; the day is
## puzzles/gumdrop_sim.gd's. This is what a daily needs between them: the
## band's deal off the day's seed, the solve, the serves Insane counts and
## the card when they run out, the finished day put back, the tutorial.
##
## A serve is the one move there is, so it is what the win's line counts.
## Easy to Hard cannot be lost: a mould under its mark is emptied and
## poured again. Insane (Three Pots) has the moulds and one more serve.

signal leave

const Sim = preload("res://puzzles/gumdrop_sim.gd")
const Mould = preload("res://puzzles/gumdrop_mould.gd")
const Table = preload("res://puzzles/gumdrop_table.gd")
const Motion = preload("res://core/motion.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const MovesDiagram = preload("res://ui/hud/moves_tutorial_diagram.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
## The serves the out-of-moves card's video buys, once a board.
const MOVES_BONUS := 2
## The gold boosters Gumdrop had on the Arcade tab, and what one cost: held
## ones come back as gold when the board opens (core/wallet.gd).
const OLD := ["gd_full", "gd_tall", "gd_soft", "gd_kind"]
const OLD_PRICE := 120
## Seconds from the last flop's number to the card.
const CARD_AFTER := 0.5
## The tray is on its way to the middle while the host's slots slide.
const WIN_HOLD := 0.9

var sim: RefCounted
var table: Control
var band := 0
## The serves a counted band starts with (0: not counted), and the name
## the host and the card read for "the day ran out".
var max_moves := 0
var out_of_hearts := false
var _heart_used := false
var _heart_card: Control
## What the host's rows cover, kept for a table built after it was said.
var _clear := Vector2.ZERO
var _restored := false

func puzzle_id() -> String: return "gumdrop"
func title() -> String: return "Gumdrop"

func rules() -> String:
	var out := tr("GD_RULES") % [sim.moulds.size(), sim.mark()]
	if band >= 2:
		out += "\n\n" + tr("GD_RULES_MIX")
	if max_moves > 0:
		out += "\n\n" + tr("GD_RULES_SERVES") % max_moves
	return out

## Syrup squeezed in cannot be taken out and the match is hidden until the
## mould is served: no Undo, no bulb, no Check.
func capabilities() -> Array[String]:
	return []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_table()
	# the boosters of its Arcade days come back as gold
	var back := 0
	var wallet := get_node_or_null("/root/Wallet")
	if wallet != null:
		for id: String in OLD:
			back += int(wallet.refund(id, OLD_PRICE))
	if back > 0:
		table.told_refund(back)

func _ensure_table() -> void:
	if table != null:
		return
	table = Table.new()
	table.name = "Table"
	table.happened.connect(_on_event)
	add_child(table)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_ensure_table()
	band = clampi(difficulty, 0, Mould.BANDS.size() - 1)
	sim = Sim.new()
	sim.deal_day(band, rng)
	max_moves = sim.budget
	out_of_hearts = false
	_heart_used = false
	_restored = false
	_close_card()
	table.lay(sim)
	table.set_clear(_clear.x, _clear.y)
	table.greet()

## The day as dealt, for tools/export_days.gd (PuzzleBase.day_dict): the
## day's jellies, the flavour each chunk is wanted in and the pots stood by
## the tray. The answer is the pot, or the two pots half and half, a chunk
## is filled from.
func day_dict() -> Dictionary:
	if sim == null or sim.moulds.is_empty():
		return {}
	var names: Array = Mould.Flavour.keys()
	var moulds: Array = []
	var fills: Array = []
	var cells := 0
	var least := 1 << 30
	var most := 0
	var mixes := 0
	var used := {}
	for m: Dictionary in sim.moulds:
		var want: Array = []
		var fill: Array = []
		for f: int in m.want:
			used[f] = true
			want.append(String(names[f]).to_lower())
			var from: Array = []
			for pot: int in Mould.recipe(f, m.pots):
				from.append(String(names[pot]).to_lower())
			if from.size() > 1:
				mixes += 1
			fill.append(" + ".join(from))
		var pots: Array = []
		for pot: int in m.pots:
			pots.append(String(names[pot]).to_lower())
		var n: int = (m.cells as Array).size()
		cells += n
		least = mini(least, n)
		most = maxi(most, n)
		moulds.append({"picture": String(m.id), "pieces": int(m.pieces), "cells": n, "want": want, "pots": pots,
			"mixed": String(names[int(m.mixed)]).to_lower() if int(m.mixed) >= 0 else ""})
		fills.append({"picture": String(m.id), "fill": fill})
	return {
		"source": "generator", "kind": "text",
		"payload": {"moulds": moulds, "mark": sim.mark(), "serves": sim.budget},
		"solution": {"moulds": fills},
		"metrics": {"moulds": moulds.size(), "mark": sim.mark(), "perfect": Sim.PERFECT, "cells": cells,
			"cells_min": least, "cells_max": most, "flavours": used.size(), "mixed_cells": mixes,
			"serves": sim.budget},
	}

## The host's rows over this board (ui/flat/flat_host.gd, a `bleed`
## board): what they cover at the top and the foot, and on the win the
## span the win screen leaves.
func set_clear(top: float, bottom: float, won := false) -> void:
	_clear = Vector2(top, bottom)
	if table != null:
		table.set_clear(top, bottom, won, _restored)

# --- the day ---

func _on_event(ev: Dictionary) -> void:
	match String(ev.type):
		"serve":
			moves += 1
			moved.emit()
		"done":
			check_solved()
		"over":
			_run_out()

func is_solved() -> bool:
	return sim != null and sim.is_done()

## The win's line is the day's numbers in the order they were served, under
## three gumdrops (`Jelly`): no mascot, the pieces are marks.
func flat_win() -> Dictionary:
	var parts: Array = []
	for m: int in sim.marks:
		parts.append("%d%%" % m)
	var row: Array = []
	for k in 3:
		row.append(Jelly.new(k))
	return {"faces": row, "subtitle": tr("GD_WIN_SUB") % " · ".join(parts)}

## The win screen waits for the last mould's number.
func win_delay() -> float:
	return 0.0 if Motion.reduce else WIN_HOLD

## Easy to Hard: the mould on the tray, clear again, and the serves made
## so far today still counted (they were made). Insane: the day from its
## first mould with every serve back, since an emptied mould there would be
## a flop taken back for nothing.
func reset_board() -> void:
	if is_done() or out_of_hearts or sim == null:
		return
	if max_moves > 0:
		sim.restart()
		moves = 0
	else:
		sim.empty()

func completion_record() -> Dictionary:
	return {"pct": sim.marks.duplicate()}

## The fluid cannot be saved, so a finished day is its last mould filled
## as the card has it, with the numbers the day was served at.
func restore_completed_board() -> void:
	var pcts = completed_record.get("pct", [])
	sim.finish(pcts if pcts is Array else [])
	_restored = true
	table.lay(sim)
	table.set_clear(_clear.x, _clear.y)

# --- Insane's serves ---

func _run_out() -> void:
	if out_of_hearts or is_done():
		return
	out_of_hearts = true
	_running = false
	table.held = true
	table.cue("game_over", Haptics.BAD)
	moved.emit()
	get_tree().create_timer(CARD_AFTER).timeout.connect(_open_card)

## The card, over the whole screen: on the host so it covers the chrome, or
## on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card) or not is_inside_tree():
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["GD_OUT_BODY", "GD_OUT_REST"], MOVES_BONUS,
		{"title": "GD_OUT_TITLE", "more": "GD_OUT_MORE"})
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the day from its first mould, every serve back, the clock
## from zero.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	moves = 0
	elapsed = 0.0
	out_of_hearts = false
	_running = true
	table.held = false
	sim.restart()
	moved.emit()

## A couple more serves (the card's video), once a board: the mould that
## ended the day is clear again.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	out_of_hearts = false
	_running = true
	table.held = false
	sim.revive(MOVES_BONUS)
	table.cue("good", Haptics.GOOD)
	moved.emit()

func _leave() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- the tutorial ---

## Each page is the table itself, small, played by a written hand
## (ui/hud/gumdrop_tutorial_diagram.gd). Loaded, not preloaded: the page's
## bench extends the table.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/gumdrop_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.FILL, "TUT_GUMDROP_FILL", tr("TUT_GUMDROP_FILL_BODY")],
		[Diagram.Lesson.SOAK, "TUT_GUMDROP_SOAK", tr("TUT_GUMDROP_SOAK_BODY")],
		[Diagram.Lesson.MATCH, "TUT_GUMDROP_MATCH", tr("TUT_GUMDROP_MATCH_BODY") % sim.mark()],
		[Diagram.Lesson.MIX, "TUT_GUMDROP_MIX", tr("TUT_GUMDROP_MIX_BODY")],
		[Diagram.Lesson.HUD, "TUT_GUMDROP_HUD", tr("TUT_GUMDROP_HUD_BODY")],
	]
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	if max_moves > 0:
		# the shared page's pill, with this board's own rule under it: the day
		# is lost with fewer serves than moulds, not at none
		var count: Control = MovesDiagram.new()
		count.moves = max_moves
		count._pill.keys = Table.SERVES
		pages.append({"diagram": count, "title": "TUT_GUMDROP_SERVES", "body": tr("GD_RULES_SERVES") % max_moves})
	return pages

# --- the win's row ---

## One gumdrop of the win screen's row (ui/flat/well_done.gd seats it as it
## seats a board's faces): a dome of jelly in a pigment's colour with its
## shadow and its shine, baked once a size and shaken under a transform as
## a jelly is. It has no face, so `expression` is taken and not used.
class Jelly extends Control:
	const FLAVOURS := [0, 2, 4]

	var expression := 0
	var _k := 0
	var _idle := false
	var _clock := 0.0
	var _mesh: ArrayMesh
	var _mesh_of := Vector2.ZERO

	func _init(k: int) -> void:
		_k = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func set_idle(on: bool) -> void:
		_idle = on
		set_process(on and not Motion.reduce)
		queue_redraw()

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0:
			return
		if _mesh == null or _mesh_of != size:
			_mesh_of = size
			# the middle one stands a little taller
			var rx := size.x * (0.4 if _k == 1 else 0.36)
			var ry := size.y * (0.72 if _k == 1 else 0.62)
			var col: Color = Sim.FLAVOURS[FLAVOURS[_k]]
			var b := Face.Builder.new()
			b.ellipse(Vector2(4.0, 2.0), rx * 1.05, size.y * 0.07, Color(0.25, 0.14, 0.06, 0.2))
			var dome := Face.Builder.arc_points(Vector2.ZERO, 1.0, PI, TAU)
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for p: Vector2 in dome:
				outer.append(Vector2(p.x * rx, p.y * ry))
				inner.append(Vector2(p.x * rx * 0.86 - rx * 0.06, p.y * ry * 0.9 - 3.0))
			b.polygon(outer, col.darkened(0.12))
			b.polygon(inner, col)
			b.ellipse(Vector2(-rx * 0.36, -ry * 0.62), rx * 0.16, ry * 0.12, Color(1, 1, 1, 0.55))
			_mesh = b.mesh()
		var w := 0.05 * sin(_clock * 5.0 + _k * 1.7) if _idle and not Motion.reduce else 0.0
		var foot := Vector2(size.x * 0.5, size.y * 0.86)
		draw_mesh(_mesh, null, Transform2D(0.0, Vector2(1.0 + w, 1.0 - w), 0.0, foot))
