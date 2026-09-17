extends "res://core/puzzle_base.gd"

## A PuzzleBase whose board lives in the 3D stage. Everything that mounts the
## board, frames the camera on it and turns touches into board-plane hits now
## lives in core/stage_view.gd, which PuzzleBase extends; all that is left
## here is what a *puzzle* answers differently. Subclasses build into `board`
## and override the on_board_* hooks exactly as before.

func is_3d() -> bool: return true

## A finished board takes no more taps.
func accepts_input() -> bool: return not is_done()

func _ready() -> void:
	stage_enter("%s_board" % puzzle_id())

func _exit_tree() -> void:
	stage_exit()
