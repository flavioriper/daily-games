extends "res://core/puzzle_base.gd"

## Sudoku, flat: nine by nine in nine regions, every number once in every row,
## column and region. The rules are in puzzles/sudoku_state.gd and this file
## draws them.
##
## **The whole of the design is in what a 100-pixel cell can be made to say**,
## because nobody needs the rules explained. Two things do the saying: the
## selection's washes (section 10 of the spec -- peers pale, twins stronger,
## clashes warm, the last Check warmer still, all derived every frame and
## none of them stored) and the wave when a unit comes right (section 11,
## this board's signature).
##
## **Drawn, not nodes.** Eighty-one cells, their washes, their rules, their
## digits and up to nine marks each is far too much to make Controls out of;
## gl_compatibility pays per draw command. The cells, the washes and the
## rules are one ArrayMesh, rebuilt while something moves the way Nonogram's
## floor and Queens' ground are, and every numeral goes over it through one
## draw_set_transform -- Nonogram's precedent for drawn text on the flat
## boards' vocabulary. The mesh the last _draw handed over is kept in
## `_shown` until the next replaces it: a canvas command holds a mesh by RID
## and not by reference, so dropping the previous one leaves the renderer
## drawing a freed RID on any frame rendered without the queued redraw
## flushed -- exactly what a harness's force_draw() does, and six boards have
## already paid for it.
##
## Every move -- a chip, a hint, an undo, Reset -- goes through one `_apply`
## or one `_settle`, so the wave is diffed in exactly one place: a snapshot
## of which units were finished before the move against which are finished
## after it. That is Queens' shape with a unit in place of a queen's sight.
## Spec: docs/superpowers/specs/2026-09-20-sudoku-flat-design.md.
## Concept page: docs/brainstorm/concepts.html#sudoku.
##
## **The polish of 2026-09-30** (spec 2026-09-30-sudoku-polish-design.md).
## Hard and Insane can be failed: every number is judged as it lands, and a
## wrong one blushes, costs a heart and tumbles off the paper, and that number
## is crossed out of that cell for good (`state.ruled`). Insane is
## **Hilltops**: a little hill in some cells counts, in dots, how many of the
## four cells beside it hold a smaller number, and there are fewer givens than
## any plain grid can have. A right number builds a streak (a tick a
## semitone higher, the x3 bubble, confetti), now and then plays a gag (hearts, a
## twirl, a boing), a finished region gets a daisy sticker, a number all nine
## of which are home hops in a wave, and the solve throws a party: the
## numbers dance, confetti, a silly bit of number wisdom and the seal.
##
## **Insane counts moves** (2026-10-04, docs/agents/flat-screens.md): no band
## is judged now (Hard's hearts went on 2026-10-03), so the hearts' code below
## never runs. Hilltops hands out its empty cells + 3 moves; a number written
## or taken out costs one, a pencil mark nothing, and there is no Undo, hint
## or Check there.

const State = preload("res://puzzles/sudoku_state.gd")
const Gen = preload("res://puzzles/sudoku_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Seal = preload("res://ui/flat/seal.gd")
const RunMesh = preload("res://ui/flat/run_mesh.gd")
const Haptics = preload("res://core/haptics.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
const MovesPill = preload("res://ui/flat/moves_pill.gd")
const MovesDiagram = preload("res://ui/hud/moves_tutorial_diagram.gd")
## The moves the out-of-moves card's video buys, once a board.
const MOVES_BONUS := 5

## The out-of-hearts card's Back to camp.
signal leave

## The grid is nine cells of 100 -- 900 -- and not the 104.9 the card's 28
## inset would allow, because the heavy rule is drawn ROUND the grid and the
## 22 of hem either side is what it stands in. PAD is those two together, so
## the board asks the slot for 900 + 100 and gets exactly the 1000 the host
## hands it on the phone; on a narrower screen the cell shrinks under the
## nominal 100 rather than the rule running off the card.
const CELL := 100.0
## The grid's nominal side, whatever its size: nine cells of 100 on hard,
## six of 150 on the mini. Everything drawn is written against CELL, so the
## mini's numerals and rules come out half as big again with its cells.
const GRID := 900.0
const HEM := 22.0
const CARD_INSET := 28.0
const PAD := HEM + CARD_INSET
const THIN_W := 2.0
const THIN_ALPHA := 0.8
## The tray's corner radius, less half its FRAME.
const CORNER := 14.0
## The selected cell's gold edge: inset from the cell's own square so the
## rule beside it still reads, and rounded to match the frame.
const EDGE_W := 5.0
const EDGE_INSET := 2.0
const EDGE_RADIUS := 10.0
const DIGIT_SIZE := 64.0
const NOTE_SIZE := 26.0
## Where a pencil mark sits in its cell: a third either way from the centre.
const NOTE_STEP := 0.28
## The hint's ring, in cells: it starts just outside the digit.
const RING_R := 0.4

## The washes, by what they mean (spec section 10). All derived; none stored.
const WASH_SELECTED := 0.34
const WASH_PEER := 0.08
const WASH_CLASH := 0.18
const WASH_WRONG := 0.22
## The gold a cell reaches at the peak of the wave. A wash like the five
## above and not a timing: it is one of the wave's own three, with the two
## below.
const WASH_FLASH := 0.55

## This board's own three: WASH_FLASH above is the gold's peak alpha,
## WAVE_FLASH below is how long the wave holds a cell at that peak, and
## WIN_WAIT is the win wait. The wave's step, Motion.WAVE_STEP, moved to
## core/motion.gd on 2026-09-20 when Sudoku became the second board to read
## it, alongside Queens; everything else here is a recipe or a constant in
## core/motion.gd, read as a curve (rule 8 of docs/art/flat-motion.md).
const WAVE_FLASH := 0.5
const WIN_WAIT := 1.4

# --- the polish (2026-09-25; the spec's section 16) ---
## The grid is a wooden tray and each region a paper panel laid in it: the
## heavy rule is the tray's own floor showing in the GUTTER between panels,
## not a stroke drawn over the paper; 8 where the rule was 6, because a groove
## reads narrower than an ink line of the same width. The
## tray's face runs FRAME of a 100 cell round the grid over a WOOD_DEEP lip
## TRAY_LIP deep; its floor is the tray's wood FLOOR_DARKEN darker, so the
## gutters read as grooves; a panel stands PANEL_LIP proud of it.
const GUTTER := 8.0
const FRAME := 15.0
const TRAY_LIP := 4.0
const FLOOR_DARKEN := 0.22
const PANEL_R := 7.0
const PANEL_LIP := 2.0
const PANEL_TONE := 0.012
const TRAY_SHINE := 0.35
## A cell's wash is a rounded square WASH_INSET in from the cell, so a lit
## row reads as tiles catching the light rather than a spreadsheet fill.
const WASH_INSET := 3.0
const WASH_R := 9.0
## The selected cell is a paper tile lifted SEL_LIFT off its panel over a soft
## shadow, rimmed in the sun; its digit rises with it.
const SEL_LIFT := 6.0
const SEL_SHADOW_A := 0.22
## A twin is a sun coin under the digit, TWIN_R of a cell, and not a square:
## the eye is scanning for digits, so the mark sits on the digit.
const TWIN_R := 0.36
const WASH_TWIN_COIN := 0.3
## A written digit lands: its shadow gathers under it as it falls, it squashes
## SQUASH on touching down (LAND_AT into the drop, where back_out first
## reaches the rest) over SQUASH_TIME, and a ring of its own ink RIPPLE_A
## strong spreads from RIPPLE_FROM to RIPPLE_TO of a cell over RIPPLE_TIME.
const LAND_AT := 0.37 * Motion.DROP_TIME
const SQUASH := 0.14
const SQUASH_TIME := 0.16
const RIPPLE_TIME := 0.4
const RIPPLE_FROM := 0.24
const RIPPLE_TO := 0.47
const RIPPLE_A := 0.45
const FALL_SHADOW_A := 0.16
## The givens drop ENTER_DROP in with their region as they fade in.
const ENTER_DROP := 14.0
## The wave hops each digit it reaches, WAVE_HOP at a 100 cell.
const WAVE_HOP := -9.0
## On the win the tray warms toward SUN_RAY by WIN_GLOW and stays warm, and a
## glint GLINT_TIME long runs once round it, clockwise from the top left.
const WIN_GLOW := 0.4
const GLOW_TIME := 0.35
const GLINT_TIME := 1.1
const GLINT_LEN := 110.0
const GLINT_A := 1.0

## How long a refusal holds the tip card before the cycling rules resume.
const SAY_HOLD := 2.2
const TIP_CYCLE := 10.0
## Translation keys (locale/ui.csv). A "%d" in a line is the grid's size,
## filled in by _tip() after tr().
const TIPS := ["SD_TIP_UNITS", "SD_TIP_TAP", "SD_TIP_CROSS", "SD_TIP_PALE"]

# --- the polish of 2026-09-30 (spec 2026-09-30-sudoku-polish-design.md) ---
## The hearts, on the family's paper pill in a strip over the tray (Queens').
const HEART_ROW := 64.0
const HEART_R := 21.0
const HEART_GAP := 12.0
const HEART_PILL_PAD := Vector2(18.0, 8.0)
const HEART_PILL_RIM := 2.0
const SPLIT_TIME := 0.7
const SPLIT_FALL := 56.0
const SPLIT_SPREAD := 14.0
const SPLIT_TURN := 0.7
const HEART_BACK_TIME := 0.3
## A wrong number stands blushing EJECT_AFTER, then tumbles off the paper:
## down TUMBLE_FALL of a cell, turning TUMBLE_TURN, fading, over TUMBLE_TIME.
const EJECT_AFTER := 0.7
const TUMBLE_TIME := 0.6
const TUMBLE_FALL := 0.55
const TUMBLE_TURN := 1.3
## A number a heart ruled out of a cell: small, crossed, in rose.
const RULED_A := 0.6
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
## The streak (Mushroom Patch's): a tick a semitone higher from the second,
## five in all, the bubble from the third, confetti at five and ten.
const COMBO_FROM := 3
const COMBO_STEPS := [-2, -1, 0, 1, 2, 3]
const COMBO_DB := -4.0
const COMBO_CONFETTI := [5, 10]
const COMBO_DEFLATE := 0.25
## The bubble shows its number this long, then deflates on its own; the
## streak itself runs on, and the next right move pops it back in.
const COMBO_HOLD := 1.2
const COMBO_FONT := 44
## Three right numbers in five play a gag, picked by the cell's hash.
const GAG_ODDS := 5
const GAGS := 3
const LOVE_HEARTS := 4
const LOVE_TIME := 1.3
const LOVE_RISE := 0.7
const LOVE_R := 0.14
const TWIRL_TIME := 0.55
const BOING_HOPS := 3
const BOING_TIME := 0.6
const BOING_H := -18.0
## Every cell of a number all N of which are home hops, a step apart.
const HOME_STEP := 0.05
const HOME_HOP := -14.0
const HOME_TIME := 0.32
## A finished region's daisy sticker, in its panel's top right corner.
const STICKER_R := 0.15
const STICKER_AT := Vector2(0.36, 0.36)
const STICKER_TIME := 0.45
const STICKER_FOLD := 0.2
## Hilltops. A hill is a mound HILL_W by HILL_H of a cell, its foot at HILL_AT
## from the cell's centre, with a dot for each lower cell beside it. The hills
## rise in along the diagonal after the grid's entrance and glow at the party.
const HILL_W := 0.42
const HILL_H := 0.23
const HILL_AT := Vector2(0.25, 0.42)
const HILL_DOT := 0.036
const HILLS_AFTER := 0.75
const HILL_STEP := 0.03
const HILL_RISE := 0.3
const HILL_GLOW := 0.6
const REACH_W := 4.0
## The party, PARTY_AT after the solve wave.
const PARTY_AT := 1.2
const PARTY_EXTRA := 1.6
const DANCE_BEATS := 4
const DANCE_BEAT := 0.22
const DANCE_TILT := 0.2
const DANCE_HOP := -7.0
const CHEERS := 12
const STAMP_AT := 0.9
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.16
const STAMP_TILT := -0.22

## The remove chip's seat in the tray, ui/flat/digit_pad.gd's REMOVE.
## Declared here rather than preloaded off the pad on purpose: the tray asks
## and the board decides, and no board in the flat family preloads its own
## tray. It took the pencil's seat on 2026-09-23 at the user's request, so
## nothing on the screen turns `_pencil` on any more; the pencil's drawing
## and state.mark stay for whenever it gets a door again.
const REMOVE_CHIP := 9

var state: State = null

var fx: Node2D
## The cell the pad will write into, and whether it writes small.
var _sel := -1
var _pencil := false
## cell -> true: what the last Check found, cleared per cell when it is
## written again. The only thing on this board that is remembered rather
## than derived, because it is a memory of a question that was asked.
var _wrong: Dictionary = {}
## `state.clashes()` as of the last grid rebuild, so the numerals drawn every
## frame read the same set the washes were built from.
var _clash: Dictionary = {}

## Every drawn moment, each the second it begins -- which may be in the
## future, since a wave hands the far cells a later one. Read off Motion's
## curve readers in _build_grid and _draw_numerals.
var _flash: Dictionary = {}    # cell -> at: the wave reaches it then
var _bump: Dictionary = {}     # cell -> at: the cell beats then
var _drop: Dictionary = {}     # cell -> at: a digit falls in then
var _shiver: Dictionary = {}   # cell -> at: a refusal shook it then

## Reset's wave: one {"i", "d", "notes", "at"} per cell the player wrote,
## still drawn where it was until its beat arrives. The state forgets the
## whole board the instant Reset is pressed -- the pad's counts, the undo
## history and `is_solved` cannot wait on an animation -- so a cell that is
## due to empty half a second from now has nothing left to bump, and the
## spec's "bumps ... and empties" would be a wave over eighty-one blanks.
## The board keeps the copy instead and draws it swelling and fading out as
## the wave reaches it: hidden_word2d.gd's `_ghosts` is the family's
## precedent for a piece outliving the state that held it.
var _leaving: Array = []

## Sparkles still owed, each {"at", "where"}. The solve's three ride the
## diagonal wave and so cannot all be fired at the move that won it;
## hidden_word2d.gd's `_fx_due` is the same queue for the same reason.
var _fx_due: Array = []

## The geometry the input and the draw both read, so neither can drift.
var _cell := 0.0
var _grid := Vector2.ZERO

var _opened := -1.0e9
## When the board was solved, for the tray's glow and glint; far past on a
## board not solved.
var _won_at := -1.0e9
var _anim_until := 0.0
var _dirty := true
var _grid_mesh: ArrayMesh
## The grid's mesh is put together by a RunMesh (the board checkup,
## 2026-10-02): the tray, its floor and the nine panels are one shape in the
## colours they were drawn in, made once a layout (and once more warmed for
## the win), and every hill at rest a shape painted by slots, copied
## natively into a run of its own; only the washes, a landing, the selected
## tile and a hill on the move are drawn live. Whole in script that build
## was 3-4 ms on every frame anything on the grid moved (Insane).
var _rm: RunMesh
## The mesh the last _draw handed the canvas item. Held so its RID stays
## alive until the next _draw has put another one on the command list.
var _shown: ArrayMesh

# --- the polish's state ---
var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
## Insane's move counter (ui/flat/moves_pill.gd): `max_moves` is 0 on a band
## that does not count. Out of moves unsolved is `out_of_hearts`, the name
## the host and the card already know.
var moves_left := 0
var max_moves := 0
var _moves_pill := MovesPill.new()
var _lost_ever := false
var _asleep := false
var _ejecting := false
var _heart_card: Control
var _split_index := -1
var _split_at := -INF
var _back_index := -1
var _back_at := -INF
var _heart_layer: Control
var _hearts_shown: ArrayMesh
var _hearts_y := 0.0
var _dusk_tw: Tween
var _bad: Dictionary = {}        # cell -> true: a wrong number waiting to tumble
var _tumbling: Array = []        # [{"i", "d", "at"}]: wrong numbers falling off
var _flawless := false
var _streak := 0
var _combo_n := 0
var _combo_cell := 0
var _combo_at := -INF
var _combo_popped := false
var _combo_out_at := -INF
var _combo_layer: Control
var _combo_shown: ArrayMesh
var _life_layer: Control
var _life_shown: Array = []
var _life_alive := false
var _love: Array = []
var _love_mesh: ArrayMesh
var _stamp_at := INF
var _seal_mesh: ArrayMesh
var _twirl: Dictionary = {}      # cell -> at: its numeral spins a turn then
var _boing: Dictionary = {}      # cell -> at: its numeral bounces then
var _home: Dictionary = {}       # cell -> at: all its number's are home, it hops then
var _sticker: Dictionary = {}    # region -> {"at", "open"}: its daisy opening or folding
var _hills_at := INF
var _glow_at := INF
var _dance_at := INF
## Bumped by every rebuild, so a callback owed to the last board does nothing.
var _gen := 0

var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer
## While a refusal or a Check owns the line, the cycle waits.
var _hold_until := 0.0

func puzzle_id() -> String: return "sudoku"
func title() -> String: return "Sudoku"

func rules() -> String:
	var n := Gen.N
	var out: String = tr("SD_RULES") % [Gen.BOX_R, Gen.BOX_C, n]
	if state != null and not state.hills.is_empty():
		out += "\n\n" + tr("SD_RULES_HILLS")
	if max_moves > 0:
		out += "\n\n" + tr("SD_RULES_MOVES") % max_moves
	elif max_hearts > 0:
		out += "\n\n" + tr("SD_RULES_HEARTS") % max_hearts
	else:
		out += "\n\n" + tr("SD_RULES_SAFE")
	return out

## The tutorial (the board checkup, 2026-10-02): one lesson a page, each
## played by a real, quietened board on this band's own grid with the pad
## beside it (ui/hud/sudoku_tutorial_diagram.gd), the pages this band needs:
## a slip and how it is taken out, the hills on Insane, Undo and the bulb
## while the band has them, and Insane's move counter (the HEARTS page is for
## a judged band, and none is since 2026-10-04).
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/sudoku_tutorial_diagram.gd")
	var band: int = state.band if state != null else 0
	var hints: int = State.HINTS_BY_BAND[band]
	var steps := [[Diagram.Lesson.PLACE, "HTP_SD_PLACE", tr("HTP_SD_PLACE_BODY") % Gen.N]]
	if max_hearts > 0:
		steps.append([Diagram.Lesson.HEARTS, "HTP_TN_HEARTS", tr("SD_RULES_HEARTS") % max_hearts])
	else:
		steps.append([Diagram.Lesson.MISTAKE, "HTP_SD_MISTAKE",
			tr("HTP_SD_MISTAKE_BODY_MOVES") if max_moves > 0 else tr("HTP_SD_MISTAKE_BODY")])
	if state != null and not state.hills.is_empty():
		steps.append([Diagram.Lesson.HILLS, "SD_HILLS_SEAL", tr("SD_RULES_HILLS")])
	if capabilities().has("undo"):
		steps.append([Diagram.Lesson.UNDO, "HTP_WT_UNDO",
			tr("HTP_SD_UNDO_BODY_JUDGED") if max_hearts > 0 else tr("HTP_SD_UNDO_BODY")])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
			tr("HTP_SD_HINT_BODY_ONE") if hints == 1 else tr("HTP_SD_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = band
		d.hearts = max_hearts
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	if max_moves > 0:
		pages.append(MovesDiagram.page(self, max_moves))
	return pages

## Insane counts moves: no Undo (taking a number out is the take-back, and
## it costs one), no hint and no Check, which would each say what is wrong.
## A judged band (none since 2026-10-04) left Check out.
func capabilities() -> Array[String]:
	if state != null and state.band >= 3:
		return []
	if max_hearts > 0:
		return ["undo", "hint"]
	return ["undo", "hint", "check"]

## The lines the tips cycle: a grid that counts moves leads with that,
## Hilltops with the hills' two, a judged grid with the hearts'.
func _tips() -> Array:
	var lead: Array = ["TIP_MOVES"] if max_moves > 0 else []
	if max_hearts > 0:
		lead.append("SD_TIP_HEARTS")
	if state != null and not state.hills.is_empty():
		return lead + ["SD_TIP_HILLS", "SD_TIP_HILLS_2"] + TIPS
	return lead + TIPS

## What the phone does under each cue (docs/agents/haptics.md). `place` is
## not mapped: it is a number written and the same number tapped back out,
## so `_apply` knocks by what the cell holds after (a tap, a tick). The
## remove chip shares Undo's cue and its tick. `line` is not mapped either:
## a row, column or region the hand finished bumps from `_apply`, but not
## under a wrong number, whose heart is that move's one knock. The streak's
## confetti is the other milestone. A cell selected, a tap refused (`locked`,
## `ruled`), the wrong number tumbling off, every one of a number home, the
## streak's notes, the daisies, the gags and the party say nothing. The seal
## thuds as it lands (`_party`).
const HAPTICS := {
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"confetti": Haptics.BUMP,
	"hint": Haptics.GOOD,
	"check_ok": Haptics.GOOD,
	"heart_back": Haptics.GOOD,
	"check": Haptics.WARN,
	"heart_lost": Haptics.BAD,
	"out_of_hearts": Haptics.LOSE,
	"solved": Haptics.WIN,
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	fx.haptics = HAPTICS
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	_heart_layer = _layer("Hearts", 1, _draw_hearts)
	_life_layer = _layer("Life", 3, _draw_life)
	_combo_layer = _layer("Combo", 4, _draw_combo)
	_rm = RunMesh.new(_make_shape)
	resized.connect(_layout)
	solved.connect(_on_solved)

## A full-rect layer over the board, drawn by `draw` (One Line's).
func _layer(nm: String, z: int, draw: Callable) -> Control:
	var layer := Control.new()
	layer.name = nm
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = z
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.draw.connect(draw)
	add_child(layer)
	return layer

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	state = State.new()
	state.setup(rng, difficulty, bank_step)
	max_hearts = int(State.HEARTS[state.band])
	max_moves = state.moves_budget()
	_heart_used = false
	_lost_ever = false
	_deal()
	_sel = -1
	_pencil = false
	_wrong = {}
	_flash = {}
	_bump = {}
	_drop = {}
	_shiver = {}
	_leaving = []
	_fx_due = []
	_won_at = -1.0e9
	_layout()
	_tip_idx = 0
	_hold_until = 0.0
	_say(_tip(0), Face.Expr.HAPPY)
	_tip_timer.start()
	_enter()

## The grid as it is dealt, and as Try again deals it back: every heart and
## every move, the day's light, nothing judged, no streak, sticker or party.
func _deal() -> void:
	hearts = max_hearts
	moves_left = max_moves
	out_of_hearts = false
	_asleep = false
	_ejecting = false
	_split_index = -1
	_back_index = -1
	_bad = {}
	_tumbling = []
	_flawless = false
	_streak = 0
	_combo_n = 0
	_combo_out_at = -INF
	_love = []
	_twirl = {}
	_boing = {}
	_home = {}
	_sticker = {}
	_glow_at = INF
	_dance_at = INF
	_stamp_at = INF
	_seal_mesh = null
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
		if layer != null:
			layer.queue_redraw()

# --- layout ---

## The grid is centred in whatever square the card gives it. The cell is the
## nominal 100 on the phone -- 900 of grid and 50 of hem either side is
## exactly the 1000 the host's arithmetic hands this slot -- and shrinks
## under it only on a screen that cannot hold that.
func _layout() -> void:
	if state == null:
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var field: float = _cell * Gen.N
	var row := _heart_row()
	_grid = Vector2((size.x - field) * 0.5, (size.y - field - row) * 0.5 + row)
	_hearts_y = _grid.y - FRAME * _scale() - TRAY_LIP - row * 0.5
	_love_mesh = null
	_seal_mesh = null
	_rm.reset()
	_redraw()
	for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
		if layer != null:
			layer.queue_redraw()

## The strip the hearts take over the tray, on a grid that has them, or
## Insane's move counter.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 or max_moves > 0 else 0.0

func _cell_for(available: float) -> float:
	return minf(GRID / float(Gen.N), minf(size.x - 2.0 * PAD, available - 2.0 * PAD - _heart_row()) / float(Gen.N))

## Everything the grid is drawn with is written against a 100 cell, so a
## smaller one scales the rules, the numerals and the marks with it.
func _scale() -> float:
	return _cell / CELL

## The board takes the whole slot: the grid is square and so is the space,
## so the slack is zero in both directions and there is nothing to centre.
## card_centred is answered anyway, because _fit_card asks.
func card_height(available: float) -> float:
	return available

func card_centred() -> bool:
	return false

## No mascot on a board of marks, as Nonogram: the win card keeps its own
## words (it had fallen back to Binairo's "Perfect balance").
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("SD_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT + PARTY_EXTRA

## Control-local point over the centre of cell (r, c). The win harness taps
## these, exactly as it does on every other flat board.
func cell_to_local(r: int, c: int) -> Vector2:
	return _grid + Vector2(c + 0.5, r + 0.5) * _cell

## The cell's top-left corner.
func _corner_of(i: int) -> Vector2:
	return _grid + Vector2(Gen.col_of(i), Gen.row_of(i)) * _cell

func _cell_at(local: Vector2) -> int:
	if _cell <= 0.0:
		return -1
	var p := (local - _grid) / _cell
	var c := int(floor(p.x))
	var r := int(floor(p.y))
	if c < 0 or c >= Gen.N or r < 0 or r >= Gen.N:
		return -1
	return r * Gen.N + c

## The grid's centre in board pixels: what the entrance pops about.
func _centre() -> Vector2:
	return _grid + Vector2.ONE * (_cell * Gen.N * 0.5)

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0 or not _current():
		return
	var now := _now()
	_deliver_fx(now)
	_tick_layers(now)
	# The rebuild is decided **here** and never in _draw. Asking `_mesh_moving`
	# twice a frame -- once to queue the redraw and once to decide whether to
	# rebuild -- is the oneline2d.gd trap in miniature: _draw's clock is a
	# hair later than _process's, so on the frame a moment expires the two
	# could disagree and the mesh would be left one frame stale with nothing
	# queuing another redraw. One ask, one flag, and _draw simply obeys it.
	if _mesh_moving(now):
		_dirty = true
	if _moving(now):
		queue_redraw()

## True while anything is still moving. **It asks about every wave, not just
## the entrance:** oneline2d.gd froze two lines at four fifths of their fade
## by asking only about its first, and it showed on a rendered frame and in
## no test. Each book holds the second a moment begins, which a wave puts in
## the future, so a cell the wave has not reached yet keeps the board
## redrawing until it has been and gone.
func _moving(now: float) -> bool:
	if now < _anim_until:
		return true
	return _mesh_moving(now) \
		or _live(_twirl, now, TWIRL_TIME) \
		or _live(_boing, now, BOING_TIME) \
		or _live(_home, now, HOME_TIME) \
		or not _tumbling.is_empty() \
		or _dancing(now)

## True while anything the **mesh** draws is moving. Deliberately narrower
## than `_moving`: the entrance is one transform laid over the finished mesh
## and a fade that lives entirely in the numerals, so for its whole 0.84 s
## not one vertex of the grid changes, and rebuilding eighty-one cells sixty
## times over would buy exactly nothing. `_drop` is in since the polish,
## because a falling digit's shadow and its landing ring are the mesh's;
## `_anim_until` is out because every wave it is ever set for has its own
## book listed here.
func _mesh_moving(now: float) -> bool:
	return _live(_flash, now, WAVE_FLASH) \
		or _live(_bump, now, Motion.BUMP_TIME) \
		or _live(_drop, now, LAND_AT + RIPPLE_TIME) \
		or _live(_shiver, now, Motion.SHIVER_TIME) \
		or _winning(now) \
		or _stickers_moving(now) \
		or _hills_moving(now)

## True while the win's glow is rising or its glint is going round the tray.
func _winning(now: float) -> bool:
	return not Motion.reduce and now < _won_at + Motion.SOLVE_DELAY + maxf(GLOW_TIME, GLINT_TIME)

static func _live(book: Dictionary, now: float, span: float) -> bool:
	for at in book.values():
		if now < float(at) + span:
			return true
	return false

## Keeps the board redrawing for `seconds` more: the entrance and the pieces
## of a moment no book holds.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Something the mesh draws has changed: rebuild it on the next draw.
func _redraw() -> void:
	_dirty = true
	queue_redraw()

# --- the drawing ---

## The grid pops in wide about its centre (rule 7: a wide thing comes from
## most of the way) as one transform over the mesh, and every numeral rides
## the same pop in its own transform, so the board arrives as one thing.
func _draw() -> void:
	if not _current() or _cell <= 0.0:
		return
	var now := _now()
	# `_dirty` is the whole test: a state change sets it through `_redraw`
	# and a live cell moment sets it in `_process`, which is the one place
	# the question is asked. See the note there.
	if _dirty:
		_clash = state.clashes()
		_grid_mesh = _build_grid(now)
		_dirty = false
	# The mesh is handed over and held in the same breath, so what the canvas
	# item has by RID is always what this board still has by reference; see
	# the header for what happens when it is not.
	_shown = _grid_mesh
	var pop := Motion.wide_pop_scale(now - _opened - Motion.ENTER_DELAY)
	var centre := _centre()
	if _shown != null:
		draw_mesh(_shown, null, Transform2D(0.0, Vector2.ONE * pop, 0.0, centre * (1.0 - pop)))
	_draw_numerals(now, pop, centre)

## Everything but the numerals: the wooden tray and its floor, the region
## panels laid in it, the thin rules inside each panel, the washes, the wave's
## gold, a falling digit's shadow and its landing ring, and last the selected
## cell's lifted tile. The heavy rule is no longer a stroke: it is the tray's
## floor showing between the panels (section 16).
func _build_grid(now: float) -> ArrayMesh:
	var k := _scale()
	var field: float = _cell * Gen.N
	if not _rm.laid():
		_rm.room(PART_BASE, 0, maxi(_rm.size_of(SHAPE_BASE), _rm.size_of(SHAPE_BASE_GLOW)))
		for reg in Gen.N:
			_rm.room(PART_STICKER, reg, _rm.size_of(SHAPE_DAISY + reg))
		_rm.room(PART_SEL, 0, _rm.size_of(SHAPE_SEL) + _rm.size_of(SHAPE_SEL_TOP))
		var most := _rm.size_of(_hill_id(true, true, 4))
		for i in Gen.CELLS:
			if state.has_hill(i):
				_rm.room(PART_HILL, i, most)
	_rm.begin()
	# The tray and the panels as made, but for the moments its warmth is
	# rising and its glint goes round, drawn live.
	var glow := _glow(now)
	_rm.open(PART_BASE, 0)
	if (glow == 0.0 or glow == 1.0) and not _glinting(now):
		_rm.put(SHAPE_BASE if glow == 0.0 else SHAPE_BASE_GLOW, [], Transform2D.IDENTITY)
	else:
		var tray := Face.Builder.new()
		_tray(tray, now, field, k, glow)
		_panels(tray, k)
		_rm.put_builder(tray)
	_rm.close()
	# The washes are derived here and nowhere else: the state keeps no
	# highlight, so nothing can leave a stale one behind after an undo. Each
	# cell's wash, twin coin and wave gold is the one shape (made at the cell,
	# about its middle) under the cell's shiver and bump, put first on the
	# tail, where a place keeps its indices (no run under every cell).
	var peers: Dictionary = {}
	var twins: Dictionary = {}
	if _sel >= 0:
		for j in Gen.peers_of(_sel):
			peers[j] = true
		for j in state.twins(_sel):
			twins[j] = true
	var clash: Dictionary = _clash
	for i in Gen.CELLS:
		if i == _sel:
			continue
		var wash := _wash_of(i, peers, twins, clash)
		var lit := _flash_level(now, i)
		var twin := wash.a <= 0.0 and twins.has(i)
		if wash.a <= 0.0 and lit <= 0.0 and not twin:
			continue
		var grow := _cell_grow(now, i)
		var mid := cell_to_local(Gen.row_of(i), Gen.col_of(i)) + Vector2(_cell_shift(now, i), 0.0)
		var xf := Transform2D(0.0, Vector2(grow, grow), 0.0, mid)
		if wash.a > 0.0:
			_rm.put(SHAPE_WASH, [wash], xf)
		elif twin:
			_rm.put(SHAPE_TWIN, [Color(Pal.SUN, WASH_TWIN_COIN)], xf)
		if lit > 0.0:
			_rm.put(SHAPE_WASH, [Color(Pal.SUN_RAY, WASH_FLASH * lit)], xf)
	_rm.close()
	var b := Face.Builder.new()
	_reach(b, k)
	_rm.put_builder(b)
	_stickers(now)
	_rm.close()
	b = Face.Builder.new()
	_landings(b, now, k)
	_rm.put_builder(b)
	if _sel >= 0:
		_rm.open(PART_SEL, 0)
		_selected_tile(now, k, _wash_of(_sel, peers, twins, clash))
	_hills(now, k)
	return _rm.mesh()

enum { PART_BASE, PART_STICKER, PART_SEL, PART_HILL }
const SHAPE_BASE := 0
const SHAPE_BASE_GLOW := 1
const SHAPE_WASH := 2
const SHAPE_TWIN := 3
## A region's daisy at rest, open and turned its own way: SHAPE_DAISY + region.
const SHAPE_DAISY := 4
## The selected tile at rest, and its face alone for the wave's gold over it
## (the mini's six regions and the nine's nine daisies end at 12).
const SHAPE_SEL := 13
const SHAPE_SEL_TOP := 14
## A hill at rest: SHAPE_HILL + 10 with a halo, + 5 with the party's glow,
## + its dots.
const SHAPE_HILL := 16

static func _hill_id(halo: bool, glow: bool, dots: int) -> int:
	return SHAPE_HILL + (10 if halo else 0) + (5 if glow else 0) + dots

## Shape `id` for the RunMesh, at this layout: the tray and the panels in
## their own colours; a cell's wash or twin coin about its middle, a region's
## daisy open about its eye, or a hill about its foot, in slot colours.
func _make_shape(id: int) -> Face.Builder:
	var b := Face.Builder.new()
	var k := _scale()
	if id == SHAPE_BASE or id == SHAPE_BASE_GLOW:
		_tray(b, -INF, _cell * Gen.N, k, 0.0 if id == SHAPE_BASE else 1.0)
		_panels(b, k)
		return b
	if id == SHAPE_WASH:
		var side := _cell - 2.0 * WASH_INSET * k
		b.fan(Face.Builder.round_rect(-Vector2.ONE * (side * 0.5), Vector2.ONE * side, WASH_R * k), RunMesh.slot(0))
		return b
	if id == SHAPE_TWIN:
		b.disc(Vector2.ZERO, _cell * TWIN_R, RunMesh.slot(0))
		return b
	if id == SHAPE_SEL or id == SHAPE_SEL_TOP:
		var slots := [RunMesh.slot(0), RunMesh.slot(1), RunMesh.slot(2), RunMesh.slot(3), RunMesh.slot(4)]
		_tile(b, Vector2.ZERO, 1.0, k, slots, id == SHAPE_SEL_TOP)
		return b
	if id < SHAPE_HILL:
		var reg := id - SHAPE_DAISY
		_daisy(b, Vector2.ZERO, _cell * STICKER_R, _sticker_turn(reg, 1.0),
			[RunMesh.slot(0), RunMesh.slot(1), RunMesh.slot(2), RunMesh.slot(3)])
		return b
	var h := id - SHAPE_HILL
	var slots := []
	for n in HILL_COLOURS:
		slots.append(RunMesh.slot(n))
	_hill(b, Vector2.ZERO, HILL_W * _cell, HILL_H * _cell, 1.0, h % 5, h >= 10, 1.0 if (h / 5) % 2 == 1 else 0.0, slots)
	return b

## True while the win's glint is going round the tray.
func _glinting(now: float) -> bool:
	var since := now - _won_at - Motion.SOLVE_DELAY
	return not Motion.reduce and since > 0.0 and since < GLINT_TIME

## The tray: a WOOD_DEEP lip under a face in the rule's own wood, lit along
## its top edge, and inside it the floor the panels stand on, darker so the
## gutters between them read as grooves. On the win the wood warms toward the
## sun and a glint runs once round it.
func _tray(b: Face.Builder, now: float, field: float, k: float, glow: float) -> void:
	var f := FRAME * k
	var outer := _grid - Vector2.ONE * f
	var side := Vector2.ONE * (field + 2.0 * f)
	var r := (CORNER + FRAME * 0.5) * k
	var face: Color = Pal.GRID_RULE.lerp(Pal.SUN_RAY, WIN_GLOW * glow)
	var lip: Color = Pal.WOOD_DEEP.lerp(Pal.SUN, WIN_GLOW * glow * 0.5)
	b.fan(Face.Builder.round_rect(outer + Vector2(0.0, TRAY_LIP * k), side, r), lip)
	b.fan(Face.Builder.round_rect(outer, side, r), face)
	var shine: Color = face.lerp(Pal.SURFACE, TRAY_SHINE)
	b.stroke(PackedVector2Array([outer + Vector2(r, 2.0 * k), outer + Vector2(side.x - r, 2.0 * k)]),
		2.5 * k, Color(shine, 0.8), false, true)
	_glint(b, now, field, k)
	var floor_col: Color = face.darkened(FLOOR_DARKEN)
	b.fan(Face.Builder.round_rect(_grid - Vector2.ONE * k, Vector2.ONE * (field + 2.0 * k),
		PANEL_R * k), floor_col)

## How warm the tray is: nothing before the win, rising over GLOW_TIME once
## the solve's wave has started, and full for good after. Under reduce motion
## it is simply full, which is a state and not a motion.
func _glow(now: float) -> float:
	var since := now - _won_at - Motion.SOLVE_DELAY
	if since < -1.0e8:
		return 0.0
	if Motion.reduce:
		return 1.0
	return clampf(since / GLOW_TIME, 0.0, 1.0)

## The win's glint: a soft light GLINT_LEN long riding the tray's midline once
## round, clockwise from the top left, easing in and out of its lap.
func _glint(b: Face.Builder, now: float, field: float, k: float) -> void:
	if Motion.reduce:
		return
	var since := now - _won_at - Motion.SOLVE_DELAY
	if since <= 0.0 or since >= GLINT_TIME:
		return
	var u := since / GLINT_TIME
	var a := GLINT_A * sin(PI * u)
	var half := FRAME * k * 0.5
	var lo := _grid - Vector2.ONE * half
	var edge := field + 2.0 * half
	# Where on the lap u = 0..1 is, eased so the light gathers and settles.
	var d := (0.5 - 0.5 * cos(PI * u)) * edge * 4.0
	var at: Vector2
	var along := true
	if d < edge:
		at = lo + Vector2(d, 0.0)
	elif d < edge * 2.0:
		at = lo + Vector2(edge, d - edge)
		along = false
	elif d < edge * 3.0:
		at = lo + Vector2(edge * 3.0 - d, edge)
	else:
		at = lo + Vector2(0.0, edge * 4.0 - d)
		along = false
	# A wide soft light and a hot core inside it: one soft disc alone peaks
	# only at its very centre, and on a frame this narrow that read as nothing.
	for layer in [[1.0, 0.7], [0.45, 1.0]]:
		var long: float = GLINT_LEN * k * 0.5 * layer[0]
		var short: float = FRAME * k * 0.75 * layer[0]
		Scenery.soft_disc(b, at, long if along else short, short if along else long,
			Color(Pal.SURFACE, a * float(layer[1])))

## The region panels: paper laid in the tray a half gutter in from the
## region's edges, each over a lip PANEL_LIP proud of the floor, the chequer
## kept and every panel toned a hair off its neighbour's so they read as
## laid by hand. The thin rules between the cells of a panel run inside it
## and stop short of its rounded corners, so none crosses a gutter.
func _panels(b: Face.Builder, k: float) -> void:
	var g := GUTTER * k * 0.5
	var r := PANEL_R * k
	var thin := Color(Pal.LINE, THIN_ALPHA)
	var size := Vector2(Gen.BOX_C, Gen.BOX_R) * _cell
	for br in Gen.N / Gen.BOX_R:
		for bc in Gen.N / Gen.BOX_C:
			var at := _grid + Vector2(bc, br) * size
			var shaded := (br + bc) % 2 == 1
			var paper: Color = Pal.GRID_TINT if shaded else Pal.SURFACE
			var tone := _hash(br, bc) * 2.0 - 1.0
			paper = paper.lightened(tone * PANEL_TONE) if tone > 0.0 else paper.darkened(-tone * PANEL_TONE)
			var lip: Color = paper.lerp(Pal.GRID_RULE, 0.45)
			var inner := size - Vector2.ONE * (2.0 * g)
			b.fan(Face.Builder.round_rect(at + Vector2(g, g + PANEL_LIP * k), inner, r), lip)
			b.fan(Face.Builder.round_rect(at + Vector2.ONE * g, inner, r), paper)
			for c in range(1, Gen.BOX_C):
				var x := at.x + c * _cell
				b.stroke(PackedVector2Array([Vector2(x, at.y + g + r * 0.5),
					Vector2(x, at.y + size.y - g - r * 0.5)]), THIN_W * k, thin, false, false)
			for rr in range(1, Gen.BOX_R):
				var y := at.y + rr * _cell
				b.stroke(PackedVector2Array([Vector2(at.x + g + r * 0.5, y),
					Vector2(at.x + size.x - g - r * 0.5, y)]), THIN_W * k, thin, false, false)

## `i`'s wash: a rounded square WASH_INSET in from its cell under the cell's
## own shiver and bump.
##
## **The cell moves, not only its numeral.** A refused tap once shook a digit
## inside a square that never budged, and a cell whose digit had just been
## taken out bumped with nothing on it to see. What moves is everything that
## is *this cell* rather than the board: its washes, the wave's gold, its
## twin coin and the selected tile -- tents2d.gd's rule 9, a piece with no
## skin of its own blushing through its cell, applied to motion. The panels
## and the rules between the cells do **not** move: they are the paper the
## grid is ruled on, and a rule that shivered with one cell would tear it.
func _wash_quad(i: int, shift: float, grow: float) -> PackedVector2Array:
	var k := _scale()
	var inset := WASH_INSET * k
	var side := (_cell - 2.0 * inset) * grow
	var mid := _corner_of(i) + Vector2(_cell * 0.5 + shift, _cell * 0.5)
	return Face.Builder.round_rect(mid - Vector2.ONE * (side * 0.5), Vector2.ONE * side, WASH_R * k * grow)

## A falling digit's shadow gathering under it, and its ring of ink spreading
## once it has touched down.
func _landings(b: Face.Builder, now: float, k: float) -> void:
	if Motion.reduce:
		return
	for i in _drop:
		var fell := now - float(_drop[i])
		if fell < 0.0 or fell >= LAND_AT + RIPPLE_TIME or state.grid[i] == 0:
			continue
		var mid := cell_to_local(Gen.row_of(i), Gen.col_of(i)) + Vector2(_cell_shift(now, i), 0.0)
		var height := Motion.DROP * k
		var lift := Motion.drop_in_lift(fell, height)
		if lift > 0.5:
			var far := clampf(lift / height, 0.0, 1.0)
			Scenery.soft_disc(b, mid + Vector2(0.0, _cell * 0.3), _cell * 0.26 * (1.0 - 0.35 * far),
				_cell * 0.07, Color(Pal.TEXT, FALL_SHADOW_A * (1.0 - 0.6 * far) * Motion.appear_level(fell)))
		var since := fell - LAND_AT
		if since > 0.0:
			var u := since / RIPPLE_TIME
			var ease := 1.0 - (1.0 - u) * (1.0 - u)
			var rad := _cell * lerpf(RIPPLE_FROM, RIPPLE_TO, ease)
			b.stroke(Face.Builder.ring(mid, rad, rad), 3.0 * k * (1.0 - u) + 0.5,
				Color(_digit_ink(i), RIPPLE_A * (1.0 - u)), true)

## The selected cell as a paper tile lifted off its panel: a soft shadow on
## the panel, a lip in the sun's deep, a face washed as the cell is (gold, or
## rose while it clashes), and the gold rim. It takes the cell's shiver and
## bump, so a refusal still shakes the clearest thing on the cell.
## Into its own run: the tile is its shape copied over the cell, and the
## wave's gold its face's shape over it. A bump scales the whole shape about
## the cell, so the lift and the shadow's drop swell with it by the bump's
## tenth (under a pixel) where they used to stand still; at rest it is as it
## was.
func _selected_tile(now: float, k: float, wash: Color) -> void:
	var grow := _cell_grow(now, _sel)
	var mid := _corner_of(_sel) + Vector2.ONE * (_cell * 0.5) + Vector2(_cell_shift(now, _sel), 0.0)
	var lit := _flash_level(now, _sel)
	var colours := [Color(Pal.TEXT, SEL_SHADOW_A), Pal.SUN.darkened(0.12),
		Pal.SURFACE.lerp(Color(wash, 1.0), wash.a), Color(Pal.SUN_RAY, WASH_FLASH * lit), Pal.SUN]
	var xf := Transform2D(0.0, Vector2(grow, grow), 0.0, mid)
	_rm.put(SHAPE_SEL, colours, xf)
	if lit > 0.0:
		_rm.put(SHAPE_SEL_TOP, colours, xf)

## The selected tile over a cell's middle `mid`, `grow` bumped: its shadow,
## lip, face and rim in `colours` (the wave's gold, slot 3, unused), or with
## `top` its face alone in the wave's gold.
func _tile(b: Face.Builder, mid: Vector2, grow: float, k: float, colours: Array, top_only: bool) -> void:
	var side := (_cell - 2.0 * EDGE_INSET * k) * grow
	var top := mid - Vector2(side * 0.5, side * 0.5 + SEL_LIFT * k)
	var r := EDGE_RADIUS * k * grow
	if top_only:
		b.fan(Face.Builder.round_rect(top, Vector2.ONE * side, r), colours[3])
		return
	Scenery.soft_disc(b, mid + Vector2(0.0, _cell * 0.34), side * 0.56, _cell * 0.16, colours[0])
	b.fan(Face.Builder.round_rect(top + Vector2(0.0, SEL_LIFT * k), Vector2.ONE * side, r), colours[1])
	b.fan(Face.Builder.round_rect(top, Vector2.ONE * side, r), colours[2])
	var w := EDGE_W * k * grow
	b.stroke(Face.Builder.round_rect(top + Vector2.ONE * (w * 0.5), Vector2.ONE * (side - w),
		maxf(r - w * 0.5, 0.0)), w, colours[4], true)

static func _hash(a: int, c: int) -> float:
	return float(posmod(hash(Vector2i(a, c)), 1000)) / 1000.0

## How far `i` is shoved sideways this frame: the refusal's and the Check's
## shiver, read off the family's curve at the cell's own scale.
func _cell_shift(now: float, i: int) -> float:
	return Motion.shiver_offset(now - float(_shiver.get(i, -1.0e9)), Motion.SHIVER_PX * _scale())

## How much bigger `i` is this frame: the bump a place, a take-out, an undo,
## a hint, Reset's wave and the solve's wave all stamp.
func _cell_grow(now: float, i: int) -> float:
	return Motion.bump_scale(now - float(_bump.get(i, -1.0e9)))

## What `i` is washed with: what the last Check found and any clash first,
## then the selection, then its twins -- the most useful scan in sudoku, and
## the reason the selection survives the tap -- then the twenty cells the
## selection cannot repeat into. A clash outranks the selection because the
## two copies of a clashing digit are always the selection and its twin the
## moment one is placed, so ranked under them it was washed gold -- the
## selection's own colour -- exactly when it happened, and read as right. The
## selected cell keeps its gold edge either way. A clash and a mistake are
## two different things: the first is visible with no answer in hand, the
## second needs the answer and costs a Check.
func _wash_of(i: int, peers: Dictionary, twins: Dictionary, clash: Dictionary) -> Color:
	if _wrong.has(i) or _bad.has(i):
		return Color(Pal.BAD, WASH_WRONG)
	if clash.has(i):
		return Color(Pal.BAD, WASH_CLASH)
	if i == _sel:
		return Color(Pal.SUN, WASH_SELECTED)
	if twins.has(i):
		return Color(1.0, 1.0, 1.0, 0.0)
	if peers.has(i):
		return Color(Pal.SUN, WASH_PEER)
	return Color(1.0, 1.0, 1.0, 0.0)

## The wave's gold on `i` now, 0 to 1. The family's flash read over this
## board's own WAVE_FLASH rather than the family's FLASH_IN + FLASH_OUT, in
## the same proportion, so the curve is the one hand and only its length is
## this board's.
func _flash_level(now: float, i: int) -> float:
	if not _flash.has(i):
		return 0.0
	var rise := WAVE_FLASH * Motion.FLASH_IN / (Motion.FLASH_IN + Motion.FLASH_OUT)
	return Motion.flash_level(now - float(_flash[i]), rise, WAVE_FLASH - rise)

## The digits and the pencil marks, over the mesh, each through one
## draw_set_transform so it takes the entrance's pop, the cell's bump, the
## refusal's shiver and the hint's drop together -- Nonogram's precedent for
## drawn text on the vocabulary.
func _draw_numerals(now: float, pop: float, centre: Vector2) -> void:
	var k := _scale()
	var digit_font: Font = CozyTheme.display(600)
	var note_font: Font = CozyTheme.body(600)
	var digit_px := int(roundf(DIGIT_SIZE * k))
	var note_px := int(roundf(NOTE_SIZE * k))
	if digit_px <= 0 or note_px <= 0:
		return
	var digit_rise := digit_font.get_ascent(digit_px) * 0.5
	var note_rise := note_font.get_ascent(note_px) * 0.5
	for i in Gen.CELLS:
		var seen := _appear_of(now, i)
		if seen <= 0.0:
			continue
		var at := cell_to_local(Gen.row_of(i), Gen.col_of(i))
		at.x += _cell_shift(now, i)
		at.y += _numeral_rise(now, i, k)
		var grow := _cell_grow(now, i)
		var d: int = state.grid[i]
		if d > 0:
			var fell := now - float(_drop.get(i, -1.0e9))
			at.y -= Motion.drop_in_lift(fell, Motion.DROP * k)
			var alpha := seen * (Motion.appear_level(fell) if _drop.has(i) else 1.0)
			_seat(at, centre, pop, grow, _squash(fell), _spin(now, i))
			_numeral(digit_font, digit_px, digit_rise, str(d), Vector2.ZERO,
				Color(_digit_ink(i), alpha))
		elif state.notes[i] != 0:
			_seat(at, centre, pop, grow)
			for n in range(1, Gen.N + 1):
				if not state.has_note(i, n):
					continue
				# Each mark sits in its own third of the cell, which is what
				# a round 100 buys: 33 is the smallest square a 26 px numeral
				# reads in.
				var spot := _note_spot(n)
				_numeral(note_font, note_px, note_rise, str(n), spot,
					Color(Pal.TEXT_DIM, seen))
		elif state.ruled.has(i):
			_seat(at, centre, pop, grow)
			_draw_ruled(i, note_font, note_px, note_rise)
	_draw_leaving(now, pop, centre, digit_font, digit_px, digit_rise,
		note_font, note_px, note_rise)
	_draw_tumbling(now, pop, centre, digit_font, digit_px, digit_rise)
	draw_set_transform(Vector2.ZERO)

## Reset's wave, drawn over the emptied cells: what the player had written
## stands where it was until its beat arrives, then swells with the family's
## bump and fades out over the same BUMP_TIME, so the wave from the far
## corner is a thing coming apart and not a wave over eighty-one blanks.
## The alpha is `appear_level` read backwards -- a recipe, not a number of
## this board's -- and the scale is the bump every other moment here uses.
func _draw_leaving(now: float, pop: float, centre: Vector2, digit_font: Font,
		digit_px: int, digit_rise: float, note_font: Font, note_px: int,
		note_rise: float) -> void:
	if _leaving.is_empty():
		return
	var keep: Array = []
	for g in _leaving:
		var since: float = now - float(g.at)
		if since >= Motion.BUMP_TIME:
			continue
		keep.append(g)
		var i: int = g.i
		# The player can write into the cell again before the wave gets
		# there; what is really on the board wins, and the ghost gives way.
		if state.grid[i] != 0 or state.notes[i] != 0:
			continue
		var at := cell_to_local(Gen.row_of(i), Gen.col_of(i))
		var alpha := 1.0 - Motion.appear_level(since, Motion.BUMP_TIME)
		_seat(at, centre, pop, Motion.bump_scale(since))
		var d: int = g.d
		if d > 0:
			_numeral(digit_font, digit_px, digit_rise, str(d), Vector2.ZERO,
				Color(Pal.LEAF_DEEP, alpha))
			continue
		for n in range(1, Gen.N + 1):
			if int(g.notes) & (1 << (n - 1)) == 0:
				continue
			var spot := _note_spot(n)
			_numeral(note_font, note_px, note_rise, str(n), spot,
				Color(Pal.TEXT_DIM, alpha))
	_leaving = keep

## Where pencil mark `n` sits from its cell's centre: three to a line, in
## three lines on a nine and two on the mini, centred either way.
func _note_spot(n: int) -> Vector2:
	var lines := float((Gen.N + 2) / 3)
	return Vector2(float((n - 1) % 3) - 1.0, float((n - 1) / 3) - (lines - 1.0) * 0.5) \
		* (_cell * NOTE_STEP)

## Puts the canvas at `at` under the entrance's pop about `centre`, scaled by
## the cell's own bump: one transform, so a numeral never drifts off the cell
## the mesh drew under it.
func _seat(at: Vector2, centre: Vector2, pop: float, grow: float, squash := Vector2.ONE, turn := 0.0) -> void:
	draw_set_transform(centre + (at - centre) * pop, turn, squash * (pop * grow))

## How far `i`'s numeral stands off its cell, negative up: raised with the
## selected tile, hopped by the wave as it passes, and a given dropping in
## with its region on the entrance.
func _numeral_rise(now: float, i: int, k: float) -> float:
	var y := 0.0
	if i == _sel:
		y -= SEL_LIFT * k
	if _flash.has(i):
		y += Motion.hop_lift(now - float(_flash[i]), WAVE_HOP * k)
	if state.is_given(i):
		y -= Motion.drop_in_lift(now - _opened - _enter_delay(i), ENTER_DROP * k)
	if _boing.has(i):
		var e := now - float(_boing[i])
		if e > 0.0 and e < BOING_TIME:
			# Three hops, each lower than the last.
			var u := e / BOING_TIME * BOING_HOPS
			var hop := int(u)
			y += BOING_H * k * sin(PI * (u - hop)) / float(hop + 1)
	if _home.has(i):
		y += Motion.hop_lift(now - float(_home[i]), HOME_HOP * k)
	var e2 := now - _dance_at
	if e2 > 0.0 and e2 < DANCE_BEAT * (DANCE_BEATS + 1) and state.grid[i] > 0:
		y += DANCE_HOP * k * absf(sin(PI * e2 / DANCE_BEAT))
	return y

## How far `i`'s numeral is turned: a whole turn for the twirl gag, and a
## sway on the beat while the numbers dance at the party.
func _spin(now: float, i: int) -> float:
	var turn := 0.0
	if _twirl.has(i):
		var e := now - float(_twirl[i])
		if e > 0.0 and e < TWIRL_TIME:
			var u := e / TWIRL_TIME
			turn += TAU * (u * u * (3.0 - 2.0 * u))
	var d := now - _dance_at
	if d > 0.0 and d < DANCE_BEAT * (DANCE_BEATS + 1):
		var side := 1.0 if (Gen.row_of(i) + Gen.col_of(i)) % 2 == 0 else -1.0
		var fade := clampf((DANCE_BEAT * (DANCE_BEATS + 1) - d) / DANCE_BEAT, 0.0, 1.0)
		turn += side * DANCE_TILT * sin(PI * d / DANCE_BEAT) * fade
	return turn

## A written digit's squash as it touches down, `fell` into its drop: wide
## and low for SQUASH_TIME, then round again.
func _squash(fell: float) -> Vector2:
	var since := fell - LAND_AT
	if Motion.reduce or since <= 0.0 or since >= SQUASH_TIME:
		return Vector2.ONE
	var s := SQUASH * sin(PI * since / SQUASH_TIME)
	return Vector2(1.0 + s, 1.0 - s)

## How much of `i`'s numeral is on screen. A given fades in with its region,
## ENTER_STAGGER apart, so the board assembles as three by three and not as
## eighty-one; anything the player put there is simply here.
func _appear_of(now: float, i: int) -> float:
	if not state.is_given(i):
		return 1.0
	return Motion.appear_level(now - _opened - _enter_delay(i), Motion.DROP_TIME)

## One step per region, nine of them: 0.24 s end to end, well inside
## `Motion.stagger`'s 0.6 cap. Stepping by band within a region instead would
## be twenty-seven indices, and 26 * ENTER_STAGGER overruns that cap -- the
## last seven bands would all land on one frame, which is neither region by
## region nor cell by cell.
func _enter_delay(i: int) -> float:
	return Motion.ENTER_DELAY + Motion.ENTER_FACE_LAG \
		+ Motion.stagger(Gen.box_of(i), Motion.ENTER_STAGGER)

## A given is ink and never changes; what the player put there is leaf, which
## is this game's own word for something that grew, and turns to the family's
## rose while it clashes or the last Check still points at it. A clash is
## wrong on its face, so a green digit in one read as a right answer.
func _digit_ink(i: int) -> Color:
	if state.is_given(i):
		return Pal.TEXT
	return Pal.BAD if _wrong.has(i) or _clash.has(i) or _bad.has(i) else Pal.LEAF_DEEP

## One numeral centred on `centre`, in the transform already set.
func _numeral(font: Font, px: int, rise: float, text: String, centre: Vector2, ink: Color) -> void:
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	draw_string(font, centre + Vector2(-wide * 0.5, rise), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, ink)

# --- input ---

## A tap on the grid **only ever selects**, and tapping the selected cell
## again clears the selection. That is what makes a 100 cell bearable under a
## thumb: nothing is typed here, and the thing tapped next is a 91 by 130
## chip in the pad.
func _gui_input(event: InputEvent) -> void:
	if not _current() or is_done() or out_of_hearts:
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not ((event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed):
		return
	var i := _cell_at(event.position)
	if i < 0:
		return
	_sel = -1 if i == _sel else i
	if _sel >= 0 and state.has_hill(_sel):
		_speak(tr("SD_HILL_SAYS") % state.hills[_sel], Face.Expr.HAPPY)
	# The pad reads the counts and the pencil back off this board on every
	# refresh, and the host refreshes on this signal.
	focus_changed.emit()
	_redraw()
	accept_event()

# --- what the tray asks ---

func pencil_on() -> bool:
	return _pencil

func remaining(d: int) -> int:
	return state.remaining(d) if state != null else Gen.N

## How many digit chips the pad shows: six on the mini, nine on hard.
func digit_count() -> int:
	return Gen.N

## A chip was tapped: 0..8 are the digits 1..9 and REMOVE_CHIP empties the
## selected cell.
func pick(i: int) -> bool:
	if state == null or is_done() or out_of_hearts or _ejecting:
		return false
	if _sel < 0:
		_speak(tr("SD_TAP_CELL"), Face.Expr.PUZZLED)
		return false
	if i == REMOVE_CHIP:
		return _erase(_sel)
	return _apply(_sel, i + 1)

## The remove chip: the selected cell's digit or marks come out, as one move
## undo can put back. Taking a digit out can only open a unit, never finish
## one, so there is no wave to settle -- but a unit it opens may still have
## its wave running, and that gold goes out with it, as in undo().
func _erase(i: int) -> bool:
	var before: Array = state.finished_units()
	var cost: int = state.erase_cost(i)
	match state.erase(i):
		State.GIVEN:
			_refuse(i, tr("SD_GIVEN"))
			return false
		State.EMPTY:
			_refuse(i, tr("SD_EMPTY"))
			return false
		State.KEPT:
			_refuse(i, tr("SD_KEPT"))
			return false
	var now := _now()
	_wrong.erase(i)
	_break_streak()
	_bump[i] = now
	_busy_for(Motion.BUMP_TIME)
	var units: Array = Gen.units()
	for u in units.size():
		if bool(before[u]) and not state.unit_done(units[u]):
			for c in units[u]:
				_flash.erase(c)
	_update_stickers(now)
	fx.cue("undo")
	_redraw()
	note_move()
	_spend(cost, now)
	return true

# --- the one door every move goes through ---

## Every move that can change the grid comes through here, so the wave is
## diffed in exactly one place: what was finished before the move against
## what is finished after it. Nothing else may call state.place or state.mark.
func _apply(i: int, d: int) -> bool:
	var before: Array = state.finished_units()
	var code: int = state.mark(i, d) if _pencil else state.place(i, d)
	match code:
		State.GIVEN:
			_refuse(i, tr("SD_GIVEN"))
			return false
		State.FILLED:
			_refuse(i, tr("SD_PENCIL"))
			return false
		State.KEPT:
			_refuse(i, tr("SD_KEPT"))
			return false
		State.RULED:
			_refuse(i, tr("SD_RULED") % d, "ruled")
			return false
	var now := _now()
	_wrong.erase(i)
	_bump[i] = now
	# A digit falls in; a pencil mark does not, because nine of them dropping
	# is a rainstorm.
	if state.grid[i] != 0 and not _pencil:
		_drop[i] = now
		_busy_for(Motion.DROP_TIME)
	_busy_for(Motion.BUMP_TIME)
	_settle(before, i, now)
	_clash = state.clashes()
	fx.cue("pencil" if _pencil else "place")
	fx.buzz(Haptics.TAP if state.grid[i] == d else Haptics.TICK)
	if not _pencil:
		if state.grid[i] != d:
			_break_streak()
		elif state.judged() and d != state.sol[i]:
			_wrong_digit(i, d)
		elif _clash.has(i):
			_break_streak()
		else:
			_on_right(i, d)
	_update_stickers(now)
	# A row, column or region the move finished rings as its wave goes out
	# (and under reduce motion, where the wave is not drawn, all the same).
	var after: Array = state.finished_units()
	for u in after.size():
		if bool(after[u]) and not bool(before[u]):
			fx.cue("line")
			if not _ejecting:
				fx.buzz(Haptics.BUMP)
			break
	_redraw()
	note_move()
	# Insane counts moves: a number written or tapped back out is one.
	_spend(state.move_cost(i, _pencil), now + (0.0 if Motion.reduce else LAND_AT))
	return true

## Diff the units and hand each cell of one that has just come right its
## moment: it lights up in gold from `at` outwards, a king-move step apart.
## Queens' `_settle`, with a unit in place of a queen's sight.
##
## A digit that closes a row *and* a region runs both at once from the same
## seat, and it comes out right for free: `step` is read off `i` and `at`
## alone and never off the unit, so the second unit hands a shared cell the
## identical `when` and neither can disturb the other. The `<` test is not
## for that -- it is there because `_flash` is never pruned, so a cell may
## still be carrying a spent moment from an earlier move, and the new one has
## to win.
func _settle(before: Array, at: int, now: float) -> void:
	if Motion.reduce:
		return
	var units: Array = Gen.units()
	for u in units.size():
		if bool(before[u]) or not state.unit_done(units[u]):
			continue
		for i in units[u]:
			var step := 0
			if at >= 0:
				step = maxi(absi(Gen.row_of(i) - Gen.row_of(at)),
					absi(Gen.col_of(i) - Gen.col_of(at)))
			var when := now + step * Motion.WAVE_STEP
			if not _flash.has(i) or float(_flash[i]) < when:
				_flash[i] = when
			_busy_for(when - now + WAVE_FLASH)

## A refused tap: the cell shivers and the tip card says why. A refusal is
## never a silence, and it is never a toast either -- this board already has
## a card whose whole job is one line.
func _refuse(i: int, line: String, cue := "locked") -> void:
	_shiver[i] = _now()
	_busy_for(Motion.SHIVER_TIME)
	_speak(line, Face.Expr.WORRIED)
	fx.cue(cue)
	_redraw()

# --- the HUD's actions ---

func is_solved() -> bool:
	return state != null and state.is_solved()

func can_undo() -> bool:
	return state != null and not is_done() and not out_of_hearts and not _ejecting \
		and not state.history.is_empty()

## Takes the last move back, wherever it was. A hint's digit comes back out
## with it; **the hint it cost does not come back**, which is the same bargain
## Reset makes below.
func undo() -> bool:
	if state == null or is_done() or out_of_hearts or _ejecting:
		return false
	var before: Array = state.finished_units()
	var i := state.undo()
	if i < 0:
		return false
	var now := _now()
	_sel = i
	_wrong.erase(i)
	_bump[i] = now
	_busy_for(Motion.BUMP_TIME)
	# An undo can take a finished unit apart, and most of that unit's wave is
	# still in the future when it does -- eight of a row's nine cells are, at
	# Motion.WAVE_STEP a step. `_settle` will not re-light it (`before` says it was
	# already finished), but nothing else would put it out either, and the
	# gold would go on sweeping a row that is no longer right. Section 7's
	# rule is that there is no highlight to leave behind; this is the one
	# place on the board that could leave one.
	#
	# The prune below is cell-granular, not unit-scoped: `_flash` is keyed by
	# cell alone with no record of which unit scheduled it, so erasing every
	# cell of a newly-reopened unit can also erase a wave a *different*,
	# still-complete unit legitimately scheduled for a cell the two units
	# share (a box cell that sits in the row this undo just broke). That is
	# accepted and cosmetic, not a bug to chase: it needs two units to finish
	# within about a wave's width of each other (eight steps of
	# Motion.WAVE_STEP, ~0.36 s) and then an undo inside that window, and the
	# cost is a legitimate flash cut a little short -- never a stale one left
	# behind, which is the failure this prune exists to prevent. Making the
	# prune unit-aware would mean tagging every `_flash` entry with the units
	# that scheduled it and only clearing a tag on their own reopening, which
	# is a real restructure for a case this narrow; over-eager is the right
	# trade until something else forces `_flash` to carry more than a time.
	var units: Array = Gen.units()
	for u in units.size():
		if not bool(before[u]) or state.unit_done(units[u]):
			continue
		for c in units[u]:
			_flash.erase(c)
	_settle(before, i, now)
	_break_streak()
	_update_stickers(now)
	fx.cue("undo")
	_redraw()
	moved.emit()
	return true

## One more hint beyond the budget (a rewarded video's), kept in the state.
func add_hint() -> void:
	if state != null:
		state.hints_left += 1

func hints_left() -> int:
	return state.hints_left if state != null else 0

## One cell from the answer, wherever the player was closest: a ring in leaf,
## the digit dropping in under sparkles, and the wave if it finished
## anything. Counts no move, but it can finish the puzzle.
func hint() -> bool:
	if state == null or is_done() or out_of_hearts or _ejecting:
		return false
	var before: Array = state.finished_units()
	var i := state.hint()
	if i < 0:
		return false
	var now := _now()
	hints_used += 1
	_sel = i
	_wrong.erase(i)
	_bump[i] = now
	_drop[i] = now
	_busy_for(maxf(Motion.BUMP_TIME, Motion.DROP_TIME))
	var at := cell_to_local(Gen.row_of(i), Gen.col_of(i))
	fx.ring(at, _cell * RING_R, Pal.LEAF)
	fx.sparkle(at, Pal.LEAF)
	fx.cue("hint")
	_settle(before, i, now)
	_update_stickers(now)
	_say(tr("SD_HINT"), Face.Expr.HAPPY)
	_redraw()
	moved.emit()
	check_solved()
	return true

## Every cell that disagrees with the answer shivers, in a shallow wave out
## from the middle row, and keeps the rose wash until it is written again.
## Givens are never wrong and a pencil mark is a note rather than a claim, so
## neither is looked at.
func check() -> int:
	if state == null or is_done() or out_of_hearts or _ejecting:
		return 0
	checks += 1
	var now := _now()
	_wrong = {}
	var w: PackedInt32Array = state.wrong()
	for i in w:
		_wrong[i] = true
		if not Motion.reduce:
			var when := now + absi(Gen.row_of(i) - (Gen.N - 1) / 2) * Motion.RESET_STAGGER
			_shiver[i] = when
			_busy_for(when - now + Motion.SHIVER_TIME)
	_speak(_check_line(w.size()), Face.Expr.STRAIN if w.size() > 0 else Face.Expr.JOY)
	fx.cue("check" if w.size() > 0 else "check_ok")
	_redraw()
	return w.size()

func _check_line(wrong: int) -> String:
	if wrong == 0:
		return tr("SD_CHECK_OK")
	if wrong == 1:
		return tr("SD_CHECK_ONE")
	return tr("SD_CHECK_N") % wrong

## Back to the givens, in a wave from the far corner. The hints spent are not
## refunded: a hint's effect on the grid is undoable and its cost is not,
## which is what the badge in the top bar is counting.
func reset_board() -> void:
	if state == null or out_of_hearts or _ejecting:
		return
	_wipe()
	moves = 0
	# A cleared grid is the grid from the top, so the moves come back too.
	moves_left = max_moves
	_heart_layer.queue_redraw()
	_say(tr("SD_RESET"),
		Face.Expr.HAPPY)
	fx.cue("reset")
	_redraw()

## Reset's half that Try again shares: the player's numbers carried out in a
## wave from the far corner, the state back to its givens, every moment and
## sticker gone.
func _wipe() -> void:
	var now := _now()
	var far := Gen.CELLS - 1
	if not Motion.reduce:
		for i in Gen.CELLS:
			if state.given[i] != 0 or (state.grid[i] == 0 and state.notes[i] == 0):
				continue
			var step := maxi(absi(Gen.row_of(i) - Gen.row_of(far)),
				absi(Gen.col_of(i) - Gen.col_of(far)))
			var when := now + Motion.stagger(step, Motion.RESET_STAGGER)
			_bump[i] = when
			# **A cell can only be leaving once.** `_draw_leaving`'s "has the
			# player written here again?" guard reads the *current* state,
			# and after a second `clear_board` the current state is empty
			# again -- so it cannot tell a ghost this Reset has just made
			# from one an earlier Reset made, and both would draw over each
			# other, each fading on its own schedule. Two plain Resets do not
			# reach here twice for one cell (the second skips a cell that is
			# already empty); write a digit, Reset, write another into that
			# same cell and Reset again, and you do. Nothing in the state can
			# separate the two generations, so the cell index has to: the old
			# entry goes before the new one is appended.
			_leaving = _leaving.filter(func(g: Dictionary) -> bool: return int(g.i) != i)
			# The copy the wave will carry out; see `_leaving` and
			# `_draw_leaving`. Taken before clear_board empties the state.
			_leaving.append({"i": i, "d": int(state.grid[i]),
				"notes": int(state.notes[i]), "at": when})
			_busy_for(when - now + Motion.BUMP_TIME)
	state.clear_board()
	_sel = -1
	_wrong = {}
	_flash = {}
	_drop = {}
	_shiver = {}
	_bad = {}
	_tumbling = []
	_twirl = {}
	_boing = {}
	_home = {}
	_break_streak()
	_update_stickers(now)

# --- the win ---

## The whole grid waves along the diagonal with the family's stagger, and
## every seventh cell sparkles in gold; the win screen follows WIN_WAIT later.
func _on_solved() -> void:
	var now := _now()
	_tip_timer.stop()
	_won_at = now
	_sel = -1
	_wrong = {}
	_say(tr("SD_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 or max_moves > 0 else checks == 0)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = now
		_combo_layer.queue_redraw()
	_party()
	if not Motion.reduce:
		for i in Gen.CELLS:
			var when := now + _solve_delay(Gen.row_of(i) + Gen.col_of(i))
			_flash[i] = when
			_bump[i] = when
			_busy_for(when - now + maxf(WAVE_FLASH, Motion.BUMP_TIME))
		# Three sparkles marching down the main diagonal with the wave, at a
		# quarter, the middle and three quarters of it. Three and not eighty-
		# one because Fx2D's sparkle pool is three: a fourth would recycle
		# the first emitter and cut its burst in half. Spaced four diagonals
		# apart they are used once each and never reclaimed mid-flight.
		var span := 2 * (Gen.N - 1)
		for d in [span / 4, span / 2, span * 3 / 4]:
			var k: int = d / 2
			_fx_due.append({"at": now + _solve_delay(d),
				"where": cell_to_local(k, k)})
	_redraw()

## A completed daily is rebuilt from its seed, so it opens on the givens.
## Write the answer into every cell and settle the board as it stands once
## the solve's wave has passed: no selection, no pencil marks, no Check
## marks, no entrance and no moment still owed. Not check_solved(): the host
## owns the win screen and `solved` must not fire a second time.
func restore_completed_board() -> void:
	if state == null:
		return
	# Retires the entrance's queued cues (the hills' rise) on a reopened day.
	_gen += 1
	var now := _now()
	_tip_timer.stop()
	state.grid = state.sol.duplicate()
	state.notes = PackedInt32Array()
	state.notes.resize(Gen.CELLS)
	state.history = []
	_sel = -1
	_pencil = false
	_wrong = {}
	_flash = {}
	_bump = {}
	_drop = {}
	_shiver = {}
	_leaving = []
	_fx_due = []
	_hold_until = 0.0
	# The entrance long over, so the grid is at full size and every given
	# fully inked.
	_opened = now - 10.0
	_won_at = now - 10.0
	_anim_until = 0.0
	# Every sticker open, the hills risen and glowing, and the seal down when
	# the solve earned one (a flawless one kept that in its record; any
	# Insane solve earns the night seal).
	_deal()
	_hills_at = now - 20.0
	_glow_at = now - 10.0
	_flawless = bool(completed_record.get("flawless", false))
	hearts = clampi(int(completed_record.get("hearts", max_hearts)), 0, max_hearts)
	moves_left = clampi(int(completed_record.get("moves", max_moves)), 0, max_moves)
	for reg in Gen.N:
		_sticker[reg] = {"at": now - 10.0, "open": true}
	if _flawless or state.band == 3:
		_stamp_at = now - 10.0
	_say(tr("SD_WIN"), Face.Expr.JOY)
	_redraw()
	for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
		layer.queue_redraw()

## Whether the solve was flawless, so a reopened daily keeps its seal, and
## how many hearts and moves it kept.
func completion_record() -> Dictionary:
	return {"flawless": _flawless, "hearts": hearts, "moves": moves_left}

func share_glyphs() -> String:
	if state == null:
		return ""
	if state.band == 3:
		return "🌙 " + tr("SD_HILLS_SEAL") + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	if _flawless:
		return "🏅 " + tr("BN_FLAWLESS")
	return ""

## When the solve's wave reaches anti-diagonal `d` (row + col, 0 to 16).
##
## **The last two diagonals share a beat and that is left alone.**
## `Motion.stagger` caps at 0.6 s, and 16 x SOLVE_STAGGER is 0.64, so
## r+c = 15 and r+c = 16 both land at 0.6. That is three cells of eighty-one
## -- (7,8), (8,7) and (8,8) -- at the very tail of a wave that has already
## been running for most of a second, and nobody will catch it. The cap is
## the family's promise that no cell waits longer than 0.6 s to be answered,
## and `stagger` does take a `cap` parameter, so raising it here would be
## legal; it would also make Sudoku's solve the slowest wave in the game for
## a difference of four hundredths on three cells. The family's number wins.
func _solve_delay(diagonal: int) -> float:
	return Motion.SOLVE_DELAY + Motion.stagger(diagonal, Motion.SOLVE_STAGGER)

## Fires the sparkles that have come due, in the order they were queued.
func _deliver_fx(now: float) -> void:
	while not _fx_due.is_empty() and now >= float(_fx_due[0].at):
		var due: Dictionary = _fx_due.pop_front()
		fx.sparkle(due.where, Pal.SUN)

# --- the sprout's line ---

## The chrome is the host's; here the grid pops in wide after the family's
## delay and the givens fade in region by region behind it.
func _enter() -> void:
	_opened = _now()
	_busy_for(_enter_delay(Gen.CELLS - 1) + Motion.DROP_TIME)
	fx.cue("enter")
	_hills_at = INF
	if not state.hills.is_empty():
		var lead := 0.0 if Motion.reduce else HILLS_AFTER
		_hills_at = _opened + lead
		_busy_for(lead + 2.0 * (Gen.N - 1) * HILL_STEP + HILL_RISE)
		_after(lead, fx.cue.bind("hills"))

## What the tip card showed. The card (ui/flat/tip_card.gd) was removed on
## 2026-09-24 as nothing had loaded it since the first-play tutorial replaced
## it; the line stays for whatever speaks the board's tips next.
func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal. A refused tap is not a move, so this is
	# the only thing that can push a refusal's line out.
	focus_changed.emit()

## A line that owns the card for SAY_HOLD seconds, after which the cycling
## rules resume. Every refusal and every Check goes through it.
func _speak(line: String, mood: int) -> void:
	_say(line, mood)
	_hold_until = _now() + SAY_HOLD
	if get_tree() == null:
		return
	get_tree().create_timer(SAY_HOLD).timeout.connect(_resume_tips)

func _resume_tips() -> void:
	if is_done() or out_of_hearts or _now() < _hold_until - 0.01:
		return
	_say(_tip(_tip_idx), Face.Expr.HAPPY)

func _tip(k: int) -> String:
	var tips := _tips()
	var line: String = tr(tips[k % tips.size()])
	return line % Gen.N if line.contains("%d") else line

func _cycle_tip() -> void:
	if is_done() or out_of_hearts or _now() < _hold_until:
		return
	_tip_idx = (_tip_idx + 1) % _tips().size()
	_say(_tip(_tip_idx), Face.Expr.HAPPY)

# --- the polish's drawing: hills, stickers, a hill's reach ---

## Control-local centre of cell `i`.
func _mid(i: int) -> Vector2:
	return cell_to_local(Gen.row_of(i), Gen.col_of(i))

## A selected hill lights the (up to) four cells it counts with a leaf rim,
## so the player can see what it looks at.
func _reach(b: Face.Builder, k: float) -> void:
	if _sel < 0 or not state.has_hill(_sel):
		return
	for j in Gen.beside(_sel):
		var quad := _wash_quad(j, 0.0, 1.0)
		b.fan(quad, Color(Pal.LEAF, 0.1))
		b.stroke(quad, REACH_W * k, Color(Pal.LEAF, 0.75), true)

## Every hill on the grid, over the cells and the selected tile: a green mound
## in the cell's lower right with a dot for each lower cell beside it. It
## rises in along the diagonal after the entrance, turns gold once its count
## comes true around it, sits on a rose halo while what is written beside it
## cannot come true, and glows gold at the party.
## Each into its own run: a hill at rest (risen, unbumped, its glow none or
## full) is its shape copied under its foot, one on the move drawn live.
func _hills(now: float, k: float) -> void:
	if state.hills.is_empty():
		return
	var glow := 0.0
	if now >= _glow_at:
		glow = 1.0 if Motion.reduce else clampf((now - _glow_at) / HILL_GLOW, 0.0, 1.0)
	var lit := glow > 0.0 and not Motion.reduce
	for i in Gen.CELLS:
		if state.hills[i] < 0:
			continue
		var rise := 1.0
		if not Motion.reduce:
			var e := now - _hills_at - (Gen.row_of(i) + Gen.col_of(i)) * HILL_STEP
			rise = 0.0 if e <= 0.0 else Motion.pop_in_scale(e, HILL_RISE).y
		if rise <= 0.01:
			continue
		var foot := _mid(i) + Vector2(HILL_AT.x * _cell + _cell_shift(now, i), HILL_AT.y * _cell)
		if i == _sel:
			foot.y -= SEL_LIFT * k
		var grow := _cell_grow(now, i)
		var standing: int = state.hill_standing(i)
		var body: Color = Pal.LEAF
		if standing > 0:
			body = Pal.LEAF.lerp(Pal.SUN_RAY, 0.55)
		body = body.lerp(Pal.SUN_RAY, glow)
		var colours := [Color(Pal.BAD, 0.32), Color(Pal.TEXT, 0.12), body.darkened(0.18), body,
			Color(Pal.SURFACE, 0.45), Pal.SURFACE, Color(Pal.SUN_TILE, glow)]
		_rm.open(PART_HILL, i)
		if rise == 1.0 and grow == 1.0 and (glow == 0.0 or glow == 1.0):
			_rm.put(_hill_id(standing < 0, lit, state.hills[i]), colours, Transform2D(0.0, foot))
			continue
		var live := Face.Builder.new()
		_hill(live, foot, HILL_W * _cell * grow, HILL_H * _cell * rise, rise, state.hills[i],
			standing < 0, glow if lit else 0.0, colours)
		_rm.put_builder(live)

## The colours a hill is drawn in: the halo, its shadow, the mound's rim and
## body, its shine, the dots and the party's glow.
const HILL_COLOURS := 7

## One hill `w` wide and `h` tall standing on `foot`, its dots `rise` grown,
## in `colours` (HILL_COLOURS of them: real ones, or RunMesh slots).
func _hill(b: Face.Builder, foot: Vector2, w: float, h: float, rise: float, dots: int,
		halo: bool, glow: float, colours: Array) -> void:
	if halo:
		b.ellipse(foot - Vector2(0.0, h * 0.45), w * 0.66, h * 0.95, colours[0])
	b.ellipse(foot + Vector2(0.0, h * 0.06), w * 0.52, h * 0.16, colours[1])
	b.polygon(_mound(foot, w * 0.5, h), colours[2])
	b.polygon(_mound(foot - Vector2(0.0, h * 0.08), w * 0.46, h * 0.9), colours[3])
	b.ellipse(foot + Vector2(-w * 0.16, -h * 0.62), w * 0.1, h * 0.12, colours[4])
	var r := HILL_DOT * _cell
	var gap := r * 2.6
	for n in dots:
		var x := (float(n) - (dots - 1) * 0.5) * gap
		b.disc(foot + Vector2(x, -h * 0.42), r * rise, colours[5])
	if glow > 0.0:
		b.disc(foot + Vector2(w * 0.3, -h * 0.9), r * 0.8 * glow, colours[6])

## The outline of a mound `hw` half-wide and `h` tall standing on `foot`.
static func _mound(foot: Vector2, hw: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	const STEPS := 16
	for n in STEPS + 1:
		var a := PI + PI * float(n) / STEPS
		pts.append(foot + Vector2(cos(a) * hw, sin(a) * h))
	return pts

func _hills_moving(now: float) -> bool:
	if state == null or state.hills.is_empty() or Motion.reduce:
		return false
	var span := 2.0 * (Gen.N - 1) * HILL_STEP + HILL_RISE
	return (now >= _hills_at and now < _hills_at + span) \
		or (now >= _glow_at and now < _glow_at + HILL_GLOW)

## A finished region's daisy sticker opening or folding in its panel's top
## right corner (Queens' flowers).
## Each into its own run: a daisy fully open is its region's shape copied
## under its spot, one opening or folding drawn live.
func _stickers(now: float) -> void:
	var size := Vector2(Gen.BOX_C, Gen.BOX_R) * _cell
	var per_row: int = Gen.N / Gen.BOX_C
	var colours := [Pal.FLOWER.darkened(0.12), Pal.FLOWER, Pal.SUN, Color(Pal.SURFACE, 0.6)]
	# In region order, the order their runs were laid.
	for reg in Gen.N:
		if not _sticker.has(reg):
			continue
		var st: Dictionary = _sticker[reg]
		var e := now - float(st.at)
		var open := 0.0
		if bool(st.open):
			open = 1.0 if Motion.reduce else Motion.pop_in_scale(e, STICKER_TIME).x
		elif not Motion.reduce and e < STICKER_FOLD:
			open = 1.0 - e / STICKER_FOLD
		if open <= 0.01:
			continue
		var br: int = int(reg) / per_row
		var bc: int = int(reg) % per_row
		var corner := _grid + Vector2(bc + 1, br) * size
		var at := corner + Vector2(-STICKER_AT.x, STICKER_AT.y) * _cell * 0.62
		_rm.open(PART_STICKER, int(reg))
		if open == 1.0:
			_rm.put(SHAPE_DAISY + int(reg), colours, Transform2D(0.0, at))
			continue
		var live := Face.Builder.new()
		_daisy(live, at, _cell * STICKER_R * open, _sticker_turn(int(reg), open), colours)
		_rm.put_builder(live)

## How far region `reg`'s daisy is turned, `open` of the way open.
func _sticker_turn(reg: int, open: float) -> float:
	var per_row: int = Gen.N / Gen.BOX_C
	return (1.0 - open) * 1.2 + _hash(reg / per_row, reg % per_row + 7) * 0.6

func _stickers_moving(now: float) -> bool:
	if Motion.reduce:
		return false
	for reg in _sticker:
		var e := now - float(_sticker[reg].at)
		if e >= 0.0 and e < maxf(STICKER_TIME, STICKER_FOLD):
			return true
	return false

## A little daisy: five petals round a sun-gold eye, in `colours` (the
## petals' rim and body, the eye, its shine: real ones, or RunMesh slots).
func _daisy(b: Face.Builder, at: Vector2, r: float, turn: float, colours: Array) -> void:
	for n in 5:
		var a := turn + TAU * n / 5.0
		b.ellipse(at + Vector2.from_angle(a) * r * 0.62, r * 0.42, r * 0.42, colours[0])
		b.ellipse(at + Vector2.from_angle(a) * r * 0.6, r * 0.36, r * 0.36, colours[1])
	b.disc(at, r * 0.36, colours[2])
	b.disc(at - Vector2(r, r) * 0.1, r * 0.12, colours[3])

## Which regions are finished now, against what the stickers show: a region
## that has just come right opens its daisy, one that has come apart folds it.
func _update_stickers(now: float) -> void:
	var units: Array = Gen.units()
	for reg in Gen.N:
		var done := state.unit_done(units[2 * Gen.N + reg])
		var shown: bool = _sticker.has(reg) and bool(_sticker[reg].open)
		if done and not shown:
			_sticker[reg] = {"at": now + (0.0 if Motion.reduce else Motion.WAVE_STEP * 3.0), "open": true}
			_after(0.0 if Motion.reduce else Motion.WAVE_STEP * 3.0, fx.cue.bind("bloom"))
		elif shown and not done:
			_sticker[reg] = {"at": now, "open": false}
	_dirty = true

# --- the numerals the polish adds ---

## The numbers a lost heart ruled out of an empty cell: small, in rose, each
## struck through, in the pencil marks' own seats.
func _draw_ruled(i: int, font: Font, px: int, rise: float) -> void:
	var mask: int = int(state.ruled[i])
	var ink := Color(Pal.BAD, RULED_A)
	for n in range(1, Gen.N + 1):
		if mask & (1 << (n - 1)) == 0:
			continue
		var spot := _note_spot(n)
		_numeral(font, px, rise, str(n), spot, ink)
		var half := px * 0.36
		draw_line(spot + Vector2(-half, half * 0.6), spot + Vector2(half, -half * 0.6), ink, maxf(2.0, px * 0.09), true)

## A wrong number tumbling off the paper: it tips over, drops and fades.
func _draw_tumbling(now: float, pop: float, centre: Vector2, font: Font, px: int, rise: float) -> void:
	if _tumbling.is_empty():
		return
	var keep: Array = []
	for t in _tumbling:
		var e: float = now - float(t.at)
		if e >= TUMBLE_TIME or Motion.reduce:
			continue
		keep.append(t)
		var u := e / TUMBLE_TIME
		var i: int = t.i
		var side := 1.0 if _hash(i, 3) > 0.5 else -1.0
		var at := _mid(i) + Vector2(side * 0.18 * _cell * u, TUMBLE_FALL * _cell * u * u)
		_seat(at, centre, pop, 1.0 - 0.3 * u, Vector2.ONE, side * TUMBLE_TURN * u)
		_numeral(font, px, rise, str(t.d), Vector2.ZERO, Color(Pal.BAD, 1.0 - u * u))
	_tumbling = keep

# --- the layers over the board ---

func _tick_layers(now: float) -> void:
	if _heart_layer == null:
		return
	if (_split_index >= 0 and now - _split_at < SPLIT_TIME + 0.1) \
			or (_back_index >= 0 and now - _back_at < HEART_BACK_TIME + 0.1) \
			or now - _opened < Motion.ENTER_DELAY + Motion.POP_IN + 0.1 \
			or _moves_pill.animating(now - 0.1):
		_heart_layer.queue_redraw()
	if _combo_n >= COMBO_FROM and (now - _combo_at < COMBO_HOLD + 0.1 or _combo_out_at > -INF):
		_combo_layer.queue_redraw()
	var alive := _tick_life(now)
	if alive or _life_alive:
		_life_layer.queue_redraw()
	_life_alive = alive

## The hearts over the tray as one mesh on a paper pill (Queens'): pink with
## a small face and a leaf, a faint ghost where one was, the lost one's halves
## falling apart, and one coming back popping in.
func _draw_hearts() -> void:
	if max_moves > 0 and _cell > 0.0 and _current():
		_moves_pill.draw(_heart_layer, Vector2(_hearts_x(), _hearts_y), moves_left, _now())
		return
	if max_hearts <= 0 or _cell <= 0.0 or not _current():
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := _hearts_y
	var x0 := _hearts_x() - step * (max_hearts - 1) * 0.5
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var corner := Vector2(_hearts_x(), y) - pill * 0.5
	var rim := Vector2.ONE * HEART_PILL_RIM
	var enter := Motion.pop_in_scale(now - _opened - Motion.ENTER_DELAY).x
	b.polygon(Face.Builder.round_rect(corner - rim, pill + 2.0 * rim, pill.y * 0.5 + HEART_PILL_RIM), Pal.LINE)
	b.polygon(Face.Builder.round_rect(corner, pill, pill.y * 0.5), Pal.SURFACE)
	for i in max_hearts:
		var at := Vector2(x0 + step * i, y)
		if i < hearts or (i == _split_index and now < _split_at):
			var r := HEART_R
			if i == _back_index and not Motion.reduce:
				r *= Motion.pop_in_scale(now - _back_at, HEART_BACK_TIME).x
			if r > 0.5:
				b.polygon(_heart(at, r, -1), Pal.FLOWER)
				b.polygon(_heart(at, r, 1), Pal.FLOWER_DEEP)
				_heart_face(b, at, r)
			continue
		b.polygon(_heart(at, HEART_R, 0), Color(Pal.FLOWER, 0.22))
		var u := (now - _split_at) / SPLIT_TIME
		if i == _split_index and u < 1.0 and not Motion.reduce:
			var fade := 1.0 - u * u
			for side in [-1, 1]:
				var turn: float = side * SPLIT_TURN * u
				var shift := Vector2(side * SPLIT_SPREAD * u, SPLIT_FALL * u * u)
				var pts := _heart(Vector2.ZERO, HEART_R, side)
				for n in pts.size():
					pts[n] = at + shift + pts[n].rotated(turn)
				b.polygon(pts, Color(Pal.FLOWER if side < 0 else Pal.FLOWER_DEEP, fade))
	_hearts_shown = b.mesh()
	var c := Vector2(_hearts_x(), y)
	_heart_layer.draw_set_transform(c * (1.0 - enter), 0.0, Vector2.ONE * enter)
	_heart_layer.draw_mesh(_hearts_shown, null)
	_heart_layer.draw_set_transform(Vector2.ZERO)

## Where the hearts' pill is centred across: over the grid (the tutorial's
## stands it over the pad beside its grid).
func _hearts_x() -> float:
	return size.x * 0.5

## A heart's small face: two dots and a smile in ink, a shine at the top left,
## and a leaf on top.
static func _heart_face(b, at: Vector2, s: float) -> void:
	b.ellipse(at + Vector2(-0.5, -0.5) * s, 0.16 * s, 0.1 * s, Color(1.0, 1.0, 1.0, 0.45))
	for sx in [-1.0, 1.0]:
		b.disc(at + Vector2(sx * 0.28, -0.12) * s, 0.09 * s, Pal.OUTLINE)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, 0.02) * s, 0.16 * s, PI * 0.2, PI * 0.8), 0.07 * s, Pal.OUTLINE)
	b.ellipse(at + Vector2(0.25, -0.76) * s, 0.24 * s, 0.11 * s, Pal.LEAF)

## A heart `s` half-wide about `at` (side 0), or its left (-1) or right (1)
## half, split along a zigzag crack so the two halves fit together
## (Binairo's; its notes say why the crack leaves the tip straight up).
static func _heart(at: Vector2, s: float, side: int) -> PackedVector2Array:
	const STEPS := 36
	var k := s / 16.0
	var off := Vector2(0.0, -2.5)
	var pts := PackedVector2Array()
	var from := 0.0 if side >= 0 else PI
	var to := TAU if side == 0 else from + PI
	var count := STEPS if side == 0 else STEPS / 2 + 1
	for i in count:
		var t := lerpf(from, to, float(i) / float(STEPS if side == 0 else STEPS / 2))
		var p := Vector2(16.0 * pow(sin(t), 3.0),
			-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)))
		pts.append(at + (p + off) * k)
	if side == 0:
		return pts
	var zig := [Vector2(0.0, 13.0), Vector2(1.5, 8.0), Vector2(-1.5, 3.0), Vector2(1.0, -2.0)]
	if side < 0:
		zig.reverse()
	for z: Vector2 in zig:
		pts.append(at + (z + off) * k)
	return pts

## The streak's paper bubble at the upper right of the cell, "x3" and up in
## leaf ink: it pops in the first time, bumps at each number and deflates
## when the streak ends (One Line's).
func _draw_combo() -> void:
	if _combo_n < COMBO_FROM or _cell <= 0.0 or not _current():
		return
	var now := _now()
	var k := 1.0
	var alpha := 1.0
	if _combo_out_at == -INF and now - _combo_at >= COMBO_HOLD:
		_combo_out_at = now
	if _combo_out_at > -INF:
		var u := (now - _combo_out_at) / COMBO_DEFLATE
		if u >= 1.0 or Motion.reduce:
			_combo_n = 0
			return
		k = 1.0 - 0.75 * u * u
		alpha = 1.0 - u
	elif not Motion.reduce:
		var e := now - _combo_at
		k = Motion.pop_in_scale(e).x if _combo_popped else Motion.bump_scale(e)
	if k <= 0.01:
		return
	var font: Font = CozyTheme.display(700)
	var text := "x%d" % _combo_n
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT).x
	var box := Vector2(tw + 30.0, COMBO_FONT + 16.0)
	var tail := _mid(_combo_cell) + Vector2(_cell * 0.25, -_cell * 0.4)
	var centre := tail + Vector2(box.x * 0.35, -box.y * 0.75)
	centre.x = clampf(centre.x, box.x * 0.5 + 4.0, size.x - box.x * 0.5 - 4.0)
	centre.y = maxf(centre.y, box.y * 0.5 + 4.0)
	var b := Face.Builder.new()
	var tip := tail - centre
	var root := Vector2(clampf(tip.x, -box.x * 0.3, box.x * 0.3), box.y * 0.3)
	b.polygon(PackedVector2Array([root + Vector2(-9.0, 0.0), tip, root + Vector2(9.0, 0.0)]), Pal.LINE)
	b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2(2.0, 2.0), box + Vector2(4.0, 4.0), box.y * 0.5 + 2.0), Pal.LINE)
	b.polygon(PackedVector2Array([root + Vector2(-6.5, -2.0), tip + (root - tip).normalized() * 3.0, root + Vector2(6.5, -2.0)]), Pal.SURFACE)
	b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
	_combo_shown = b.mesh()
	_combo_layer.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	_combo_layer.draw_mesh(_combo_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	var ascent := font.get_ascent(COMBO_FONT)
	var descent := font.get_descent(COMBO_FONT)
	_combo_layer.draw_string(font, Vector2(-tw * 0.5, (ascent - descent) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.LEAF_DEEP, alpha))
	_combo_layer.draw_set_transform(Vector2.ZERO)

## Keeps the life layer drawing while anything on it moves.
func _tick_life(now: float) -> bool:
	var still: Array = []
	for l in _love:
		if now < float(l.t) + LOVE_TIME:
			still.append(l)
	_love = still
	return not _love.is_empty() or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## The life over the board: love hearts floating off a number, and the seal
## after the solve, with its words.
func _draw_life() -> void:
	if _cell <= 0.0 or not _current():
		_life_shown = []
		return
	var now := _now()
	var shown: Array = []
	if not _love.is_empty():
		var mesh := _love_heart()
		shown.append(mesh)
		for l in _love:
			var e: float = now - float(l.t)
			if e <= 0.0:
				continue
			var u := e / LOVE_TIME
			var at: Vector2 = l.at + Vector2(sin(u * TAU + float(l.phase)) * 0.08 * _cell,
				-LOVE_RISE * _cell * (1.0 - (1.0 - u) * (1.0 - u)))
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.2, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.4, 0.0, 1.0)))
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_life_shown = shown

## A little pink heart for the love gag, built once a layout.
func _love_heart() -> ArrayMesh:
	if _love_mesh == null:
		var b := Face.Builder.new()
		var r := _cell * LOVE_R
		b.polygon(_heart(Vector2.ZERO, r * 1.15, 0), Pal.FLOWER_DEEP)
		b.polygon(_heart(Vector2.ZERO, r, 0), Pal.FLOWER)
		b.ellipse(Vector2(-0.45, -0.45) * r, 0.18 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
		_love_mesh = b.mesh()
	return _love_mesh

## The seal on the tray's lower right, dropping in from STAMP_FROM its size
## and settling with the back ease's overshoot, its words over it.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	var insane: bool = state.band == 3
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var field := _cell * Gen.N
	var centre := _grid + Vector2(field, field) - Vector2(rad * 0.45, rad * 0.3)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless else tr("SD_HILLS_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- rewards ---

## A right number (on Hard and Insane the answer's; on Easy and Medium any
## number that clashes with nothing, which reveals nothing) builds the streak
## -- a tick a semitone higher from the second, the bubble from the third,
## confetti at five and ten -- now and then plays a gag, and when it is the
## last of its number home, every one of them hops.
func _on_right(i: int, d: int) -> void:
	if is_done():
		return
	var land := 0.0 if Motion.reduce else LAND_AT
	_streak += 1
	if _streak >= 2:
		var step: int = COMBO_STEPS[mini(_streak - 2, COMBO_STEPS.size() - 1)]
		_after(land, func() -> void:
			if not is_done():
				fx.cue("combo", pow(2.0, step / 12.0), COMBO_DB))
	if _streak >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = _streak
		_combo_cell = i
		_combo_at = _now()
		_combo_out_at = -INF
		_combo_layer.queue_redraw()
	if COMBO_CONFETTI.has(_streak) and not Motion.reduce:
		_after(land, func() -> void:
			if is_done():
				return
			fx.confetti(_mid(i), 22)
			fx.cue("confetti"))
	if state.count_of(d) == Gen.N and not _any_clash_of(d):
		_all_home(d)
	else:
		_gag(i, land)

func _any_clash_of(d: int) -> bool:
	for c in _clash:
		if state.grid[c] == d:
			return true
	return false

## The streak ends: a take-out, a clash, a wrong number, an undo, a reset, the
## hearts running out. The bubble deflates.
func _break_streak() -> void:
	_streak = 0
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
		if _combo_layer != null:
			_combo_layer.queue_redraw()
	else:
		_combo_n = 0

## Every one of `d` is on the grid: each hops in a wave out from the last one
## placed, in reading order, with a sparkle at the end, and the line cheers.
func _all_home(d: int) -> void:
	if state.is_solved():
		return
	var now := _now()
	var n := 0
	for c in Gen.CELLS:
		if state.grid[c] != d:
			continue
		if not Motion.reduce:
			_home[c] = now + LAND_AT + n * HOME_STEP
		n += 1
	_busy_for(LAND_AT + n * HOME_STEP + HOME_TIME)
	_after(0.0 if Motion.reduce else LAND_AT, func() -> void:
		if is_done():
			return
		fx.cue("all_home")
		_speak(tr("SD_ALL_HOME") % d, Face.Expr.JOY))

## Three right numbers in five play a gag, picked by the cell's hash so a day
## replays the same: little hearts float up off it; it twirls a whole turn;
## or it boings three times. Under reduce-motion, none.
func _gag(i: int, land: float) -> void:
	if Motion.reduce or is_done() or state.is_solved():
		return
	var roll := posmod(hash(Vector2i(i * 13 + 7, _streak * 5 + 3)), GAG_ODDS)
	if roll >= GAGS:
		return
	var now := _now()
	match roll:
		0:
			var at := _mid(i) - Vector2(0.0, _cell * 0.2)
			for n in LOVE_HEARTS:
				var off := Vector2((n - (LOVE_HEARTS - 1) * 0.5) * 0.22, -0.2) * _cell
				_love.append({"at": at + off, "t": now + land + n * 0.08, "phase": _hash(i, n + 11) * TAU})
			_after(land, fx.cue.bind("love"))
		1:
			_twirl[i] = now + land
			_busy_for(land + TWIRL_TIME)
			_after(land, func() -> void:
				fx.sparkle(_mid(i) - Vector2(0.0, _cell * 0.3), Pal.SUN)
				fx.cue("twirl"))
		2:
			_boing[i] = now + land
			_busy_for(land + BOING_TIME)
			_after(land, func() -> void:
				fx.puff(_mid(i) + Vector2(0.0, _cell * 0.3), Pal.SURFACE_HI, 4)
				fx.cue("boing"))

# --- failing ---

## `cost` moves go off Insane's counter. The last one gone with the grid
## unfinished ends the board once the number has landed (`land`).
func _spend(cost: int, land: float) -> void:
	if max_moves <= 0 or cost <= 0:
		return
	moves_left = maxi(0, moves_left - cost)
	_moves_pill.bump(_now())
	_heart_layer.queue_redraw()
	if moves_left > 0 or is_done() or state.is_solved():
		return
	_lost_ever = true
	out_of_hearts = true
	_running = false
	moved.emit()
	_after(maxf(0.0, land - _now()), _run_out)

## A number the answer does not hold there, on Hard or Insane: it lands like
## any other, then its cell blushes and a heart splits, and EJECT_AFTER later
## it tumbles off the paper and that number is crossed out of that cell.
func _wrong_digit(i: int, d: int) -> void:
	if hearts <= 0 or is_done():
		return
	var land := 0.0 if Motion.reduce else LAND_AT
	hearts -= 1
	_lost_ever = true
	_break_streak()
	_split_index = hearts
	_split_at = _now() + land
	_ejecting = true
	if hearts <= 0:
		out_of_hearts = true
		_running = false
	_bad[i] = true
	_after(land, func() -> void:
		_heart_layer.queue_redraw()
		fx.cue("heart_lost")
		if not Motion.reduce:
			fx.puff(_mid(i), Pal.BAD, 4)
			_shiver[i] = _now()
			_busy_for(Motion.SHIVER_TIME)
		_speak(tr("SD_WRONG"), Face.Expr.WORRIED)
		_redraw())
	_busy_for(land + EJECT_AFTER + TUMBLE_TIME)
	_after(land + (0.0 if Motion.reduce else EJECT_AFTER), _tumble.bind(i, d))

## The wrong number falls off the paper, and the cell keeps it crossed out.
func _tumble(i: int, d: int) -> void:
	_ejecting = false
	if is_done() or not _bad.has(i):
		return
	_bad.erase(i)
	var now := _now()
	state.reject(i)
	_drop.erase(i)
	if not Motion.reduce:
		_tumbling.append({"i": i, "d": d, "at": now})
		_busy_for(TUMBLE_TIME)
	fx.cue("tumble")
	_update_stickers(now)
	moved.emit()
	_redraw()
	if out_of_hearts:
		_after(0.0 if Motion.reduce else TUMBLE_TIME, _run_out)

## The last heart is gone: the tray slips to dusk, the line yawns, and the
## card comes up.
func _run_out() -> void:
	if _asleep:
		return
	_asleep = true
	_break_streak()
	_tip_timer.stop()
	fx.cue("out_of_hearts")
	_say(tr("SD_OUT"), Face.Expr.SLEEPY)
	_dusk_toward(DUSK)
	_redraw()
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

func _dusk_toward(tint: Color) -> void:
	Motion.stop(_dusk_tw)
	if Motion.reduce:
		modulate = tint
		return
	_dusk_tw = create_tween()
	_dusk_tw.tween_property(self, "modulate", tint, DUSK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## The card, over the whole screen: laid on the host so it covers the chrome,
## or on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, [], MOVES_BONUS) if max_moves > 0 \
		else load(OUT_OF_HEARTS).new(_heart_used, ["SD_OUT_BODY", "SD_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave_board)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same grid from its givens in Reset's wave, every heart back
## and the crossed-out numbers gone, the day's light, the clock and the moves
## from zero; hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	_wipe()
	state.ruled = {}
	_deal()
	elapsed = 0.0
	checks = 0
	moves = 0
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_running = true
	_tip_idx = 0
	_hold_until = 0.0
	_say(_tip(0), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	moved.emit()
	_redraw()

## One more heart (the card's video): once a board. The light comes back.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	if max_moves > 0:
		moves_left = MOVES_BONUS
		_moves_pill.bump(_now())
	else:
		hearts = 1
		_back_index = 0
		_back_at = _now()
	_heart_layer.queue_redraw()
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	_resume_tips()
	_tip_timer.start()
	moved.emit()
	_redraw()

## Back from the card: the board ends unsolved first, so the host logs
## puzzle_complete {solved: false} and not an abandon.
func _leave_board() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

## Holds the host's hint video while a wrong number is still on the paper.
func busy() -> bool:
	return _ejecting

# --- the party ---

## After the solve wave: the numbers dance on the beat, confetti sweeps the
## tray twice, on Insane the hills glow gold, the seal stamps when the solve
## earned one (flawless, or any Insane grid), and the line shares a silly bit
## of number wisdom. Under reduce-motion the glow and the seal stand at once.
func _party() -> void:
	var now := _now()
	var lead := 0.0 if Motion.reduce else PARTY_AT
	_after(lead, func() -> void:
		_say(_cheer(), Face.Expr.JOY))
	if not state.hills.is_empty():
		_glow_at = now + lead * 0.5
		_busy_for(lead * 0.5 + HILL_GLOW)
		_after(lead * 0.5, fx.cue.bind("hills_glow"))
	if _flawless or state.band == 3:
		_stamp_at = now if Motion.reduce else now + lead + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	if Motion.reduce:
		return
	var field := Rect2(_grid, Vector2.ONE * Gen.N * _cell)
	_after(lead + 0.15, func() -> void:
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell * 0.3), 30, field.size.x * 0.9)
		fx.cue("party"))
	_after(lead + 0.6, func() -> void:
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	_dance_at = now + lead + 0.35
	_busy_for(lead + 0.35 + DANCE_BEAT * (DANCE_BEATS + 1))
	_after(lead + 0.35, fx.cue.bind("dance"))

func _dancing(now: float) -> bool:
	return now >= _dance_at and now < _dance_at + DANCE_BEAT * (DANCE_BEATS + 1)

## One of CHEERS silly bits of number wisdom, picked by the grid itself, so a
## day always gets the same one.
func _cheer() -> String:
	return tr("SD_CHEER_%d" % posmod(hash(state.sol), CHEERS))

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	if get_tree() == null:
		return
	var gen := _gen
	get_tree().create_timer(maxf(delay, 0.0)).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

# --- odds and ends ---

## Whether Gen's geometry is still this board's. Gen holds one size at a
## time, and a board being replaced by one of another band (the mini by
## hard) lives a frame after the new one has switched Gen over; it must not
## read the new geometry against its own arrays in that frame.
func _current() -> bool:
	return state != null and state.grid.size() == Gen.CELLS

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
