class_name PuzzleBase
extends Control

## Every prototype implements this. The menu only ever talks to this interface,
## so adding a puzzle costs one file and one menu entry.

signal solved
signal moved

var moves: int = 0
var elapsed: float = 0.0
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
# -------------------

func start(rng: RandomNumberGenerator, difficulty: int) -> void:
	moves = 0
	elapsed = 0.0
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
	if not _done and is_solved():
		_done = true
		_running = false
		solved.emit()

func is_done() -> bool:
	return _done
