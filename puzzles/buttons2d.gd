extends "res://core/puzzle_base.gd"

## Jewel Box as a flat board (Button Box until 2026-10-19, and the code
## keeps its words: a button is a jewel, a patch a slot, the tin the case,
## sewn is set): a cream page from edge to edge (`"bleed": true` in
## ui/registry.gd), a picture of slots on it, each the colour of the jewel
## it wants and joined with its neighbours of that colour, with a jewel of
## the wrong colour on every one, and a white case at the foot. A move is
## two taps: the first picks a jewel and every one of its colour touching
## it, and they lift and draw together; the second says where they go -- a
## bare slot of their colour, where they are set, or the case. Nothing
## lands by itself (the user, 2026-10-11). The rules are in
## puzzles/buttons_state.gd, which this only draws.
##
## How it is drawn. `_bg` is the page (a layout); `_still` the picture's
## edge and the slots; `_tin` the case, rebuilt when it gains places.
## The buttons are unit meshes under transforms baked with Face.FlatBuilder:
## the ones at rest into a mesh a block of the cloth (`_blocks`, rebuilt
## only when a button of the block changes: Insane's picture is a thousand
## buttons), the ones doing something (`_live`) into one mesh a frame, a
## pick into `_held_mesh`, and the ones in the air into `_top`. The picture
## is on a layer of its own (`_cloth`) so that Hard and Insane, whose
## pictures are 24 and 32 square, can be looked at close: one transform
## (`zoom`, ui/flat/pan_zoom.gd) over the same meshes, clipped to the room
## between the pill and the tin. What flies between the cloth and the tin
## is drawn over both (`_over`), clipped while zoomed to the picture's top
## and the screen's foot so it never crosses the bar. The pill, the toast and the
## streak's bubble are on a layer of their own and never scale.
##
## How it moves. The flat boards' vocabulary (core/motion.gd,
## docs/art/flat-motion.md) read as curves. This board's own: a run leaving
## one jewel after another, each in an arc, far enough apart that each is
## seen to go (the user, 2026-10-19: "pieces should move one after another
## to make it more cozier"); a button settling into its
## socket as it lands (the drop's back ease, from a hair above) and, on its
## own colour, the square filling out from under it (the user, 2026-10-14:
## "the button slide in the slot and make it full when color is right"); a
## whole colour hopping outward from its last button; the tin's new place.

const State = preload("res://puzzles/buttons_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const Art = preload("res://ui/faces/button_art.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")
const MovesDiagram = preload("res://ui/hud/moves_tutorial_diagram.gd")
const PanZoom = preload("res://ui/flat/pan_zoom.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"
## The taps the out-of-moves card's video buys, once a board.
const MOVES_BONUS := 5

# --- the table ---
const PAD := 34.0
const HUD_ROW := 76.0
const GAP := 26.0
const BORDER := 18.0
## The border around the picture's shape: this much of a square wide, kept
## between OUTLINE_MIN and OUTLINE_MAX px so a big picture's stays seen and
## a small one's stays a border.
const OUTLINE_K := 0.4
const OUTLINE_MIN := 4.0
const OUTLINE_MAX := 12.0
## The case as the reference's (measured on the user's shots, 2026-10-19,
## "make it match"): twelve places a row, a place TIN_STEP_K of the
## screen's width whatever the picture's square, the panel TIN_WIDE of the
## width, and as many rows as the places need (Insane's sixty-four are six
## rows: the picture gives up the room). The panel hugs the places,
## TIN_PAD_X at the sides and TIN_PAD_Y above and below.
const TIN_ROW := 12
const TIN_WIDE := 0.87
const TIN_STEP_K := TIN_WIDE / TIN_ROW
const TIN_STEP := 96.0
const TIN_PAD_X := 2.0
const TIN_PAD_Y := 10.0
const CELL_MAX := 84.0
## A button in the tin, as a share of a place: the size it had there before
## the cloth's buttons changed, twice smaller and then the gem tile (0.86 of
## the old 0.8 across: 0.335 / Art.RIM).
const TIN_FIT := 0.838
## The tin's ring, which is cut with the tin's buttons, at the hollow's
## own size (0.4 of a place over the unit's 0.5 x TIN_FIT).
const TIN_RING := 0.955
## The zoom button's close: a square about this big on the screen (and
## CELL_MAX at the closest a pinch goes).
const NEAR_PX := 60.0
const ZOOM_B := 84.0
const ZOOM_INSET := 12.0
## The buttons at rest are baked a block of this many squares a side, on a
## picture over 16 square; a smaller picture is one block.
const BLOCK := 8
## A picture of more buttons than this moves as blocks: no button of it
## pops in by itself and the win hops a block at a time.
const BIG := 300
## The plain button (Art.SMALL) gives way to the whole one as the picture
## comes close, and back, a little apart so a pinch does not flicker.
const LOD_IN := 46.0
const LOD_OUT := 42.0
## A pick of more buttons than this stands still once lifted.
const HELD_BOB_MAX := 48

# --- motion: what is this board's own ---
## One jewel of a run leaves this long after the one before it: with a
## flight of FLY_TIME, two or three are in the air at once and each landing
## is its own (0.06 and a cap of 0.9 s kept five up and read as a stream;
## the user, 2026-10-19: "pieces should move one after another"). The cap
## only squeezes the case's biggest stows (48 on Insane); a stretch set or
## a stow of twenty keeps the step. Twice as fast since 2026-10-19 (the
## user: "increase speed of pieces move by 2x"): the flight, the step and
## the cap all halved (0.3, 0.12, 2.4), so the chain reads the same; then
## "double speed again": 0.075, 0.03, 0.6; then "slow it down 25%": the
## speed at three quarters, so 0.1, 0.04, 0.8. Then slower and smoother
## (the user, 2026-10-20: "reduce piece movement speed, and make it way
## smoother and more satisfact to watch"): 0.28, 0.08, 1.6, so each landing
## clears TICK_GAP and ticks on its own. Then the gap halved, the flight
## kept ("keep current flight time, but reduce gap between gems"): 0.04,
## 0.8, so every other landing ticks. Then 0.1 and no cap (the user,
## 2026-10-21: "they should fly one after another after 0.1s, not all at
## once"): the cap had squeezed a run of twenty or more to a burst. Then
## twice as quick (the user, the same day: "make the gap between pieces 2x
## faster"): 0.05. Then twice as quick again (the user, 2026-10-23:
## "double speed of gap between pieces"): 0.025.
const RUN_STEP := 0.025
## The case's own sliding along a place go one after another too, this
## far apart, the whole pack no longer than SLIDE_CAP (a pack on Insane
## can slide sixty places, and a place is not pickable until its jewel has
## landed).
const SLIDE_STEP := 0.03
const SLIDE_CAP := 0.45
## A pick comes up as a wave out of the tapped button: each one this long
## after its neighbour nearer the tap, the farthest no later than the cap
## (the user, 2026-10-11: "start pushing them in sequence on linked ones
## like a wave").
## Gone to 0 on 2026-10-19 (the user: "linked ones should select at once
## instead of into a wave"): the whole run lifts together; PICK_CAP only
## says when a big pick may stand still.
const PICK_STEP := 0.0
const PICK_CAP := 0.0
## A flight eases out and in on the smootherstep (no jolt at either end),
## rises on a parabola over the distance covered, leans into its way by up
## to FLY_TILT and back upright to land, its shadow shrinking as it climbs.
## Half the speed since 2026-10-20 (the user: "slow flight time by half"):
## 0.28 to 0.56. Back to 0.28 on 2026-10-21 (the user: "make flying time
## 2x faster"). Halved
## again to 0.14 on 2026-10-23 (the user: "increase fly speed of pieces"),
## then the speed at three quarters ("reduce fly speed by 25%"): 0.14 x 4/3,
## and at three quarters again ("reduce fly time more 25%", meant slower):
## 0.187 x 4/3. Then at half the speed (the user, 2026-10-29: "slow down
## flight speed by 50%"): 0.249 x 2.
const FLY_TIME := 0.498
## Every flight takes FLY_TIME, however far it goes (the user, 2026-10-23:
## "never increase fly time, it should be a constant no matter where"); a
## flight out of the case or into it no longer stretches by its length.
## A button of the tin sliding along to the next place (State.SLIDE).
const SLIDE_TIME := 0.26
const FLY_ARC := 0.6
const FLY_TILT := 0.2
const FLY_GROW := 0.18
## A flight to a patch ends this much of a square above its socket, still
## at HELD_SCALE, and the button settles in from there: the drop's back
## ease down and the release's back to size over RELEASE_TIME, so it sinks
## a hair past the socket and comes back. On its own colour the square
## then merges into it (the user, 2026-10-20: "when the piece is on the
## right slot, merge it into it"): the slot's flat square covers the seat
## and the gem sinks into it, shrinking to nothing over MERGE_TIME.
## Since 2026-10-29 a move's jewels merge together (the user: "instead of
## merging the slot to the board piece by piece, wait all color pieces to
## finish moving, and merge them into the board together"): each landed
## jewel stands on its slot until the move's last has settled, then they
## go in as a wave out of the tapped patch, MERGE_WAVE a ring and no more
## than MERGE_WAVE_CAP from first to last. A jewel swells and rises for
## MERGE_SWELL of its merge, then twists down to nothing as the slot's
## square pops up under it from MERGE_FROM of its size.
const SETTLE_DROP := 0.1
const MERGE_TIME := 0.42
const MERGE_WAVE := 0.035
const MERGE_WAVE_CAP := 0.3
const MERGE_SWELL := 0.3
const MERGE_GROW := 0.14
const MERGE_RISE := 0.1
const MERGE_TWIST := 0.7
const MERGE_FROM := 0.55
## The merge's one pop, a little above the landings' ticks, and the most
## sparkles it throws.
const MERGE_PITCH := 1.26
const MERGE_DB := -4.0
const MERGE_SPARKLES := 5
## A button out of the tin leaves once its patch is bare.
const TIN_LAG := 0.16
const WHOLE_STEP := 0.03
## On a big picture a colour whole hops this many squares out from the
## tapped one and no further, and sparkles this often at the most; a run
## rings this many times.
const WHOLE_REACH := 6
const SPARKLES := 12
const RINGS := 8
const BLOCK_STAGGER := 0.09
const WIN_WAIT := 1.3
const PARTY_EXTRA := 0.6
const WIN_SLIDE := 0.5
## A part of Insane's picture sewn: its jewels hop, it waits this long, and
## the next part comes on in its place. A part
## waiting is its colours this far toward the page (the reference's
## washed-out squares), a part sewn is flat as a set jewel.
const PART_HOLD := 0.9
const PART_FADE := 0.72
const STAMP_AT := 0.7
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.15
const STAMP_TILT := -0.22
const CARD_AFTER := 1.0
const CARD_AFTER_STILL := 0.3
## A picked run draws this far toward the button that was tapped, stands
## this much bigger and higher, and bobs. It comes up only a little (the
## user, 2026-10-11: "it should not raise so high because it become bad to
## understand where is each piece"; HELD_RISE was 0.14, and PULL 0.22 up to
## 0.9 of a square, which took a button half a square off its own).
const PULL := 0.05
const PULL_MOST := 0.12
const HELD_SCALE := 1.1
const HELD_RISE := 0.06
const HELD_BOB := 0.03
const HINT_BEAT := 0.5
## A button landing is never the same tick twice (docs/agents/sound.md, rule
## 2), and a run climbs half a step a button, five at the most.
const TICK_VARY := Vector2(0.96, 1.04)
const RUN_CLIMB := 0.5
const RUN_CLIMB_MAX := 5.0
## The least time between two landing ticks of one kind.
const TICK_GAP := 0.075
## A run this long sewn at once is the board's small party.
const BIG_RUN := 5

const PILL_FONT := 30
const PILL_H := 48.0
const LOW := 3
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 24.0

## The streak (docs/agents/flat-screens.md, "The streak's bubble"): taps in a
## row that each sewed a button.
const COMBO_FROM := 3
const COMBO_STEPS := [0, 1, 2, 3, 4, 5]
const COMBO_DB := -3.0
const COMBO_CONFETTI := [5, 10]
const COMBO_DEFLATE := 0.25
const COMBO_HOLD := 1.2
const COMBO_FONT := 44

## What the phone does under each cue (docs/agents/haptics.md). A button
## lifted is a tick and one into the tin a tap; one sewn is a small yes and
## a long run a firmer one; a colour whole is the milestone.
const HAPTICS := {
	"lift": Haptics.TICK,
	"tin": Haptics.TAP,
	"sew": Haptics.BUMP,
	"run": Haptics.GOOD,
	"combo": Haptics.TICK,
	"whole": Haptics.GOOD,
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"hint": Haptics.GOOD,
	"heart_back": Haptics.GOOD,
	"locked": Haptics.WARN,
	"out_of_hearts": Haptics.LOSE,
	"solved": Haptics.WIN,
}

var state = State.new()
## Back to camp from the out-of-moves card; the host listens for it.
signal leave

var fx: Node2D
## Insane's move counter: `max_moves` is 0 on a band that never runs out. Out
## of taps unsolved is `out_of_hearts`, the name the host and the card know.
var hearts := 0
var max_hearts := 0
var moves_left := 0
var max_moves := 0
var out_of_hearts := false
var _heart_used := false
var _asleep := false
var _heart_card: Control

## What the host's rows cover (a `bleed` board), and whether the win screen
## has them.
var _clear := Vector2.ZERO
var _won := false
var _cell := 0.0
var _grid := Vector2.ZERO
var _tin_rect := Rect2()
var _tin_step := TIN_STEP
## The places the tin is drawn with and the most a place is across: the
## tutorial's page has a short tin of one row.
var _tin_places := State.CASE_MIN
var _tin_step_max := TIN_STEP
var _tin_per := TIN_ROW
## The picture before the win's slots moved, for its slide to the middle.
var _from_cell := 0.0
var _from_grid := Vector2.ZERO
var _slid_at := -INF
## Between a part sewn and the next on the cloth: nothing plays.
var _turning := false
var _gen := 0

# --- the meshes ---
var _bg: ArrayMesh
var _still: ArrayMesh
var _tin: ArrayMesh
var _tin_units := {}
var _top: ArrayMesh
var _tin_rest: ArrayMesh
var _units := {}
## The plain buttons, on a picture whose squares are under Art.SMALL.
var _units_far := {}
var _near_look := true
var _flat_cache: Dictionary = {}
var _shown: Array = []
var _shown_cloth: Array = []
var _shown_over: Array = []
## The buttons at rest, a mesh a block, and which blocks are stale.
var _blocks: Array = []
var _block_stale := PackedByteArray()
var _block_hop := PackedFloat32Array()
var _bsize := 16
var _bw := 1
var _bh := 1
## The squares whose button is doing something: out of its block and drawn
## every frame until all of them are still.
var _live := {}
var _live_mesh: ArrayMesh
var _held_mesh: ArrayMesh
var _held_still := false

# --- the zoom (Hard and Insane) ---
var zoom := PanZoom.new()
var _view := Rect2()
var _cloth: Control
var _over: Control
var _zoom_b: IconButton
## The zoom as the win found it, for the slide.
var _from_zoom := Transform2D.IDENTITY
var _hud_layer: Control
var _hud_shown: ArrayMesh
var _combo_shown: ArrayMesh
var _seal_mesh: ArrayMesh

# --- what the buttons are doing ---
## The second the button on a square (or in a place of the tin) lands: it is
## in the air until then, drawn by its flight.
var _arrive := PackedFloat32Array()
var _tin_arrive := PackedFloat32Array()
## The second a landed jewel on its own slot starts to merge into it
## (-INF: merged long since).
var _merge_at := PackedFloat32Array()
var _hop_at := PackedFloat32Array()
var _shiver_at := PackedFloat32Array()
## Buttons in the air: {c, from, to, at, time, sewn}.
var _flights: Array = []
## The pick: the squares of a run off the cloth, or the places of the tin's
## own of one colour; its colour (-1: nothing picked), since when, and the
## point it draws toward.
var _held_cells := PackedInt32Array()
var _held_places := PackedInt32Array()
var _held_c := -1
var _held_at := 0.0
var _held_anchor := Vector2.ZERO
## What the finger went down on: a square, or TIN_HIT and a place.
var _pressed_tin := -2
var _pressed := -1
var _pressed_at := Vector2.ZERO
var _kept_told := false

var _streak := 0
var _combo_n := 0
var _combo_cell := 0
var _combo_at := -INF
var _combo_out_at := -INF
var _combo_popped := false

var _pill_bump := -INF
var _opened := -1.0e9
## -INF until the day is won (a restored day's is in the past, and early in
## a run that is under zero).
var _solved_at := -INF
var _stamp_at := INF
var _anim_until := 0.0
var _toast := ""
var _toast_at := -100.0
var _toast_high := false
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""
var _final_taps := 0
var _final_left := 0

func puzzle_id() -> String: return "buttons"
func title() -> String: return "Jewel Box"

func rules() -> String:
	var out := tr("BB_RULES")
	if state.band <= State.CORNERS_TO:
		out += " " + tr("BB_RULES_CORNERS")
	if state.band >= State.BIG_FROM:
		out += "\n\n" + tr("BB_RULES_BIG")
	if state.band >= State.PARTS_FROM:
		out += "\n\n" + tr("BB_RULES_PARTS")
	out += "\n\n" + tr("BB_RULES_TIN") % state.places()
	if max_moves > 0:
		out += "\n\n" + tr("RULES_MOVES_SEQ") % max_moves
	return out

## The tutorial: each page is the board itself on a small hand-made cloth
## (ui/hud/buttons_tutorial_diagram.gd). Loaded, not preloaded: the page's
## board extends this script.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/buttons_tutorial_diagram.gd")
	var hints: int = State.hints_for(state.band)
	var steps := [
		[Diagram.Lesson.LIFT, "HTP_BB_LIFT", tr("HTP_BB_LIFT_BODY")],
		[Diagram.Lesson.SEW, "HTP_BB_SEW", tr("HTP_BB_SEW_BODY")],
		[Diagram.Lesson.TIN, "HTP_BB_TIN", tr("HTP_BB_TIN_BODY")]]
	if state.band >= State.BIG_FROM:
		steps.append([Diagram.Lesson.ZOOM, "HTP_BB_ZOOM", tr("HTP_BB_ZOOM_BODY")])
	if hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_BB_HINT",
			tr("HTP_BB_HINT_BODY_ONE") if hints == 1 else tr("HTP_BB_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	if max_moves > 0:
		pages.append(MovesDiagram.page(self, max_moves, true))
	return pages

## Undo on every band and the bulb up to Hard (Insane has no hints; it had
## no Undo either while it counted its moves, until 2026-10-12). There is
## no Check on any band: a button sewn on says so itself.
## Insane has the bulb again since 2026-10-13, as many hints as Hard: what is
## said of it above is the history (docs/agents/flat-screens.md).
func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_cloth = Control.new()
	_cloth.name = "Cloth"
	_cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cloth.draw.connect(_draw_cloth)
	add_child(_cloth)
	_over = Control.new()
	_over.name = "Over"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.z_index = 1
	_over.draw.connect(_draw_over)
	add_child(_over)
	fx = Fx2D.new()
	fx.haptics = HAPTICS
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_hud_layer = Control.new()
	_hud_layer.name = "Hud"
	_hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.z_index = 3
	_hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_layer.draw.connect(_draw_hud)
	add_child(_hud_layer)
	# The zoom button, at the foot of the picture's room on the left (the
	# thumb's side stays clear): its own size, in no container.
	_zoom_b = IconButton.new("plus", "", "IconButton")
	_zoom_b.name = "Zoom"
	_zoom_b.z_index = 1
	_zoom_b.visible = false
	_zoom_b.custom_minimum_size = Vector2(ZOOM_B, ZOOM_B)
	var up := CozyTheme.soft_button(Pal.SURFACE, int(ZOOM_B * 0.5), false, 0)
	var down := CozyTheme.soft_button(Pal.SURFACE, int(ZOOM_B * 0.5), true, 0)
	for st in ["normal", "hover", "disabled"]:
		_zoom_b.add_theme_stylebox_override(st, up)
	_zoom_b.add_theme_stylebox_override("pressed", down)
	_zoom_b.pressed.connect(zoom_button)
	add_child(_zoom_b)
	zoom.one_finger_pan = true
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	state.setup(rng, difficulty, daily_key if bank_step == 0 else 0)
	_begin()

## The day as dealt, for tools/export_days.gd (PuzzleBase.day_dict): the
## buttons as the day opens and the picture they are sewn into, a row a
## string (a colour's index in base 36, `.` off the cloth).
func day_dict() -> Dictionary:
	if state.slot.is_empty():
		return {}
	var w: int = state.w
	var h: int = state.h
	var digits := "0123456789abcdefghijklmnopqrstuvwxyz"
	var puzzle: Array = []
	var answer: Array = []
	var opened: Array = []
	var sewn: Array = []
	var home := 0
	for y in h:
		var a := ""
		var b := ""
		for x in w:
			var want: int = state.slot[y * w + x]
			var has: int = state.start[y * w + x]
			if want < 0:
				puzzle.append({"wall": true})
				answer.append({"wall": true})
				a += "."
				b += "."
				continue
			if has == want:
				home += 1
			puzzle.append({"c": has, "given": true} if has == want else {"c": has})
			answer.append({"c": want})
			a += digits[has] if has >= 0 else "."
			b += digits[want]
		opened.append(a)
		sewn.append(b)
	return {
		"source": "bank" if state.name_key != "" else "generator", "kind": "grid",
		"payload": {"w": w, "h": h, "picture": state.name_key, "colours": Array(state.colours), "rows": opened},
		"solution": {"rows": sewn},
		"metrics": {"w": w, "h": h, "buttons": state.count(), "colours": state.colours.size(), "par": state.par,
			"sewn_at_start": home, "draws": state.draws, "tin_places": state.places(),
			"hints": State.hints_for(state.band), "moves": max_moves},
		"view": {"w": w, "h": h, "puzzle": puzzle, "solution": answer, "legend": Array(state.colours)},
	}

## The cloth as `state` has it, from the top.
func _begin() -> void:
	max_moves = state.moves_budget()
	_heart_used = false
	_won = false
	_solved_at = -INF
	_slid_at = -INF
	_turning = false
	_stamp_at = INF
	_seal_mesh = null
	zoom.reset()
	_deal()
	_layout()
	_enter()

func _deal() -> void:
	moves_left = max_moves
	out_of_hearts = false
	_asleep = false
	_pressed = -1
	_toast = ""
	_flights = []
	_unhold()
	_streak = 0
	_combo_n = 0
	_kept_told = false
	var n: int = state.slot.size()
	_arrive = _filled(n, -INF)
	_merge_at = _filled(n, -INF)
	_hop_at = _filled(n, -INF)
	_shiver_at = _filled(n, -INF)
	_tin_places = state.places()
	_tin_arrive = _filled(_tin_places, -INF)
	_tin = null
	_live = {}
	_stale_all()
	if _hud_layer != null:
		_hud_layer.queue_redraw()

static func _filled(n: int, value: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(value)
	return out

# --- layout ---

## The host's rows over this board (ui/flat/flat_host.gd, a `bleed` board):
## what they cover at the top and the foot, and on the win the span the win
## screen leaves, which the picture slides to the middle of.
func set_clear(top: float, bottom: float, won := false) -> void:
	_clear = Vector2(top, bottom)
	if won and not _won and _cell > 0.0:
		_from_cell = _cell
		_from_grid = _origin()
		# the win has the picture whole: the slide starts from the zoom it
		# found
		_from_zoom = zoom.xf()
		zoom.reset()
		_slid_at = _now() if is_inside_tree() and _solved_at > _now() - 5.0 else -INF
	_won = won
	_layout()

## The picture as big as the room between the pill and the tin allows, in
## the middle of it, and the tin at the foot.
func _layout() -> void:
	if state.w <= 0 or size.x <= 0.0:
		return
	var top := _clear.x
	var foot := size.y - _clear.y
	_tin_step = minf(_tin_step_max, size.x * TIN_STEP_K)
	_tin_per = mini(TIN_ROW, _tin_places)
	var tin_rows := ceili(float(_tin_places) / _tin_per)
	var per_row := _tin_per
	var tin_size := Vector2(per_row * _tin_step + 2.0 * TIN_PAD_X, tin_rows * _tin_step + 2.0 * TIN_PAD_Y)
	_tin_rect = Rect2(Vector2((size.x - tin_size.x) * 0.5, foot - tin_size.y - GAP * 0.5), tin_size)
	var head := top if _won else top + HUD_ROW
	var floor_y := foot if _won else _tin_rect.position.y - GAP
	var room := Vector2(size.x - 2.0 * (PAD + BORDER), floor_y - head - 2.0 * BORDER)
	# a picture in parts is laid by the part being played, the rest of it
	# running on round it past the room; won, it is laid whole
	var whole: Vector2i = state.whole_size() if _won else Vector2i(state.w, state.h)
	_cell = minf(CELL_MAX, minf(room.x / whole.x, room.y / whole.y))
	if _cell <= 0.0:
		return
	var pic := Vector2(whole) * _cell
	_grid = Vector2((size.x - pic.x) * 0.5, head + BORDER + (room.y - pic.y) * 0.5)
	if _won:
		_grid += Vector2(state.part_at) * _cell
	# the picture's room, which a zoomed picture is clipped to
	_view = Rect2(0.0, head, size.x, maxf(1.0, floor_y - head))
	_cloth.position = _view.position
	_cloth.size = _view.size
	# what flies, from the picture's top to the foot: zoomed, a jewel bound
	# for a square out of sight goes under the edge, not over the bar
	_over.position = _view.position
	_over.size = Vector2(size.x, maxf(1.0, size.y - _view.position.y))
	var limits := _zoom_limits()
	zoom.setup(_view, limits.x, limits.y)
	_zoom_b.position = Vector2(ZOOM_INSET, _view.end.y - ZOOM_INSET - ZOOM_B)
	_zoom_b.size = Vector2(ZOOM_B, ZOOM_B)
	_flat_cache = {}
	var named: Array = []
	for c: String in state.colours:
		named.append(c)
	# a big picture's buttons are the light ones: plain seen whole, with
	# their holes seen close
	# (only a big one: Hard's 16 squares are 44 px on a narrow screen, and
	# with no zoom its buttons keep their holes)
	var lite := _cell < Art.SMALL and _big()
	_units = Art.units(_cell, named, Art.CLOSE if lite else Art.FULL)
	_units_far = Art.units(_cell, named, Art.PLAIN) if lite else {}
	_near_look = _units_far.is_empty() or _cell * zoom.k >= LOD_IN
	_bsize = BLOCK if maxi(state.w, state.h) > 16 else 16
	_bw = ceili(float(state.w) / _bsize)
	_bh = ceili(float(state.h) / _bsize)
	_blocks = []
	_blocks.resize(_bw * _bh)
	_block_hop = _filled(_bw * _bh, -INF)
	_stale_all()
	_tin_units = Art.units(_tin_step * TIN_FIT, named)
	var b := Face.Builder.new()
	Art.linen(b, size)
	_bg = b.mesh()
	_still = _build_still()
	_tin = null
	_seal_mesh = null
	_held_still = false
	_hud_layer.queue_redraw()
	_request()

## How close the picture may come, (the button's, a pinch's most): only the
## big pictures of Hard and Insane zoom, and not once they are won.
func _zoom_limits() -> Vector2:
	if state.band < State.BIG_FROM or _won or _cell <= 0.0:
		return Vector2.ONE
	return Vector2(NEAR_PX / _cell, CELL_MAX / _cell)

func _zoom_button_wanted() -> bool:
	return zoom.enabled and not _won and _solved_at == -INF and not is_done()

## The zoom button: whole, half way, close, and back out a step at a time.
func zoom_button() -> void:
	zoom.cycle()
	_request()

## The middle of square `i` on the cloth as it is laid out. Under a zoom the
## screen has it at `cell_screen`.
func cell_centre(i: int) -> Vector2:
	return _grid + (Vector2(state.xy(i)) + Vector2(0.5, 0.5)) * _cell

## Control-local point over the middle of square `i`, zoomed as it is. The
## harnesses press these.
func cell_screen(i: int) -> Vector2:
	return zoom.to_screen(cell_centre(i))

func _big() -> bool:
	return state.count() > BIG

## The buttons as they are drawn at this zoom: the plain ones on a big
## picture seen whole.
func _lu() -> Dictionary:
	return _units if _near_look else _units_far

func _block_of(i: int) -> int:
	return (i / state.w) / _bsize * _bw + (i % state.w) / _bsize

func _stale_all() -> void:
	_block_stale = PackedByteArray()
	_block_stale.resize(_bw * _bh)
	_block_stale.fill(1)
	_held_still = false

## Square `i`'s button is about to do something: it leaves its block's mesh
## for the one drawn every frame.
func _mark(i: int) -> void:
	if i < 0 or _live.has(i):
		return
	_live[i] = true
	var b := _block_of(i)
	if b < _block_stale.size():
		_block_stale[b] = 1

func _mark_all() -> void:
	for i in state.slot.size():
		if state.slot[i] >= 0:
			_live[i] = true
	_stale_all()

func cell_to_local(r: int, c: int) -> Vector2:
	return _grid + (Vector2(c, r) + Vector2(0.5, 0.5)) * _cell

## How many places a row of the tin holds (`_layout`): the rows as even as
## they come, a short last row in the middle.
func _tin_row() -> int:
	return _tin_per

func tin_centre(place: int) -> Vector2:
	return Art.tin_place(_tin_rect, place, _tin_row(), _tin_step, _tin_places)

## The square under a point of the cloth as laid out.
func _cell_at(local: Vector2) -> int:
	if _cell <= 0.0:
		return -1
	var p := (local - _grid) / _cell
	return state.at_xy(Vector2i(int(floor(p.x)), int(floor(p.y))))

## The square under a finger: through the zoom, and only inside the room a
## zoomed picture shows in (what it hides under the tin is not there).
func _cell_under(at: Vector2) -> int:
	if zoom.zoomed() and not _view.has_point(at):
		return -1
	return _cell_at(zoom.to_layout(at))

func _field_px() -> Rect2:
	return Rect2(_grid, Vector2(state.w, state.h) * _cell)

## Where the whole picture's first square is laid: the part's own for a
## picture played whole.
func _origin() -> Vector2:
	return _grid - Vector2(state.part_at) * _cell

## The picture's edge, a border around its own shape, and a slot a square,
## each in its jewel's colour with a seat: one mesh, and the slots of one
## colour join in it.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var centres := PackedVector2Array()
	for i in state.slot.size():
		if state.slot[i] >= 0:
			centres.append(cell_centre(i))
	# the parts of Insane's picture round this one: sewn flat, or waiting
	# washed out
	var around: Array = state.around()
	var origin := _origin()
	for one: Array in around:
		centres.append(origin + (Vector2(one[0]) + Vector2(0.5, 0.5)) * _cell)
	Art.outline(b, centres, _cell, clampf(_cell * OUTLINE_K, OUTLINE_MIN, OUTLINE_MAX))
	for one: Array in around:
		var col := Art.colour(one[1])
		if not one[2]:
			col = col.lerp(Pal.SURFACE, PART_FADE)
		Art.sewn(b, origin + (Vector2(one[0]) + Vector2(0.5, 0.5)) * _cell, _cell, col)
	for i in state.slot.size():
		if state.slot[i] >= 0:
			Art.patch(b, cell_centre(i), _cell, Art.colour(state.colours[state.slot[i]]), _cell < Art.SMALL)
	return b.mesh()

func _build_tin() -> ArrayMesh:
	var b := Face.Builder.new()
	Art.tin(b, _tin_rect, _tin_places, state.capacity(), _tin_row(), _tin_step)
	return b.mesh()

# --- the drawing ---

## Where the picture's own pixels are on the screen now: itself, but for the
## win's slide from where it was played (and however close) to the middle of
## what is left.
func _slide_xf(now: float) -> Transform2D:
	var e := now - _slid_at
	if Motion.reduce or e >= WIN_SLIDE or _from_cell <= 0.0 or _cell <= 0.0:
		return Transform2D.IDENTITY
	var u := clampf(e / WIN_SLIDE, 0.0, 1.0)
	var s := u * u * (3.0 - 2.0 * u)
	var k0 := _from_cell / _cell
	var was := _from_zoom * Transform2D(0.0, Vector2(k0, k0), 0.0, _from_grid - _origin() * k0)
	var k := lerpf(was.get_scale().x, 1.0, s)
	return Transform2D(0.0, Vector2(k, k), 0.0, was.origin.lerp(Vector2.ZERO, s))

## From the cloth as laid out to the screen: the zoom, and the win's slide.
func _pic_xf(now: float) -> Transform2D:
	return _slide_xf(now) * zoom.xf()

## The linen, the tin and the tin's own buttons at rest: what never scales.
func _draw() -> void:
	if _cell <= 0.0 or _bg == null:
		return
	var now := _now()
	var shown: Array = [_bg]
	draw_mesh(_bg, null)
	var since := now - _opened - Motion.ENTER_DELAY
	var tin_seen := 1.0 if Motion.reduce else Motion.appear_level(since)
	if _solved_at > -INF:
		tin_seen = 0.0 if Motion.reduce else clampf(1.0 - (now - _solved_at - WIN_WAIT * 0.4) / 0.3, 0.0, 1.0)
		if _won and _slid_at == -INF:
			tin_seen = 0.0
	if tin_seen > 0.0:
		if _tin == null:
			_tin = _build_tin()
		draw_mesh(_tin, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, tin_seen))
		shown.append(_tin)
	_tin_rest = null
	if _solved_at == -INF or now - _solved_at < WIN_WAIT:
		var rest := Face.FlatBuilder.new(_flat_cache)
		for p in _tin_places:
			var c: int = state.tin[p]
			if c < 0 or now < _tin_arrive[p] or (_held_c >= 0 and _held_places.has(p)):
				continue
			var k := 1.0
			if not Motion.reduce and now - _tin_arrive[p] < Motion.BUMP_TIME:
				_busy_for(0.1)
				k = Motion.bump_scale(now - _tin_arrive[p], 0.12)
			rest.append(_tin_units.loose[c], Transform2D(0.0, Vector2(k, k), 0.0, tin_centre(p)))
		_tin_rest = rest.mesh()
	if _tin_rest != null:
		draw_mesh(_tin_rest, null)
		shown.append(_tin_rest)
	_shown = shown

## The picture: the border and the patches, the buttons at rest a block at a
## time, the ones doing something and the pick, all under one transform.
func _draw_cloth() -> void:
	if _cell <= 0.0 or _bg == null or _still == null:
		return
	var now := _now()
	var shown: Array = []
	var since := now - _opened - Motion.ENTER_DELAY
	var seen := 1.0 if Motion.reduce else Motion.appear_level(since)
	var grown := 1.0 if Motion.reduce else Motion.wide_pop_scale(since)
	var centre := _field_px().get_center()
	var pic := Transform2D(0.0, -_cloth.position) * _pic_xf(now)
	var xf := pic * Transform2D(0.0, Vector2(grown, grown), 0.0, centre) * Transform2D(0.0, -centre)
	# the plain button far off, the whole one close
	if not _units_far.is_empty():
		var px := _cell * zoom.k
		var near := px >= LOD_IN if not _near_look else px > LOD_OUT
		if near != _near_look:
			_near_look = near
			_stale_all()
	if seen > 0.0:
		_cloth.draw_mesh(_still, null, xf, Color(1.0, 1.0, 1.0, seen))
		shown.append(_still)
	var busy := _build_live(now)
	var cut := zoom.zoomed()
	var tint := Color(1.0, 1.0, 1.0, seen)
	for b in _blocks.size():
		var at := Vector2(b % _bw, b / _bw) * _bsize * _cell + _grid
		if cut and not _view.intersects(zoom.xf() * Rect2(at, Vector2.ONE * _bsize * _cell).grow(_cell)):
			continue
		if _block_stale[b] == 1:
			_block_stale[b] = 0
			_blocks[b] = _build_block(b)
		if _blocks[b] == null or seen <= 0.0:
			continue
		var hop := now - _block_hop[b]
		var lift := 0.0
		if not Motion.reduce and hop < Motion.SOLVE_TIME and hop > -3.0:
			busy = true
			if hop >= 0.0:
				lift -= Motion.hop_lift(hop, Motion.SOLVE_HOP, Motion.SOLVE_TIME)
		_cloth.draw_mesh(_blocks[b], null, xf * Transform2D(0.0, Vector2(0.0, -lift)), tint)
		shown.append(_blocks[b])
	if _live_mesh != null:
		_cloth.draw_mesh(_live_mesh, null, pic)
		shown.append(_live_mesh)
	if _held_c >= 0:
		if not _held_still or _held_mesh == null:
			busy = true
			_build_held(now)
		if _held_mesh != null:
			_cloth.draw_mesh(_held_mesh, null, pic)
			shown.append(_held_mesh)
	else:
		_held_mesh = null
	if now >= _stamp_at:
		_draw_stamp(now, shown, pic)
	_shown_cloth = shown
	if busy:
		_busy_for(0.1)

## The buttons at rest in block `b`.
func _build_block(b: int) -> ArrayMesh:
	var rest := Face.FlatBuilder.new(_flat_cache)
	var u := _lu()
	var x0 := (b % _bw) * _bsize
	var y0 := (b / _bw) * _bsize
	for y in range(y0, mini(state.h, y0 + _bsize)):
		for x in range(x0, mini(state.w, x0 + _bsize)):
			var i: int = y * state.w + x
			var c: int = state.cur[i]
			if state.slot[i] < 0 or c < 0 or _live.has(i):
				continue
			var at := Transform2D(0.0, cell_centre(i))
			if c == state.slot[i]:
				rest.append(u.sewn[c], at)
			else:
				rest.append(u.shade, at)
				rest.append(u.loose[c], at)
	return rest.mesh()

## Every button that is doing something, where it is at `now`, and the rings
## on the patches a pick may go to. True while any of them still moves; once
## none does they go back to their blocks.
func _build_live(now: float) -> bool:
	var rest := Face.FlatBuilder.new(_flat_cache)
	var u := _lu()
	var busy := false
	var holding := _held_c >= 0
	var held := {}
	if holding:
		# where the pick may go: a ring on every bare patch of its colour
		# (Easy and Medium only: Hard and Insane never show where to place)
		if state.guides():
			busy = true
			var pulse := 1.0 + 0.07 * sin((now - _held_at) * 7.0)
			for i in state.bare_of(_held_c):
				rest.append(u.ring, Transform2D(0.0, Vector2(pulse, pulse) * 0.82, 0.0, cell_centre(i)))
		for i in _held_cells:
			held[i] = true
	var still := 0
	for i: int in _live:
		var c: int = state.cur[i]
		if held.has(i):
			continue
		if c < 0:
			still += 1
			continue
		if now < _arrive[i]:
			busy = true
			continue
		var at := cell_centre(i)
		var sc := Vector2.ONE
		var lift := 0.0
		var home: bool = c == state.slot[i]
		var moving := false
		# a landed button settles into its socket, loose; on its own colour
		# it stands there until its move's merge, then the square pops up
		# from under it (`fill`, 0 to 1) as it twists down to nothing
		var settling := false
		var fill := 1.0
		var spin := 0.0
		var gem := 0.0
		var rise := 0.0
		if not Motion.reduce:
			var p: Vector2i = state.xy(i)
			var e := now - _opened - Motion.ENTER_DELAY - Motion.stagger(p.x + p.y, Motion.ENTER_STAGGER)
			if e < Motion.POP_IN and not _big():
				busy = true
				if e <= 0.0:
					continue
				moving = true
				sc = Motion.pop_in_scale(e)
			var landed := now - _arrive[i]
			if landed < Motion.RELEASE_TIME:
				moving = true
				settling = true
				sc *= lerpf(HELD_SCALE, 1.0, Motion.back_out(landed / Motion.RELEASE_TIME))
				lift += Motion.drop_in_lift(landed, SETTLE_DROP * _cell, Motion.RELEASE_TIME)
			if home:
				var mz := now - _merge_at[i]
				if mz < 0.0:
					# waiting for the move's last to settle: still a gem
					moving = true
					settling = true
				elif mz < MERGE_TIME:
					moving = true
					var m := mz / MERGE_TIME
					if m < MERGE_SWELL:
						var w := m / MERGE_SWELL
						var up := w * w * (3.0 - 2.0 * w)
						fill = 0.0
						gem = 1.0 + MERGE_GROW * up
						rise = MERGE_RISE * _cell * up
					else:
						var w := (m - MERGE_SWELL) / (1.0 - MERGE_SWELL)
						var down := w * w * (3.0 - 2.0 * w)
						fill = maxf(0.001, Motion.back_out(w))
						gem = (1.0 + MERGE_GROW) * (1.0 - down)
						rise = MERGE_RISE * _cell * (1.0 - down)
						spin = MERGE_TWIST * down
			var hop := now - _hop_at[i]
			if hop >= 0.0 and hop < Motion.SOLVE_TIME:
				moving = true
				lift -= Motion.hop_lift(hop, Motion.SOLVE_HOP, Motion.SOLVE_TIME)
			elif hop < 0.0 and hop > -3.0:
				moving = true
			var shiver := now - _shiver_at[i]
			if shiver >= 0.0 and shiver < Motion.SHIVER_TIME:
				moving = true
				at.x += Motion.shiver_offset(shiver, Motion.SHIVER_PX * 2.0)
		if moving:
			busy = true
		else:
			still += 1
		var loose := not home or settling
		if loose or (lift > 0.5 and gem <= 0.0):
			rest.append(u.shade, Transform2D(0.0, sc, 0.0, at))
		if loose:
			rest.append(u.loose[c], Transform2D(0.0, sc, 0.0, at - Vector2(0.0, lift)))
		else:
			# merged: the slot's square over the seat, the gem going into it
			if fill > 0.0:
				var k := lerpf(MERGE_FROM, 1.0, fill) if gem > 0.0 else 1.0
				rest.append(u.sewn[c], Transform2D(0.0, sc * k, 0.0, at - Vector2(0.0, lift)))
			if gem > 0.0:
				rest.append(u.shade, Transform2D(0.0, sc * gem, 0.0, at))
				rest.append(u.loose[c], Transform2D(spin, sc * gem, 0.0, at - Vector2(0.0, lift + rise)))
	_live_mesh = rest.mesh()
	# all still: back to the blocks (the pick stays out while it is held)
	if not busy and still > 0:
		for i: int in _live.keys():
			if not held.has(i):
				_live.erase(i)
				_block_stale[_block_of(i)] = 1
		_live_mesh = null
	return busy

## The pick, lifted: built every frame while it comes up and bobs, and once
## for a pick too big to bob.
func _build_held(now: float) -> void:
	var top := Face.FlatBuilder.new(_flat_cache)
	var u := _lu()
	for i in _held_cells:
		var at := _held_pos(i, false, now)
		var k := Vector2.ONE * _held_grow(now, _held_lag(i, false))
		top.append(u.shade, Transform2D(0.0, k, 0.0, cell_centre(i).lerp(at, 0.8) + Vector2(0.0, _cell * HELD_RISE * _held_k(now, _held_lag(i, false)))))
	for i in _held_cells:
		var k := Vector2.ONE * _held_grow(now, _held_lag(i, false))
		top.append(u.loose[_held_c], Transform2D(0.0, k, 0.0, _held_pos(i, false, now)))
	_held_mesh = top.mesh()
	_held_still = (Motion.reduce or not _held_bobs()) and now - _held_at > Motion.LIFT_TIME * 1.6 + PICK_CAP

func _held_bobs() -> bool:
	return _held_cells.size() + _held_places.size() <= HELD_BOB_MAX

## What is over the cloth and the tin both, and never clipped: the rings on
## the tin's free places, the tin's own buttons picked, and every button in
## the air, each end of its flight where the screen has it now.
func _draw_over() -> void:
	if _cell <= 0.0 or _bg == null:
		return
	var now := _now()
	var top := Face.FlatBuilder.new(_flat_cache)
	var u := _lu()
	var busy := false
	if _held_c >= 0:
		if state.guides() and not _held_cells.is_empty():
			var pulse := 1.0 + 0.07 * sin((now - _held_at) * 7.0)
			var free: int = state.capacity() - state.in_tin()
			for p in _tin_places:
				if free > 0 and p < state.capacity() and state.tin[p] < 0:
					free -= 1
					top.append(_tin_units.ring, Transform2D(0.0, Vector2(pulse, pulse) * TIN_RING, 0.0, tin_centre(p)))
		if not _held_places.is_empty():
			busy = true
			for p in _held_places:
				var k := Vector2.ONE * _held_grow(now, _held_lag(p, true))
				top.append(_tin_units.loose[_held_c], Transform2D(0.0, k, 0.0, _held_pos(p, true, now)))
	var pic := _pic_xf(now)
	var zk := pic.get_scale().x
	var keep: Array = []
	for f: Dictionary in _flights:
		var e: float = now - float(f.at)
		if e >= float(f.time):
			continue
		keep.append(f)
		busy = true
		var t := clampf(e / float(f.time), 0.0, 1.0)
		var s := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
		var arc := 4.0 * s * (1.0 - s)
		# an end on the cloth is where the zoom has it this frame
		var from: Vector2 = pic * (f.from as Vector2) if bool(f.fc) else f.from
		var to: Vector2 = pic * (f.to as Vector2) if bool(f.tc) else f.to
		var tilt := arc * FLY_TILT * clampf((to.x - from.x) / (_cell * 3.0), -1.0, 1.0)
		var k_from := float(f.k0) * (zk if bool(f.fc) else 1.0)
		var k_to := float(f.k1) * (zk if bool(f.tc) else 1.0)
		var at := from.lerp(to, s)
		var grow := lerpf(k_from, k_to, s) * (1.0 + arc * FLY_GROW)
		var lift := arc * FLY_ARC * _cell * lerpf(zk if bool(f.fc) else 1.0, zk if bool(f.tc) else 1.0, s)
		# a flight to a patch ends a hair above the socket, to settle in
		if bool(f.tc):
			lift += SETTLE_DROP * _cell * zk * s
		var low := grow * (1.0 - arc * 0.3)
		top.append(u.shade, Transform2D(0.0, Vector2(low, low), 0.0, at + Vector2(0.0, lift * 0.2)))
		top.append(u.loose[int(f.c)], Transform2D(tilt, Vector2(grow, grow), 0.0, at - Vector2(0.0, lift)))
	_flights = keep
	_top = top.mesh()
	_shown_over = [_top]
	if _top != null:
		_over.draw_mesh(_top, null, Transform2D(0.0, -_over.position))
	if busy:
		_busy_for(0.1)

# --- the pill, the toast and the streak ---

func _draw_hud() -> void:
	if _cell <= 0.0 or state.w <= 0:
		return
	var now := _now()
	var since := now - _opened - Motion.ENTER_DELAY
	if since < 0.0 and not Motion.reduce:
		return
	if not _won:
		var font: Font = CozyTheme.display(700)
		var text := pill_text()
		var ink := Pal.TEXT
		if max_moves > 0 and moves_left <= LOW:
			ink = Pal.BAD
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT).x
		var box := Vector2(wide + 52.0, PILL_H)
		var b := Face.Builder.new()
		b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2.ONE * 2.0, box + Vector2.ONE * 4.0, box.y * 0.5 + 2.0), Pal.LINE)
		b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
		_hud_shown = b.mesh()
		var alpha := 1.0 if Motion.reduce else Motion.appear_level(since)
		var k := 1.0 if Motion.reduce else Motion.bump_scale(now - _pill_bump, 0.12)
		_hud_layer.draw_set_transform(Vector2(size.x * 0.5, _clear.x + HUD_ROW * 0.5), 0.0, Vector2(k, k))
		_hud_layer.draw_mesh(_hud_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
		var rise := (font.get_ascent(PILL_FONT) - font.get_descent(PILL_FONT)) * 0.5
		_hud_layer.draw_string(font, Vector2(-wide * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT, Color(ink, alpha))
		_hud_layer.draw_set_transform(Vector2.ZERO)
	_draw_combo(now)
	_draw_toast(now)

## What the pill reads: the buttons sewn of all there are, and on Insane the
## taps left beside it.
func pill_text() -> String:
	var sewn := tr("BB_PILL") % [state.homes(), state.count()]
	if state.in_parts():
		sewn = tr("BB_PART") % [state.part + 1, state.parts.size()] + " · " + sewn
	if max_moves > 0:
		return (tr("MOVES_LEFT_ONE") if moves_left == 1 else tr("MOVES_LEFT_N") % moves_left) + " · " + sewn
	return sewn

func _bump_pill() -> void:
	_pill_bump = _now()
	_hud_layer.queue_redraw()

func _draw_combo(now: float) -> void:
	if _combo_n < COMBO_FROM:
		return
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
	# over the square on the screen, wherever the zoom has it; inside the
	# picture's room when it has gone out of sight
	var tail := _at(_combo_cell) + Vector2(0.25, -0.4) * _cell * zoom.k
	if zoom.zoomed():
		tail = tail.clamp(_view.position + Vector2(0.0, box.y), _view.end)
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
	_hud_layer.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	_hud_layer.draw_mesh(_combo_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_hud_layer.draw_string(font, Vector2(-tw * 0.5, (font.get_ascent(COMBO_FONT) - font.get_descent(COMBO_FONT)) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.LEAF_DEEP, alpha))
	_hud_layer.draw_set_transform(Vector2.ZERO)

func _draw_toast(now: float) -> void:
	if _toast == "":
		return
	var since := now - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var font: Font = CozyTheme.body(600)
	var room := maxf(TOAST_PAD, size.x - 120.0)
	var text_room := room - TOAST_PAD
	var one: float = font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x
	var lines := 1
	var text_w := one
	if one > text_room:
		var wrapped: Vector2 = font.get_multiline_string_size(_toast, HORIZONTAL_ALIGNMENT_CENTER, text_room, TOAST_FONT)
		lines = maxi(1, int(round(wrapped.y / font.get_height(TOAST_FONT))))
		text_w = minf(text_room, wrapped.x)
	var wide := minf(room, text_w + TOAST_PAD)
	var tall := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [_toast, int(wide), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-wide, -tall) * 0.5, Vector2(wide, tall), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh()
		_toast_mesh_for = key
	var field := _field_px()
	var mid := Vector2(size.x * 0.5, field.end.y - TOAST_MARGIN - tall * 0.5)
	if _toast_high:
		mid.y = field.position.y + TOAST_MARGIN + tall * 0.5
	_hud_layer.draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha * 0.94))
	var top := mid.y - tall * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - wide * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		_hud_layer.draw_string(font, Vector2(left, top), _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		_hud_layer.draw_multiline_string(font, Vector2(left, top), _toast, HORIZONTAL_ALIGNMENT_CENTER,
			wide - TOAST_PAD, TOAST_FONT, lines, Color(Pal.PAPER, alpha))

## A line the player has to see now, on the toast. `near` is the square the
## finger is on, so the toast keeps out of its way.
func _tell(text: String, near := -1) -> void:
	_toast = text
	_toast_at = _now()
	_toast_high = near >= 0 and _at(near).y >= lerpf(_field_px().position.y, _field_px().end.y, 0.62)
	_hud_layer.queue_redraw()

# --- the pick ---

func holding() -> bool:
	return _held_c >= 0

func _unhold() -> void:
	_held_cells = PackedInt32Array()
	_held_places = PackedInt32Array()
	_held_c = -1
	_held_still = false

## Square `i` on the screen now (for what is drawn over the picture and not
## in it: a ring, confetti, the streak's bubble).
func _at(i: int) -> Vector2:
	return _pic_xf(_now()) * cell_centre(i)

## A point of the picture to throw confetti from: square `i`, or the nearest
## point of the room when the zoom has it out of sight.
func _at_seen(i: int) -> Vector2:
	var p := _at(i)
	return p.clamp(_view.position, _view.end) if zoom.zoomed() else p

func _in_sight(i: int) -> bool:
	return not zoom.zoomed() or _view.has_point(_at(i))

## How far a pick has come up: 0 as it is tapped, 1 once it is lifted.
func _held_k(now: float, lag := 0.0) -> float:
	if Motion.reduce:
		return 1.0
	return Motion.back_out(clampf((now - _held_at - lag) / (Motion.LIFT_TIME * 1.6), 0.0, 1.0))

func _held_grow(now: float, lag := 0.0) -> float:
	return lerpf(1.0, HELD_SCALE, _held_k(now, lag))

## How long after the tap a picked button starts up: its distance from the
## tapped one, a PICK_STEP a square, so the lift runs out through the run.
func _held_lag(i: int, in_tin: bool) -> float:
	if Motion.reduce:
		return 0.0
	var home := tin_centre(i) if in_tin else cell_centre(i)
	var unit := _tin_step if in_tin else _cell
	return minf(home.distance_to(_held_anchor) / maxf(unit, 1.0) * PICK_STEP, PICK_CAP)

## Where a picked button is drawn: drawn toward the tapped one, lifted, and
## bobbing a little, each a beat behind its neighbour.
func _held_pos(i: int, in_tin: bool, now: float) -> Vector2:
	var k := _held_k(now, _held_lag(i, in_tin))
	var home := tin_centre(i) if in_tin else cell_centre(i)
	var unit := _tin_step if in_tin else _cell
	# no button draws together further than PULL_MOST of a square: each
	# stays over its own
	var at := home if in_tin else home + ((_held_anchor - home) * PULL).limit_length(_cell * PULL_MOST) * k
	var bob := 0.0 if Motion.reduce or not _held_bobs() else sin((now - _held_at) * 5.0 + i * 0.9) * HELD_BOB * unit
	return at - Vector2(0.0, (HELD_RISE * unit + bob) * k)

func _pick(cells: PackedInt32Array, places: PackedInt32Array, c: int, anchor: Vector2) -> void:
	_held_cells = cells
	_held_places = places
	_held_c = c
	_held_at = _now()
	_held_anchor = anchor
	_held_still = false
	for i in cells:
		_mark(i)
	fx.cue("lift", randf_range(TICK_VARY.x, TICK_VARY.y))
	_request()

## Puts the pick down where it was.
func _drop() -> void:
	if not holding():
		return
	_unhold()
	_tap_at = -INF
	fx.cue("lift", 0.84 * randf_range(TICK_VARY.x, TICK_VARY.y))
	_request()

# --- input ---

const TIN_HIT := -3
## The aim (the user, 2026-10-12: "add some helper to place the piece even
## if user don't hit exactly above the cell"). With a pick in hand, a tap
## that lands on nothing at all -- linen, the border, a sewn button -- goes
## to the nearest bare patch of the pick's colour within AIM_REACH squares
## of the finger. A tap that means something keeps its meaning but for the
## AIM_EDGE of a square nearest the patch: a button that could be picked is
## still a pick, and a bare patch of another colour still says so (two
## browns side by side are the puzzle on a big picture; the aim does not
## choose between them). Its edge is the patch's, its middle its own.
## With nothing in hand (the user, 2026-10-17: "the click to get the closest
## available action so user don't need to be pixel perfect"), a touch on
## anything but a button that can be picked picks the nearest one within
## AIM_REACH, and a touch on the tin's wood or a free place the nearest of
## its buttons within TIN_REACH places.
## Then (the user, 2026-10-21: "when user click somewhere, and it's a
## missclick, it should try to do the nearest available action to avoid
## needing a perfect click"): the reach is never under AIM_PX of the screen,
## a fingertip, however small the squares (Hard and Insane seen whole have
## squares of 15 px, and 1.5 of them was under the finger), and a bare
## patch of another colour with a pick in hand reaches as far as linen does
## for one of the pick's colour, and is refused only with none in reach.
## Since 2026-10-26 a miss like that, or one on a sewn button, with a pick
## in hand puts the pick down instead of refusing it (`tap`).
## Since 2026-10-29 (the user: "when there is a color selected, it should
## trigger the color placement, this way we can avoid selecting another
## color when user is trying to place what is selected") a tap on another
## jewel that could be picked reaches as far as linen does for a patch of
## the pick's colour, and picks that jewel only with none in reach; only
## the pick itself keeps the AIM_EDGE middle.
const AIM_REACH := 1.5
const AIM_PX := 44.0
const AIM_EDGE := 0.7
const TIN_REACH := 0.9
## A finger that wanders this little (of a square, or SLOP_PX on the screen
## if more) between press and release taps what it went down on.
const SLOP := 0.6
const SLOP_PX := 18.0
## Two taps on one run within this are the shortcut to the tin (the user,
## 2026-10-12: "add some shortcut to send the piece to the case").
const TWICE := 0.35
var _tap_at := -INF
var _tap_run := PackedInt32Array()

## Touch and mouse, as every flat board takes them (touch is not mouse here:
## emulate_mouse_from_touch is off). A tap is a press and a release on one
## thing: a square of the cloth, or the tin.
##
## On Hard and Insane the zoom reads every event first: two fingers pinch
## and pan, one finger dragged pans a picture seen close (this board is
## played by taps alone), the wheel zooms on a desk. A gesture that begins
## takes the press in hand with it, so letting go taps nothing.
func _gui_input(event: InputEvent) -> void:
	if zoom.enabled:
		var took := zoom.feed(event)
		if took != PanZoom.NONE:
			if took == PanZoom.BEGAN:
				_pressed = -1
				_pressed_tin = -2
				_gesture_tick()
			_request()
			return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		var over := aim(event.position)
		var over_tin := _tin_aim(event.position)
		if event.pressed:
			_pressed = over
			_pressed_tin = over_tin
			_pressed_at = event.position
		else:
			var slop := maxf(SLOP * _cell * zoom.k, SLOP_PX)
			if event.position.distance_to(_pressed_at) <= slop:
				over = _pressed
				over_tin = _pressed_tin
			if over >= 0 and over == _pressed:
				tap(over, _now() - _tap_at <= TWICE and _tap_run.has(over))
			elif over < 0 and over_tin != -2 and _pressed_tin != -2:
				tap_tin(over_tin)
			elif over < 0 and _pressed < 0 and holding():
				_drop()
			_pressed = -1
			_pressed_tin = -2

## The square a finger at `at` means: the one under it, or with a pick in
## hand the bare patch of its colour the finger all but hit (AIM_REACH), or
## with nothing in hand the button that can be picked it all but hit. -1
## for none. The tin and what a zoom hides are never aimed past.
func aim(at: Vector2) -> int:
	var over := _cell_under(at)
	if _cell <= 0.0 or _tin_at(at) != -2:
		return over
	if zoom.zoomed() and not _view.has_point(at):
		return over
	if not holding():
		return _aim_pick(at, over)
	var reach := _reach()
	if over >= 0:
		if state.cur[over] < 0 and state.slot[over] == _held_c:
			return over
		# only the pick itself keeps its middle (a tap there puts it down,
		# two send it to the tin); any other jewel reaches for a patch
		if state.judge(over) == State.OK and _held_cells.has(over):
			reach = AIM_EDGE * _cell
	var lp := zoom.to_layout(at)
	var p := ((lp - _grid) / _cell).floor()
	var span := ceili(reach / _cell)
	var best := -1
	var best_d := reach
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var j: int = state.at_xy(Vector2i(int(p.x) + dx, int(p.y) + dy))
			if j < 0 or state.slot[j] != _held_c or state.cur[j] >= 0 or not _in_sight(j):
				continue
			var d := cell_centre(j).distance_to(lp)
			if d <= best_d:
				best_d = d
				best = j
	return best if best >= 0 else over

## With nothing in hand: the square under the finger if its button can be
## picked, or else the nearest one that can within AIM_REACH (a sewn
## button, a bare patch and linen have no pick of their own to keep).
func _aim_pick(at: Vector2, over: int) -> int:
	if over >= 0 and state.judge(over) == State.OK:
		return over
	var lp := zoom.to_layout(at)
	var p := ((lp - _grid) / _cell).floor()
	var reach := _reach()
	var span := ceili(reach / _cell)
	var now := _now()
	var best := -1
	var best_d := reach
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var j: int = state.at_xy(Vector2i(int(p.x) + dx, int(p.y) + dy))
			if j < 0 or state.judge(j) != State.OK or now < _arrive[j] or not _in_sight(j):
				continue
			var d := cell_centre(j).distance_to(lp)
			if d <= best_d:
				best_d = d
				best = j
	return best if best >= 0 else over

## How far the aim looks, in the picture's own measure: AIM_REACH squares,
## or a fingertip on the screen if that is more.
func _reach() -> float:
	return maxf(AIM_REACH * _cell, AIM_PX / maxf(0.01, zoom.k))

## The tin a finger at `at` means (`_tin_at`'s answer): on its wood or a
## free place with no run off the cloth in hand, the nearest place holding
## a button within TIN_REACH places; a run in hand goes in there anyway.
func _tin_aim(at: Vector2) -> int:
	var place := _tin_at(at)
	if place == -2 or (place >= 0 and state.tin[place] >= 0) or not _held_cells.is_empty():
		return place
	var best_d := TIN_REACH * _tin_step
	for p in _tin_places:
		if state.tin[p] < 0:
			continue
		var d := tin_centre(p).distance_to(at)
		if d <= best_d:
			best_d = d
			place = p
	return place

## A pan or a pinch has no button's click under it, so it ticks as it
## begins (the tutorial's page is silent).
func _gesture_tick() -> void:
	fx.touch(0.9)

## The tin under `local`: a place, -1 for its wood between places, -2 off it.
func _tin_at(local: Vector2) -> int:
	if _won or not _tin_rect.grow(_tin_step * 0.2).has_point(local):
		return -2
	for p in _tin_places:
		if tin_centre(p).distance_to(local) < _tin_step * 0.5:
			return p
	return -1

func _can_play() -> bool:
	if is_done() or out_of_hearts or _solved_at > -INF or _turning:
		return false
	return max_moves == 0 or moves_left > 0

## A tap on square `i`: picks the run of the button there, puts a pick back
## down, or -- on a bare patch -- sews the pick onto it. The harnesses and
## the tutorial call this too. `twice` is the second of two quick taps on
## one run: the run goes to the tin, as a tap on the tin would send it.
func tap(i: int, twice := false) -> void:
	if not _can_play() or i < 0 or _now() < _arrive[i]:
		return
	_tap_at = -INF
	if state.cur[i] < 0:
		if not holding():
			_refuse(i, "BB_REFUSE_PICK")
			return
		var places := _held_places
		var starts := {}
		var now := _now()
		for g in _held_cells:
			starts[g] = _held_pos(g, false, now)
		for p in places:
			starts[-1 - p] = _held_pos(p, true, now)
		var res: Dictionary = state.sew(_held_cells, places, i)
		if int(res.why) != State.OK:
			# a miss the aim found nothing for puts the pick down, no
			# refusal (the user, 2026-10-26: "if user miss click and there
			# is nothing to be done around it by the helper, just remove
			# selection")
			_drop()
			return
		# The ones no patch was left for stay picked, for the next bare patch
		# (the user, 2026-10-11: "it should keep selected until end or use
		# click on it again, so user can select a color and click into
		# different places of board to keep placing"). A pick that outlives
		# its move must never keep the tin's own out of reach: `tap_tin`.
		var kept: PackedInt32Array = res.kept
		if kept.is_empty():
			_unhold()
		elif _held_cells.is_empty():
			# the tin packs after a sew out of it, so the ones kept are not
			# where they were: the pick follows its colour to its new places
			_held_places = state.tin_of(_held_c)
		else:
			_held_cells = kept
		# (a pick too big to bob is drawn once and kept: what is left of it
		# is drawn again, or the ones sent stay on the screen where they were)
		_held_still = false
		_play(res, i, starts)
		return
	match state.judge(i):
		State.REFUSED_HOME:
			if holding():
				_drop()
			else:
				_refuse(i, "BB_REFUSE_HOME")
		State.OK:
			if twice:
				# the first tap picked the run, or put it down: either way the
				# second sends it, by the tin's own path (a full tin refuses
				# and the run stays picked)
				if not _held_cells.has(i):
					_pick(state.run_of(i), PackedInt32Array(), state.cur[i], cell_centre(i))
				tap_tin()
			elif _held_cells.has(i):
				_tap_run = _held_cells
				_drop()
				_tap_at = _now()
			else:
				_pick(state.run_of(i), PackedInt32Array(), state.cur[i], cell_centre(i))
				_tap_run = _held_cells
				_tap_at = _now()

## A tap on the tin (`place` -1: its wood): a run picked off the cloth goes
## in; with nothing picked, a button there picks every one of its colour in
## the tin.
func tap_tin(place := -1) -> void:
	if not _can_play():
		return
	_tap_at = -INF
	# A tap on a button in the tin is always a pick, whatever is held: the
	# tin's own are the way on when it is full, and a run still picked off
	# the cloth once kept them out of reach ("something is causing the game
	# to get stuck"). A run off the cloth goes in on a tap on a free place
	# or on the tin's wood.
	var on_button: bool = place >= 0 and state.tin[place] >= 0
	if not _held_cells.is_empty() and not on_button:
		var starts := {}
		var now := _now()
		for g in _held_cells:
			starts[g] = _held_pos(g, false, now)
		var res: Dictionary = state.stow(_held_cells)
		if int(res.why) != State.OK:
			fx.cue("locked")
			return
		# what the tin had no room for stays picked
		var kept: PackedInt32Array = res.kept
		if kept.is_empty():
			_unhold()
		else:
			_held_cells = kept
		_held_still = false
		_play(res, -1, starts)
		return
	var c: int = state.tin[place] if place >= 0 else -1
	if c < 0 or (holding() and _held_cells.is_empty() and _held_c == c):
		_drop()
		return
	if _now() < _tin_arrive[place]:
		return
	_pick(PackedInt32Array(), state.tin_of(c), c, tin_centre(place))

var _last_land := 0.0
## When the last landing ticked, into the tin (true) and onto a patch.
var _ticked_at := {}

## Sends a move's buttons on their way, one after another, each from where
## it hung (`starts`: a square, or -1 - place for one out of the tin) to
## its patch or its place in the tin. `at_cell` is the patch tapped, -1 for
## the tin.
func _play(res: Dictionary, at_cell: int, starts: Dictionary) -> void:
	var now := _now()
	var moves_: Array = res.moves
	var step := RUN_STEP
	var fly := 0.0 if Motion.reduce else FLY_TIME
	var order := 0
	var slides := 0
	var sliding := 0
	for m: Array in moves_:
		if int(m[0]) == State.SLIDE:
			sliding += 1
	var slide_step := minf(SLIDE_STEP, SLIDE_CAP / maxf(1.0, sliding))
	var sewn := 0
	var last := now
	var tin_k := _tin_step * TIN_FIT / _cell
	# landings counted as they come, on one shared counter
	var landed := [0]
	# the patches this move sews, to merge together once all have settled
	var homed := PackedInt32Array()
	for m: Array in moves_:
		var kind := int(m[0])
		if kind == State.SLIDE:
			# a jewel of the case moved along a place: a short hop, one after
			# another a slide_step apart, with no tick of their own (one
			# still picked hangs over its new place instead)
			if _held_places.has(int(m[2])):
				continue
			var hop := 0.0 if Motion.reduce else SLIDE_TIME
			var from_ := now + (0.0 if Motion.reduce else slides * slide_step)
			slides += 1
			_flights.append({"c": int(m[3]), "time": hop, "at": from_, "k0": tin_k, "k1": tin_k, "fc": false, "tc": false,
				"from": tin_centre(int(m[1])), "to": tin_centre(int(m[2]))})
			_tin_arrive[int(m[2])] = from_ + hop
			last = maxf(last, from_ + hop)
			continue
		var at := now + (0.0 if Motion.reduce else order * step)
		# `fc` and `tc`: the end is on the cloth (in the picture's own
		# measure, which the zoom moves) and not on the tin (the screen's)
		# a patch landing keeps HELD_SCALE to the end: the settle takes it down
		var f := {"c": int(m[3]), "time": fly, "at": at, "k0": HELD_SCALE, "k1": HELD_SCALE, "fc": true, "tc": true}
		match kind:
			State.TO_PATCH:
				f.from = starts.get(int(m[1]), cell_centre(int(m[1])))
				f.to = cell_centre(int(m[2]))
				_arrive[int(m[2])] = at + fly
				_mark(int(m[1]))
				_mark(int(m[2]))
				sewn += 1
				homed.append(int(m[2]))
			State.TO_TIN:
				f.from = starts.get(int(m[1]), cell_centre(int(m[1])))
				f.to = tin_centre(int(m[2]))
				f.tc = false
				f.k1 = tin_k
				_tin_arrive[int(m[2])] = at + fly
				_mark(int(m[1]))
			State.FROM_TIN:
				f.from = starts.get(-1 - int(m[1]), tin_centre(int(m[1])))
				f.to = cell_centre(int(m[2]))
				f.fc = false
				f.k0 = tin_k * HELD_SCALE
				_arrive[int(m[2])] = at + fly
				_mark(int(m[2]))
				sewn += 1
				homed.append(int(m[2]))
		_flights.append(f)
		var lands := at + float(f.time)
		last = maxf(last, lands)
		_after(lands - now, _landed.bind(kind, int(m[2]), landed, moves_.size()))
		order += 1
	var merged := _merge_all(homed, at_cell, last)
	_last_land = merged
	_bump_pill()
	_busy_for(merged - now + 0.1)
	# the streak: moves in a row that each sewed something
	if sewn > 0:
		_streak += 1
		if _streak >= 2:
			var semis: int = COMBO_STEPS[mini(_streak - 2, COMBO_STEPS.size() - 1)]
			_after(last - now, func() -> void:
				if not is_done():
					fx.cue("combo", pow(2.0, semis / 12.0), COMBO_DB))
		if _streak >= COMBO_FROM:
			_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
			_combo_n = _streak
			_combo_cell = at_cell
			_combo_at = _now()
			_combo_out_at = -INF
			if COMBO_CONFETTI.has(_streak) and not Motion.reduce:
				fx.confetti(_at_seen(at_cell), 14, _cell * 3.0)
	else:
		_streak = 0
		if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
			_combo_out_at = now
	if sewn >= BIG_RUN:
		_after(last - now, func() -> void:
			if not is_done():
				fx.cue("run")
				if not Motion.reduce:
					fx.confetti(_at_seen(at_cell), 10 + mini(sewn, 12), _cell * 4.0))
	if not (res.whole as Array).is_empty():
		_after(merged - now, _whole.bind(res.whole, at_cell))
	_request()
	note_move()
	_spend(1, last)
	if state.part_done():
		_part_sewn(merged)

## A move's jewels on their own slots merge together: once the last of them
## has settled, as a wave out of `at_cell`, the nearest first. The second
## the last merge ends (`last` with nothing to merge).
func _merge_all(homed: PackedInt32Array, at_cell: int, last: float) -> float:
	if homed.is_empty():
		return last
	var now := _now()
	var lands := now
	for to in homed:
		lands = maxf(lands, _arrive[to])
	if Motion.reduce:
		for to in homed:
			_merge_at[to] = lands
		return maxf(last, lands)
	var go := lands + Motion.RELEASE_TIME
	var origin: Vector2i = state.xy(at_cell if at_cell >= 0 else homed[0])
	var far := 1
	for to in homed:
		var d: Vector2i = state.xy(to) - origin
		far = maxi(far, maxi(absi(d.x), absi(d.y)))
	var step := minf(MERGE_WAVE, MERGE_WAVE_CAP / far)
	for to in homed:
		var d: Vector2i = state.xy(to) - origin
		_merge_at[to] = go + maxi(absi(d.x), absi(d.y)) * step
	_after(go - now, _merging.bind(homed, at_cell))
	return maxf(last, go + far * step + MERGE_TIME)

## The merge begins: one pop, a ring round the tapped patch, and a few
## sparkles over the jewels going in.
func _merging(homed: PackedInt32Array, at_cell: int) -> void:
	if is_done():
		return
	fx.cue("sew", MERGE_PITCH * randf_range(TICK_VARY.x, TICK_VARY.y), MERGE_DB)
	var c: int = state.slot[homed[0]]
	if at_cell >= 0 and _in_sight(at_cell) and not Motion.reduce:
		fx.ring(_at(at_cell), _cell * zoom.k * 1.1, Art.thread_for(Art.colour(state.colours[c])))
	if Motion.reduce:
		return
	var stride := maxi(1, ceili(float(homed.size()) / MERGE_SPARKLES))
	for k in range(0, homed.size(), stride):
		var to: int = homed[k]
		if _in_sight(to):
			_after(_merge_at[to] - _now() + MERGE_TIME * MERGE_SWELL, fx.sparkle.bind(_at(to), Pal.SUN))
	_request()

## One button has landed: its tick, a step up the run, and a ring where it
## was sewn.
func _landed(kind: int, where: int, landed: Array, of: int) -> void:
	var nth: int = landed[0]
	landed[0] += 1
	var pitch := pow(2.0, minf(RUN_CLIMB_MAX, nth * RUN_CLIMB) / 12.0) * randf_range(TICK_VARY.x, TICK_VARY.y)
	# A run lands a button every 0.04 s, and all at once with motion reduced:
	# its ticks and its knocks are a wheel spun, one every TICK_GAP, never a
	# rattle (fx.cue holds the sound to one in 60 ms but knocks every time).
	var now := _now()
	var into_tin := kind == State.TO_TIN
	var tick: bool = now - float(_ticked_at.get(into_tin, -INF)) >= TICK_GAP
	if tick:
		_ticked_at[into_tin] = now
		fx.cue("tin" if into_tin else "sew", pitch)
	# a ring every third, and of a long run RINGS in all (a ring is a draw)
	if not into_tin and nth % maxi(3, ceili(float(of) / RINGS)) == 0 and _in_sight(where):
		fx.ring(_at(where), _cell * zoom.k * 0.6, Art.thread_for(Art.colour(state.colours[state.slot[where]])))
	_bump_pill()
	_busy_for(Motion.BUMP_TIME)
	_request()

## A colour is whole: its buttons hop outward from the tapped patch.
func _whole(which: Array, from: int) -> void:
	if is_done():
		return
	var now := _now()
	var origin: Vector2i = state.xy(from)
	var far := 0
	var big := _big()
	var sparkles := 0
	for i in state.slot.size():
		if which.has(state.slot[i]):
			var d: Vector2i = state.xy(i) - origin
			var ring := maxi(absi(d.x), absi(d.y))
			# a sky of four hundred does not hop to its far corner
			if big and ring > WHOLE_REACH:
				continue
			far = maxi(far, ring)
			_hop_at[i] = now + ring * WHOLE_STEP
			_mark(i)
			if not Motion.reduce and (i * 7) % 5 == 0 and sparkles < SPARKLES and _in_sight(i):
				sparkles += 1
				fx.sparkle(_at(i), Pal.SUN)
	fx.cue("whole")
	_busy_for(Motion.SOLVE_TIME + far * WHOLE_STEP + 0.1)
	_tell(tr("BB_WHOLE"), from)
	_request()

## A tap that does nothing says so with the sound and the shiver alone: the
## toast is for a key event (the user, 2026-10-12: "remove the annoying
## message that keep showing after sending pieces around, no message needed
## at all if not a key event"). `why` names the refusal for a reader.
func _refuse(i: int, _why: String) -> void:
	fx.cue("locked")
	if not Motion.reduce and state.cur[i] >= 0:
		_shiver_at[i] = _now()
		_mark(i)
		_busy_for(Motion.SHIVER_TIME)
	_request()

func tip_line() -> Dictionary:
	return {"text": "", "mood": Face.Expr.HAPPY}

# --- the HUD's actions ---

func can_undo() -> bool:
	return max_moves == 0 and not is_done() and not out_of_hearts and not _turning and not state.history.is_empty()

## Takes the last tap back: its buttons are where they were, at once.
func undo() -> bool:
	if not can_undo() or not state.undo():
		return false
	_gen += 1
	_flights = []
	_arrive.fill(-INF)
	_merge_at.fill(-INF)
	_tin_arrive.fill(-INF)
	_hop_at.fill(-INF)
	_unhold()
	_live = {}
	_stale_all()
	_streak = 0
	_combo_n = 0
	_tin = null
	_bump_pill()
	fx.cue("undo", randf_range(TICK_VARY.x, TICK_VARY.y))
	_request()
	moved.emit()
	return true

func hints_left() -> int:
	return State.hints_for(state.band) + hints_extra - hints_used

## Makes the move the state's own hand would, as the player makes it: the
## pick, a beat, then the tap that says where it goes.
func hint() -> bool:
	if is_done() or out_of_hearts or _turning or hints_left() <= 0:
		return false
	var move: Dictionary = state.hint()
	if move.is_empty():
		return false
	hints_used += 1
	_unhold()
	var cells: PackedInt32Array = move.cells
	var places: PackedInt32Array = move.places
	var from_tin := cells.is_empty()
	var c: int = state.tin[places[0]] if from_tin else state.cur[cells[0]]
	var anchor := tin_centre(places[0]) if from_tin else cell_centre(cells[0])
	# a picture seen close is brought to the pick, and then to where it goes
	if not from_tin:
		zoom.show_point(anchor)
	var shown := anchor if from_tin else zoom.xf() * anchor
	fx.ring(shown, _cell * zoom.k * 0.7, Pal.SUN)
	fx.sparkle(shown, Pal.SUN)
	fx.cue("hint")
	_pick(cells, places, c, anchor)
	var to := int(move.to)
	_tell(tr("BB_HINTED"), to if to >= 0 else cells[0])
	_after(0.0 if Motion.reduce else HINT_BEAT, func() -> void:
		if to >= 0:
			zoom.show_point(cell_centre(to))
			tap(to)
		else:
			tap_tin()
		# the bulb's move is one move: what it could not place is let go
		_unhold()
		_request())
	return true

## The cloth as the day opened it, every button popping back on, and on
## Insane every tap back. The hints a player spent are not refunded.
func reset_board() -> void:
	if is_done() or out_of_hearts:
		return
	_restart()
	_tell(tr("BB_RESET"))
	fx.cue("reset")

func _restart() -> void:
	_gen += 1
	_turning = false
	state.reset()
	moves = 0
	_running = true
	zoom.reset()
	_deal()
	_opened = _now() - Motion.ENTER_DELAY
	if not _big():
		_mark_all()
	_busy_for(Motion.POP_IN + Motion.stagger(state.w + state.h, Motion.ENTER_STAGGER) + 0.1)
	_bump_pill()
	_request()

func is_solved() -> bool:
	return state.is_solved()

## The win's brain report: the fewest taps against the taps made (spec 2026-10-22-brain-skills, section 6).
func skill_quality() -> float:
	var par := int(state.par)
	if par <= 0:
		return -1.0
	return clampf(float(par) / float(maxi(state.taps, par)), 0.0, 1.0)

func completion_record() -> Dictionary:
	return {"taps": state.taps, "left": moves_left}

## A completed daily is rebuilt from its seed, so the cloth opens scrambled:
## every button is sewn on and the taps it took are put back.
func restore_completed_board() -> void:
	var now := _now()
	_gen += 1
	state.finish(int(completed_record.get("taps", state.par)))
	_turning = false
	_deal()
	_layout()
	moves_left = int(completed_record.get("left", 0))
	_opened = now - 10.0
	_solved_at = now - 10.0
	_slid_at = -INF
	_final_taps = state.taps
	_final_left = moves_left
	_anim_until = 0.0
	_stamp_at = now - 10.0 if _stamped() else INF
	_seal_mesh = null
	zoom.reset()
	_hud_layer.queue_redraw()
	_request()

func share_glyphs() -> String:
	var out: String = state.share_glyphs()
	out += "\n💎 %d" % _final_taps
	if max_moves > 0:
		out += " " + "⭐".repeat(mini(_final_left, 10))
	return out

# --- the win ---

## Whether the day earned the seal: any Insane cloth, or one sewn in no more
## taps than the state's own hand takes.
func _stamped() -> bool:
	return state.band >= State.INSANE or _final_taps <= state.par

func flat_win() -> Dictionary:
	var what := tr(state.name_key) if state.name_key != "" else title()
	var sub := tr("BB_WIN_SUB_ONE") % what if _final_taps == 1 else tr("BB_WIN_SUB_N") % [what, _final_taps]
	return {"faces": [], "subtitle": sub}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT + PARTY_EXTRA

## The last buttons land, the whole picture hops along its diagonals, the
## tin is put away and the picture has the table.
func _on_solved() -> void:
	var now := _now()
	_pressed = -1
	_toast = ""
	_unhold()
	_combo_n = 0
	_solved_at = now
	_final_taps = state.taps
	_final_left = moves_left - (1 if max_moves > 0 else 0)
	var lag := 0.0 if Motion.reduce else maxf(0.0, _last_land - now) + Motion.SOLVE_DELAY
	# the picture is seen whole for its win
	if zoom.zoomed():
		zoom.toggle()
	_hop_all(now + lag)
	_after(lag, fx.cue.bind("solved"))
	_hud_layer.queue_redraw()
	_party(lag)
	_busy_for(lag + Motion.SOLVE_TIME + 1.0 + WIN_SLIDE + 0.3)
	_request()

## The cloth's jewels hop along its diagonals from `from`.
func _hop_all(from: float) -> void:
	if _big():
		# a thousand buttons hop a block at a time, each block one mesh
		for b in _blocks.size():
			_block_hop[b] = from + Motion.stagger(b % _bw + b / _bw, BLOCK_STAGGER, 1.0)
	else:
		for i in state.slot.size():
			if state.slot[i] >= 0:
				var c: Vector2i = state.xy(i)
				_hop_at[i] = from + Motion.stagger(c.x + c.y, Motion.SOLVE_STAGGER, 1.0)
				_mark(i)

## A part of Insane's picture is sewn and another waits: it hops as a won
## picture does, with the colour-whole cue, and the next part comes on.
func _part_sewn(last: float) -> void:
	var now := _now()
	_turning = true
	_pressed = -1
	_unhold()
	_combo_n = 0
	var lag := 0.0 if Motion.reduce else maxf(0.0, last - now) + Motion.SOLVE_DELAY
	if zoom.zoomed():
		zoom.toggle()
	_hop_all(now + lag)
	_after(lag, func() -> void:
		fx.cue("whole")
		if not Motion.reduce:
			fx.confetti(zoom.to_screen(_field_px().get_center()), 24, _cell * 6.0))
	_busy_for(lag + PART_HOLD + 0.3)
	_after(0.0 if Motion.reduce else lag + PART_HOLD, _next_part)
	_request()

## The next part on the cloth, where the last one was played, its jewels
## popping in as a day's do (a slide of the whole picture along was tried
## and never seen to move in a harness: 2026-10-27).
func _next_part() -> void:
	_turning = false
	if not state.part_done():
		return
	state.next_part()
	zoom.reset()
	_deal()
	_layout()
	_enter()
	_bump_pill()
	_request()

func _party(lag: float) -> void:
	var now := _now()
	if _stamped():
		_stamp_at = now if Motion.reduce else now + lag + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_request())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
			_busy_for(lag + STAMP_AT + STAMP_DROP * 3.0)
	if Motion.reduce:
		return
	_after(lag + 0.15, func() -> void:
		var field := _field_px()
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell), 30, field.size.x * 0.8)
		fx.cue("party"))
	_after(lag + 0.6, func() -> void:
		var field := _field_px()
		fx.confetti(field.get_center(), 24, field.size.x * 0.6))

## The seal on the picture's lower right, dropping in and settling.
func _draw_stamp(now: float, shown: Array, slide: Transform2D) -> void:
	var field := _field_px()
	var rad := maxf(field.size.x, 420.0) * STAMP_R
	var insane: bool = state.band >= State.INSANE
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := field.end - Vector2(rad, rad) * 0.6
	var xf := slide * Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_cloth.draw_set_transform_matrix(xf)
	_cloth.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_cloth.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var neat: bool = _final_taps <= state.par
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02], [tr("BB_SEAL_NEAT") if neat else tr("BB_SEAL_INSANE"), 0.17, 0.36]]
	else:
		lines = [[tr("BB_SEAL_NEAT"), 0.24, 0.12]]
	Seal.text(_cloth, rad, lines)
	_cloth.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- Insane's taps ---

## Spends `cost` taps. The last one spent with buttons still loose is the
## board lost, once its buttons have landed.
func _spend(cost: int, land: float) -> void:
	if max_moves <= 0 or cost <= 0:
		return
	moves_left = maxi(0, moves_left - cost)
	_hud_layer.queue_redraw()
	if moves_left > 0 or is_done():
		return
	out_of_hearts = true
	_running = false
	_after(maxf(0.0, land - _now()) + (0.0 if Motion.reduce else 0.5), _run_out)

func _run_out() -> void:
	if _asleep:
		return
	_asleep = true
	_pressed = -1
	fx.cue("out_of_hearts")
	_tell(tr("BB_OUT"))
	_request()
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

## The card, over the whole screen: on the host so it covers the chrome, or
## on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["OUT_MOVES_BODY", "OUT_MOVES_REST"], MOVES_BONUS)
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same cloth from the top, every tap back, the clock from
## zero.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	elapsed = 0.0
	_restart()
	fx.cue("reset")
	moved.emit()

## A few more taps (the card's video): once a board.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	moves_left = MOVES_BONUS
	_bump_pill()
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	moved.emit()

func _leave() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- entrance ---

## The chrome is the host's; here the cloth pops in wide and the buttons pop
## onto it along the diagonals.
func _enter() -> void:
	_opened = _now()
	if not _big():
		_mark_all()
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP + Motion.POP_IN + Motion.stagger(state.w + state.h, Motion.ENTER_STAGGER))
	fx.cue("enter")

# --- odds and ends ---

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	if delay <= 0.0:
		what.call()
		return
	var gen := _gen
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0:
		return
	var now := _now()
	var gliding := zoom.step(delta)
	if gliding or zoom.busy() or now < _anim_until or now - _slid_at < WIN_SLIDE + 0.1:
		_request()
	# a zoomed picture is cut to its room; whole, it may pop and slide past it
	# (a part of a picture in parts is cut to it too: the rest runs on past
	# it, and the cloth is drawn over the case)
	_cloth.clip_contents = zoom.zoomed() or (state.in_parts() and not _won)
	_over.clip_contents = zoom.zoomed()
	var wanted := _zoom_button_wanted()
	if _zoom_b.visible != wanted:
		_zoom_b.visible = wanted
	if wanted:
		_zoom_b.set_icon("plus" if zoom.next_in() else "minus")
	var since := now - _opened - Motion.ENTER_DELAY
	if since < Motion.DROP_FADE + 0.1 or now - _pill_bump < Motion.BUMP_TIME + 0.1 \
			or (_toast != "" and now - _toast_at < TOAST_HOLD + 0.1) \
			or (_combo_n >= COMBO_FROM and (now - _combo_at < COMBO_HOLD + 0.1 or _combo_out_at > -INF)) \
			or (gliding and _combo_n >= COMBO_FROM):
		_hud_layer.queue_redraw()

## Draws the board again: the linen and the tin, the picture, what flies.
func _request() -> void:
	queue_redraw()
	if _cloth != null:
		_cloth.queue_redraw()
		_over.queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
