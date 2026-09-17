extends StageView

## One committed input a day, an immediate reveal, and a graded result.
## Never a pass or a fail: a bad day still produces a number and a picture
## worth posting.
##
## Deliberately not a PuzzleBase. A turn has no moves, no hints, no checks
## and nothing to undo, and inheriting that vocabulary would hand the
## mismatch to every game built on this.
## Spec: docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md,
## section 2.2.

signal locked
signal revealed
signal graded(score: int)
## The player changed what they are about to commit; the host re-reads.
signal input_changed

enum State { INPUT, LOCKED, REVEALED }

var state: int = State.INPUT
var elapsed: float = 0.0
## -1 until the turn has been graded.
var score: int = -1
var content: Dictionary = {}

# --- to override ---
func turn_id() -> String: return "unnamed"
func title() -> String: return "Untitled"
func motto() -> String: return ""
func footer() -> String: return ""
## The day's question, already localised by the subclass.
func prompt_text() -> String: return ""
## Stand the scene from the day's content. Called once, before the first frame.
func build_turn(_content: Dictionary) -> void: pass
## Whether the player has committed enough for Lock to light up.
func has_input() -> bool: return false
## What the player committed, as it goes to the server.
func guess() -> Variant: return null
## 0 to 100. Never negative, never a fail.
func grade(_answer) -> int: return 0
## The camera move and the comparison. Runs once, on lock.
func reveal() -> void: pass
func share_text() -> String: return ""
func share_glyphs() -> String: return ""
# -------------------

func _ready() -> void:
	stage_enter("%s_turn" % turn_id())

func _exit_tree() -> void:
	stage_exit()

## A turn stops taking input the instant it is locked.
func accepts_input() -> bool:
	return state == State.INPUT

func is_done() -> bool:
	return state != State.INPUT

## Stands the turn up from the day's content.
func start_turn(the_content: Dictionary) -> void:
	content = the_content
	state = State.INPUT
	elapsed = 0.0
	score = -1
	build_turn(content)
	set_process(true)

func _process(delta: float) -> void:
	if state == State.INPUT:
		elapsed += delta

## One way, once. There is no undo on a turn.
func lock() -> void:
	if state != State.INPUT:
		return
	state = State.LOCKED
	locked.emit()
	reveal()
	state = State.REVEALED
	revealed.emit()
	score = clampi(grade(content.get("answer")), 0, 100)
	graded.emit(score)

## Puts a turn straight into its revealed state, for a day already played.
func restore(the_content: Dictionary, the_score: int) -> void:
	content = the_content
	build_turn(content)
	state = State.REVEALED
	score = clampi(the_score, 0, 100)
	reveal()
