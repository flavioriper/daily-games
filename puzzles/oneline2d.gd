extends "res://core/puzzle_base.gd"

## One Line as a flat board: the figure drawn square-on on the host's
## parchment card, its lines lying as dark stone fords, and a snail walking
## the stroke that lays a warm plank over every one it crosses. Built beside
## the island version (puzzles/oneline3d.gd) so the two can be judged against
## each other on the phone; the rules live in puzzles/oneline_state.gd, which
## this only draws.
##
## What flat buys here is the figure. Half of a hard board's lines are
## diagonals, and seen at seven degrees a 45-degree plank is not at 45 degrees
## any more: the lattice shears, the near rows stretch, the far rows crowd,
## and the shape the player is asked to trace is a shape the camera invented.
## Worse, One Line is the only board in the set that asks a question about the
## *whole* drawing -- is what is left still all in one piece from where I
## stand -- which is the last thing that should be foreshortened. Square-on,
## the figure is the figure, and a crossing stops being a rendering problem:
## the island has to lift every plank 0.0008 per edge index to keep two
## coplanar top faces from z-fighting, and here the later stroke is simply on
## top. **And it buys the walker.** On the island the player's finger is the
## walker and the planks rise behind it; flat, a small character can ride the
## stroke and lay the line as it goes, which makes "without lifting your
## finger" literal and costs a canvas almost nothing.
##
## How it is drawn. The whole figure is **one** mesh, rebuilt only while
## something is moving: every line as a stone stroke, every plank walked over
## it, and every post as a drum with its coloured cap over its own soft
## shadow. The stone runs first and the planks all go over it, so the trail is
## never cut by a line nobody has walked. Only the walker is a Control, with
## the face family's cached meshes behind it (ui/faces/snail_face.gd), and it
## stands in a slot the board positions every frame (the ride, the facing and
## the rock) so the recipes can tween the snail inside it.
##
## Motion is the flat boards' shared vocabulary (core/motion.gd,
## docs/art/flat-motion.md): the posts and lines are drawn, so they read the
## recipes as curves off Motion, and the walker takes them as tweens. What is
## this board's own is the walk itself -- the plank growing under the snail
## over LAY_TIME -- and the trail warming back along itself on the win.
## Spec: docs/superpowers/specs/2026-09-18-oneline-flat-design.md, sections 2
## to 7 and the amendment in section 11, and the mock it is ported from
## (docs/brainstorm/concepts.html#oneline).

const State = preload("res://puzzles/oneline_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Face = preload("res://ui/faces/face.gd")
const SnailFace = preload("res://ui/faces/snail_face.gd")
const MushroomFace = preload("res://ui/faces/mushroom_face.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"

# --- the field ---
## The card's inset around the figure.
const PAD := 40.0
## The lattice keeps **square spacing** -- the same distance across as down --
## so a diagonal stays a diagonal and the figure reads as a drawing rather
## than as a stretched grid. This is the post and its air at the edge of the
## figure, in steps, which is what the lattice needs beyond its own span.
const MARGIN := 0.8

# --- the pieces, in steps ---
const POST_R := 0.17
const LINE_W := 0.13
const PLANK_DEEP_W := 0.15
const PLANK_W := 0.115
## The walker's radius. 0.15 left a snail a third the size of a post's
## drum, which read as a speck beside the figure it is meant to be walking.
const SNAIL_R := 0.2
## How high above the line the walker rides: on a post it stands on the
## drum's rim above the cap, which is the one thing it must never hide; out
## on a line it comes down to ride the plank it is laying. It climbs between
## the two within CLIMB of a post.
const POST_LIFT := 0.3
const PLANK_LIFT := 0.12
const CLIMB := 0.3
## Out on a line the walker leans with it, up to TILT_MAX, so it climbs a
## diagonal rather than skating along it; on a post it stands level.
const TILT_MAX := 0.5
## A change of heading turns the walker round over TURN rather than
## flipping it on one frame.
const TURN := 0.14
## The crawl: a snail does not rock, it stretches and gathers. The walker's
## length swells by CRAWL at CRAWL_RATE while it is on the move.
const CRAWL := 0.07
const CRAWL_RATE := 26.0
## How close a tap or a drag has to pass a post to take it. The line between
## two posts is never in doubt, so there is nothing to aim at but the post:
## this is simply a thumb-sized reach, and it is the tightest gesture of the
## eight flat screens (37 CSS pixels on hard).
const REACH := 0.42
## The ford: a soft shadow under each stone line, and a lit crest along its
## upper side, both in steps. The crest is drawn without caps: a stroke's
## round caps overlap its body and double the alpha at each end.
const FORD_SHADOW := Vector2(0.0, 0.035)
const FORD_SHADOW_A := 0.1
const CREST_W := 0.03
const CREST_A := 0.16
## The plank is a boardwalk: slats about SLAT long, with a seam of the deep
## wood between them, each cut within SLAT_TONE of the plank's colour off a
## hash of its line and place, so a figure is laid the same way every time.
## A slat lands over SLAT_POP once the walker is past it, flat and then wide.
const SLAT := 0.21
const SEAM := 0.018
const SLAT_TONE := 0.06
const SLAT_POP := 0.2
const SLAT_LIGHT_A := 0.28
## The walker's sheen: a wet shine along the middle of the plank behind it,
## SHEEN long and SHEEN_A at the snail, fading out over SHEEN_FADE once it
## lands.
const SHEEN := 0.55
const SHEEN_A := 0.42
const SHEEN_FADE := 0.45
## Before the stroke begins, the posts it may begin at glow in the family's
## green: a soft disc under the drum, GLOW_SPREAD post radii across.
const GLOW_A := 0.26
const GLOW_SPREAD := 1.85
## A cap's lip: a darker crescent under it, so it sits in the drum.
const CAP_LIP := 0.18
## On the win the glint that runs down each plank as it warms, GLINT long
## in steps, and every cap turns toward the sun as the warmth reaches it.
const GLINT := 0.3
const GLINT_A := 0.55
const CAP_WARM := 0.75

## The post's shadow on the parchment: the family's soft disc, whose rim
## fades, so it needs about twice the peak of the flat 0.13 ellipse it
## replaced to read the same.
const SHADOW_A := 0.24
const SHADOW_SPREAD := 1.15
## The hint's ring, in post radii: it starts just outside the drum.
const RING_R := 1.6
## How far a post sunk under the finger goes toward its deep colour at the
## bottom of its press: the family's 0.94 alone is five pixels on a drum this
## size, and Light Up found the same on its stones.
const SINK_SHADE := 0.5

# --- this board's own motion ---
## The island's own LAY_TIME: a plank grows under the walker over this, which
## is also exactly how long the walker takes to cross the line.
const LAY_TIME := 0.28
const ROCK := 0.07
const ROCK_RATE := 9.0
const ROCK_STILL := 0.25
## On the win every plank warms a shade brighter along the trail, in walk
## order at the family's solve stagger, and the posts hop as the warmth
## reaches them: the stroke runs back along itself. This is how long each
## plank takes to warm.
const BRIGHT_TIME := 0.35
## The beat the host waits after the last post has landed before the win
## screen.
const WIN_SETTLE := 0.3

# --- the polish pass (docs/superpowers/specs/2026-09-30-oneline-polish-design.md) ---
## The hearts over the figure: Light Up's, Tents' and Shikaku's pill.
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
## A wrong step: the walker lands, worries, and EJECT_AFTER later the plank
## comes back up under her as she slides home. The plank blushes meanwhile.
const EJECT_AFTER := 0.85
## Out of hearts: the figure slips to dusk and the card comes up after.
const DUSK := Color(0.74, 0.76, 0.92)
const DUSK_TIME := 0.8
const CARD_AFTER := 1.1
const CARD_AFTER_STILL := 0.3
## The streak (Binairo's, Shikaku's, Tents', Light Up's).
const COMBO_FROM := 3
const COMBO_STEPS := [-5, -3, 0, 2, 4, 7, 9]
const COMBO_DB := -4.0
const COMBO_CONFETTI := [5, 10]
const COMBO_DEFLATE := 0.25
## The bubble shows its number this long, then deflates on its own; the
## streak itself runs on, and the next right move pops it back in.
const COMBO_HOLD := 1.2
const COMBO_FONT := 44
## Gags, three of every GAG_ODDS right steps by the line's own hash.
const GAG_ODDS := 5
const GAGS := 3
const GLASSES_IN := 0.28
const GLASSES_HOLD := 1.0
const GLASSES_OUT := 0.2
const LOVE_HEARTS := 4
const LOVE_TIME := 1.3
const LOVE_RISE := 0.55
const LOVE_R := 0.11
const MUSH_HOLD := 1.4
const MUSH_SIZE := 0.62
## Ladybugs that come to ride the shell on Hard and Insane: one at the first
## judged step, then at these shares of the figure.
const BUG_AT := [0.0, 0.4, 0.75]
const BUG_FLY := 0.6
const BUG_R := 0.075
## A spent post blooms: a daisy opens on its pale cap.
const DAISY_PETALS := 7
const DAISY_R := 0.72
const DAISY_TIME := 0.45
## Sunny Spells: the sunny ford's sparkles and the dewy ford's drops, in
## steps, and how far a refused sunny line fades while the snail is dry.
const SUN_SPARK := 0.05
const DEW_DROP := 0.04
const DRY_FADE := 0.45
## The landing squash each step ends in.
const LAND_SQUASH := 0.1
## The seal and the party.
const STAMP_AT := 0.35
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.16
const STAMP_TILT := -0.22
const PARTY_AT := 0.1
const PARTY_HAT := 0.3
const PARTY_EXTRA := 1.4
const PETALS := 5
const PETAL_TIME := 1.8
const PETAL_FALL := 1.1
const PETAL_STAGGER := 0.04

const HINTS := State.HINTS
## The figure's pieces: one of each per post or per line, each with its own
## run of vertices in the figure mesh (`_slot`).
enum { PIECE_GLOW, PIECE_SHADOW, PIECE_FORD, PIECE_STONE, PIECE_PLANK,
	PIECE_DRUM, PIECE_CAP, PIECE_DAISY }
## The steps a line's fade is drawn in while it arrives, so even an arriving
## line is a cached piece.
const FADE_STEPS := 4
const TIP_CYCLE := 10.0
## The three lines that teach the board, cycled while there is nothing better
## to say.
const TIPS := [
	"OL_TIP_START",
	"OL_TIP_DRAG",
	"OL_TIP_GREEN",
]

## Back to camp from the out-of-hearts card: the host leaves the board.
signal leave

var state = State.new()

var hearts := 0
var max_hearts := 0
var out_of_hearts := false
var _heart_used := false
var _lost_ever := false
var _asleep := false
var _ejecting := false
var _worried := false
var _heart_card: Control
var _split_index := -1
var _split_at := -INF
var _back_index := -1
var _back_at := -INF
var _heart_layer: Control
var _hearts_shown: ArrayMesh
var _dusk_tw: Tween
## Line -> when its plank blushed: a wrong step's plank before it comes up.
var _bad_plank: Dictionary = {}
var _flawless := false
var _streak := 0
var _combo_n := 0
var _combo_post := 0
var _combo_at := -INF
var _combo_popped := false
var _combo_out_at := -INF
var _combo_layer: Control
var _combo_shown: ArrayMesh
## Post -> when its daisy opened.
var _bloom: Dictionary = {}
## The life over the figure: the love hearts along a plank, ladybugs flying
## in, petals falling at the party, and the seal.
var _life_layer: Control
var _life_shown: Array = []
var _life_alive := false
var _love: Array = []
var _bugs: Array = []
var _petals: Array = []
var _stamp_at := INF
var _seal_mesh: ArrayMesh
var _love_mesh: ArrayMesh
var _bug_mesh: ArrayMesh
var _mushroom: MushroomFace
var _mush_tw: Tween
var _gag_tw: Tween
var _squash_tw: Tween
## The names the win harness and the island board share, so one driver solves
## both twins: they are the state's own.
var _edges: Array:
	get: return state.edges
var _nodes: Array:
	get: return state.nodes
var _walked: Dictionary:
	get: return state.walked

var fx: Node2D
var snail: SnailFace
## The walker's slot: the board writes its position, its facing and its rock
## every frame; the snail inside takes the recipes (rule 2 of the motion doc).
var _seat: Control
var _step := 0.0
var _origin := Vector2.ZERO
var _card := Rect2()

## The line in flight, and the walker's own travel with it:
## {"edge", "from", "to", "at", "up", "to_cap"}. `from` and `to` are posts --
## the walker goes from one to the other in either direction -- and `up` is
## false for an undo, where the plank sinks back to stone instead of growing.
## The plank always grows from the end it was originally walked from
## (`up` ? from : to), which is what keeps the trail behind the snail and
## never against it. `to_cap` is the colour the far post wore before the
## move: it keeps it until the walker lands, and takes its new one with the
## Count bump then.
var _stroke: Dictionary = {}
## Every drawn thing's moments, keyed by post or line, each the second it
## began, read off Motion's curve readers in _cast_figure.
var _post_press: Dictionary = {}  # post -> {"down", "up"}
var _post_hop: Dictionary = {}    # post -> {"at", "height", "time"}
var _cap_bump: Dictionary = {}    # post -> at: the cap was recounted
var _post_shiver: Dictionary = {} # post -> at: a refused press
var _post_blush: Dictionary = {}  # post -> at: the drum blushes
var _wrong: Dictionary = {}       # line -> at: Check found it stranded
var _bright: Dictionary = {}      # line -> at: it warms on the win
var _warm: Dictionary = {}        # post -> at: its cap turns on the win
## Planks taken up by Reset, shrinking to nothing where they lay:
## [{"from": Vector2, "to": Vector2, "at": float}].
var _gone: Array = []
## Where the walker last stood, and when Reset popped it out, so the slot
## stays put through the pop rather than vanishing with state.current.
var _walker_rest := Vector2.ZERO
var _walker_out := -100.0
var _walker_dir := 1.0
## The walker's facing as drawn, easing toward _walker_dir through a turn,
## and the clock the ease last read.
var _face := 1.0
var _placed_at := 0.0
var _joy := false
var _opened := 0.0
var _anim_until := 0.0
var _settling := false
var _solved_at := -1.0
var _gen := 0
var _look_tw: Tween
var _pos_tw: Tween

## The figure as one indexed mesh, put together each frame something on it
## moves without building more than the moving pieces in script
## (`_cast_figure`). Every piece -- a post's glow, shadow, drum, cap and
## daisy, a line's shadow, stone and plank -- owns a run of vertices sized at
## layout for its largest look (`_slot`: Vector2i(piece, index) ->
## Vector2i(base, room)), so its indices, offset to that run once, stay true
## whatever else changes. A look is made once (`_looks`: Vector4i(piece,
## index, look, 0) -> [verts, cols, offset indices, fits]) and copied in
## natively, under the piece's transform when it pops, hops or wobbles; only a
## piece whose colours move (a blush, a press, a warming cap, the plank being
## laid) is built in script. Cut to the step and the figure, so cleared on
## both. A flat triangle list instead (one native copy, no indices) was four
## times the vertices and 1.3 ms a frame more to draw on a full Insane figure.
var _slot: Dictionary = {}
var _looks: Dictionary = {}
var _fixed := 0
var _fv := PackedVector2Array()
var _fc := PackedColorArray()
var _fi := PackedInt32Array()
var _tv := PackedVector2Array()
var _tc := PackedColorArray()
var _figure: ArrayMesh
## The mesh the last _draw actually handed to the canvas item. A canvas
## command holds the mesh by RID and not by reference, so dropping the only
## reference to a mesh still on the item's command list leaves the renderer
## drawing a freed RID ("Parameter mesh is null", and an empty card) on any
## frame rendered without its queued redraw flushed first -- which is what
## RenderingServer.force_draw() in a harness does.
var _shown: ArrayMesh

var _drawing := false
var _pressed_post := -1
var _walker_pressed := false
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "oneline"
func title() -> String: return "One Line"

func rules() -> String:
	var out := tr("OL_RULES")
	if state.has_sun():
		out += "\n\n" + tr("OL_RULES_SUN")
	if max_hearts > 0:
		out += "\n\n" + (tr("OL_RULES_HEARTS_1") if max_hearts == 1 else tr("OL_RULES_HEARTS_N") % max_hearts)
	return out

## The lines the sprout cycles: a sunny figure leads with the sun's two.
func _tips() -> Array:
	if state.has_sun():
		return ["OL_TIP_SUN", "OL_TIP_POSTS"] + TIPS
	return TIPS

## The tutorial, a page a rule, each a little house walked by the board
## itself (ui/hud/oneline_tutorial_diagram.gd): one stroke, the green posts,
## never twice, stranding (with hearts on Hard and Insane), the hint, then
## Sunny Spells on Insane.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/oneline_tutorial_diagram.gd")
	var hints: int = State.HINTS_BY_BAND[clampi(state.band, 0, 3)]
	var steps := [
		[Diagram.Lesson.TRACE, "HTP_OL_TRACE", tr("HTP_OL_TRACE_BODY")],
		[Diagram.Lesson.START, "HTP_OL_START", tr("HTP_OL_START_BODY")],
		[Diagram.Lesson.ONCE, "HTP_OL_ONCE", tr("HTP_OL_ONCE_BODY")]]
	if max_hearts > 0:
		steps.append([Diagram.Lesson.STRAND, "HTP_TN_HEARTS",
			tr("OL_RULES_HEARTS_1") if max_hearts == 1 else tr("OL_RULES_HEARTS_N") % max_hearts])
	else:
		steps.append([Diagram.Lesson.STRAND, "HTP_OL_STRAND", tr("HTP_OL_STRAND_BODY")])
	steps.append([Diagram.Lesson.HINT, "HTP_TN_HINT",
		tr("HTP_OL_HINT_BODY_ONE") if hints == 1 else tr("HTP_OL_HINT_BODY_N") % hints])
	if state.has_sun():
		steps.append([Diagram.Lesson.SUN, "OL_SUN_SEAL", tr("OL_RULES_SUN")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.hearts = max_hearts
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

## What the phone does under each cue (docs/agents/haptics.md). The walker
## set down and a plank laid are the faintest knock, a post at a time as the
## finger crosses them (a hint's own step is under its `hint`), and a line
## taken back fainter still; the streak's confetti is the milestone. On Easy
## and Medium the step that first strands a line warns (`_walk_to`: it has
## no cue); on Hard and Insane that step costs the heart instead. A post
## that will not start, a walked line, a sunny line refused (`locked`,
## `sun`), the eject's `slip`, the daisies, the dew, the streak's pluck and
## the gags say nothing. The seal thuds as it lands (`_party`).
const HAPTICS := {
	"undo": Haptics.TICK,
	"start": Haptics.TAP,
	"lay": Haptics.TAP,
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
	fx.haptics = HAPTICS
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_seat = Control.new()
	_seat.name = "WalkerSeat"
	_seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seat.z_index = 1
	add_child(_seat)
	snail = SnailFace.new()
	snail.name = "Walker"
	snail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seat.add_child(snail)
	snail.set_idle(true)
	_mushroom = MushroomFace.new()
	_mushroom.name = "Mushroom"
	_mushroom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mushroom.z_index = 1
	_mushroom.visible = false
	add_child(_mushroom)
	_life_layer = _layer("Life", 2, _draw_life)
	_heart_layer = _layer("Hearts", 1, _draw_hearts)
	_combo_layer = _layer("Combo", 3, _draw_combo)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

## A full-rect layer over the figure, drawn by `draw` (Tents', Light Up's).
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
	_stop_all()
	state.setup(rng, difficulty, bank_step)
	max_hearts = State.HEARTS[state.band]
	_heart_used = false
	_lost_ever = false
	_deal()
	_stroke = {}
	_post_press = {}
	_post_hop = {}
	_cap_bump = {}
	_post_shiver = {}
	_post_blush = {}
	_wrong = {}
	_bright = {}
	_warm = {}
	_gone = []
	_walker_out = -100.0
	_joy = false
	_drawing = false
	_pressed_post = -1
	_solved_at = -1.0
	_layout()
	_enter()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()

## The figure as it is dealt, and as Try again deals it back: every heart,
## the day's light, nothing judged, blooming or riding.
func _deal() -> void:
	_slot = {}
	_looks = {}
	hearts = max_hearts
	out_of_hearts = false
	_asleep = false
	_ejecting = false
	_worried = false
	_split_index = -1
	_back_index = -1
	_bad_plank = {}
	_flawless = false
	_streak = 0
	_combo_n = 0
	_combo_out_at = -INF
	_bloom = {}
	_love = []
	_bugs = []
	_petals = []
	_stamp_at = INF
	_seal_mesh = null
	Motion.stop(_dusk_tw)
	modulate = Color.WHITE
	if snail != null:
		snail.riders = 0
		snail.dry = false
		snail.glasses = 0.0
		snail.hat = 0.0
	if _mushroom != null:
		_mushroom.visible = false
	for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
		if layer != null:
			layer.queue_redraw()

# --- layout ---

## The figure is the largest square-spaced lattice the card holds, and the
## card is then cut to the figure and centred in the slot rather than pinned
## under the day card. Easy and hard fill it; medium, whose lattice is wider
## than it is tall, leaves air above and below in equal measure -- which reads
## as room, where all of it below would read as a board that fell over.
func _layout() -> void:
	if state.nodes.is_empty():
		return
	_step = _step_for(size.y)
	if _step <= 0.0:
		return
	_slot = {}
	_looks = {}
	var figure := Vector2(_step * (state.cols - 1), _step * (state.rows - 1))
	var row := _heart_row()
	var tall := minf(size.y, figure.y + 2.0 * PAD + _step * MARGIN + row)
	_card = Rect2(0.0, (size.y - tall) * 0.5, size.x, tall)
	_origin = Vector2(size.x * 0.5 - figure.x * 0.5,
		_card.position.y + row + (tall - row - figure.y) * 0.5)
	# The life's meshes are cut to the step; a new step cuts them again.
	_love_mesh = null
	_bug_mesh = null
	var mush := _step * MUSH_SIZE
	_mushroom.size = Vector2.ONE * mush
	_mushroom.pivot_offset = _mushroom.size * 0.5
	var seat := _step * SNAIL_R * SnailFace.SEAT
	_seat.size = Vector2.ONE * seat
	_seat.pivot_offset = _seat.size * 0.5
	snail.size = _seat.size
	snail.pivot_offset = snail.size * 0.5
	_refresh()

## The lattice step a slot of `available` height holds. The figure's span is
## one step short of its lattice, plus the MARGIN a post and its air want at
## each edge.
func _step_for(available: float) -> float:
	if state.nodes.is_empty():
		return 0.0
	return minf((size.x - 2.0 * PAD) / (float(state.cols) - 1.0 + MARGIN),
		(available - 2.0 * PAD - _heart_row()) / (float(state.rows) - 1.0 + MARGIN))

## The strip the hearts take over the figure, on a board that has them.
func _heart_row() -> float:
	return HEART_ROW if max_hearts > 0 else 0.0

## The host cuts its card to the figure and centres it, which is what these
## two say.
func card_height(available: float) -> float:
	var one := _step_for(available)
	if one <= 0.0:
		return available
	return minf(available, one * (float(state.rows) - 1.0 + MARGIN) + 2.0 * PAD + _heart_row())

func card_centred() -> bool:
	return true

## Control-local point over post `n`. The win harness taps these, exactly as
## it does on the island board.
func node_to_local(n: int) -> Vector2:
	return _origin + Vector2(n % state.cols, n / state.cols) * _step

## The post nearest `at` within a thumb of it, or -1.
func _nearest(at: Vector2) -> int:
	if _step <= 0.0:
		return -1
	var best := -1
	var closest := _step * REACH
	for n in state.nodes:
		var d := at.distance_to(node_to_local(n))
		if d < closest:
			closest = d
			best = n
	return best

## A post's place on the diagonal from the top-left corner, which paces the
## entrance and the solve wave; the far corner paces Reset.
func _diagonal(n: int) -> int:
	return n % state.cols + n / state.cols

func _far() -> int:
	var far := 0
	for n in state.nodes:
		far = maxi(far, _diagonal(n))
	return far

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _step <= 0.0 or state.nodes.is_empty():
		return
	var now := _now()
	# One build past the motion, with every piece at its rest: the last
	# animating frame was a step short of it, and this one fills the cache.
	if now < _anim_until or _settling:
		_settling = now < _anim_until
		_refresh()
	if (_split_index >= 0 and now - _split_at < SPLIT_TIME + 0.1) \
			or (_back_index >= 0 and now - _back_at < HEART_BACK_TIME + 0.1):
		_heart_layer.queue_redraw()
	if _combo_n >= COMBO_FROM and (now - _combo_at < COMBO_HOLD + 0.1 or _combo_out_at > -INF):
		_combo_layer.queue_redraw()
	# One more redraw once the life goes quiet, so the last frame of a
	# landing ladybug or a fading heart is not left standing.
	var alive := _tick_life(now)
	if alive or _life_alive:
		_life_layer.queue_redraw()
	_life_alive = alive

## Keeps the figure redrawing for `seconds` more: something on it is moving.
## Nothing is rebuilt on a frame outside that, which is most of them: a
## figure sitting still costs the walker's blinks and nothing else.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _refresh() -> void:
	if _step <= 0.0 or state.nodes.is_empty():
		return
	var t := _now()
	_place_walker(t)
	_cast_figure(t)
	queue_redraw()

# --- the walker ---

## The snail rides the stroke: on the post it stands on, or part way along the
## line it is crossing, facing the way it is heading, leaning with the line
## and stretching as it crawls. The slot carries all of that; the snail inside
## it carries the recipes.
func _place_walker(t: float) -> void:
	var dt := clampf(t - _placed_at, 0.0, 0.1)
	_placed_at = t
	var leaving := t < _walker_out + Motion.POP_OUT and not Motion.reduce
	if state.current < 0 and not leaving:
		_seat.visible = false
		return
	_seat.visible = true
	var at := _walker_rest
	var dir := _walker_dir
	var moving := false
	var tilt := 0.0
	if state.current >= 0:
		var ride := _ride(t)
		at = ride.at - Vector2(0.0, _step * lerpf(POST_LIFT, PLANK_LIFT, ride.out))
		dir = ride.dir
		moving = ride.moving
		tilt = ride.tilt * ride.out
		_walker_rest = at
		_walker_dir = dir
	if Motion.reduce:
		_face = dir
	else:
		_face = move_toward(_face, dir, dt * 2.0 / TURN)
		if not is_equal_approx(_face, dir):
			_busy_for(TURN)
	# Through the turn the walker narrows to its edge and never to nothing.
	var across := signf(_face if _face != 0.0 else dir) * maxf(absf(_face), 0.2)
	var stretch := 0.0
	if moving and not Motion.reduce:
		stretch = CRAWL * sin(t * CRAWL_RATE)
	_seat.position = at - _seat.size * 0.5
	_seat.scale = Vector2(across * (1.0 + stretch), 1.0 - stretch * 0.6)
	var rock := 0.0 if Motion.reduce or moving else sin(t * ROCK_RATE) * ROCK * ROCK_STILL
	_seat.rotation = tilt + rock
	if _joy:
		snail.expression = Face.Expr.JOY
	elif _asleep:
		snail.expression = Face.Expr.SLEEPY
	elif _worried:
		snail.expression = Face.Expr.WORRIED
	elif not state.stranded().is_empty():
		snail.expression = Face.Expr.STRAIN
	else:
		snail.expression = Face.Expr.HAPPY
	snail.dry = state.dry() and not is_done() and _stroke_landed(t)

## Whether the line in flight (if any) has been crossed: the snail dries out
## as she steps off a sunny line, not as she steps onto it.
func _stroke_landed(t: float) -> bool:
	return _stroke.is_empty() or Motion.reduce or t >= float(_stroke.at) + LAY_TIME

## Where the walker is, which way it faces, whether it is on the move, how far
## out on the line it is (0 on a post, 1 once it is CLIMB clear of both), and
## the lean the line asks of it.
func _ride(t: float) -> Dictionary:
	var at := node_to_local(state.current)
	var dir := 1.0
	var moving := false
	var out := 0.0
	var tilt := 0.0
	if not _stroke.is_empty():
		var a := node_to_local(int(_stroke.from))
		var b := node_to_local(int(_stroke.to))
		var u := _dec((t - float(_stroke.at)) / LAY_TIME)
		dir = 1.0 if b.x >= a.x else -1.0
		if u < 1.0:
			at = a.lerp(b, u)
			moving = true
			var clear := minf(u, 1.0 - u) * a.distance_to(b)
			out = smoothstep(0.0, _step * CLIMB, clear)
			var d := b - a
			tilt = clampf(atan2(d.y, absf(d.x)) * dir, -TILT_MAX, TILT_MAX)
	return {"at": at, "dir": dir, "moving": moving, "out": out, "tilt": tilt}

## The walker arrives on a post: with the squash when a tap stood it there,
## or from above when a hint did (the Hint moment).
func _walker_arrives(drop: bool) -> void:
	Motion.stop(_look_tw)
	Motion.stop(_pos_tw)
	snail.rotation = 0.0
	snail.position = Vector2.ZERO
	snail.modulate.a = 1.0
	snail.visible = true
	if drop:
		snail.scale = Vector2.ONE
		_pos_tw = Motion.drop_in(snail)
		_busy_for(Motion.DROP_TIME)
	else:
		_look_tw = Motion.pop_in(snail)
		_busy_for(Motion.POP_IN)

## The walker sinks under the finger with its post, and springs back.
func _walker_press(down: bool) -> void:
	Motion.stop(_look_tw)
	_look_tw = Motion.press(snail, down)
	_busy_for(Motion.PRESS_TIME if down else Motion.RELEASE_TIME)

## The walker hops `height` over `time` after `delay`, from its rest.
func _walker_hop(height: float, time: float, delay := 0.0) -> void:
	Motion.stop(_pos_tw)
	snail.position = Vector2.ZERO
	_pos_tw = Motion.hop(snail, height, time, delay, 0.0)
	_busy_for(delay + time)

# --- the drawing ---

func _draw() -> void:
	_shown = _figure
	if _shown != null:
		draw_mesh(_shown, null)

## The whole figure in one mesh: every post's shadow and glow, every line's
## shadow, every line as stone, every plank walked over it, then the posts.
## The stone runs in one pass before any plank, so a walked line is never cut
## where an unwalked one crosses it -- the island cannot do that at all, since
## its planks are solids at the same height.
##
## Building the whole of a 45-line Insane figure in script was 16-20 ms, on
## every frame anything on it moved (the checkup,
## docs/agents/boards/oneline.md); now a piece at rest, or only popping,
## hopping or wobbling, is a native copy of a look made once (`_slot`).
func _cast_figure(t: float) -> void:
	if _slot.is_empty():
		_lay_slots()
	_fv = PackedVector2Array()
	_fc = PackedColorArray()
	_fi = PackedInt32Array()
	_tv = PackedVector2Array()
	_tc = PackedColorArray()
	var R := _step * POST_R
	var glow: bool = state.current < 0 and not is_done()
	for n in state.nodes:
		var grow := _post_entrance(n, t)
		if grow.y <= 0.0:
			continue
		var at := node_to_local(n)
		var xf := _about(at, at, grow)
		if glow and state.may_start(n):
			_show(PIECE_GLOW, n, 0, _build_glow.bind(n), xf)
		var under := at + Vector2(0.05, 0.3) * R
		_show(PIECE_SHADOW, n, 0, _build_shadow.bind(n), _about(under, under, grow))
	var lines: Dictionary = {}
	for i in state.edges.size():
		var pose := _line_pose(i, t)
		if not pose.is_empty():
			lines[i] = pose
	for i in lines:
		var pose: Array = lines[i]
		_show(PIECE_FORD, i, pose[1], _build_ford.bind(i, pose[1]), pose[0])
	var lost: Dictionary = {}
	for e in state.stranded():
		lost[e] = true
	var refused := _refused_now(t)
	for i in lines:
		var pose: Array = lines[i]
		var blush := Motion.flash_level(t - float(_wrong.get(i, -100.0)))
		var look: int = int(lost.has(i)) | int(state.walked.has(i)) << 1 | int(refused.has(i)) << 2 | pose[1] << 3
		if blush > 0.0:
			var alpha: float = float(pose[1]) / FADE_STEPS * (DRY_FADE if refused.has(i) else 1.0)
			_show_live(PIECE_STONE, i, _build_stone.bind(i, _line_geometry(i, t), lost.has(i), alpha, blush, t, true))
		else:
			_show(PIECE_STONE, i, look, _build_rest_stone.bind(i, lost.has(i), refused.has(i), pose[1]), pose[0])
	for i in lines:
		var look := _plank_look(i, t)
		if look < 0:
			_show_live(PIECE_PLANK, i, _build_plank.bind(i, t))
		elif look > 0:
			_show(PIECE_PLANK, i, look, _build_rest_plank.bind(i, look))
	if not _gone.is_empty():
		var b := Face.Builder.new()
		_build_gone(b, t)
		_tail([b.verts, b.cols, b.idx], Transform2D.IDENTITY)
	for n in state.nodes:
		_cast_post(n, t)
	if _fi.is_empty():
		_figure = null
		return
	_fv.resize(_fixed)
	_fc.resize(_fixed)
	_fv.append_array(_tv)
	_fc.append_array(_tc)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _fv
	arrays[Mesh.ARRAY_COLOR] = _fc
	arrays[Mesh.ARRAY_INDEX] = _fi
	_figure = ArrayMesh.new()
	_figure.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

## Every piece's run of vertices, in the order `_cast_figure` visits them,
## each as long as the piece's largest look: a line's stone dressed, a
## post's glow, cap and open daisy. This builds every piece once, which is
## what the figure cost a frame before its pieces were kept.
func _lay_slots() -> void:
	_fixed = 0
	var room := func(piece: int, index: int, draw: Callable) -> void:
		var b := Face.Builder.new()
		draw.call(b)
		_slot[Vector2i(piece, index)] = Vector2i(_fixed, b.verts.size())
		_fixed += b.verts.size()
	for n in state.nodes:
		room.call(PIECE_GLOW, n, _build_glow.bind(n))
		room.call(PIECE_SHADOW, n, _build_shadow.bind(n))
	for i in state.edges.size():
		room.call(PIECE_FORD, i, _build_ford.bind(i, FADE_STEPS))
	for i in state.edges.size():
		room.call(PIECE_STONE, i, func(b) -> void:
			var e: Vector2i = state.edges[i]
			_build_stone(b, i, {"a": node_to_local(e.x), "b": node_to_local(e.y)}, false, 1.0, 0.0, -1.0, true))
	for i in state.edges.size():
		room.call(PIECE_PLANK, i, _build_rest_plank.bind(i, 1))
	for n in state.nodes:
		var at := node_to_local(n)
		var R := _step * POST_R
		room.call(PIECE_DRUM, n, _build_drum.bind(at, R, R, Pal.POST_STONE, Pal.POST_DEEP))
		room.call(PIECE_CAP, n, _build_cap.bind(at, R, R, Pal.ACCENT, 1.0))
		room.call(PIECE_DAISY, n, _build_open_daisy.bind(n))

## Piece (`piece`, `index`) in `look` under `xf`: the look's vertices into the
## piece's run, made by `draw` the first time.
func _show(piece: int, index: int, look: int, draw: Callable, xf := Transform2D.IDENTITY) -> void:
	var key := Vector4i(piece, index, look, 0)
	var part = _looks.get(key)
	if part == null:
		part = _part(piece, index, draw)
		_looks[key] = part
	_emit(piece, index, part, xf)

## Piece (`piece`, `index`) built afresh by `draw`, for a piece whose colours
## are moving.
func _show_live(piece: int, index: int, draw: Callable) -> void:
	_emit(piece, index, _part(piece, index, draw), Transform2D.IDENTITY)

## What `draw` builds, as [verts, cols, indices, fits]: the indices offset to
## the piece's run when it fits there, and left as they are when it does not
## (it then goes on the tail, `_tail`).
func _part(piece: int, index: int, draw: Callable) -> Array:
	var b := Face.Builder.new()
	draw.call(b)
	var run: Vector2i = _slot[Vector2i(piece, index)]
	if b.verts.size() > run.y:
		return [b.verts, b.cols, b.idx, false]
	var ix := b.idx
	for k in ix.size():
		ix[k] += run.x
	return [b.verts, b.cols, ix, true]

func _emit(piece: int, index: int, part: Array, xf: Transform2D) -> void:
	if not part[3]:
		_tail(part, xf)
		return
	var base: int = _slot[Vector2i(piece, index)].x
	_fv.resize(base)
	_fc.resize(base)
	_fv.append_array(part[0] if xf == Transform2D.IDENTITY else xf * (part[0] as PackedVector2Array))
	_fc.append_array(part[1])
	_fi.append_array(part[2])

## A drawing with no run of its own (the planks Reset takes up), after every
## run, its indices offset in script.
func _tail(part: Array, xf: Transform2D) -> void:
	var base := _fixed + _tv.size()
	_tv.append_array(part[0] if xf == Transform2D.IDENTITY else xf * (part[0] as PackedVector2Array))
	_tc.append_array(part[1])
	var ix: PackedInt32Array = (part[2] as PackedInt32Array).duplicate()
	for k in ix.size():
		ix[k] += base
	_fi.append_array(ix)

## The transform that takes a drawing made about `from` to `to`, scaled by
## `scale` and turned by `angle` about it.
static func _about(from: Vector2, to: Vector2, scale: Vector2, angle := 0.0) -> Transform2D:
	if from == to and scale == Vector2.ONE and angle == 0.0:
		return Transform2D.IDENTITY
	return Transform2D(angle, scale, 0.0, to) * Transform2D(0.0, -from)

## Line `i` as it is drawn now: [the transform from its rest, its fade step],
## or [] while it has not arrived. It pops in wide about its middle along the
## entrance stagger, stretched along itself (rule 7 of the motion doc: a long
## thing comes from most of the way), and wobbles about that middle when
## Check has found it stranded.
func _line_pose(i: int, t: float) -> Array:
	var elapsed := t - _opened - _enter_line_delay(i)
	if elapsed <= 0.0 and not Motion.reduce:
		return []
	var grow := Motion.wide_pop_scale(elapsed)
	var angle := Motion.wobble_angle(t - float(_wrong.get(i, -100.0)))
	var fade := clampi(ceili(Motion.appear_level(elapsed) * FADE_STEPS), 1, FADE_STEPS)
	if grow == 1.0 and angle == 0.0:
		return [Transform2D.IDENTITY, fade]
	var edge: Vector2i = state.edges[i]
	var a := node_to_local(edge.x)
	var c := node_to_local(edge.y)
	var mid := a.lerp(c, 0.5)
	var phi := (c - a).angle()
	var xf := Transform2D(0.0, -mid).rotated(-phi).scaled(Vector2(grow, 1.0)).rotated(phi + angle).translated(mid)
	return [xf, fade]

## Line `i`'s soft shadow on the parchment, under every stone, at fade step
## `fade`.
func _build_ford(b, i: int, fade: int) -> void:
	var edge: Vector2i = state.edges[i]
	var off: Vector2 = FORD_SHADOW * _step
	b.stroke(PackedVector2Array([node_to_local(edge.x) + off, node_to_local(edge.y) + off]),
		_step * LINE_W * 1.2, Color(Pal.TEXT, FORD_SHADOW_A * float(fade) / FADE_STEPS))

## Line `i`'s stone at rest: lost or not, faded back while the sun refuses
## it, at fade step `fade`.
func _build_rest_stone(b, i: int, lost: bool, refused: bool, fade: int) -> void:
	var e: Vector2i = state.edges[i]
	var alpha := float(fade) / FADE_STEPS * (DRY_FADE if refused else 1.0)
	_build_stone(b, i, {"a": node_to_local(e.x), "b": node_to_local(e.y)}, lost, alpha, 0.0, -1.0,
		not state.walked.has(i))

## A line as stone, its Sunny Spells dressing while `dressed`, and its crest,
## at `alpha`, blushing by `blush`. `t` is negative for a line at rest, whose
## sparkles stand still.
func _build_stone(b, i: int, line: Dictionary, lost: bool, alpha: float, blush: float, t: float,
		dressed: bool) -> void:
	var stone: Color = Pal.PLANK_LOST if lost else Pal.FORD_STONE
	if state.has_sun() and not lost:
		stone = Pal.FORD_SUN if state.is_sunny(i) else Pal.FORD_DEW
	if blush > 0.0:
		stone = stone.lerp(Pal.BAD_TILE, blush)
	b.stroke(PackedVector2Array([line.a, line.b]), _step * LINE_W, Color(stone, alpha))
	if state.has_sun() and dressed:
		_dress_ford(b, i, line, alpha, t)
	# The crest sits on whichever side faces up the page, so a light falls
	# on every ford from the same sky.
	var along: Vector2 = (line.b - line.a).normalized()
	var up := Vector2(along.y, -along.x)
	if up.y > 0.0:
		up = -up
	var lift := up * _step * (LINE_W * 0.5 - CREST_W * 0.7)
	b.stroke(PackedVector2Array([line.a + lift, line.b + lift]), _step * CREST_W,
		Color(1.0, 1.0, 1.0, CREST_A * alpha), false, false)

## Line `i`'s plank as a look: 0 for none, -1 while it is live (being laid or
## taken up, or changing colour), or its resting look (the way it was laid,
## blushed, brightened by the win).
func _plank_look(i: int, t: float) -> int:
	if not _stroke.is_empty() and int(_stroke.edge) == i:
		return -1
	if not state.walked.has(i):
		return 0
	var look := 1 | int(int(state.lay_from.get(i, state.edges[i].x)) == state.edges[i].x) << 1
	if _bad_plank.has(i):
		if not Motion.reduce and t - float(_bad_plank[i]) < 0.25:
			return -1
		look |= 4
	if _bright.has(i):
		var g := (t - float(_bright[i])) / BRIGHT_TIME
		if not Motion.reduce and g < 1.0:
			return -1 if g > 0.0 else look
		look |= 8
	return look

## Line `i`'s plank at rest in `look`: the wood `_build_plank` lays, in the
## colour it settles on.
func _build_rest_plank(b, i: int, look: int) -> void:
	var edge: Vector2i = state.edges[i]
	var anchor: int = int(state.lay_from.get(i, edge.x))
	var warm: Color = Pal.PLANK_LAID
	if state.is_sunny(i):
		warm = warm.lightened(0.14)
	if look & 4:
		warm = warm.lerp(Pal.BAD_TILE, 0.8)
	if look & 8:
		warm = warm.lerp(Pal.PLANK_HI, 1.0)
	_plank(b, node_to_local(anchor), node_to_local(edge.y if anchor == edge.x else edge.x), 1.0, warm, 1.0, i)

## Post `n`: its drum, cap and daisy, each a look under the post's entrance,
## hop, shiver and cap bump. A pressed or blushing drum and a warming cap,
## whose colours move, are built in script. Drawn off the readers: it pops in
## with the squash along the diagonal, sinks under the finger, hops when the
## walker lands and on the waves, shivers and blushes when it refuses, and its
## cap bumps when the count it shows has changed. On the win the cap turns
## toward the sun.
func _cast_post(n: int, t: float) -> void:
	var grow := _post_entrance(n, t)
	if grow.y <= 0.0:
		return
	var rest := node_to_local(n)
	var at := rest
	var R := _step * POST_R
	var drum: Color = Pal.POST_STONE
	var deep: Color = Pal.POST_DEEP
	var live := false
	if _post_press.has(n):
		var pr: Dictionary = _post_press[n]
		var released := -1.0 if is_inf(float(pr.up)) else t - float(pr.up)
		var sink := Motion.press_scale(t - float(pr.down), released)
		if sink != 1.0:
			grow *= sink
			drum = drum.lerp(deep, SINK_SHADE * clampf((1.0 - sink) / (1.0 - Motion.PRESS_SCALE), 0.0, 1.0))
			live = true
	if _post_hop.has(n):
		var hop: Dictionary = _post_hop[n]
		at.y += Motion.hop_lift(t - float(hop.at), hop.height, hop.time)
	at.x += Motion.shiver_offset(t - float(_post_shiver.get(n, -100.0)), Motion.SHIVER_PX)
	var blush := Motion.flash_level(t - float(_post_blush.get(n, -100.0)))
	if blush > 0.0:
		drum = drum.lerp(Pal.BAD_TILE, blush)
		deep = deep.lerp(Pal.BAD, blush * 0.5)
		live = true
	if live:
		_show_live(PIECE_DRUM, n, _build_drum.bind(at, R * grow.x, R * grow.y, drum, deep))
	else:
		_show(PIECE_DRUM, n, 0, _build_drum.bind(rest, R, R, drum, deep), _about(rest, at, grow))
	var cap := Motion.bump_scale(t - float(_cap_bump.get(n, -100.0)))
	var colour := _cap_colour(n, t)
	var warming := false
	if _warm.has(n):
		var w := (t - float(_warm[n])) / BRIGHT_TIME
		colour = colour.lerp(Pal.SUN_RAY, CAP_WARM * _dec(w))
		warming = not Motion.reduce and w > 0.0 and w < 1.0
	var centre := at + Vector2(0.0, -0.04) * R * grow.y
	var home := rest + Vector2(0.0, -0.04) * R
	if warming:
		_show_live(PIECE_CAP, n, _build_cap.bind(at, R * grow.x, R * grow.y, colour, cap))
	else:
		_show(PIECE_CAP, n, colour.to_rgba32(), _build_cap.bind(rest, R, R, colour, 1.0),
			_about(home, centre, grow * cap))
	if _bloom.has(n) and n != state.current:
		var e := t - float(_bloom[n])
		if e < 0.0:
			return
		var u := clampf(e / DAISY_TIME, 0.0, 1.0)
		var k := 1.0 if Motion.reduce else Motion.back_out(u)
		if k <= 0.01:
			return
		var turn := 0.0 if Motion.reduce else (1.0 - u) * 0.8
		_show(PIECE_DAISY, n, 0, _build_open_daisy.bind(n), _about(home, centre, grow * k, turn))

## The pieces `_cast_post` places, each at the post's rest: its shadow and
## its green glow, the drum, the cap (`cap` its bump), and its daisy open.
func _build_shadow(b, n: int) -> void:
	var R := _step * POST_R
	Scenery.soft_disc(b, node_to_local(n) + Vector2(0.05, 0.3) * R, 0.92 * R * SHADOW_SPREAD,
		0.8 * R * SHADOW_SPREAD, Color(Pal.TEXT, SHADOW_A))

func _build_glow(b, n: int) -> void:
	var R := _step * POST_R
	Scenery.soft_disc(b, node_to_local(n), GLOW_SPREAD * R, GLOW_SPREAD * R, Color(Pal.GOOD, GLOW_A))

func _build_drum(b, at: Vector2, rx: float, ry: float, drum: Color, deep: Color) -> void:
	b.ellipse(at + Vector2(0.0, 0.1) * ry, rx, ry, deep)
	b.ellipse(at, rx, ry, drum)
	# The drum's cut face catches the light on its upper rim.
	b.stroke(Face.Builder.arc_points(at, 0.86 * rx, PI * 1.05, PI * 1.7), 0.07 * rx,
		Color(1.0, 1.0, 1.0, 0.3), false, false)

func _build_cap(b, at: Vector2, rx: float, ry: float, colour: Color, cap: float) -> void:
	var centre := at + Vector2(0.0, -0.04) * ry
	b.ellipse(centre + Vector2(0.0, 0.07) * ry, 0.64 * rx * cap, 0.64 * ry * cap, colour.darkened(CAP_LIP))
	b.ellipse(centre, 0.6 * rx * cap, 0.6 * ry * cap, colour)
	b.ellipse(at + Vector2(-0.2, -0.26) * ry, 0.26 * rx * cap, 0.16 * ry * cap, Color(1.0, 1.0, 1.0, 0.28))

func _build_open_daisy(b, n: int) -> void:
	var R := _step * POST_R
	_daisy(b, node_to_local(n) + Vector2(0.0, -0.04) * R, R * DAISY_R, DAISY_TIME, n)

## The sunny lines the snail may not take from here while she is dry: they
## fade back, so the rule is seen before it is broken.
func _refused_now(t: float) -> Dictionary:
	var out: Dictionary = {}
	if not state.has_sun() or not state.dry() or not _stroke_landed(t) or is_done():
		return out
	for q in state.adj.get(state.current, []):
		if state.is_sunny(int(q.i)) and not state.walked.has(int(q.i)):
			out[int(q.i)] = true
	return out

## A Sunny Spells ford's dressing: a sunny line glints with little four-point
## sparkles that twinkle, a dewy one carries drops of dew with a shine.
func _dress_ford(b, i: int, line: Dictionary, alpha: float, t: float) -> void:
	var a: Vector2 = line.a
	var z: Vector2 = line.b
	var span := a.distance_to(z)
	var count := maxi(1, roundi(span / (_step * 0.45)))
	for k in count:
		var u := (k + 0.5) / count
		var at := a.lerp(z, u)
		if state.is_sunny(i):
			var tw := 1.0 if Motion.reduce or t < 0.0 else 0.75 + 0.25 * sin(t * 3.0 + float(i * 7 + k * 3))
			var r := _step * SUN_SPARK * tw
			b.polygon(PackedVector2Array([at + Vector2(0, -r * 1.6), at + Vector2(r * 0.4, -r * 0.4),
				at + Vector2(r * 1.6, 0), at + Vector2(r * 0.4, r * 0.4), at + Vector2(0, r * 1.6),
				at + Vector2(-r * 0.4, r * 0.4), at + Vector2(-r * 1.6, 0), at + Vector2(-r * 0.4, -r * 0.4)]),
				Color(Pal.SUN_SPARK, alpha * 0.95))
		else:
			var r := _step * DEW_DROP
			b.disc(at + Vector2(0.0, r * 0.2), r * 1.15, Color(Pal.DEW_EDGE, alpha * 0.8))
			b.disc(at, r, Color(Pal.DEW, alpha))
			b.disc(at + Vector2(-0.35, -0.35) * r, r * 0.3, Color(1.0, 1.0, 1.0, alpha * 0.85))

## Line `i`'s two ends as drawn now, and its alpha: it pops in wide about its
## middle along the entrance stagger (rule 7 of the motion doc: a long thing
## comes from most of the way), and wobbles about that middle when Check has
## found it stranded. {} while it has not arrived.
func _line_geometry(i: int, t: float) -> Dictionary:
	var elapsed := t - _opened - _enter_line_delay(i)
	if elapsed <= 0.0 and not Motion.reduce:
		return {}
	var edge: Vector2i = state.edges[i]
	var a := node_to_local(edge.x)
	var c := node_to_local(edge.y)
	var mid := a.lerp(c, 0.5)
	var grow := Motion.wide_pop_scale(elapsed)
	var angle := Motion.wobble_angle(t - float(_wrong.get(i, -100.0)))
	var half := (c - mid).rotated(angle) * grow
	return {"a": mid - half, "b": mid + half, "alpha": Motion.appear_level(elapsed)}

## The plank laid over line `i`, as far along as the walker has taken it. It
## grows from the post the walker crossed *from*, slat by slat, each slat
## landing as the walker clears it, with the walker's wet sheen behind it;
## on the win it warms a shade brighter in walk order with a glint running
## down it, so the finished figure draws itself once more.
func _build_plank(b, i: int, t: float) -> void:
	var u := 1.0 if state.walked.has(i) else 0.0
	var anchor: int = int(state.lay_from.get(i, state.edges[i].x))
	var laying := -1.0
	var live := not _stroke.is_empty() and int(_stroke.edge) == i
	if live:
		var prog := _dec((t - float(_stroke.at)) / LAY_TIME)
		u = prog if bool(_stroke.up) else 1.0 - prog
		anchor = int(_stroke.from) if bool(_stroke.up) else int(_stroke.to)
		if bool(_stroke.up):
			laying = float(_stroke.at)
	if u <= 0.0:
		return
	var edge: Vector2i = state.edges[i]
	var from := node_to_local(anchor)
	var to := node_to_local(edge.y if anchor == edge.x else edge.x)
	var warm: Color = Pal.PLANK_LAID
	if state.is_sunny(i):
		warm = warm.lightened(0.14)
	var glint := -1.0
	if _bad_plank.has(i):
		warm = warm.lerp(Pal.BAD_TILE, _dec((t - float(_bad_plank[i])) / 0.25) * 0.8)
	if _bright.has(i):
		var g := (t - float(_bright[i])) / BRIGHT_TIME
		warm = warm.lerp(Pal.PLANK_HI, _dec(g))
		if g > 0.0 and g < 1.0 and not Motion.reduce:
			glint = g
	_plank(b, from, to, u, warm, 1.0, i, laying)
	if glint >= 0.0:
		var along := (to - from).normalized()
		var at := from.lerp(to, glint)
		var reach := along * _step * GLINT * 0.5
		var fade := sin(glint * PI)
		b.stroke(PackedVector2Array([at - reach, at + reach]), _step * PLANK_W * 0.5,
			Color(1.0, 1.0, 1.0, GLINT_A * fade))
	if live and bool(_stroke.up):
		_build_sheen(b, from, to, u, t)

## The walker's wet shine down the middle of the plank behind it: a run of
## short strokes brightening toward the snail, fading out once it lands.
func _build_sheen(b, from: Vector2, to: Vector2, u: float, t: float) -> void:
	if Motion.reduce:
		return
	var landed := t - float(_stroke.at) - LAY_TIME
	var level := 1.0 - clampf(landed / SHEEN_FADE, 0.0, 1.0)
	if level <= 0.0:
		return
	var span := from.distance_to(to)
	if span <= 0.0:
		return
	var head := u * span
	var tail := maxf(0.0, head - _step * SHEEN)
	const PARTS := 5
	for k in PARTS:
		var p0 := lerpf(tail, head, float(k) / PARTS)
		var p1 := lerpf(tail, head, float(k + 1) / PARTS)
		var a := SHEEN_A * level * float(k + 1) / PARTS
		b.stroke(PackedVector2Array([from.lerp(to, p0 / span), from.lerp(to, p1 / span)]),
			_step * PLANK_W * 0.28, Color(1.0, 1.0, 1.0, a), false, false)

## A plank from `from` toward `to`, laid as far as `u` of the way: the deep
## wood underneath as far as it reaches, then the slats over it with a seam
## between each. `grain` cuts each slat's tone; `laying` is the second the
## walker set off down it, or negative for a plank already down, and then a
## slat lands as the walker clears it.
func _plank(b, from: Vector2, to: Vector2, u: float, warm: Color, grow: float,
		grain: int, laying := -1.0) -> void:
	var span := from.distance_to(to)
	if span <= 0.0:
		return
	var along := (to - from) / span
	var tip := from + along * span * u
	b.stroke(PackedVector2Array([from, tip]), _step * PLANK_DEEP_W * grow, Pal.WOOD_DEEP)
	var count := maxi(1, roundi(span / (_step * SLAT)))
	var cut := span / count
	var gap := _step * SEAM * 0.5
	var t := _now()
	for k in count:
		var start := k * cut
		var reach := minf((k + 1) * cut, span * u)
		if reach <= start:
			break
		var wide := grow
		if laying >= 0.0:
			var clear := t - laying - (k + 1) * cut / span * LAY_TIME
			wide *= Motion.pop_in_scale(clear + SLAT_POP * 0.35, SLAT_POP).x
		if wide <= 0.0:
			continue
		var tone := _hash(grain * 31 + k) * 2.0 - 1.0
		var slat := warm.lightened(tone * SLAT_TONE) if tone > 0.0 else warm.darkened(-tone * SLAT_TONE)
		var a := from + along * (start + gap)
		var z := from + along * maxf(start + gap, reach - gap)
		var w := _step * PLANK_W * wide
		b.stroke(PackedVector2Array([a, z]), w, slat, false, false)
		var up := Vector2(along.y, -along.x)
		if up.y > 0.0:
			up = -up
		var edge := up * w * 0.32
		b.stroke(PackedVector2Array([a + edge, z + edge]), w * 0.22,
			Color(1.0, 1.0, 1.0, SLAT_LIGHT_A), false, false)

## A fixed 0..1 hash of `k`, so a slat is cut the same every time it is drawn.
func _hash(k: int) -> float:
	var h := (k * 374761393 + 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 1000) / 999.0

## The planks Reset took up: each shrinks to nothing about its own middle in
## the wave from the far corner (the Remove moment, without the quarter turn a
## long thing would only wobble through).
func _build_gone(b, t: float) -> void:
	var keep: Array = []
	for g in _gone:
		var elapsed: float = t - float(g.at)
		var grow := Motion.pop_out_scale(elapsed)
		if grow <= 0.0:
			continue
		keep.append(g)
		var mid: Vector2 = (g.from as Vector2).lerp(g.to, 0.5)
		var half: Vector2 = ((g.to as Vector2) - mid) * grow
		_plank(b, mid - half, mid + half, 1.0, Pal.PLANK_LAID, grow, int(g.seed))
	_gone = keep

## The post's soft shadow on the parchment, at the post's rest: a hopping post
## leaves it behind, which is what makes the hop read as height. It arrives
## with the post's own pop. A post the stroke may begin at glows green under
## it until the stroke has begun. (Placed by `_cast_figure`, of the pieces
## `_build_shadow` and `_build_glow`.)

## A mooring post, seen from above the way the whole board is: a stone drum
## with a coloured cap. The cap carries all the guidance, which is the
## island's own use for it -- a player who cannot see where the stroke may
## start cannot start it. (Placed by `_cast_post`.)

## An ellipse `rx` by `ry` about `at`, turned by `a`.
static func _oval(b, at: Vector2, rx: float, ry: float, a: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		var u := TAU * k / 14.0
		pts.append(at + Vector2(cos(u) * rx, sin(u) * ry).rotated(a))
	b.polygon(pts, colour)

## A daisy on a spent post's cap: white petals round a sun-yellow middle,
## opening over DAISY_TIME with the back ease and turning a little as it
## does, so a finished post is seen to be finished from across the figure.
func _daisy(b, at: Vector2, r: float, e: float, n: int) -> void:
	if e < 0.0:
		return
	var k := 1.0 if Motion.reduce else Motion.back_out(clampf(e / DAISY_TIME, 0.0, 1.0))
	if k <= 0.01:
		return
	var turn := _hash(n) * TAU + (0.0 if Motion.reduce else (1.0 - clampf(e / DAISY_TIME, 0.0, 1.0)) * 0.8)
	for p in DAISY_PETALS:
		var a := turn + TAU * p / DAISY_PETALS
		var dir := Vector2.from_angle(a)
		_oval(b, at + dir * r * 0.55 * k, r * 0.36 * k, r * 0.17 * k, a, Pal.PETAL_EDGE)
		_oval(b, at + dir * r * 0.55 * k, r * 0.32 * k, r * 0.13 * k, a, Pal.SURFACE)
	b.disc(at, r * 0.3 * k, Pal.SUN_DEEP)
	b.disc(at + Vector2(0.0, -0.04) * r, r * 0.25 * k, Pal.SUN_RAY)

## The post's entrance scale: pop_in's squash along the diagonal, a beat after
## the lines begin. Zero before it starts.
func _post_entrance(n: int, t: float) -> Vector2:
	return Motion.pop_in_scale(t - _opened - _enter_post_delay(n))

## The island's four caps, unchanged: terracotta under the walker, green on a
## post the stroke may begin at, teal where lines are still to walk, and pale
## stone once a post is finished with. The measurement says the green matters
## most -- 198 of 200 easy figures and all 400 of the harder ones have exactly
## two odd posts, so the opening is forced almost every time. The post the
## walker is crossing to keeps its old cap until the walker lands.
func _cap_colour(n: int, t: float) -> Color:
	if not _stroke.is_empty() and int(_stroke.to) == n and _stroke.has("to_cap") \
			and t < float(_stroke.at) + LAY_TIME and not Motion.reduce:
		return _stroke.to_cap
	return _cap_of(n)

func _cap_of(n: int) -> Color:
	if n == state.current:
		return Pal.ACCENT_2
	if state.current < 0 and state.may_start(n):
		return Pal.GOOD
	if state.open_at(n) > 0:
		return Pal.ACCENT
	return Pal.POST_SPENT

# --- the moments ---

## The chrome is the host's; here each stone line pops in wide about its
## middle in index order, and each post pops onto the figure a beat later with
## the squash along the diagonal from the top-left corner, its shadow arriving
## with it. The figure draws itself before the first touch: it is the thing to
## read, and the planks are the answer to it.
func _enter() -> void:
	_opened = _now()
	var lines := _enter_line_delay(state.edges.size() - 1) + maxf(Motion.ENTER_POP, Motion.DROP_FADE)
	var posts := _enter_post_delay(_far()) + Motion.POP_IN
	_busy_for(maxf(lines, posts))
	fx.cue("enter")

func _enter_line_delay(i: int) -> float:
	return Motion.ENTER_DELAY + Motion.stagger(i, Motion.ENTER_STAGGER)

func _enter_post_delay(n: int) -> float:
	return Motion.ENTER_DELAY + Motion.ENTER_FACE_LAG + Motion.stagger(_diagonal(n), Motion.ENTER_STAGGER)

## The post under the finger sinks (the Press moment), and the walker with it
## when it is standing there.
func _press_post(n: int) -> void:
	_release_post()
	_pressed_post = n
	_post_press[n] = {"down": _now(), "up": INF}
	_busy_for(Motion.PRESS_TIME)
	if n == state.current:
		_walker_pressed = true
		_walker_press(true)

## Whatever the finger sank springs back.
func _release_post() -> void:
	if _pressed_post < 0:
		return
	var n := _pressed_post
	_pressed_post = -1
	if _post_press.has(n) and is_inf(float(_post_press[n].up)):
		_post_press[n].up = _now()
		_busy_for(Motion.RELEASE_TIME)
	_release_walker()

## The walker springs back if the finger had it down.
func _release_walker() -> void:
	if not _walker_pressed:
		return
	_walker_pressed = false
	_walker_press(false)

## The walker lands on post `n` at `at`: the post hops, its cap takes its new
## colour with the Count bump, and a puff in the plank's wood when a line was
## laid (the Place moment; an undo lands without one).
func _land(n: int, at: float, puff: bool) -> void:
	_post_hop[n] = {"at": at, "height": Motion.HOP, "time": Motion.HOP_TIME}
	_cap_bump[n] = at
	_busy_for(at - _now() + maxf(Motion.HOP_TIME, Motion.BUMP_TIME))
	if puff and not Motion.reduce:
		_after(at - _now(), fx.puff.bind(node_to_local(n), Pal.PLANK_LAID))

## The walker leaves post `n` now: its cap is recounted at once.
func _depart(n: int) -> void:
	_cap_bump[n] = _now()
	_busy_for(Motion.BUMP_TIME)

## A press the rules will not take on post `n`: it shivers while its drum
## blushes toward the family's rose and settles (the Refused moment).
func _refuse(n: int) -> void:
	if Motion.reduce:
		return
	var now := _now()
	_post_shiver[n] = now
	_post_blush[n] = now
	_busy_for(maxf(Motion.SHIVER_TIME, Motion.FLASH_IN + Motion.FLASH_OUT))

## The wave from the far corner Reset runs, per post or per line.
func _reset_wave(diagonal: float) -> float:
	if Motion.reduce:
		return 0.0
	return Motion.stagger(int(roundf(float(_far()) - diagonal)), Motion.RESET_STAGGER)

# --- input ---

## Touch and drag only, as every flat board takes them. A press takes the post
## under it; a drag steps whenever the finger comes within a thumb of a
## neighbouring post, because the line between two posts is never in doubt.
## Taps work too: the same reach, one step at a time, which is what a player
## with a small screen and a big thumb will actually do.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(event.position)
		else:
			_drawing = false
			_release_post()
			_refresh()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _drawing:
		_reach(event.position)

func _press(at: Vector2) -> void:
	if is_done() or out_of_hearts or _ejecting:
		return
	var n := _nearest(at)
	if n < 0:
		return
	_drawing = true
	_press_post(n)
	_take(n)

func _reach(at: Vector2) -> void:
	if is_done() or out_of_hearts or _ejecting:
		return
	var n := _nearest(at)
	if n < 0 or n == state.current:
		return
	_take(n)

func _take(n: int) -> void:
	if state.current < 0:
		_begin(n)
	else:
		_walk_to(n)

## Stands the walker on a post to open the stroke: it pops in with the squash
## and a puff in its own terracotta, and the post hops under it. A post the
## figure forbids answers with a shiver, a blush and a line from the sprout
## rather than a move.
func _begin(n: int) -> void:
	var t := _now()
	if not state.begin(n):
		_refuse(n)
		_say(tr("OL_BEGIN_GREEN")
			if not state.starts.is_empty()
			else tr("OL_BEGIN_ANY"), Face.Expr.PUZZLED)
		fx.cue("locked")
		_refresh()
		return
	_stroke = {}
	_walker_arrives(false)
	_post_hop[n] = {"at": t, "height": Motion.HOP, "time": Motion.HOP_TIME}
	for m in state.nodes:
		_cap_bump[m] = t
	_busy_for(maxf(Motion.HOP_TIME, Motion.BUMP_TIME))
	fx.puff(node_to_local(n), Pal.ACCENT_2)
	_say(tr("OL_NOW_WALK"), Face.Expr.HAPPY)
	fx.cue("start")
	_refresh()

## Walks the line to post `n`, if there is one left to walk. A line already
## walked refuses with a shiver: every line takes exactly one crossing.
##
## On Hard and Insane every step is judged before it is taken: one that leaves
## the rest of the figure unwalkable (stranded on Hard, or on Insane with no
## walk that keeps the sun apart) costs a heart, and its plank comes back up.
## Anything else is right, and builds the streak.
func _walk_to(n: int, judged := true) -> void:
	var t := _now()
	var from: int = state.current
	var to_cap := _cap_of(n)
	var was_dry: bool = state.dry()
	var finishes: bool = state.may_step(n) and state.step_leaves_finish(n)
	# (Easy and Medium: whether a line was out of reach before this step)
	var was_lost: bool = max_hearts == 0 and not state.stranded().is_empty()
	match state.step(n):
		State.STEP_WALKED:
			_refuse(n)
			_say(tr("OL_WALKED"),
				Face.Expr.PUZZLED)
			fx.cue("locked")
			_refresh()
		State.STEP_SUN:
			_refuse(n)
			var e := state.edge_between(from, n)
			if not Motion.reduce and e >= 0:
				_wrong[e] = t
				_busy_for(maxf(Motion.WOBBLE_TIME, Motion.FLASH_IN + Motion.FLASH_OUT))
			_say(tr("OL_REFUSE_SUN"), Face.Expr.STRAIN)
			fx.cue("sun")
			_refresh()
		State.STEP_OK:
			var e: int = state.trail[-1]
			var land := t + (0.0 if Motion.reduce else LAY_TIME)
			_stroke = {"edge": e, "from": from, "to": n,
				"at": t, "up": true, "to_cap": to_cap}
			_release_walker()
			_busy_for(LAY_TIME + SHEEN_FADE)
			_depart(from)
			_land(n, land, true)
			_squash_on(land - t)
			fx.cue("lay", 1.0 + 0.04 * float(mini(_streak, 8)))
			if was_dry and not state.is_sunny(e):
				_after(land - t, _drink.bind(n))
			if max_hearts > 0 and judged and not finishes:
				_refresh()
				note_move()
				_wrong_step(e, n)
				return
			_bloom_spent([from, n], land)
			_speak()
			_refresh()
			note_move()
			if is_done():
				return
			# The step that strands a line is felt once, as it is taken; the
			# steps after it on the same lost figure are plain planks.
			if max_hearts == 0 and not was_lost and not state.stranded().is_empty():
				fx.buzz(Haptics.WARN)
			if finishes:
				_on_right_step(e, n, judged and max_hearts > 0)
			else:
				_break_streak()

## The snail lands with a little squash, as a thing with a soft foot does.
func _squash_on(delay: float) -> void:
	if Motion.reduce:
		return
	_after(delay, func() -> void:
		Motion.stop(_squash_tw)
		_squash_tw = Motion.squash(snail, LAND_SQUASH, 0.16))

## A dewy line after a sunny one: the bead of sweat goes and a few drops of
## dew spring off her, with a small "ahh".
func _drink(n: int) -> void:
	if is_done() and not _joy:
		return
	if not Motion.reduce:
		fx.puff(node_to_local(n) - Vector2(0.0, _step * POST_LIFT), Pal.DEW, 5)
	fx.cue("dew")
	if not _worried and state.stranded().is_empty():
		_say(tr("OL_DEW"), Face.Expr.HAPPY)

## Posts in `posts` with no line left to walk open a daisy at `at`.
func _bloom_spent(posts: Array, at: float) -> void:
	var any := false
	for p in posts:
		if int(p) >= 0 and state.open_at(int(p)) == 0 and not _bloom.has(int(p)):
			_bloom[int(p)] = at
			any = true
	if any:
		_busy_for(at - _now() + DAISY_TIME)
		_after(at - _now(), func() -> void: fx.cue("bloom"))

## Daisies on posts that have lines to walk again (an undo, an eject) fold.
func _unbloom() -> void:
	for p in _bloom.keys():
		if state.open_at(int(p)) > 0:
			_bloom.erase(p)

# --- the sprout's line ---

## What the tip card says: the rule while nothing is walked, then how many
## lines are left, and the stranding warning the moment it applies -- after
## the step that caused it and never before. Live reachability was on the
## table and was turned down: avoiding stranding *is* the difficulty, and a
## board that greys out the wrong moves has played the puzzle for you.
func _speak(undone := false) -> void:
	if is_done():
		return
	var lost := state.stranded()
	if not lost.is_empty():
		if undone:
			_say(tr("OL_STILL_ONE") if lost.size() == 1
				else tr("OL_STILL_N") % lost.size(),
				Face.Expr.STRAIN)
		else:
			_say(tr("OL_STRANDED_ONE")
				if lost.size() == 1
				else tr("OL_STRANDED_N")
					% lost.size(), Face.Expr.STRAIN)
		return
	var left := state.lines_left()
	_say(tr("OL_LEFT_ONE") if left == 1 else tr("OL_LEFT_N") % left,
		Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal; nothing else on this screen has a focus.
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _tip_mood != Face.Expr.HAPPY:
		return
	var tips := _tips()
	_tip_idx = (_tip_idx + 1) % tips.size()
	_say(tr(tips[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not out_of_hearts and not _ejecting and not state.trail.is_empty()

## The host holds its hint video while a wrong step is being taken back.
func busy() -> bool:
	return _ejecting

## Takes back the last line walked: the plank sinks to stone and the walker
## steps back onto the post it came from, which hops as it lands. Counts no
## move, as on the island.
func undo() -> bool:
	if is_done() or out_of_hearts or _ejecting or state.trail.is_empty():
		return false
	var caps := _snapshot_caps()
	var out: Dictionary = state.undo()
	if out.is_empty():
		return false
	var t := _now()
	_stroke = {"edge": int(out.edge), "from": int(out.from), "to": int(out.to),
		"at": t, "up": false, "to_cap": caps.get(int(out.to), _cap_of(int(out.to)))}
	_busy_for(LAY_TIME)
	_depart(int(out.from))
	_land(int(out.to), t + (0.0 if Motion.reduce else LAY_TIME), false)
	_unbloom()
	_break_streak()
	_speak(true)
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

## Every post's cap as it is now, before a move changes the state under it.
func _snapshot_caps() -> Dictionary:
	var caps: Dictionary = {}
	for n in state.nodes:
		caps[n] = _cap_of(n)
	return caps

func hints_left() -> int:
	return State.HINTS_BY_BAND[state.band] + hints_extra - hints_used

## Shows the next safe step. Before the stroke begins that is a post it may
## begin at, and the walker drops onto it from above under a ring; after, it
## walks one line whose far end still leaves every other line walkable in one
## stroke, so a hint can never be the move that strands the figure, and the
## ring and the sparkle come as it lands. When no such line exists it says so
## rather than inventing one, which is the island's behaviour exactly and the
## one place a hint is allowed to refuse.
func hint() -> bool:
	if is_done() or out_of_hearts or _ejecting or hints_left() <= 0 or state.nodes.is_empty():
		return false
	var t := _now()
	if state.current < 0:
		var n := state.start_post()
		if n < 0 or not state.begin(n):
			return false
		hints_used += 1
		_stroke = {}
		_walker_arrives(true)
		for m in state.nodes:
			_cap_bump[m] = t
		_busy_for(Motion.BUMP_TIME)
		_ring_at(n)
		fx.cue("hint")
		_say(tr("OL_HINT_BEGIN"), Face.Expr.HAPPY)
		_refresh()
		moved.emit()
		return true
	var to := state.safe_step()
	if to < 0:
		_say(tr("OL_NO_SAFE"),
			Face.Expr.STRAIN)
		fx.cue("locked")
		_refresh()
		return false
	hints_used += 1
	_after(0.0 if Motion.reduce else LAY_TIME, _ring_at.bind(to))
	fx.cue("hint")
	# _walk_to counts the move and can finish the puzzle, as the island's does.
	# A hint's step is safe by construction, so it is judged right but earns
	# no ladybug: only the player's own steps do.
	_walk_to(to, false)
	return true

## The hint's ring and sparkle, in the family's green, out of post `n`.
func _ring_at(n: int) -> void:
	var at := node_to_local(n)
	fx.ring(at, _step * POST_R * RING_R, Pal.GOOD)
	fx.sparkle(at, Pal.GOOD)

## Every line that can no longer be reached from where the walker stands
## wobbles about its middle and blushes toward the family's rose, and the
## sprout says how many. That is the only way to lose One Line, and it is the
## one thing this board will not draw in advance.
func check() -> int:
	if is_done() or out_of_hearts or _ejecting:
		return 0
	checks += 1
	var t := _now()
	var lost := state.stranded()
	if not Motion.reduce:
		for e in lost:
			_wrong[e] = t
		if not lost.is_empty():
			_busy_for(maxf(Motion.WOBBLE_TIME, Motion.FLASH_IN + Motion.FLASH_OUT))
	if state.current < 0:
		_say(tr("OL_CHECK_BARE"),
			Face.Expr.HAPPY)
	elif lost.is_empty():
		_say(tr("OL_CHECK_OK"), Face.Expr.JOY)
	else:
		_say(tr("OL_LOST_ONE") if lost.size() == 1
			else tr("OL_LOST_N") % lost.size(),
			Face.Expr.STRAIN)
	fx.cue("check" if not lost.is_empty() else "check_ok")
	_refresh()
	return lost.size()

## The jetty is taken up again: every plank shrinks to nothing in a wave from
## the far corner while the posts hop, and the walker pops out where it
## stood. The hints spent are not refunded.
func reset_board() -> void:
	if out_of_hearts or _ejecting:
		return
	_clear_figure()
	_break_streak()
	fx.cue("reset")
	_refresh()

## Every plank shrinks to nothing in a wave from the far corner while the
## posts hop, the daisies fold, and the walker pops out where it stood.
## Reset and Try again share it.
func _clear_figure() -> void:
	var now := _now()
	_release_post()
	_drawing = false
	for e in state.walked:
		var anchor: int = int(state.lay_from.get(e, state.edges[e].x))
		var edge: Vector2i = state.edges[e]
		var other: int = edge.y if anchor == edge.x else edge.x
		var diagonal := 0.5 * float(_diagonal(anchor) + _diagonal(other))
		_gone.append({"from": node_to_local(anchor), "to": node_to_local(other),
			"at": now + _reset_wave(diagonal), "seed": e})
	if state.current >= 0:
		_walker_out = now
		Motion.stop(_look_tw)
		Motion.stop(_pos_tw)
		snail.position = Vector2.ZERO
		_look_tw = Motion.pop_out(snail)
		_busy_for(Motion.POP_OUT)
	state.reset()
	_stroke = {}
	_post_press = {}
	_post_shiver = {}
	_post_blush = {}
	_wrong = {}
	_bright = {}
	_warm = {}
	_joy = false
	if not Motion.reduce:
		for n in state.nodes:
			var at: float = now + _reset_wave(float(_diagonal(n)))
			_post_hop[n] = {"at": at, "height": Motion.RESET_HOP, "time": Motion.HOP_TIME}
			_cap_bump[n] = at
		_busy_for(_reset_wave(0.0) + maxf(Motion.HOP_TIME, maxf(Motion.BUMP_TIME, Motion.POP_OUT)))
	_bloom = {}
	_bad_plank = {}
	moves = 0
	_running = true
	_say(tr("OL_RESET"),
		Face.Expr.HAPPY)

## A completed daily is rebuilt from its seed with nothing walked. Walk the
## generator's own Eulerian trail through the state, then settle everything as
## a finished solve wave leaves it: every plank laid and warmed, every post in
## place, the walker grinning on the post where the stroke ended. No entrance
## and no wave play, and `solved` is not emitted a second time.
func restore_completed_board() -> void:
	var t := _now()
	_stop_all()
	_drawing = false
	_pressed_post = -1
	_walker_pressed = false
	state.reset()
	var path: Array = state.solution_path()
	if path.is_empty() or not state.begin(int(path[0])):
		return
	for k in range(1, path.size()):
		state.step(int(path[k]))
	_stroke = {}
	_post_press = {}
	_post_hop = {}
	_cap_bump = {}
	_post_shiver = {}
	_post_blush = {}
	_wrong = {}
	_gone = []
	_bright = {}
	_warm = {}
	for e in state.trail:
		_bright[e] = t - 10.0
	for n in state.nodes:
		_warm[n] = t - 10.0
		if n != state.current:
			_bloom[n] = t - 10.0
	_walker_out = -100.0
	_opened = t - 10.0
	_anim_until = 0.0
	_solved_at = t - 10.0
	_joy = true
	_tip_timer.stop()
	_say(tr("OL_WIN"), Face.Expr.JOY)
	# A restore keeps the seal on Insane: the day was won there.
	if state.band == 3:
		_stamp_at = t - 10.0
		_life_layer.queue_redraw()
	_refresh()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	var out: String = state.share_glyphs()
	if state.band == 3:
		out += "\n🌙 " + (tr("OL_SUN_SEAL") if state.has_sun() else tr("BN_INSANE_SEAL")) + (" · " + tr("BN_FLAWLESS") if _flawless else "")
	elif _flawless:
		out += "\n🏅 " + tr("BN_FLAWLESS")
	return out

# --- the win ---

## The board is the answer here, as it is on Untangle and Balance, so the win
## screen shows no cast: the finished figure stays on the card under it with
## the walker standing where it finished.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("OL_WIN_SUB")}

## The trail has to finish warming, the last post has to land and the walker
## has to come down.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return _solve_delay(state.trail.size()) + Motion.SOLVE_TIME + WIN_SETTLE + PARTY_EXTRA

## The k-th step of the solve wave, which runs the whole trail rather than
## capping at the family's 0.6: the stroke running back along itself is this
## board's signature, and a capped retrace would arrive all at once at the
## end.
func _solve_delay(k: int) -> float:
	return Motion.SOLVE_DELAY + float(k) * Motion.SOLVE_STAGGER

## Every plank warms a shade brighter along the trail in walk order, so the
## stroke runs back along itself and draws the figure once more; each post
## hops as the warmth reaches it, and the walker last of all, grinning, with a
## sparkle where the stroke ended.
func _on_solved() -> void:
	var t := _now()
	_drawing = false
	_release_post()
	_tip_timer.stop()
	_solved_at = t
	_bright = {}
	_warm = {}
	var last := _solve_delay(state.trail.size())
	for k in state.trail.size():
		_bright[state.trail[k]] = t + _solve_delay(k)
	if not Motion.reduce:
		for k in state.walk.size():
			_post_hop[state.walk[k]] = {"at": t + _solve_delay(k),
				"height": Motion.SOLVE_HOP, "time": Motion.SOLVE_TIME}
			_warm[state.walk[k]] = minf(float(_warm.get(state.walk[k], INF)), t + _solve_delay(k))
		_walker_hop(Motion.SOLVE_HOP, Motion.SOLVE_TIME, last)
		_after(last, func() -> void:
			_joy = true
			fx.sparkle(node_to_local(state.current), Pal.SUN)
			_refresh())
	else:
		_joy = true
		for n in state.nodes:
			_warm[n] = t
	_busy_for(last + maxf(Motion.SOLVE_TIME, BRIGHT_TIME))
	_flawless = hints_used == 0 and (not _lost_ever if max_hearts > 0 else checks == 0)
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = t
		_combo_layer.queue_redraw()
	_bloom_spent(state.nodes, t + last)
	_say(tr("OL_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_party(last)
	_refresh()

# --- judging a step ---

## A step judged right: on Hard and Insane one that keeps the figure
## finishable, on Easy and Medium one that strands nothing. It builds the
## streak (the combo pitched up the pentatonic from the second, the bubble
## from the third, confetti at five and ten) and may play a gag. `judged`
## (Hard and Insane, the player's own step) also calls a ladybug to ride.
func _on_right_step(e: int, n: int, judged: bool) -> void:
	_streak += 1
	if _streak >= 2:
		var step: int = COMBO_STEPS[mini(_streak - 2, COMBO_STEPS.size() - 1)]
		_after(0.0 if Motion.reduce else LAY_TIME, fx.cue.bind("combo", pow(2.0, step / 12.0), COMBO_DB))
	if _streak >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF
		_combo_n = _streak
		_combo_post = n
		_combo_at = _now()
		_combo_out_at = -INF
		_combo_layer.queue_redraw()
	if COMBO_CONFETTI.has(_streak) and not Motion.reduce:
		_after(LAY_TIME, func() -> void:
			fx.confetti(node_to_local(n), 22)
			fx.cue("confetti"))
	if judged:
		_want_bug()
	_gag(e, n)

## The streak ends: a stranding step, a wrong one, an undo, a reset, the
## hearts running out. The bubble deflates.
func _break_streak() -> void:
	_streak = 0
	if _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_out_at = _now()
		if _combo_layer != null:
			_combo_layer.queue_redraw()
	else:
		_combo_n = 0

## A wrong step on Hard or Insane: a heart goes (its halves fall), the snail
## lands worried, the plank she laid blushes and on Hard the lines it
## stranded wobble rose, and EJECT_AFTER later the plank comes back up under
## her as she slides home -- taken back through state.undo(), leaving no
## history of it.
func _wrong_step(e: int, n: int) -> void:
	if hearts <= 0:
		return
	var now := _now()
	var land := 0.0 if Motion.reduce else LAY_TIME
	# The finger is let go: still down on the wrong post, the next drag
	# after the eject would take the same step again.
	_drawing = false
	_release_post()
	hearts -= 1
	_lost_ever = true
	_break_streak()
	_split_index = hearts
	_split_at = now + land
	_ejecting = true
	if hearts <= 0:
		out_of_hearts = true
		_running = false
	_bad_plank[e] = now + land
	var lost := state.stranded()
	_after(land, func() -> void:
		_heart_layer.queue_redraw()
		_worried = true
		if not Motion.reduce:
			var t := _now()
			for i in lost:
				_wrong[i] = t
		_busy_for(maxf(Motion.WOBBLE_TIME, Motion.FLASH_IN + Motion.FLASH_OUT))
		_say(tr("OL_WRONG_SUN") if state.has_sun() else tr("OL_WRONG_STEP"), Face.Expr.WORRIED)
		fx.cue("heart_lost")
		_refresh())
	_busy_for(land + EJECT_AFTER + LAY_TIME)
	moved.emit()
	_after(land + EJECT_AFTER, _eject)

## The wrong step is taken back: the plank sinks back to stone as the snail
## slides home along it, and she is herself again when she lands.
func _eject() -> void:
	_ejecting = false
	if is_done():
		return
	var caps := _snapshot_caps()
	var out: Dictionary = state.undo()
	if out.is_empty():
		return
	var t := _now()
	_stroke = {"edge": int(out.edge), "from": int(out.from), "to": int(out.to),
		"at": t, "up": false, "to_cap": caps.get(int(out.to), _cap_of(int(out.to)))}
	_bad_plank.erase(int(out.edge))
	_busy_for(LAY_TIME)
	_depart(int(out.from))
	_land(int(out.to), t + (0.0 if Motion.reduce else LAY_TIME), false)
	_unbloom()
	fx.cue("slip")
	_after(0.0 if Motion.reduce else LAY_TIME, func() -> void:
		_worried = false
		if not out_of_hearts:
			_speak()
		_refresh())
	moved.emit()
	_refresh()
	if out_of_hearts:
		_after(0.0 if Motion.reduce else LAY_TIME, _run_out)

## The last heart is gone: the figure slips to dusk, the snail curls up for
## a nap, the ladybugs fly home, and the card comes up once she has.
func _run_out() -> void:
	if _asleep:
		return
	_asleep = true
	_drawing = false
	_release_post()
	_break_streak()
	fx.cue("out_of_hearts")
	_say(tr("OL_OUT"), Face.Expr.SLEEPY)
	_dusk_toward(DUSK)
	_bugs_leave()
	_refresh()
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

## The whole figure and everything on it eases toward `tint`: DUSK when the
## hearts run out, white again when a heart comes back or the figure is
## walked again.
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
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["OL_OUT_BODY", "OL_OUT_REST"])
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same figure from the top, every heart back, the day's
## light, the clock and the moves from zero; hints spent stay spent.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	elapsed = 0.0
	checks = 0
	_clear_figure()
	_deal()
	# _deal() puts the light back at once; hold the dusk so it fades.
	modulate = DUSK
	_dusk_toward(Color.WHITE)
	_heart_layer.queue_redraw()
	_tip_idx = 0
	_say(tr(_tips()[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("reset")
	moved.emit()
	_refresh()

## One more heart (the card's video): once a board. The light comes back and
## the snail wakes where she stands.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	hearts = 1
	_back_index = 0
	_back_at = _now()
	_heart_layer.queue_redraw()
	out_of_hearts = false
	_asleep = false
	_running = true
	fx.cue("heart_back")
	_dusk_toward(Color.WHITE)
	if state.current >= 0 and not Motion.reduce:
		_walker_hop(Motion.HOP, Motion.HOP_TIME)
	_speak()
	moved.emit()
	_refresh()

## Back from the card: the board ends unsolved first, so the host logs
## puzzle_complete {solved: false} and not an abandon.
func _leave() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- the hearts ---

## The hearts over the figure as one mesh on a paper pill (Light Up's,
## Tents', Shikaku's and Binairo's): pink with a small face and a leaf, a faint
## ghost where one was, the lost one's halves falling apart, and one coming
## back popping in.
func _draw_hearts() -> void:
	if max_hearts <= 0 or _step <= 0.0:
		return
	var b := Face.Builder.new()
	var now := _now()
	var step := 2.0 * HEART_R + HEART_GAP
	var y := _card.position.y + 12.0 + HEART_ROW * 0.5
	var x0 := size.x * 0.5 - step * (max_hearts - 1) * 0.5
	var pill := Vector2(step * (max_hearts - 1) + 2.0 * HEART_R, 2.0 * HEART_R) + 2.0 * HEART_PILL_PAD
	var corner := Vector2(size.x * 0.5, y) - pill * 0.5
	var rim := Vector2.ONE * HEART_PILL_RIM
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
				for k in pts.size():
					pts[k] = at + shift + pts[k].rotated(turn)
				b.polygon(pts, Color(Pal.FLOWER if side < 0 else Pal.FLOWER_DEEP, fade))
	_hearts_shown = b.mesh()
	_heart_layer.draw_mesh(_hearts_shown, null)

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

# --- the streak's bubble ---

## The streak's paper bubble at the upper right of its post, "x3" and up in
## ink: it pops in the first time, bumps at each step and deflates when the
## streak ends. One mesh for the paper and one string (Light Up's).
func _draw_combo() -> void:
	if _combo_n < COMBO_FROM or _step <= 0.0:
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
	var post := node_to_local(_combo_post)
	var tail := post + Vector2(_step * 0.25, -_step * 0.45)
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

# --- gags, ladybugs and the life over the figure ---

## A right step now and then plays a gag, picked by the line's own hash so a
## figure replays the same: the snail slides on sunglasses, little hearts
## float up off the plank she just laid, or a mushroom pops up by the post
## she lands on and grins. Under reduce-motion, none.
func _gag(e: int, n: int) -> void:
	if Motion.reduce or is_done():
		return
	var roll := posmod(hash(Vector2i(e * 13 + 7, n * 5 + 3)), GAG_ODDS)
	if roll >= GAGS:
		return
	match roll:
		0:
			Motion.stop(_gag_tw)
			_gag_tw = snail.create_tween()
			_gag_tw.tween_property(snail, "glasses", 1.0, GLASSES_IN).from(0.0).set_delay(LAY_TIME) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_gag_tw.tween_interval(GLASSES_HOLD)
			_gag_tw.tween_property(snail, "glasses", 0.0, GLASSES_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			_after(LAY_TIME, fx.cue.bind("cool"))
		1:
			var edge: Vector2i = state.edges[e]
			var now := _now() + LAY_TIME
			for k in LOVE_HEARTS:
				var u := (k + 0.5) / LOVE_HEARTS
				_love.append({"at": node_to_local(edge.x).lerp(node_to_local(edge.y), u),
					"t": now + k * 0.08, "phase": _hash(e * 5 + k) * TAU})
			_after(LAY_TIME, fx.cue.bind("love"))
		2:
			_pop_mushroom(n)

## The mushroom pops up beside post `n`, on the side away from the figure's
## middle, grins, and sinks back after MUSH_HOLD.
func _pop_mushroom(n: int) -> void:
	var at := node_to_local(n)
	# Beside the post, on the side away from the figure's middle, and never
	# above it: the top row would put her over the hearts.
	var middle: float = _origin.x + (state.cols - 1) * _step * 0.5
	var side := 1.0 if at.x >= middle else -1.0
	var spot := at + Vector2(side * 0.4, 0.14) * _step
	Motion.stop(_mush_tw)
	_mushroom.position = spot - _mushroom.size * 0.5
	_mushroom.expression = Face.Expr.JOY
	_mushroom.visible = true
	_mushroom.scale = Vector2.ZERO
	_mush_tw = Motion.pop_in(_mushroom, Motion.POP_IN, LAY_TIME)
	_after(LAY_TIME, fx.cue.bind("mushroom"))
	_after(LAY_TIME + MUSH_HOLD, func() -> void:
		Motion.stop(_mush_tw)
		_mush_tw = Motion.pop_out(_mushroom)
		_after(Motion.POP_OUT, func() -> void: _mushroom.visible = false))

## A judged step may call a ladybug: one at the first, then one past each of
## BUG_AT's shares of the figure. She flies in from above the card and lands
## on the shell.
func _want_bug() -> void:
	if snail.riders + _bugs.size() >= BUG_AT.size():
		return
	var share := float(state.walked.size()) / float(maxi(1, state.edges.size()))
	var due := 0
	for s in BUG_AT:
		if share > float(s) or (float(s) == 0.0):
			due += 1
	if snail.riders + _bugs.size() >= due:
		return
	if Motion.reduce:
		snail.riders += 1
		return
	var side := -1.0 if (_bugs.size() + snail.riders) % 2 == 0 else 1.0
	_bugs.append({"from": Vector2(size.x * (0.5 + 0.45 * side), _card.position.y - _step * 0.4),
		"t": _now() + LAY_TIME, "phase": randf() * TAU})
	_after(LAY_TIME, fx.cue.bind("ladybug"))

## Out of hearts: the riders fly home (they are simply gone; the dusk hides
## the rest), and a heart back or Try again starts over without them.
func _bugs_leave() -> void:
	_bugs = []
	if snail.riders > 0 and not Motion.reduce:
		fx.puff(snail.global_position - global_position + snail.size * 0.5, Pal.BAD, 4)
	snail.riders = 0

## Keeps the life layer drawing while anything on it moves; lands arriving
## ladybugs on the shell.
func _tick_life(now: float) -> bool:
	var still: Array = []
	for l in _love:
		if now < float(l.t) + LOVE_TIME:
			still.append(l)
	_love = still
	still = []
	for bug in _bugs:
		if now >= float(bug.t) + BUG_FLY:
			snail.riders += 1
			if not Motion.reduce:
				fx.sparkle(_seat.position + _seat.size * 0.5, Pal.BAD)
		else:
			still.append(bug)
	_bugs = still
	still = []
	for p in _petals:
		if now < float(p.t) + PETAL_TIME:
			still.append(p)
	_petals = still
	return not _love.is_empty() or not _bugs.is_empty() or not _petals.is_empty() \
		or (now >= _stamp_at and now - _stamp_at < STAMP_DROP * 2.0 + 0.1)

## The life over the figure: love hearts floating off a plank, ladybugs
## flying in, petals falling at the party, each a mesh built once and drawn
## under its own transform; and the seal after the solve, with its words.
func _draw_life() -> void:
	if _step <= 0.0:
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
			var at: Vector2 = l.at + Vector2(sin(u * TAU + float(l.phase)) * 0.06 * _step,
				-LOVE_RISE * _step * (1.0 - (1.0 - u) * (1.0 - u)))
			var k := Motion.pop_in_scale(e, 0.2).x
			_life_layer.draw_mesh(mesh, null, Transform2D(sin(u * TAU) * 0.2, Vector2(k, k), 0.0, at),
				Color(1.0, 1.0, 1.0, clampf((1.0 - u) / 0.4, 0.0, 1.0)))
	if not _bugs.is_empty():
		var mesh := _bug()
		shown.append(mesh)
		var to := _seat.position + _seat.size * 0.5 - Vector2(0.0, _seat.size.y * 0.3)
		for bug in _bugs:
			var e: float = now - float(bug.t)
			if e <= 0.0:
				continue
			var u := clampf(e / BUG_FLY, 0.0, 1.0)
			var from: Vector2 = bug.from
			var mid := from.lerp(to, 0.5) + Vector2(0.0, -_step * 0.6)
			var at := from.lerp(mid, u).lerp(mid.lerp(to, u), u)
			at += Vector2(sin(e * 18.0 + float(bug.phase)), cos(e * 14.0)) * _step * 0.03 * (1.0 - u)
			var head := (to - at).angle() + PI * 0.5
			_life_layer.draw_mesh(mesh, null, Transform2D(head, at))
	if not _petals.is_empty():
		# Every petal in one mesh, rebuilt while they fall: one draw call for
		# the whole shower rather than one a petal.
		var pb := Face.Builder.new()
		var r := _step * POST_R * DAISY_R
		for p in _petals:
			var e: float = now - float(p.t)
			if e <= 0.0:
				continue
			var u := e / PETAL_TIME
			var v: Vector2 = p.v
			var at: Vector2 = p.at + v * _step * u + Vector2(sin(e * 4.0 + float(p.phase)) * 0.12 * _step,
				PETAL_FALL * _step * u * u)
			var spin: float = float(p.phase) + e * float(p.spin)
			var flat := absf(cos(e * 5.0 + float(p.phase))) * 0.7 + 0.3
			var fade := clampf((1.0 - u) / 0.35, 0.0, 1.0)
			_oval(pb, at, r * 0.4, r * 0.2 * flat, spin, Color(Pal.PETAL_EDGE, fade))
			_oval(pb, at, r * 0.36, r * 0.16 * flat, spin, Color(Pal.SURFACE, fade))
		if not pb.verts.is_empty():
			var mesh := pb.mesh()
			shown.append(mesh)
			_life_layer.draw_mesh(mesh, null)
	if now >= _stamp_at:
		_draw_stamp(now, shown)
	_life_shown = shown

## A little pink heart for the love gag, built once.
func _love_heart() -> ArrayMesh:
	if _love_mesh == null:
		var b := Face.Builder.new()
		var r := _step * LOVE_R
		b.polygon(_heart(Vector2.ZERO, r * 1.15, 0), Pal.FLOWER_DEEP)
		b.polygon(_heart(Vector2.ZERO, r, 0), Pal.FLOWER)
		b.ellipse(Vector2(-0.45, -0.45) * r, 0.18 * r, 0.1 * r, Color(1.0, 1.0, 1.0, 0.5))
		_love_mesh = b.mesh()
	return _love_mesh

## A flying ladybug, heading up, built once: the rider's own shape with its
## wings out.
func _bug() -> ArrayMesh:
	if _bug_mesh == null:
		var b := Face.Builder.new()
		var r := _step * BUG_R
		for sx in [-1.0, 1.0]:
			_oval(b, Vector2(sx * r * 0.9, r * 0.1), r * 0.8, r * 0.4, sx * 0.5, Color(1.0, 1.0, 1.0, 0.55))
		SnailFace.ladybug(b, Vector2.ZERO, r, 0.0)
		_bug_mesh = b.mesh()
	return _bug_mesh

## After the retrace (`lead` from now): the snail puts on a party hat, every
## daisy lets its petals go in a shower, confetti sweeps the figure twice,
## and the seal, when the solve earned one (flawless, or any Insane figure),
## stamps onto the card's lower right. Under reduce-motion only the seal,
## standing still.
func _party(lead: float) -> void:
	var now := _now()
	if _flawless or state.band == 3:
		_stamp_at = now if Motion.reduce else now + lead + Motion.SOLVE_TIME + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_life_layer.queue_redraw())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
	if Motion.reduce:
		return
	var at := lead + PARTY_AT
	snail.hat_style = posmod(state.edges.size(), 7)
	Motion.stop(_gag_tw)
	snail.glasses = 0.0
	_gag_tw = snail.create_tween()
	_gag_tw.tween_property(snail, "hat", 1.0, PARTY_HAT).from(0.0).set_delay(at) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_after(at, func() -> void:
		var field := _figure_rect()
		fx.confetti(Vector2(field.get_center().x, field.position.y + _step * 0.3), 30, field.size.x * 0.9)
		fx.cue("party"))
	_after(at + 0.45, func() -> void:
		var field := _figure_rect()
		fx.confetti(field.get_center(), 24, field.size.x * 0.7))
	var petals := at + PARTY_HAT
	for n in state.nodes:
		for k in PETALS:
			var a := _hash(n * 11 + k) * TAU
			_petals.append({"at": node_to_local(n), "t": now + petals + Motion.stagger(_diagonal(n), PETAL_STAGGER),
				"v": Vector2.from_angle(a) * 0.5, "phase": a, "spin": lerpf(-4.0, 4.0, _hash(n * 3 + k))})
	_after(petals, func() -> void: fx.cue("petals"))
	_anim_until = maxf(_anim_until, now + petals + PETAL_TIME)

## The figure's span on the card.
func _figure_rect() -> Rect2:
	return Rect2(_origin, Vector2(state.cols - 1, state.rows - 1) * _step)

## The seal on the card's lower right, dropping in from STAMP_FROM its size
## and settling with the back ease's overshoot, its words over it.
func _draw_stamp(now: float, shown: Array) -> void:
	var rad := size.x * STAMP_R * 0.75
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, state.band == 3)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := _card.end - Vector2(rad * 1.2, rad * 0.95)
	var xf := Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	_life_layer.draw_set_transform_matrix(xf)
	_life_layer.draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_life_layer.draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var lines: Array
	if state.band == 3:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02],
			[tr("BN_FLAWLESS") if _flawless or not state.has_sun() else tr("OL_SUN_SEAL"), 0.17, 0.36]]
	else:
		lines = [[tr("BN_FLAWLESS"), 0.24, 0.12]]
	Seal.text(_life_layer, rad, lines)
	_life_layer.draw_set_transform_matrix(Transform2D.IDENTITY)

# --- odds and ends ---

## Kills every tween the previous board still tracks and retires its pending
## callbacks, so a rebuild never inherits a hop aimed at the last figure.
func _stop_all() -> void:
	_gen += 1
	Motion.stop(_look_tw)
	Motion.stop(_pos_tw)
	Motion.stop(_gag_tw)
	Motion.stop(_mush_tw)
	Motion.stop(_squash_tw)
	Motion.stop(_dusk_tw)
	_close_card()
	if snail != null:
		snail.scale = Vector2.ONE
		snail.position = Vector2.ZERO
		snail.rotation = 0.0
		snail.modulate.a = 1.0
		snail.visible = true

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	if delay <= 0.0:
		what.call()
		return
	var gen := _gen
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

## Seconds since the scene started, the clock every animation here reads.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## 0 to 1, and 1 at once under reduce-motion.
func _dec(u: float) -> float:
	return 1.0 if Motion.reduce else clampf(u, 0.0, 1.0)
