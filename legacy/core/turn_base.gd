extends "res://legacy/core/stage_view.gd"

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
## Put a committed guess back on the board, for a day already played. The
## inverse of guess(); a turn whose guess() is null need not implement it.
func apply_guess(_the_guess) -> void: pass
## 0 to 100. Never negative, never a fail.
func grade(_answer) -> int: return 0
## The camera move and the comparison. Runs once, on lock, and again with
## `animate` false when a day already played is reopened (see restore()). A
## subclass whose reveal tweens or moves the camera may be a coroutine -- the
## grade waits for it -- but it must honour `animate == false` by jumping
## straight to the end state, because that path is not a reveal: the result
## panel is already on screen and nothing is waiting for the show.
func reveal(_animate := true) -> void: pass
## One line under the score, in the turn's own words: what the answer was
## and how the guess stood to it. Read after `graded` and on restore; empty
## means the host shows nothing there.
func result_text() -> String: return ""
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
	# The base reveal returns nothing, but a subclass's may be a coroutine --
	# a camera move, a tween -- and the score must not pop while it is still
	# travelling. Awaiting a plain return resolves in place, so this costs
	# the stub nothing; the warning is silenced here and nowhere else.
	@warning_ignore("redundant_await")
	await reveal()
	state = State.REVEALED
	revealed.emit()
	score = clampi(grade(content.get("answer")), 0, 100)
	graded.emit(score)

## Puts a turn straight into its revealed state, for a day already played.
## `guess` is what the player committed, so the board can be rebuilt as they
## left it rather than at whatever the subclass defaults to.
func restore(the_content: Dictionary, the_score: int, the_guess = null) -> void:
	content = the_content
	build_turn(content)
	if the_guess != null:
		apply_guess(the_guess)
	state = State.REVEALED
	score = clampi(the_score, 0, 100)
	reveal(false)
