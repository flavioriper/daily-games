class_name PuzzleBase
extends Control

## Every prototype implements this. The menu only ever talks to this interface,
## so adding a puzzle costs one file and one menu entry.
##
## A plain Control. Until 2026-09-18 this extended StageView, so every flat
## board inherited stage mounting, camera fitting and board-plane ray picking
## it never called -- and the 2D game could not be built without the 3D one.
## The stage machinery went to legacy/ with the boards that use it
## (legacy/core/stage_board.gd); nothing here knows the stage exists.

signal solved
signal moved
## A board that tracks a focused cell emits this when the focus moves or clears.
signal focus_changed
## A board that can run out ends without a solve. Hidden Word is the only one
## (spec 2026-09-19-hidden-word-flat-design.md, section 8): six wrong rows and
## the word is revealed. The clock stops and the chrome greys exactly as a
## solve does, but `solved` never fires, so the host raises no win screen.
signal ended

var moves: int = 0
var elapsed: float = 0.0
var hints_used: int = 0
var checks: int = 0
var _running: bool = false
var _done: bool = false

# --- to override ---
func puzzle_id() -> String: return "unnamed"
func title() -> String: return "Untitled"
func rules() -> String: return ""
func build(_rng: RandomNumberGenerator, _difficulty: int) -> void: pass
func is_solved() -> bool: return false
func share_glyphs() -> String: return ""
func reset_board() -> void: pass
func is_3d() -> bool: return false

# --- optional, for the HUD (docs/superpowers/specs/2026-09-14-binairo-hud-design.md,
# section 3). Defaults mean "unsupported"; the HUD hides what a puzzle lacks. ---
## Which optional actions this puzzle supports: any of "undo", "hint", "check", "lines", "palette", "pieces", "view", "status".
func capabilities() -> Array[String]: return []
func can_undo() -> bool: return false
## Reverts the last move. True when something was undone.
func undo() -> bool: return false
func hints_left() -> int: return 0
## Fills one cell from the solution. True when a cell was filled.
func hint() -> bool: return false
## Marks the cells that differ from the solution. Returns how many; -1 when unsupported.
func check() -> int: return -1
## What the Check button says for this puzzle; a board that ends on that press
## calls it Submit.
func check_label() -> String: return "Check"
## {} when nothing is focused, else {"row": {"index": r, "cells": [...]},
## "col": {"index": c, "cells": [...]}} with cells -1 empty, 0 sun, 1 moon.
func line_state() -> Dictionary: return {}
## The colour tray's entries in order, [] when unsupported:
## {"colour": Color, "mark": int (1..7, the pip count), "enabled": bool}.
func palette() -> Array[Dictionary]: return []
## The piece tray's entries in order, [] when unsupported: {"kind": String
## (an icon name in ui/icons.gd), "count": int, "selected": bool,
## "enabled": bool}.
func pieces() -> Array[Dictionary]: return []
## The player chose tray entry `i`. True when a peg was placed.
func pick(_i: int) -> bool: return false
## The player asked for a quarter turn of the board. Boards that show a solid
## ("view") do it; a flat board has nothing to turn.
func turn_view() -> void: pass
## The player is holding the peek button, or has just let it go: fade whatever
## the near scenery hides while it is held.
func peek(_on: bool) -> void: pass
## One line of running counts for the status card ("status"), "" when unsupported.
func status_text() -> String: return ""
# -------------------

func start(rng: RandomNumberGenerator, difficulty: int) -> void:
	moves = 0
	elapsed = 0.0
	hints_used = 0
	checks = 0
	_done = false
	build(rng, difficulty)
	_running = true
	set_process(true)

func _process(delta: float) -> void:
	if _running and not _done:
		elapsed += delta

func note_move() -> void:
	moves += 1
	moved.emit()
	check_solved()

## Ends the puzzle if the board is solved. note_move calls this; hints and
## undos call it directly because they do not count as moves.
func check_solved() -> void:
	if not _done and is_solved():
		_done = true
		_running = false
		solved.emit()

func is_done() -> bool:
	return _done

func finish_unsolved() -> void:
	if _done:
		return
	_done = true
	_running = false
	ended.emit()
