extends Control

## Peapod: the sixth game on the Arcade tab, a pea cannon against crates
## that come down with a number on each (spec
## docs/superpowers/specs/2026-10-04-arcade-peapod-design.md). The flat
## boards' top bar (back, the title in ink, restart, settings), a paper row
## with the score, the best and the wave, and under them the garden on the
## flat boards' parchment card, hedges round its foot: a pale sky the crates
## come down, the sun watching from it, the cart on the grass.
##
## Play: slide anywhere to roll the cart; it never stops firing. The game is
## arcade/peapod_sim.gd, stepped at its fixed DT; this screen draws it and
## plays its events.
##
## The fourth pass (2026-10-05): nothing is caught. A gift crate's gift
## starts as it breaks, every crate pays energy (the fourth plate of the
## row), and a wave cleared opens the shop (`_open_shop`) where energy buys
## the gun's three numbers and more energy. Every pea landing floats what it
## took off (`_nums`), a crit's bigger and gold, and leaves the pea itself
## tumbling away (`_crumbs`).
##
## The fifth pass (2026-10-05): a gift is kept, not started, and a press on
## its button starts it; a press that lands on a button never takes the
## cart. A shape and an element run together. (Its two buttons on the grass,
## the chute behind them and the rings beside them went with the eighth.)
##
## The eighth pass (2026-10-05): the line of gifts is gone. All seven gifts
## stand from the start on a rack down the garden's left side (the right
## was tried first: the thumb that slides the cart rests there, over it), one under
## another, each with how many are had lettered on a pip (none at first); a
## gift crate's gift flies to its own button, a press starts one (the keys 1
## to 7), and what is running runs down round its own button's rim. The
## garden is fitted beside the rack (`_fit`), so no button is ever over a
## crate or under the cart. A volley's peas leave side by side, a pod a pea
## (`_draw_cart`); a gift started flies to the pod, which swallows it and
## wears it: the element's colour, the Fan's side pods, the Dart's nozzle,
## the Berry's bunches, lightning or a pilot flame at the mouth. And energy
## is motes of light, not balls (`Art.orb`, `_draw_orbs`).
##
## The tenth pass (2026-10-06): six carts, chosen on a card before the run
## (`_build_carts`; opened by the furthest wave reached, `CART_WAVE`), each
## with a gun and a shot of its own and one card of its own in the shop; ten
## gifts on the rack (three more elements, each a pea's colour and a mark at
## a corner of what it is on: `_draw_marks`); and a thing that goes while
## alight bursts (`_on_flare`).
##
## Drawing: the garden (sky, hills, grass) is one still mesh, built on
## resize. Everything that moves is drawn by one Control over it: a cached
## mesh a crate, a plate, a token and a part of the cart, moved by the
## transform and gathered a MultiMesh a look, their numbers lettered over
## them in ink, and one live mesh for what is laid fresh each frame.
##
## The soft pass (the spec's section 7): Lucky Thirteen's pastel pieces and
## Posy's card and hedges; a gift caught flies to its place on the grass, a
## crate gone leaves its shape swelling away, a streak is counted on a paper
## pill with its time running down, a wave cleared is stamped one to three
## stars and that many flowers come up along the grass, the pod wears a
## crown once the best is passed, and the big moments are held a beat.

signal closed

const Sim = preload("res://arcade/peapod_sim.gd")
const Art = preload("res://arcade/peapod_art.gd")
const Record = preload("res://arcade/arcade_record.gd")
const FlatTopBar = preload("res://ui/flat/flat_top_bar.gd")
const SettingsSheet = preload("res://ui/hud/settings_sheet.gd")
const ScreenTutor = preload("res://ui/hud/screen_tutor.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
## What the phone knocks for (docs/agents/haptics.md). The gun never stops
## and a volley's peas land several to a frame, so only the end card's cue is
## mapped: the events ask through `_feel` and the frame knocks once, with the
## strongest. The shots and the peas landing play through `_quiet`, which
## knocks for nothing.
const HAPTICS := {"new_best": Haptics.WIN}
const Face = preload("res://ui/faces/face.gd")
const Analytics = preload("res://core/analytics.gd")
const Boosters = preload("res://arcade/boosters.gd")
const BoostCard = preload("res://arcade/boost_card.gd")
const SecondChance = preload("res://arcade/second_chance.gd")
const GoldDoubler = preload("res://arcade/gold_doubler.gd")
const Rewards = preload("res://arcade/rewards.gd")

const GAME := "peapod"
const MARGIN := 40
const GAP := 20
const HUD_H := 110.0
const FRAME := 16
const BACKDROP_BLEED := 90.0
## The most sim steps one frame may run, so a stall never fast-forwards.
const MAX_STEPS := 4
## The finger's slide, times this, is the cart's.
const GAIN := 1.35
## Where the grass begins, in field units: under the cart's wheels.
const TURF := Sim.CART_Y + 9.0
const RECOIL := 0.09
const SKY_TOP := Color("d3e9f4")
const SKY_LOW := Color("f9f3e3")
const HILL_FAR := Color("d6e8c8")
const HILL := Color("c2deac")
const HILL_NEAR := Color("b0d596")
const GRASS := Color("a5d385")
const GRASS_DEEP := Color("8fc56f")
const GRASS_LIP := Color("c8e8ab")
const BUSH := [Color("8fc56f"), Color("a0d07f"), Color("b3db93")]
const ALARM := Color("f07f72")
const HEAT := Color("f6b866")
const FROST := Color("8fd0ee")
const STAR_OFF := Color("dccfb6")
## A gift on its way from the cart to its place on the grass.
const FLIGHT_T := 0.5
## The shape a crate gone leaves, swelling away.
const GHOST_T := 0.18
## A streak is counted on its pill from this many.
const STREAK_FROM := 5
## The stars a cleared wave is stamped: three if the line was never nearer
## than the first of these, two under the second.
const STAR_PEAKS := [0.2, 0.65]
const STAR_STEP := 0.22
const MAX_BLOOMS := 30
## The gun's three numbers on the grass, left to right (Sim.Card), and what
## is added to a card for its key among the things that bump (`_chip_at`).
const GUN := [Sim.Card.DAMAGE, Sim.Card.SPEED, Sim.Card.CRIT]
const CHIP := 100
## The stickers' letters, in Lucky Thirteen's pastels.
const STICKER_COLS := [Color("f08a80"), Color("f6b866"), Color("f0d36a"), Color("9ed48a"), Color("86c2ee"), Color("c19be0")]
## How round the garden's corners are, inside the card's.
const ROUND := 22.0
## A streak's word, by its length, loudest first.
const WORDS := [[75, "PP_WORD_5"], [50, "PP_WORD_4"], [35, "PP_WORD_3"], [20, "PP_WORD_2"], [10, "PP_WORD_1"]]
const GOT := {Sim.Kind.FAN: "PP_GOT_FAN", Sim.Kind.PIERCE: "PP_GOT_PIERCE", Sim.Kind.BURST: "PP_GOT_BURST", Sim.Kind.ZAP: "PP_GOT_ZAP",
	Sim.Kind.FLAME: "PP_GOT_FLAME", Sim.Kind.NETTLE: "PP_GOT_NETTLE", Sim.Kind.HAIL: "PP_GOT_HAIL", Sim.Kind.GUST: "PP_GOT_GUST",
	Sim.Kind.FROST: "PP_GOT_FROST", Sim.Kind.SHOVE: "PP_GOT_SHOVE"}
## The gifts' rack down the garden's left side: the strip it stands in
## (the garden is fitted beside it), a seat's size, the step from one button
## down to the next, how far up from the field's foot the lowest is, how far
## into the garden a press is still the rack's, and how long a press and a
## refusal show.
const RACK_W := 30.0
const RACK_R := 12.4
const RACK_STEP := 32.0
const RACK_FOOT := 17.0
const RACK_REACH := 5.0
const RACK_PRESS := 0.14
const RACK_NO := 0.3
## A gift started, on its way from its button to the pod's mouth.
const USE_T := 0.3
## The pods of a volley of one to four peas: how big each is.
const POD_SIZE := [1.0, 0.86, 0.78, 0.72]
## The sound a gift starts with, where it has one of its own.
const CATCH_CUE := {Sim.Kind.FAN: "pod", Sim.Kind.PIERCE: "pod", Sim.Kind.BURST: "pod", Sim.Kind.ZAP: "pod", Sim.Kind.FLAME: "pod",
	Sim.Kind.NETTLE: "pod", Sim.Kind.HAIL: "pod", Sim.Kind.GUST: "pod", Sim.Kind.FROST: "frost", Sim.Kind.SHOVE: "shove"}
## The numbers off a pea landing: how many at once, how long one lives, and
## its colours by what it came off by (Sim.Hit), a crit's last (NUM_CRIT).
const MAX_NUMS := 26
const NUM_T := 0.55
const NUM_COLS := [Color("fffaf0"), Color("d8ecff"), Color("ffe9a8"), Color("ffc59a"), Color("e6d2ff"), Color("ffd65c")]
const NUM_RIMS := [Color("3b3028"), Color("3d5878"), Color("7a4a10"), Color("8a3d1c"), Color("4f3472"), Color("7a4a10")]
const NUM_CRIT := 5
## The spent peas tumbling off, and a bolt's life.
const MAX_CRUMBS := 20
const CRUMB_T := 0.42
const BOLT_T := 0.14
const MAX_BOLTS := 6
## The energy a crate lets go: motes of light drifting out of it for
## ORB_OUT (and as long again at most), hanging there breathing, then drawn
## in to the energy plate, slowly and then quick, round a bend of their own,
## one after another, each leaving a dust of smaller lights behind it. So
## many at once at most (what is over is counted at once), and so many a
## crate (a millipede's head is worth a hundred: its motes are fewer and
## bigger). The dust: so many specks at most, how long one glows, and how
## far a mote flies between two.
const MAX_ORBS := 150
const ORBS_A_CRATE := 28
const ORB_OUT := 0.34
const ORB_IN := 0.55
const ORB_GAP := 0.03
const MAX_DUST := 150
const DUST_T := 0.42
const DUST_STEP := 8.0
const SHOP_NAMES := ["PP_CARD_DAMAGE", "PP_CARD_SPEED", "PP_CARD_CRIT", "PP_CARD_ENERGY", "PP_CARD_SHOTS"]
## The carts (Sim.Cart): each one's name, what it says of itself where it is
## chosen, the card only it sells and that card's line of figures; and the
## wave a player must have reached to roll each out (the pea gun is everyone's).
const CART_NAMES := ["PP_CART_PEA", "PP_CART_CONKER", "PP_CART_PUMPKIN", "PP_CART_HOSE", "PP_CART_DANDELION", "PP_CART_TWINS"]
const CART_LINES := ["PP_CART_PEA_LINE", "PP_CART_CONKER_LINE", "PP_CART_PUMPKIN_LINE", "PP_CART_HOSE_LINE", "PP_CART_DANDELION_LINE", "PP_CART_TWINS_LINE"]
const OWN_NAMES := ["PP_CARD_SHOTS", "PP_CARD_HOPS", "PP_CARD_BLAST", "PP_CARD_JET", "PP_CARD_SEEDS", "PP_CARD_TWIN"]
const OWN_LINES := ["PP_CARD_SHOTS_LINE", "PP_CARD_HOPS_LINE", "PP_CARD_BLAST_LINE", "PP_CARD_JET_LINE", "PP_CARD_SEEDS_LINE", "PP_CARD_TWIN_LINE"]
const CART_WAVE := [0, 5, 8, 11, 14, 17]
## The gun's click is heard this far apart at the closest (a hose is a
## dozen drops a second and more), and a burst or a blast its thump.
const SHOT_GAP := 0.07
const THUMP_GAP := 0.09
const MAX_PUFFS := 10
const PUFF_T := 0.32
## The shop's cards, top to bottom: the gun's four and then the energy.
const SHOP_ORDER := [Sim.Card.DAMAGE, Sim.Card.SPEED, Sim.Card.SHOTS, Sim.Card.CRIT, Sim.Card.ENERGY]
const MAX_POPS := 12
const MAX_SPARKS := 40
const SunFace = preload("res://ui/faces/sun_face.gd")

var sim: RefCounted
## A harness rolls this cart out and is never asked (-1: the player's own).
static var force_cart := -1
## The cart this run rolls out (Sim.Cart): the player's last, kept on the
## device (`Record.pick`), where the furthest wave reached still opens it.
var _cart := 0
## The carts' card, up before a run once there is more than one to choose.
var _cart_card: Control
var _cart_tiles: Array = []
var _cart_line: Label
## What the furthest wave was when this run began, for the cart it opens.
var _stage_was := 0
## The run's boosters and whether it was helped (arcade/boosters.gd): a best
## made so is marked. The Second chance is offered once a run, and the gold
## the run earned goes on the end card.
var _boosts: Array = []
var _boosted := false
var _chance_used := false
var _run_gold := 0
var top_bar: Control
var settings_sheet: Control
## The tutorial card: the top bar's ?, the settings' How to play and the
## first play (ui/hud/screen_tutor.gd).
var tutor: RefCounted
var field: Control
var _fx: Node2D
## The gun's own voice: the shots and the peas landing, which nothing knocks
## for.
var _quiet: Node2D
var _backdrop: ColorRect
var _margins: MarginContainer
var _score_l: Label
var _best_l: Label
var _wave_l: Label
var _energy_l: Label
var _shown_energy := -1
## The motes on their way to the energy plate, drawn over the whole screen:
## {pos, vel, t, out, from, bend, val, size, seed, gone}. `_orb_due` is what they carry
## that the plate does not show yet, `_orb_note` the run of notes they land
## on and `_orb_heard` when the last one was heard.
var _orbs: Array = []
var _orb_layer: Control
var _orb_mm: MultiMesh
var _orb_buf := PackedFloat32Array()
var _orb_count := 0
var _orb_due := 0.0
var _orb_note := 0
var _orb_heard := -10.0
var _orb_pulse := -10.0
## The light the motes throw, added to what is under them: a layer of its
## own over the motes' (a blend is a canvas item's, not a draw's).
var _orb_light: Control
var _orb_light_mm: MultiMesh
## The dust the motes leave on their way in, oldest first, four numbers a
## speck (x, y, when it was left, its size); `_dust_from` is the first that
## still glows.
var _dust := PackedFloat32Array()
var _dust_from := 0
var _sub: Label
var _sub_pill: PanelContainer
var _banner_tw: Tween
## The hedges round the card's foot, and the sun in the garden's sky.
var _hedge: Control
var _hedge_mesh: ArrayMesh
var _hedge_rect := Rect2()
var _frame: PanelContainer
var _sun: Control
var _pause_card: Control
var _end: Control
var _over: Control
var _acc := 0.0
var _paused := false
var _started_at := 0
var _best := 0
var _shown_score := -1
var _roll := 0.0
var _beat_best := false
## The knock this frame's events asked for, the strongest of them (-1: none).
var _knock := -1
## Pixels a field unit, and where the field's origin lands in `field`.
var _u := 2.4
var _origin := Vector2.ZERO
var _scene: ArrayMesh
var _land: ArrayMesh
var _live_top: ArrayMesh
## Built with the garden and only moved or tinted after: the chalk line's
## dashes and the plates under the gun's three numbers.
var _dashes: ArrayMesh
var _chips: ArrayMesh
var _text_fs := 13
## Every pea in the air is one draw a look, every spark one more (checkup,
## 2026-10-04: a pea laid into a mesh in script each frame was most of a
## frame once the gun was full and a millipede let the peas fly far).
var _pea_mm: Array = []
var _pea_buf: Array = []
var _spark_mm: MultiMesh
## The crates and the plates the same way, one draw a look of them: a wall
## of forty-five was forty-five draws, and the phone pays by the draw.
## ArrayMesh -> [MultiMesh, its buffer, how many this frame].
## One Dictionary a draw of the frame (`_cast_turn`).
var _casts: Array = []
var _cast_turn := 0
var _spark_buf := PackedFloat32Array()
## The screen's own clock, for motion the sim does not own; it stops with
## the pause.
var _clock := 0.0
## The finger sliding the cart: the touch, where it came down and where the
## cart was then.
var _touch := -1
var _mouse := false
var _touch_from := Vector2.ZERO
var _cart_from := 0.0
## When each crate or plate last took a pea, by its id, for the flash, and
## how cracked each was at its last hit (`Art.worn`), for the chips.
var _hit_at := {}
var _worn_of := {}
## Sparks where a pea lands: {pos, t, col}.
var _sparks: Array = []
## Numbers rising off a crate gone: {pos, text, t, col, big}.
var _pops: Array = []
var _shot_at := -10.0
## The gun's sound (2026-10-05, the user hated the set): every shot is the
## faintest click (the user asked for one; silence was tried and was wrong)
## and the peas landing are heard at most once in HIT_GAP seconds -- a
## volley's peas as one, every volley of the quickest gun (0.102 s apart)
## -- so a full gun is a soft patter and not a rattle of sixteen ticks a
## second.
const HIT_GAP := 0.07
var _hit_heard := -10.0
## A pea landing sounds by the number left on what it hit (the user,
## 2026-10-05), and each paint has its note: HIT_NOTES by `Art.tier_of`, in
## semitones from the take, down the major pentatonic as the number trebles.
## So a wall of mixed crates is a handful of woody notes that always sit
## together, whichever order the peas find them in, and a crate steps up a
## note each time it is worn down a colour. The sound itself is a damped
## wooden tock, never a ringing one; HIT_DRIFT of pitch and HIT_SOFT dB of
## level at random keep two alike from being the same sound twice.
const HIT_NOTES := [9, 7, 4, 2, 0, -3, -5, -8]
const HIT_DRIFT := 0.012
const HIT_SOFT := 2.0
var _wheel := 0.0
var _last_x := 0.0
var _lean := 0.0
var _shake := 0.0
var _shake_off := Vector2.ZERO
var _seat: Control
## The loud rewards over the whole screen (arcade/rewards.gd).
var _rw: Rewards
## The warm glow a long streak lights round the garden (0..1), and the red
## one as the line is neared.
var _heat := 0.0
var _alarm := 0.0
var _flash := 0.0
var _flash_col := Color.WHITE
## The millipede head's number and where it goes, lettered after the peas.
var _head_tag: Array = []
var _end_score: Label
var _end_at := 0.0
## Crates and plates just gone: {pos, round, col, t}.
var _ghosts: Array = []
## Gifts in the air: {kind, from, used, t, time}. One had flies from its
## crate to its button on the rack; one started (`used`) from its button to
## the pod's mouth.
var _flights: Array = []
## The rack's buttons, by `kind - Sim.Kind.FAN`: when each was last pressed
## and when it last refused (none had, or no wave on to use it against), the
## frame of its last press (a touch is also sent as a mouse press) and
## whether its key is down.
var _rack_at: Array = _seven(-10.0)
var _rack_no: Array = _seven(-10.0)
var _rack_frame: Array = _seven(-1)
var _rack_key: Array = _seven(false)
## The pod as the gifts running dress it: how far out each shape's dressing
## is (0..1, by `kind - Sim.Kind.FAN`), from when each gift shows (until
## then it is on its way from its button), the element the pod is painted,
## and when it last swallowed a gift.
var _dress := [0.0, 0.0, 0.0]
var _looks_at := {}
var _pod_el := 0
var _gulp_at := -10.0
## The labels' beats running, by label: a new one starts from rest.
var _beats := {}
## When each of the gun's three numbers, and each of the rack's buttons,
## last took one in (by CHIP + card, and by Sim.Kind), for the bump.
var _chip_at := {}
## The streak's pill: how many it shows, when it last went up, and how far
## it has come in (0..1).
var _streak_n := 0
var _streak_at := -10.0
var _streak_in := 0.0
## The pods' pill, under the streak's: how many pods ran together when it
## was last up, and how far in it is.
var _pair_n := 2
var _pair_in := 0.0
## The wave's stars: how near the line came, and the stamping of the last
## clear ({at, stars, said}).
var _wave_peak := 0.0
var _clear := {}
## The flowers the run has grown: {x, look, at, lean}.
var _blooms: Array = []
## The cart's hop ({at, tall, time}) and the crown it wears.
var _hop := {}
var _crown_at := -1.0
var _dust_at := 0.0
## The beat a big moment is held: seconds left of it, and how slow.
var _hold_t := 0.0
var _hold_k := 1.0
## What each pea landing took off: {pos, text, t, look, big, vx}.
var _nums: Array = []
## The peas themselves, tumbling off what they hit: {pos, vel, t}.
var _crumbs: Array = []
## Lightning on its way along a chain: {pts, t}.
var _bolts: Array = []
## A gust's puffs where its shots land: {pos, t, way}.
var _puffs: Array = []
var _thump_at := -10.0
var _shot_heard := -10.0
## The shop, open between waves: its card, and a row a card ({card, button,
## value, price}).
var _shop: Control
var _shop_rows: Array = []
var _shop_energy: Label

func puzzle_id() -> String:
	return GAME

## The tutorial's pages, each a slice of this garden played by a finger
## (ui/hud/peapod_tutorial_diagram.gd): the slide, the numbers and the line,
## the gifts, the pods, the special crates, the millipede, and the boosters
## and the top bar.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/peapod_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.SLIDE, "TUT_PEAPOD_SLIDE", tr("TUT_PEAPOD_SLIDE_BODY")],
		[Diagram.Lesson.CRATES, "TUT_PEAPOD_CRATES", tr("TUT_PEAPOD_CRATES_BODY")],
		[Diagram.Lesson.GIFTS, "TUT_PEAPOD_GIFTS", tr("TUT_PEAPOD_GIFTS_BODY")],
		[Diagram.Lesson.PODS, "TUT_PEAPOD_PODS", tr("TUT_PEAPOD_PODS_BODY") % int(Sim.POD_TIME)],
		[Diagram.Lesson.SHOP, "TUT_PEAPOD_SHOP", tr("TUT_PEAPOD_SHOP_BODY")],
		[Diagram.Lesson.SPECIAL, "TUT_PEAPOD_SPECIAL", tr("TUT_PEAPOD_SPECIAL_BODY")],
		[Diagram.Lesson.MILLI, "TUT_PEAPOD_MILLI", tr("TUT_PEAPOD_MILLI_BODY")],
		[Diagram.Lesson.HUD, "TUT_PEAPOD_HUD", tr("TUT_PEAPOD_HUD_BODY")],
	]
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func _ready() -> void:
	add_to_group("versus_host")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	_build()
	settings_sheet = SettingsSheet.new(false)
	settings_sheet.name = "SettingsSheet"
	add_child(settings_sheet)
	tutor = ScreenTutor.new(self, puzzle_id(), "Peapod", _tutor_hold)
	tutor.wire(top_bar, settings_sheet)
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _apply_insets())
	top_bar.enter(0.0)
	# before the boost card, so the bar behind it is already this game's
	top_bar.refresh(self)
	_ask(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if sim != null and not sim.is_over() and _end == null and _shop == null:
			_pause(true)

# --- building ---

func _build() -> void:
	var page := ColorRect.new()
	page.color = Pal.PAPER
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	_backdrop = Vistas.board_plate(GAME, Pal.LEAF_DEEP)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(_backdrop)
	_hedge = Control.new()
	_hedge.name = "Hedge"
	_hedge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hedge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hedge.draw.connect(_draw_hedge)
	add_child(_hedge)

	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margins)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	_margins.add_child(col)

	top_bar = FlatTopBar.new("Peapod", tr("PEAPOD_MOTTO"), true)
	top_bar.name = "TopBar"
	top_bar.back.connect(_on_back)
	top_bar.reset.connect(_on_reset)
	top_bar.settings.connect(func() -> void:
		_pause(true)
		settings_sheet.open())
	col.add_child(top_bar)
	col.add_child(_build_hud())

	_frame = PanelContainer.new()
	_frame.name = "Frame"
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# the flat boards' card (ui/flat/flat_host.gd): parchment, a hairline, a
	# soft shadow
	var box := CozyTheme.lifted(Pal.PARCHMENT, 36, FRAME)
	box.set_border_width_all(2)
	box.border_color = Color(Pal.LINE, 0.35)
	_frame.add_theme_stylebox_override("panel", box)
	_frame.resized.connect(func() -> void: _hedge.queue_redraw())
	col.add_child(_frame)
	field = Control.new()
	field.name = "Field"
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.draw.connect(_draw_field)
	field.resized.connect(_layout_field)
	field.gui_input.connect(_on_field_input)
	_frame.add_child(field)
	# the sun in the garden's sky, under everything that moves: it watches
	# the cart, beams through a streak and frets as the line is neared
	_sun = SunFace.new()
	_sun.name = "Sun"
	_sun.shadowless = true
	field.add_child(_sun)
	_sun.set_idle(true)
	_over = Control.new()
	_over.name = "Over"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	field.add_child(_over)
	_fx = Fx2D.new()
	_fx.haptics = HAPTICS
	field.add_child(_fx)
	_quiet = Fx2D.new()
	_quiet.buzzes = false
	field.add_child(_quiet)

	# the line under a banner, on a paper pill (Posy's)
	_sub_pill = PanelContainer.new()
	_sub_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := CozyTheme.lifted(Color("fffaf0", 0.96), 34, 18)
	pill.content_margin_left = 30
	pill.content_margin_right = 30
	_sub_pill.add_theme_stylebox_override("panel", pill)
	field.add_child(_sub_pill)
	_sub = Label.new()
	_sub.theme_type_variation = "SheetBody"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", Art.INK)
	_sub_pill.add_child(_sub)
	_sub_pill.modulate.a = 0.0
	_orb_layer = Control.new()
	_orb_layer.name = "Orbs"
	_orb_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_orb_layer.draw.connect(_draw_orbs)
	add_child(_orb_layer)
	_orb_light = Control.new()
	_orb_light.name = "OrbLight"
	_orb_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb_light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_orb_light.material = add
	_orb_light.draw.connect(_draw_orb_light)
	_orb_layer.add_child(_orb_light)
	_rw = Rewards.new()
	_rw.sticker_cols = STICKER_COLS
	add_child(_rw)
	_apply_insets()

func _build_hud() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = HUD_H
	row.add_theme_constant_override("separation", 16)
	var made := []
	for key in ["FF_SCORE", "FF_BEST", "PP_WAVE", "PP_ENERGY"]:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.size_flags_stretch_ratio = 1.25 if key == "FF_SCORE" else 1.0
		plate.add_theme_stylebox_override("panel", CozyTheme.lifted(Color("fcf7ef"), 30, 8))
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", -6)
		plate.add_child(words)
		var kicker := Label.new()
		kicker.text = key
		kicker.theme_type_variation = "MenuKicker"
		kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(kicker)
		var value := Label.new()
		value.text = "0"
		value.theme_type_variation = "SheetTitle"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(value)
		row.add_child(plate)
		made.append(value)
	_score_l = made[0]
	_best_l = made[1]
	_wave_l = made[2]
	_energy_l = made[3]
	_wave_l.text = "1"
	return row

func _apply_insets() -> void:
	var insets := SafeArea.insets(self)
	_margins.add_theme_constant_override("margin_left", MARGIN)
	_margins.add_theme_constant_override("margin_right", MARGIN)
	_margins.add_theme_constant_override("margin_top", MARGIN + int(insets.x))
	_margins.add_theme_constant_override("margin_bottom", MARGIN + int(insets.y))
	_backdrop.offset_bottom = MARGIN + insets.x + FlatTopBar.HEIGHT + GAP + HUD_H + BACKDROP_BLEED
	Vistas.set_top_pad(_backdrop, insets.x)

## The garden is scaled to the room and stood on its bottom edge: a phone is
## taller than the field, and the extra is sky the crates come down through.
func _layout_field() -> void:
	var s := field.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	_fit(s)
	if sim != null:
		sim.sky = _sky()
	_scene = _build_scene()
	_land = _build_land()
	_casts.clear()
	_dashes = _build_dashes()
	_chips = _build_chips()
	_text_fs = int(12.0 * _u)
	if _sun != null:
		var side := 58.0 * _u
		_sun.size = Vector2(side, side)
		_sun.position = _sun_at() - _sun.size * 0.5
	if _hedge != null:
		_hedge.queue_redraw()
	_redraw_all()

## The field's unit and origin in a room `s` (a tutorial page stands a slice
## of the garden in its own: ui/hud/peapod_tutorial_diagram.gd).
## The garden stands beside the gifts' rack, which has the strip on its left.
func _fit(s: Vector2) -> void:
	var wide := Sim.W + RACK_W
	_u = minf(s.x / wide, s.y / Sim.H)
	_origin = Vector2((s.x - wide * _u) * 0.5 + RACK_W * _u, s.y - Sim.H * _u)

## The garden's middle, `part` of the way down the field: where what is
## lettered over the garden stands (the rack is off to its left).
func _mid(part: float) -> Vector2:
	return Vector2(px(Vector2(Sim.W * 0.5, 0)).x, field.size.y * part)

static func _seven(v: Variant) -> Array:
	var a: Array = []
	a.resize(Sim.GIFTS)
	a.fill(v)
	return a

func px(p: Vector2) -> Vector2:
	return _origin + p * _u

## The sky over the field's top, in field units: the peas fly to the top of
## it (the sim's `sky`), not to where the field ends in mid air.
func _sky() -> float:
	return maxf(0.0, _origin.y / _u)

# --- the game ---

func _new_game() -> void:
	if _end != null:
		_end.queue_free()
		_end = null
	sim = Sim.new(-1, _cart)
	sim.sky = _sky()
	_stage_was = Record.best_stage(GAME)
	Boosters.apply(GAME, sim, _boosts)
	_boosted = not _boosts.is_empty()
	_chance_used = false
	_run_gold = 0
	_acc = 0.0
	_paused = false
	_touch = -1
	_mouse = false
	_hit_at.clear()
	_worn_of.clear()
	_sparks.clear()
	_pops.clear()
	_shot_at = -10.0
	_hit_heard = -10.0
	_last_x = sim.x
	_lean = 0.0
	_shake = 0.0
	_roll = 0.0
	_beat_best = false
	_heat = 0.0
	_alarm = 0.0
	_flash = 0.0
	_end_score = null
	_ghosts.clear()
	_flights.clear()
	_chip_at.clear()
	_clear_rack()
	_streak_n = 0
	_streak_in = 0.0
	_pair_in = 0.0
	_wave_peak = 0.0
	_clear = {}
	_blooms.clear()
	_hop = {}
	_crown_at = -1.0
	_hold_t = 0.0
	_nums.clear()
	_crumbs.clear()
	_bolts.clear()
	_puffs.clear()
	_land_orbs()
	_shown_energy = -1
	if _shop != null:
		_shop.queue_free()
		_shop = null
		_shop_rows.clear()
	if _sun != null:
		_sun.hat = 0.0
	_rw.clear()
	_best = Record.best(GAME)
	_shown_score = -1
	_started_at = Time.get_ticks_msec()
	if _pause_card != null:
		_pause_card.queue_free()
		_pause_card = null
	_refresh_hud()
	top_bar.refresh(self)
	_fx.cue("start")
	Analytics.track("arcade_start", {"game": GAME, "boosts": ",".join(_boosts), "cart": _cart})

func capabilities() -> Array:
	return []

func is_done() -> bool:
	return sim != null and sim.is_over()

func is_solved() -> bool:
	return false

func can_undo() -> bool:
	return false

func hints_left() -> int:
	return 0

func _process(delta: float) -> void:
	if sim == null:
		return
	if not _paused:
		var d := delta * _pace(delta)
		_clock += d
		_keys()
		_acc += minf(d, Sim.DT * MAX_STEPS)
		while _acc >= Sim.DT:
			_acc -= Sim.DT
			sim.step()
			_play_events()
		_animate(d)
	_refresh_hud(delta)
	_knock_now()
	if _seat != null and is_instance_valid(_seat):
		_seat.queue_redraw()
	if _end_score != null and is_instance_valid(_end_score):
		_count_end()
	_redraw_all()

## How fast the run goes this frame: slowed for the beat a big moment is
## held, and eased back out of it.
func _pace(delta: float) -> float:
	if _hold_t <= 0.0:
		return 1.0
	_hold_t -= delta
	return lerpf(1.0, _hold_k, clampf(_hold_t / 0.1, 0.0, 1.0))

## Holds the run at `pace` of its speed for `seconds`: a big moment's beat.
func _hold(seconds: float, pace: float) -> void:
	if Motion.reduce:
		return
	_hold_t = maxf(_hold_t, seconds)
	_hold_k = pace

## Asks for a knock this frame; the strongest asked for is the one played.
func _feel(kind: int) -> void:
	_knock = maxi(_knock, kind)

func _knock_now() -> void:
	if _knock >= 0:
		_fx.buzz(_knock)
		_knock = -1

func _redraw_all() -> void:
	field.queue_redraw()
	_over.queue_redraw()
	if _orb_layer != null:
		_orb_layer.queue_redraw()
		_orb_light.queue_redraw()

func _animate(delta: float) -> void:
	for sp: Dictionary in _sparks:
		sp.t += delta
	_sparks = _sparks.filter(func(sp: Dictionary) -> bool: return sp.t < 0.22)
	for p: Dictionary in _pops:
		p.t += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p.t < 0.8)
	if not _nums.is_empty():
		for n: Dictionary in _nums:
			n.t += delta
		_nums = _nums.filter(func(n: Dictionary) -> bool: return n.t < NUM_T)
	if not _crumbs.is_empty():
		for c: Dictionary in _crumbs:
			c.t += delta
			c.vel += Vector2(0, 520.0 * delta)
			c.pos += c.vel * delta
		_crumbs = _crumbs.filter(func(c: Dictionary) -> bool: return c.t < CRUMB_T)
	if not _bolts.is_empty():
		for bo: Dictionary in _bolts:
			bo.t += delta
		_bolts = _bolts.filter(func(bo: Dictionary) -> bool: return bo.t < BOLT_T)
	if not _puffs.is_empty():
		for pf: Dictionary in _puffs:
			pf.t += delta
		_puffs = _puffs.filter(func(pf: Dictionary) -> bool: return pf.t < PUFF_T)
	_step_orbs(delta)
	if _hit_at.size() > 240:
		_hit_at.clear()
		_worn_of.clear()
	# the wheels turn as far as the cart rolled, and it leans into the roll
	var moved: float = sim.x - _last_x
	_last_x = sim.x
	_wheel += moved / 9.0
	var want_lean := 0.0 if Motion.reduce else clampf(moved / maxf(delta, 0.001) / 900.0, -1.0, 1.0) * 0.12
	_lean = lerpf(_lean, want_lean, minf(1.0, delta * 14.0))
	_shake = maxf(0.0, _shake - delta * 3.0)
	if _shake > 0.0 and not Motion.reduce:
		var amp := 12.0 * _shake * _shake
		_shake_off = Vector2(sin(_clock * 71.0), cos(_clock * 57.0)) * amp
	else:
		_shake_off = Vector2.ZERO
	_rw.bounds = Rect2(_rw.at(field, Vector2.ZERO), field.size)
	_rw.step(delta)
	var playing: bool = sim.phase == Sim.Phase.PLAY
	var want := clampf((sim.streak - 6) / 30.0, 0.0, 1.0) if playing else 0.0
	_heat = move_toward(_heat, want, delta * (1.5 if want > _heat else 0.8))
	_alarm = move_toward(_alarm, sim.danger(), delta * 2.0)
	_flash = maxf(0.0, _flash - delta * 2.6)
	for g: Dictionary in _ghosts:
		g.t += delta
	_ghosts = _ghosts.filter(func(g: Dictionary) -> bool: return g.t < GHOST_T)
	_step_flights(delta)
	_step_dress(delta)
	# the streak's pill: in while a streak of five or more runs, out after
	var live: bool = playing and sim.streak >= STREAK_FROM
	if live:
		if sim.streak > _streak_n:
			_streak_at = _clock
		_streak_n = sim.streak
	_streak_in = move_toward(_streak_in, 1.0 if live else 0.0, delta * (7.0 if live else 3.0))
	# the pods' pill: in while two pods or more run together
	var pods: int = sim.pods_on() if playing else 0
	if pods >= 2:
		_pair_n = pods
	_pair_in = move_toward(_pair_in, 1.0 if pods >= 2 else 0.0, delta * (7.0 if pods >= 2 else 3.0))
	_wave_peak = maxf(_wave_peak, sim.danger())
	_step_clear()
	# a puff off the wheels of a cart rolled hard
	if not Motion.reduce and absf(moved) > 6.0 * delta * 60.0 and _clock - _dust_at > 0.09:
		_dust_at = _clock
		_rw.spray(_in_rw(Vector2(sim.x - signf(moved) * 15.0, TURF - 2.0)), Color("fffaf0", 0.9), 1, 90.0, "mote", 0.7)
	_mood_sun()

## The sun's face: worried as the line is neared and at the end, beaming
## through a streak and a cleared wave; its eyes follow the cart.
func _mood_sun() -> void:
	if _sun == null:
		return
	var want: int = Face.Expr.HAPPY
	if sim.is_over() or _alarm > 0.35:
		want = Face.Expr.WORRIED
	elif _heat > 0.25 or not _clear.is_empty():
		want = Face.Expr.JOY
	if _sun.expression != want:
		_sun.expression = want
	var to := px(Vector2(sim.x, Sim.CART_Y)).x - (_sun.position.x + _sun.size.x * 0.5)
	var look := Vector2(signf(to) if absf(to) > field.size.x * 0.15 else 0.0, 1.0)
	if _sun.look != look:
		_sun.look = look

## The gifts in the air: one had lands on its button with a bump, one
## started is swallowed by the pod.
func _step_flights(delta: float) -> void:
	if _flights.is_empty():
		return
	for f: Dictionary in _flights:
		f.t += delta
		if f.t >= float(f.time):
			var kind: int = f.kind
			if f.used:
				_gulp(kind)
			else:
				_chip_at[kind] = _clock
				_quiet.cue("hit", 1.25, -7.0)
				_rw.ring(_rw.at(field, _rack_px(kind) + _shake_off), 15.0 * _u, Color(Art.GIFT[kind], 0.9), 0.0, 0.3)
	_flights = _flights.filter(func(f: Dictionary) -> bool: return f.t < float(f.time))

## Where a flight ends: a gift had goes to its button, a gift started to the
## pod's mouth, wherever the cart is by then.
func _flight_home(f: Dictionary) -> Vector2:
	return _mouth_px() if f.used else _rack_px(int(f.kind))

func _mouth_px() -> Vector2:
	return px(Vector2(sim.x, Sim.CART_Y - 38.0))

## A gift started has reached the pod's mouth: the pod swallows it and
## swells, a ring and stars off its mouth in the gift's colour, and from now
## it wears what the gift is.
func _gulp(kind: int) -> void:
	_gulp_at = _clock
	var col: Color = Art.GIFT[kind]
	var mouth := _in_rw(Vector2(sim.x, Sim.CART_Y - 40.0))
	_quiet.cue("hit", 0.8, -5.0)
	_rw.ring(mouth, 30.0 * _u, Color(col, 0.9), 0.0, 0.3)
	_rw.spray(mouth, col.lightened(0.2), 7, 520.0, "star", 0.8)
	_rw.spray(mouth, Color("fffaf0"), 5, 460.0, "spark", 0.9)

## The swallow, 1 as the gift goes in and ringing down to 0: the pod goes
## wide and short and springs back.
func _gulp_now() -> float:
	var since := _clock - _gulp_at
	if since > 0.5 or Motion.reduce:
		return 0.0
	return exp(-since * 8.0) * cos(since * 26.0)

## The pod's dressings come out as their gift reaches it and go as it runs
## out, and the pod is painted the element that has reached it.
func _step_dress(delta: float) -> void:
	for k in _dress.size():
		var kind: int = Sim.Kind.FAN + k
		var on: bool = sim.has_shape(kind) and _clock >= float(_looks_at.get(kind, -10.0))
		if Motion.reduce:
			_dress[k] = 1.0 if on else 0.0
		else:
			_dress[k] = move_toward(float(_dress[k]), 1.0 if on else 0.0, delta * (4.0 if on else 6.0))
	if sim.element == 0 or _clock >= float(_looks_at.get(sim.element, -10.0)):
		_pod_el = sim.element

## A thing on the grass swells as a gift lands on it and settles.
func _bump(kind: int) -> float:
	var since: float = _clock - float(_chip_at.get(kind, -10.0))
	if since > 0.5 or Motion.reduce:
		return 1.0
	return 1.0 + 0.28 * exp(-since * 9.0) * cos(since * 22.0)

## The stamping of a cleared wave: its stars one at a time, each a note
## higher, and a flower up out of the grass for each.
func _step_clear() -> void:
	if _clear.is_empty():
		return
	var since: float = _clock - float(_clear.at)
	while int(_clear.said) < int(_clear.stars) and since >= 0.35 + STAR_STEP * int(_clear.said):
		var k: int = _clear.said
		_clear.said = k + 1
		_fx.cue("catch", 1.0 + 0.14 * k, -3.0)
		_feel(Haptics.TICK)
		var at := _rw.at(field, _star_at(k) + _shake_off)
		_rw.spray(at, Pal.SUN, 6, 420.0, "star", 0.8)
		_rw.ring(at, 26.0 * _u, Color(Pal.SUN, 0.8))
		_bloom()
	if since > 1.5:
		_clear = {}

func _star_at(k: int) -> Vector2:
	return _mid(0.3) + Vector2((k - 1) * 36.0, 78.0) * _u

## A flower comes up somewhere along the grass, clear of the others.
func _bloom() -> void:
	if _blooms.size() >= MAX_BLOOMS:
		return
	var x := 0.0
	for attempt in 12:
		x = randf_range(10.0, Sim.W - 10.0)
		var free := true
		for bl: Dictionary in _blooms:
			if absf(float(bl.x) - x) < 9.0:
				free = false
				break
		if free:
			break
	var look := randi() % Art.BLOOM.size()
	_blooms.append({"x": x, "y": randf_range(1.0, 5.0), "look": look, "at": _clock, "size": randf_range(0.85, 1.15)})
	_rw.spray(_in_rw(Vector2(x, TURF - 8.0)), Art.BLOOM[look][0], 5, 260.0, "confetti", 0.7)

func _keys() -> void:
	var axis := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		axis -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		axis += 1.0
	sim.axis = axis
	for k in Sim.GIFTS:
		var down := Input.is_key_pressed(KEY_0 if k == 9 else KEY_1 + k)
		if down and not _rack_key[k]:
			_press_gift(Sim.Kind.FAN + k)
		_rack_key[k] = down

func _on_field_input(event: InputEvent) -> void:
	if _paused:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			if _end == null and not settings_sheet.is_open():
				_pause(false)
		return
	if sim == null:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _rack_hit(t.position) >= 0:
			# a button's press is not the cart's, whichever finger it is
			_press_gift(_rack_hit(t.position))
		elif t.pressed and _touch == -1:
			_touch = t.index
			_grab(t.position)
		elif not t.pressed and t.index == _touch:
			_touch = -1
			sim.target_x = NAN
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch:
			_slide(d.position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		if m.pressed and _rack_hit(m.position) >= 0:
			_press_gift(_rack_hit(m.position))
			return
		_mouse = m.pressed and _touch == -1
		if _mouse:
			_grab(m.position)
		elif _touch == -1:
			sim.target_x = NAN
	elif event is InputEventMouseMotion and _mouse:
		_slide((event as InputEventMouseMotion).position)

func _grab(at: Vector2) -> void:
	_touch_from = at
	_cart_from = sim.x
	sim.target_x = sim.x

## A slide, not a spot: the cart moves as far as the finger did, and a
## little more.
func _slide(at: Vector2) -> void:
	sim.target_x = _cart_from + (at.x - _touch_from.x) / _u * GAIN
	# A slide past the wall re-anchors, so coming back moves at once.
	var lo := Sim.CART_HALF
	var hi := Sim.W - lo
	if sim.target_x < lo or sim.target_x > hi:
		sim.target_x = clampf(sim.target_x, lo, hi)
		_touch_from = at
		_cart_from = sim.target_x

# --- the rack ---

func _clear_rack() -> void:
	_rack_at = _seven(-10.0)
	_rack_no = _seven(-10.0)
	_rack_frame = _seven(-1)
	_dress = [0.0, 0.0, 0.0]
	_looks_at.clear()
	_pod_el = 0
	_gulp_at = -10.0

## Whether the rack stands in this garden (a tutorial page with no gift on
## it has none).
func _rack_on() -> bool:
	return true

## The middle of the rack's strip, in field units: left of the garden, away
## from the thumb that slides the cart.
func _rack_x() -> float:
	return -RACK_W * 0.5

## The step from one button down to the next (a tutorial page's slice is
## shorter than ten of them, and closes them up).
func _rack_step() -> float:
	return RACK_STEP

## Where gift `kind`'s button is: the ten one under another, the Fan at the
## top (the shapes, then the five elements) and the frost and the shove at
## the foot, nearest the thumb.
func _rack_px(kind: int) -> Vector2:
	return px(Vector2(_rack_x(), Sim.H - RACK_FOOT - _rack_step() * (Sim.Kind.SHOVE - kind)))

## The gift whose button a press at `at` (the field's pixels) is on, -1 for
## none: the whole of the strip beside each button, and a little of the
## garden's side.
func _rack_hit(at: Vector2) -> int:
	if sim == null or not _rack_on():
		return -1
	var top := _rack_px(Sim.Kind.FAN).y - _rack_step() * 0.5 * _u
	if at.x > px(Vector2(_rack_x() + RACK_W * 0.5 + RACK_REACH, 0)).x or at.y < top:
		return -1
	return Sim.Kind.FAN + clampi(int((at.y - top) / (_rack_step() * _u)), 0, Sim.GIFTS - 1)

## A press on gift `kind`'s button: one of it starts, or (none had, or no
## wave on to use it against) the button shakes its head.
func _press_gift(kind: int) -> void:
	if sim == null or _paused or not Sim.holds_gift(kind):
		return
	var k := kind - Sim.Kind.FAN
	var frame := Engine.get_process_frames()
	if frame == int(_rack_frame[k]):
		return
	_rack_frame[k] = frame
	if sim.use(kind):
		_rack_at[k] = _clock
	else:
		_rack_no[k] = _clock
		_feel(Haptics.TICK)

## How far down button `k` is, 1 just pressed to 0, and its shake when it
## refuses.
func _rack_down(k: int) -> float:
	return clampf(1.0 - (_clock - float(_rack_at[k])) / RACK_PRESS, 0.0, 1.0)

func _rack_shift(k: int) -> Vector2:
	var off := Vector2(0, 1.8 * _u * _rack_down(k))
	var since: float = _clock - float(_rack_no[k])
	if since < RACK_NO and not Motion.reduce:
		off.x += sin(since * 42.0) * 2.4 * _u * (1.0 - since / RACK_NO)
	return off

## The part of gift `kind`'s time that is left, 0 when it is not running
## (the shove never is: it is done at once).
func _running(kind: int) -> float:
	if Sim.is_shape(kind):
		return float(sim.shape_t[kind - Sim.Kind.FAN]) / Sim.POD_TIME
	if Sim.is_element(kind):
		return sim.element_t / Sim.POD_TIME if sim.element == kind else 0.0
	if kind == Sim.Kind.FROST:
		return sim.frost_t / Sim.FROST_TIME
	return 0.0

## How many of gift `kind` its button shows: what is had, less any still on
## its way from its crate.
func _counted(kind: int) -> int:
	var n: int = sim.has(kind)
	for f: Dictionary in _flights:
		if int(f.kind) == kind and not f.used:
			n -= 1
	return maxi(0, n)

## The rack's strip, built with the land: a pale paper shelf down the
## garden's left side, from over the highest button to the field's foot.
func _build_rail(b: Face.Builder) -> void:
	if not _rack_on():
		return
	var first := _rack_px(Sim.Kind.FAN)
	var w := (RACK_W - 2.6) * _u
	var at := Vector2(first.x - w * 0.5, first.y - (_rack_step() * 0.5 + 2.0) * _u)
	var size := Vector2(w, px(Vector2(0, Sim.H - 2.4)).y - at.y)
	b.fan(Face.Builder.round_rect(at + Vector2(0, 2.0 * _u), size, w * 0.5), Color(0.2, 0.32, 0.1, 0.12))
	b.fan(Face.Builder.round_rect(at, size, w * 0.5), Color(Art.PAPER, 0.55))

## Under each button: its shadow, a paper seat that goes down and darker
## under a press, and round the seat's rim the time its gift has left.
func _draw_rack_seats(b: Face.Builder) -> void:
	if not _rack_on():
		return
	var r := RACK_R * _u
	for k in Sim.GIFTS:
		var kind: int = Sim.Kind.FAN + k
		var c := _rack_px(kind)
		b.disc(c + Vector2(0, 2.4 * _u), r, Color(0.2, 0.32, 0.1, 0.24))
		c += _rack_shift(k)
		b.disc(c, r, Art.CREAM.darkened(0.1 * _rack_down(k)))
		var part := clampf(_running(kind), 0.0, 1.0)
		if part > 0.0:
			b.stroke(Face.Builder.arc_points(c, r - 1.0 * _u, -PI * 0.5, -PI * 0.5 + TAU * part), 2.3 * _u, Art.deepen(Art.GIFT[kind]), false, false)

## On each seat its gift: breathing while one can be started, whole while it
## runs (blinking as it runs out), pale with none had.
func _draw_rack_tokens() -> void:
	if not _rack_on():
		return
	for k in Sim.GIFTS:
		var kind: int = Sim.Kind.FAN + k
		var had := _counted(kind) > 0
		var ready: bool = had and sim.can_use(kind)
		var left := _running(kind)
		var sc := _bump(kind)
		if ready and not Motion.reduce:
			sc *= 1.0 + 0.04 * sin(_clock * 4.2 + k * 1.7)
		var a := 1.0 if ready or left > 0.0 else (0.62 if had else 0.34)
		if left > 0.0 and left < 0.2 and fmod(_clock, 0.3) < 0.12 and not Motion.reduce:
			a = 0.45
		_cast_add(Art.button(kind, _u), Transform2D(0.0, Vector2(sc, sc), 0.0, _rack_px(kind) + _rack_shift(k)), Color(1, 1, 1, a))

## Where button `k`'s count is lettered: on a pip at its corner, the
## garden's side.
func _pip_px(kind: int) -> Vector2:
	return _rack_px(kind) + _rack_shift(kind - Sim.Kind.FAN) + Vector2(8.2, 8.0) * _u

## The pips, over the gifts: a draw of their own, every frame.
func _draw_rack_pips() -> void:
	if _rack_on():
		for k in Sim.GIFTS:
			var kind: int = Sim.Kind.FAN + k
			_cast_add(Art.pip(_u), Transform2D(0.0, _pip_px(kind)), Color(1, 1, 1, 1.0 if _counted(kind) > 0 else 0.7))
	_cast_draw()

## How many of each gift are had, in ink on its pip: a nought with none.
func _draw_rack_counts(font: Font) -> void:
	if not _rack_on():
		return
	var fs := int(8.8 * _u)
	for k in Sim.GIFTS:
		var kind: int = Sim.Kind.FAN + k
		var n := _counted(kind)
		var text := str(mini(n, 99))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := _pip_px(kind)
		var ink := Color(Art.INK, 1.0 if n > 0 else 0.4)
		var sc := _bump(kind)
		if sc != 1.0:
			_over.draw_set_transform(_shake_off + at, 0.0, Vector2(sc, sc))
			_over.draw_string(font, Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
			_over.draw_set_transform(_shake_off)
		else:
			_over.draw_string(font, at + Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

## The tutorial card stops the run and leaves it paused, a tap from going on.
func _tutor_hold(on: bool) -> void:
	if on and sim != null and not sim.is_over() and _end == null:
		_pause(true)

func _pause(on: bool) -> void:
	if on == _paused:
		return
	_paused = on
	if on:
		_touch = -1
		_mouse = false
		if sim != null:
			sim.target_x = NAN
		_pause_card = _build_pause()
		field.add_child(_pause_card)
		Motion.appear(_pause_card, 0.0, 1.0, 0.2)
	elif _pause_card != null:
		_pause_card.queue_free()
		_pause_card = null

func _build_pause() -> Control:
	var scrim := ColorRect.new()
	scrim.color = Color(0.16, 0.12, 0.06, 0.5)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.add_child(col)
	var head := Label.new()
	head.text = "FF_PAUSED"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", Color("fffaf0"))
	col.add_child(head)
	var line := Label.new()
	line.text = "FF_RESUME"
	line.theme_type_variation = "SheetTitle"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_color_override("font_color", Color("fffaf0"))
	col.add_child(line)
	return scrim

# --- events ---

## The pitch a pea lands at on a crate or a plate with `hp` left.
func _hit_pitch(hp: int) -> float:
	var note: int = HIT_NOTES[mini(Art.tier_of(hp), HIT_NOTES.size() - 1)]
	return pow(2.0, note / 12.0) * randf_range(1.0 - HIT_DRIFT, 1.0 + HIT_DRIFT)

func _play_events() -> void:
	for ev: Dictionary in sim.events:
		var pos: Vector2 = ev.get("pos", Vector2.ZERO)
		match String(ev.type):
			"ready":
				_show_banner(tr("PP_READY"), tr("PP_READY_LINE"), 1.0)
			"go":
				_fx.cue("go")
			"wave":
				_wave_peak = 0.0
				var milli: bool = ev.kind == Sim.Wave.MILLI
				if int(ev.wave) > 1:
					_show_banner(tr("PP_WAVE_N") % int(ev.wave), tr("PP_MILLI_LINE") if milli else "", 0.7)
					_fx.cue("milli" if milli else "wave")
				_wave_l.pivot_offset = _wave_l.size * 0.5
				_beat(_wave_l, 0.3, 0.35)
			"shot":
				_shot_at = _clock
				if _clock - _shot_heard >= SHOT_GAP:
					_shot_heard = _clock
					_quiet.cue("shot", randf_range(0.94, 1.08), -4.0)
			"hit":
				_hit_at[ev.id] = _clock
				# a light shot now and then takes nothing off: no number for it
				if int(ev.dmg) > 0:
					_number(ev)
				_chip(ev)
				# the pea that breaks a thing is heard and seen as the break
				if not ev.quiet and int(ev.hp) > 0:
					_spark(pos, Art.colour(ev.kind, 1).lerp(Color("fffaf0"), 0.6) if Sim.holds_gift(ev.kind) else Color("fffaf0"))
					_crumb(pos)
					if _clock - _hit_heard >= HIT_GAP:
						_hit_heard = _clock
						_quiet.cue("clank" if ev.kind == Sim.Kind.IRON else "hit", _hit_pitch(int(ev.hp)), -6.0 - randf() * HIT_SOFT)
			"kill":
				_on_kill(ev)
			"gift":
				_on_gift(ev)
			"use":
				_on_use(ev)
			"zap":
				if _bolts.size() >= MAX_BOLTS:
					_bolts.pop_front()
				_bolts.append({"pts": ev.pts, "t": 0.0})
			"flare":
				_on_flare(pos)
			"blast":
				_on_blast(pos, float(ev.r))
			"gust":
				if not Motion.reduce:
					if _puffs.size() >= MAX_PUFFS:
						_puffs.pop_front()
					_puffs.append({"pos": pos + Vector2(randf_range(-8.0, 8.0), randf_range(-12.0, -2.0)), "t": 0.0, "way": 1.0 if randf() < 0.5 else -1.0})
			"shop":
				_open_shop()
			"boom":
				_fx.cue("boom")
				_feel(Haptics.THUD)
				_shake = maxf(_shake, 0.7)
				_hold(0.07, 0.4)
				_flash_now(Color("ffd65c"), 0.4)
				_rw.ring(_in_rw(pos), 78.0 * _u, Color("ffd65c", 0.95))
				_rw.ring(_in_rw(pos), 52.0 * _u, Color("fffaf0", 0.9), 0.06)
				_rw.spray(_in_rw(pos), Art.CRACKER, 12, 760.0, "shard", 1.0)
				_rw.spray(_in_rw(pos), Color("ffd65c"), 10, 820.0, "spark", 1.3)
				_rw.sticker(tr("PP_BOOM"), _in_rw(pos + Vector2(0, -26.0)), 60, 0.9, false, Color("ffd65c"), false, "boom", 30.0)
			"knock":
				_fx.cue("knock", randf_range(0.95, 1.08), -4.0)
			"pod_off":
				_fx.cue("twin_off", 1.25, -8.0)
			"clear":
				_on_clear(ev)
			"warn":
				_fx.cue("warn")
				_feel(Haptics.WARN)
				_rw.sticker(tr("PP_CAREFUL"), _rw.at(field, _mid(0.52)), 62, 1.1, false, ALARM, false, "warn")
			"over":
				_fx.cue("over")
				_feel(Haptics.LOSE)
				_shake = maxf(_shake, 0.9)
				_hold(0.4, 0.3)
				_flash_now(ALARM, 0.5)
				_game_over()
			"revive":
				_flash_now(Color("fffaf0"), 0.5)
				_rw.ring(_in_rw(Vector2(sim.x, Sim.CART_Y)), 160.0 * _u, Color(Pal.SUN, 0.9))
	sim.events.clear()

## A thing that went while alight bursts: a ring of fire out to what is next
## to it, embers thrown, a soft thump (one a THUMP_GAP at most: a wall going
## up is a dozen of these on each other's heels).
func _on_flare(pos: Vector2) -> void:
	var at := _in_rw(pos)
	_rw.ring(at, 50.0 * _u, Color(Art.EMBER, 0.9), 0.0, 0.26)
	_rw.ring(at, 30.0 * _u, Color(Art.BOLT, 0.85), 0.03, 0.2)
	_rw.spray(at, Art.EMBER, 5, 520.0, "spark", 0.9)
	_rw.spray(at, Art.FIRE, 3, 380.0, "mote", 0.8)
	_spark(pos, Art.BOLT)
	_shake = maxf(_shake, 0.16)
	if _clock - _thump_at >= THUMP_GAP:
		_thump_at = _clock
		_quiet.cue("knock", randf_range(0.72, 0.82), -9.0)

## A shell has landed: a ring out as far as its blast reaches, and dust.
func _on_blast(pos: Vector2, reach: float) -> void:
	var at := _in_rw(pos)
	_rw.ring(at, reach * _u, Color(Art.PUMPKIN.lerp(Art.PAPER, 0.35), 0.9), 0.0, 0.24)
	_rw.ring(at, reach * 0.6 * _u, Color(Art.PAPER, 0.8), 0.03, 0.18)
	_rw.spray(at, Art.PUMPKIN, 4, 460.0, "shard", 0.8 * _u / 2.4)
	_rw.spray(at, Art.PAPER, 3, 320.0, "mote", 0.8)
	_shake = maxf(_shake, 0.2)
	if _clock - _thump_at >= THUMP_GAP:
		_thump_at = _clock
		_quiet.cue("knock", randf_range(0.6, 0.68), -6.0)

func _spark(at: Vector2, col: Color) -> void:
	if _sparks.size() < MAX_SPARKS:
		_sparks.append({"pos": at, "t": 0.0, "col": col, "turn": randf() * TAU})

## A crate or a plate gone: chips of its paint, its number rising, and by
## what it was a golden shower, a head's end, or the streak's word.
func _on_kill(ev: Dictionary) -> void:
	var pos: Vector2 = ev.pos
	var kind: int = ev.kind
	var col := Art.colour(kind, int(ev.max))
	var at := _in_rw(pos)
	var k := _u / 2.4
	var popped: bool = ev.popped
	var head := kind == Sim.Kind.HEAD
	var round: bool = head or sim.wave_kind == Sim.Wave.MILLI
	_ghosts.append({"pos": pos, "round": round, "col": col.lerp(Color("fffaf0"), 0.45), "t": 0.0, "big": head})
	_rw.spray(at, col, 3 if popped else 6, 460.0, "shard", 0.9 * k)
	_rw.spray(at, Color("fffaf0"), 2 if popped else 3, 400.0, "spark", 0.9 * k)
	_spark(pos, col.lightened(0.4))
	var gold := kind == Sim.Kind.GOLD
	if _pops.size() >= MAX_POPS:
		_pops.pop_front()
	_pops.append({"pos": pos, "text": "+" + Art.short(int(ev.points)), "t": 0.0, "col": Color("fff1c2") if gold or head else Color("fffaf0"),
		"rim": Art.GOLD_INK if gold else Art.deepen(col).darkened(0.3), "big": gold or head, "drift": randf_range(-1.0, 1.0)})
	_drop_orbs(pos, int(ev.energy))
	var streak: int = ev.streak
	if head:
		_fx.cue("head")
		_feel(Haptics.THUD)
		_shake = maxf(_shake, 0.6)
		_hold(0.2, 0.25)
		_flash_now(Color("fffaf0"), 0.4)
		_rw.sticker(tr("PP_SQUASHED"), _in_rw(pos + Vector2(0, -34.0)), 76, 1.3, true, Color.WHITE, true, "head", 30.0)
		_rw.ring(at, 90.0 * _u, Color(Pal.SUN, 0.9))
		_rw.spray(at, Art.HEAD, 12, 700.0, "shard", 1.1 * k)
		_rw.spray(at, Pal.SUN, 10, 760.0, "star", 1.0)
	elif gold:
		_fx.cue("pop_gold")
		_feel(Haptics.BUMP)
		_shake = maxf(_shake, 0.3)
		_flash_now(Art.GOLD, 0.3)
		_rw.spray(at, Art.GOLD, 14, 720.0, "coin", 1.0 * k)
		_rw.spray(at, Pal.SUN, 4, 520.0, "star", 0.8, 0.1, _plate_at(_score_l))
		_rw.ring(at, 44.0 * _u, Color(Art.GOLD, 0.9))
		_rw.sticker(tr("PP_GOLDEN"), _in_rw(pos + Vector2(0, -28.0)), 58, 1.1, true, Color.WHITE, true, "gold", 30.0)
	else:
		_fx.cue("pop", minf(1.25, 1.0 + 0.0125 * streak), -8.0 if popped else 0.0)
		_feel(Haptics.TICK if popped else Haptics.TAP)
		_shake = maxf(_shake, 0.12)
	for i in WORDS.size():
		if streak == int(WORDS[i][0]):
			var tier := WORDS.size() - 1 - i
			var mid := _rw.at(field, _mid(0.42))
			_rw.sticker(tr(WORDS[i][1]), mid, 72 + 8 * tier, 1.3 + 0.12 * tier, true, Color.WHITE, tier >= 1, "word", 24.0)
			_rw.spray(mid, Pal.SUN, 6 + 3 * tier, 760.0, "star", 1.0)
			_rw.spray(mid, STICKER_COLS[tier % STICKER_COLS.size()], 8 + 2 * tier, 700.0, "confetti", 1.0)
			_flash_now(Color("fffaf0"), 0.2 + 0.06 * tier)
			_fx.cue("word", 1.0 + 0.06 * tier)
			_feel(Haptics.BUMP)
			if tier >= 3:
				_rw.rain(1.6, ["confetti", "star"], STICKER_COLS)
			break

## A gift crate broken: what it held, lettered over where it was, and the
## gift itself off to its button on the rack, whose count goes up as it
## lands.
func _on_gift(ev: Dictionary) -> void:
	var kind: int = ev.kind
	var pos: Vector2 = ev.pos
	var at := _in_rw(pos)
	var col: Color = Art.GIFT[kind]
	_fx.cue("catch")
	_feel(Haptics.GOOD)
	_hop = {"at": _clock, "tall": 3.5, "time": 0.22, "twice": false}
	if not Motion.reduce:
		_flights.append({"kind": kind, "from": px(pos), "used": false, "t": 0.0, "time": FLIGHT_T})
	else:
		_chip_at[kind] = _clock
	_rw.sticker(tr(GOT[kind]), at + Vector2(0, -30.0), 58, 1.1, false, col.lightened(0.25), false, "got", 34.0)
	_rw.ring(at, 40.0 * _u, Color(col, 0.9))
	_rw.spray(at, col, 8, 520.0, "star", 0.9)
	_rw.spray(at, Color("fffaf0"), 6, 460.0, "spark", 1.0)

## A gift started from its button: its sound, a ring off the button, and the
## gift on its way to the pod's mouth, which swallows it (`_gulp`) and wears
## it from then (`_looks_at`). The shove is the whole garden's: a ring up
## off the cart.
func _on_use(ev: Dictionary) -> void:
	var kind: int = ev.kind
	var col: Color = Art.GIFT[kind]
	var from := _rack_px(kind)
	var at := _rw.at(field, from + _shake_off)
	_fx.cue(CATCH_CUE.get(kind, "catch"))
	_feel(Haptics.BUMP)
	if kind == Sim.Kind.SHOVE:
		_rw.ring(_in_rw(Vector2(Sim.W * 0.5, Sim.CART_Y - 60.0)), 200.0 * _u, Color(col, 0.9))
		_shake = maxf(_shake, 0.3)
	if not Motion.reduce:
		_flights.append({"kind": kind, "from": from, "used": true, "t": 0.0, "time": USE_T})
		_looks_at[kind] = _clock + USE_T
	_rw.ring(at, 30.0 * _u, Color(col, 0.9))
	_rw.spray(at, col, 6, 420.0, "star", 0.8)
	_flash_now(col, 0.16)

## What a pea landing took off, bounced off where it landed: a small hop to
## a side and down out of the way, and gone. A crit's is bigger and gold; a splash's, a
## firecracker's and a burn's are smaller and their own colour.
func _number(ev: Dictionary) -> void:
	if _nums.size() >= MAX_NUMS:
		_nums.pop_front()
	var lucky: bool = ev.crit
	var how: int = ev.how
	# a pea's falls away under what it hit, clear of the number that is on
	# it; any other's stands at the thing's corner
	var from: Vector2 = ev.pos + (Vector2(0, 8.0) if how == Sim.Hit.PEA else Vector2(15.0, -11.0))
	_nums.append({"pos": from, "text": Art.short(int(ev.dmg)) + ("!" if lucky else ""), "t": 0.0, "look": NUM_CRIT if lucky else how,
		"big": 2 if lucky else (1 if how == Sim.Hit.PEA else 0), "vx": randf_range(-34.0, 34.0), "fall": how == Sim.Hit.PEA})

## A hit that cracks a thing further (`Art.worn`) knocks chips of its paint
## off it, more of them the nearer it is to breaking.
func _chip(ev: Dictionary) -> void:
	var worn := Art.worn(int(ev.hp), int(ev.max))
	if int(ev.hp) <= 0 or worn <= int(_worn_of.get(ev.id, 0)):
		return
	_worn_of[ev.id] = worn
	var col := Art.colour(ev.kind, int(ev.hp))
	_rw.spray(_in_rw(ev.pos), col, 1 + worn, 300.0, "shard", 0.6 * _u / 2.4)
	_rw.spray(_in_rw(ev.pos), col.lerp(Color("fffaf0"), 0.6), worn, 240.0, "mote", 0.6)

## The pea itself, knocked off what it hit and tumbling down.
func _crumb(at: Vector2) -> void:
	if Motion.reduce:
		return
	if _crumbs.size() >= MAX_CRUMBS:
		_crumbs.pop_front()
	_crumbs.append({"pos": at, "vel": Vector2(randf_range(-80.0, 80.0), randf_range(-40.0, 30.0)), "t": 0.0})

## A wave cleared: lettered, its bonus under it, one to three stars stamped
## by how far off the line was kept (a flower for each: `_step_clear`), the
## cart hopping and the pod letting off a volley of its own, a short rain.
func _on_clear(ev: Dictionary) -> void:
	var mid := _rw.at(field, _mid(0.3))
	_fx.cue("clear")
	_feel(Haptics.BUMP)
	var stars := 3 if _wave_peak < float(STAR_PEAKS[0]) else (2 if _wave_peak < float(STAR_PEAKS[1]) else 1)
	_clear = {"at": _clock, "stars": stars, "said": 0}
	_hop = {"at": _clock, "tall": 11.0, "time": 0.7, "twice": true}
	_hold(0.16, 0.35)
	_rw.sticker(tr("PP_CLEARED"), mid, 78, 1.3, true, Color.WHITE, true, "clear", 0.0, true)
	_rw.sticker("+" + Record.grouped(int(ev.bonus)), mid + Vector2(0, 34.0 * _u), 46, 1.3, false, Pal.SUN, false, "clear_bonus", 0.0, true)
	_rw.spray(mid, Pal.SUN, 12, 780.0, "star", 1.0)
	_rw.spray(mid, Pal.SUN, 5, 520.0, "star", 0.8, 0.15, _plate_at(_score_l))
	var mouth := _in_rw(Vector2(sim.x, Sim.CART_Y - 46.0))
	for i in STICKER_COLS.size():
		_rw.spray(mouth, STICKER_COLS[i], 3, 900.0, "confetti", 0.9, 0.05 * i)
	_rw.rain(1.2, ["confetti", "star"], STICKER_COLS)
	_flash_now(Color("fffaf0"), 0.25)

## A banner: the word as a sticker, a letter hopping in at a time, and the
## line under it on a paper pill.
func _show_banner(text: String, sub: String, hold: float) -> void:
	var mid := _mid(0.36)
	_rw.sticker(text, _rw.at(field, mid), 92, hold + 0.75, true, Color.WHITE, false, "banner", 0.0, true)
	Motion.stop(_banner_tw)
	_sub.text = sub
	if sub == "":
		_sub_pill.modulate.a = 0.0
		return
	_sub_pill.reset_size()
	_sub_pill.position = Vector2((field.size.x - _sub_pill.size.x) * 0.5, mid.y + 60.0)
	_sub_pill.pivot_offset = _sub_pill.size * 0.5
	_banner_tw = create_tween()
	if Motion.reduce:
		_sub_pill.scale = Vector2.ONE
		_banner_tw.tween_property(_sub_pill, "modulate:a", 1.0, 0.15)
		_banner_tw.tween_interval(hold)
		_banner_tw.tween_property(_sub_pill, "modulate:a", 0.0, 0.3)
		return
	_sub_pill.scale = Vector2(0.7, 0.7)
	_sub_pill.modulate.a = 0.0
	_banner_tw.set_parallel(true)
	_banner_tw.tween_property(_sub_pill, "modulate:a", 1.0, 0.14).set_delay(0.12)
	_banner_tw.tween_property(_sub_pill, "scale", Vector2.ONE, 0.34).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.chain().tween_interval(hold)
	_banner_tw.chain().tween_property(_sub_pill, "modulate:a", 0.0, 0.3)

## A label's beat, from rest: Motion.bump swells from whatever size the
## thing is, so one begun before the last was over left it a little bigger
## each time, and a streak of kills blew the score up over its plate.
func _beat(node: Control, amount: float, time: float) -> void:
	Motion.stop(_beats.get(node))
	node.scale = Vector2.ONE
	_beats[node] = Motion.bump(node, amount, time)

## The score rolls up to the real one and gives a beat when it lands; the
## best follows it once passed.
func _refresh_hud(delta := 0.0) -> void:
	if sim == null:
		return
	if sim.score != _shown_score:
		if sim.score > _shown_score and _shown_score >= 0:
			_score_l.pivot_offset = _score_l.size * 0.5
			_beat(_score_l, 0.1, 0.2)
		_shown_score = sim.score
		if not _beat_best and _best > 0 and sim.score > _best:
			_beat_best = true
			_best_l.pivot_offset = _best_l.size * 0.5
			_beat(_best_l, 0.3, 0.4)
			_new_best_passed()
	if Motion.reduce or sim.score < _roll:
		_roll = sim.score
	else:
		_roll = move_toward(_roll, sim.score, maxf(delta * absf(sim.score - _roll) * 10.0, delta * 300.0))
	var shown := Record.grouped(int(_roll))
	if _score_l.text != shown:
		_score_l.text = shown
		_best_l.text = Record.grouped(maxi(_best, int(_roll)))
	var wave := str(maxi(1, sim.wave))
	if _wave_l.text != wave:
		_wave_l.text = wave
	# the plate counts what has landed on it, not what is still in the air
	var held := int((sim.energy - _orb_due) / Sim.ORBS + 0.001)
	if held != _shown_energy:
		_shown_energy = held
		_energy_l.text = Record.grouped(held)

# --- drawing ---

## Where the sun stands: low on the right, coming up from behind the far
## hills, clear of the sky the crates come down.
func _sun_at() -> Vector2:
	return px(Vector2(Sim.W * 0.8, TURF - 94.0))

## The garden's foot from `y0` down, its round corners kept.
func _foot(b: Face.Builder, y0: float, col: Color) -> void:
	var s := field.size
	var pts := PackedVector2Array([Vector2(0, y0), Vector2(s.x, y0)])
	pts.append_array(Face.Builder.arc_points(Vector2(s.x - ROUND, s.y - ROUND), ROUND, 0.0, PI * 0.5))
	pts.append_array(Face.Builder.arc_points(Vector2(ROUND, s.y - ROUND), ROUND, PI * 0.5, PI))
	b.fan(pts, col)

## The still sky, built on resize: pale blue going to cream at the grass,
## and the sun's glow.
func _build_scene() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	var k := _u / 2.4
	var turf := px(Vector2(0, TURF)).y
	# the sky: one rounded sheet, a colour a vertex by how far down it is
	var rim := Face.Builder.round_rect(Vector2.ZERO, s, ROUND)
	var mid := b.vertex(s * 0.5, SKY_TOP.lerp(SKY_LOW, clampf(s.y * 0.5 / turf, 0.0, 1.0)))
	var first := -1
	var prev := -1
	for p in rim:
		var i := b.vertex(p, SKY_TOP.lerp(SKY_LOW, clampf(p.y / turf, 0.0, 1.0)))
		if prev >= 0:
			b.tri(mid, prev, i)
		else:
			first = i
		prev = i
	b.tri(mid, prev, first)
	# the sun's glow and rays; its face is a node of its own over them, and
	# where there is none (a tutorial page) a plain pale disc
	var sun := _sun_at()
	b.disc(sun, 62.0 * k, Color(1, 0.96, 0.78, 0.4))
	Rewards.sunrays(b, sun, 56.0 * k, 124.0 * k, 12, 0.2, Color(1, 0.95, 0.72, 0.26))
	if _sun == null:
		b.disc(sun, 40.0 * k, Color("fdeeb5"))
	return b.mesh()

## The still land, laid over the sky and the sun: three rows of soft hills
## with round trees and bushes on them, and the grass the cart rolls on.
func _build_land() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := field.size
	var turf := px(Vector2(0, TURF)).y
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	# three rows of hills, the far one palest
	for i in 3:
		b.ellipse(Vector2(s.x * (0.12 + 0.38 * i), turf + 12.0 * _u), s.x * 0.34, (72.0 + 16.0 * ((i + 1) % 2)) * _u, HILL_FAR)
	for i in 4:
		b.ellipse(Vector2(s.x * 0.33 * i, turf + 8.0 * _u), s.x * 0.26, (40.0 + 10.0 * (i % 2)) * _u, HILL)
	for i in 3:
		b.ellipse(Vector2(s.x * (0.2 + 0.36 * i), turf + 6.0 * _u), s.x * 0.24, (20.0 + 6.0 * (i % 2)) * _u, HILL_NEAR)
	# a few round trees along them
	for i in 6:
		var at := Vector2(s.x * rng.randf_range(0.05, 0.95), turf - rng.randf_range(5.0, 22.0) * _u)
		var r := rng.randf_range(5.0, 8.0) * _u
		b.fan(Face.Builder.round_rect(at + Vector2(-r * 0.14, 0), Vector2(r * 0.28, r * 1.1), r * 0.1), Color("c9a172", 0.8))
		b.disc(at + Vector2(0, -r * 0.34), r, BUSH[0])
		b.disc(at + Vector2(-r * 0.12, -r * 0.5), r * 0.78, BUSH[1])
		b.disc(at + Vector2(-r * 0.3, -r * 0.74), r * 0.36, Color(1, 1, 1, 0.16))
	# and Posy's bushes at the garden's sides, starred with daisies
	for side in [0.0, 1.0]:
		for i in 3:
			var at := Vector2(s.x * (side + (0.02 + 0.07 * i) * (1.0 - 2.0 * side)), turf - rng.randf_range(0.0, 6.0) * _u)
			var r := rng.randf_range(9.0, 13.0) * _u
			for layer in 3:
				b.disc(at + Vector2(rng.randf_range(-2.0, 2.0) * _u, -layer * r * 0.24), r * (1.0 - 0.2 * layer), BUSH[layer])
			var d := at + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.9, -0.3)) * r
			for q in 5:
				b.disc(d + Vector2.from_angle(TAU * q / 5.0) * 1.7 * _u, 1.35 * _u, Color("fffaf0"))
			b.disc(d, 1.1 * _u, Color("f6cb5e"))
	# the grass: a pale lip, and a scalloped edge to the deeper turf under it
	_foot(b, turf, GRASS)
	b.fan(PackedVector2Array([Vector2(0, turf), Vector2(s.x, turf), Vector2(s.x, turf + 2.6 * _u), Vector2(0, turf + 2.6 * _u)]), GRASS_LIP)
	var y0 := turf + 15.0 * _u
	var scallop := 8.0 * _u
	var x := scallop * 0.5
	while x < s.x:
		b.disc(Vector2(x, y0), scallop * 0.62, GRASS_DEEP)
		x += scallop
	_foot(b, y0, GRASS_DEEP)
	_build_rail(b)
	return b.mesh()

## The hedges round the card's foot (Posy's): leafy bushes poking out past
## its sides and lower corners, built once for the card where it stands.
func _draw_hedge() -> void:
	if _frame == null or _frame.size.x <= 0.0:
		return
	var rect := Rect2(_hedge.get_global_transform().affine_inverse() * _frame.global_position, _frame.size)
	if _hedge_mesh == null or rect != _hedge_rect:
		_hedge_rect = rect
		var b := Face.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var spots: Array = []
		var y := rect.end.y - rect.size.y * 0.3
		while y < rect.end.y + 30.0:
			for side in [0, 1]:
				var x: float = rect.position.x - 4.0 if side == 0 else rect.end.x + 4.0
				spots.append(Vector2(x + rng.randf_range(-12.0, 12.0), y))
			y += rng.randf_range(84.0, 130.0)
		for corner in [Vector2(rect.position.x, rect.end.y), rect.end]:
			for i in 3:
				spots.append(corner + Vector2(rng.randf_range(-36.0, 36.0), rng.randf_range(-26.0, 22.0)))
		for layer in 3:
			for p: Vector2 in spots:
				var r := rng.randf_range(32.0, 52.0) * (1.0 - layer * 0.18)
				b.disc(p + Vector2(rng.randf_range(-10.0, 10.0), -layer * 10.0), r, BUSH[layer])
		for p: Vector2 in spots:
			if rng.randf() < 0.55:
				var at := p + Vector2(rng.randf_range(-22.0, 22.0), rng.randf_range(-28.0, 0.0))
				for q in 6:
					b.disc(at + Vector2.from_angle(TAU * q / 6.0) * 7.0, 5.2, Color("fffaf0"))
				b.disc(at, 4.2, Color("f6cb5e"))
		_hedge_mesh = b.mesh()
	_hedge.draw_mesh(_hedge_mesh, null)

func _draw_field() -> void:
	if _scene == null:
		_layout_field()
	if _scene != null:
		field.draw_mesh(_scene, null)

## Over the sky and the sun the land, and then everything that moves, back
## to front: the clouds (under the land), the line, the crates
## or the millipede and their numbers, the peas and the sparks, what is
## laid fresh (the streak's pill, the stars, the glows, the rack's seats and
## what runs down round them), the gun's line, the rack's gifts and their
## pips, the flowers, the cart, the gifts in the air and the numbers going
## up.
func _draw_over() -> void:
	if sim == null:
		return
	var font := Art.font()
	_cast_turn = 0
	_over.draw_set_transform(Vector2.ZERO)
	_draw_clouds()
	if _land != null:
		_over.draw_mesh(_land, null)
	_over.draw_set_transform(_shake_off)
	if sim.frost_t > 0.0:
		# the frost: a pale wash over the garden, going as it runs out
		_over.draw_rect(Rect2(Vector2.ZERO, field.size), Color(FROST, 0.2 * minf(1.0, sim.frost_t)))
	_draw_line()
	var top := Face.Builder.new()
	_head_tag = []
	_draw_ghosts()
	if sim.wave_kind == Sim.Wave.WALL:
		_draw_wall(font)
	else:
		_draw_milli(font, top)
	_draw_peas()
	_draw_sparks()
	_draw_bolts(top)
	_draw_muzzle(top)
	_draw_rack_seats(top)
	_draw_streak_pill(top)
	_draw_pair_pill(top)
	_draw_stars(top)
	if sim.frost_t > 0.0:
		Rewards.edge_glow(top, Rect2(Vector2.ZERO, field.size), FROST, minf(1.0, sim.frost_t), 0.6)
	if _heat > 0.01:
		var hb := 0.6 if Motion.reduce else 0.5 + 0.5 * sin(_clock * 9.0)
		Rewards.edge_glow(top, Rect2(Vector2.ZERO, field.size), HEAT.lerp(ALARM, _heat), _heat, hb)
	if _alarm > 0.01:
		var ab := 0.6 if Motion.reduce else 0.5 + 0.5 * sin(_clock * 11.0)
		Rewards.edge_glow(top, Rect2(Vector2.ZERO, field.size), ALARM, _alarm, ab)
	if not top.verts.is_empty():
		_live_top = top.mesh()
		_over.draw_mesh(_live_top, null)
	if _chips != null:
		_over.draw_mesh(_chips, null)
	# the medallions on the gun's line, and the rack's gifts
	for k in GUN.size():
		var sc := 0.62 * _bump(CHIP + int(GUN[k]))
		_cast_add(Art.card_token(GUN[k], _u), Transform2D(0.0, Vector2(sc, sc), 0.0, _gun_chip(k)), Color.WHITE)
	_draw_rack_tokens()
	_draw_blooms()
	for c: Dictionary in _crumbs:
		var k: float = float(c.t) / CRUMB_T
		_cast_add(Art.crumb(_u), Transform2D(0.0, px(c.pos)), Color(1, 1, 1, 1.0 - k * k))
	_cast_draw()
	_draw_rack_pips()
	if not _head_tag.is_empty():
		Art.number(_over, font, px(_head_tag[0]), _head_tag[1], Sim.SEG_R * 1.25 * _u, 1.0, Sim.Kind.HEAD)
	if sim.cart == Sim.Cart.TWINS:
		# the twin, across the garden's middle from the cart
		_draw_cart(Sim.W - sim.x, true)
	_draw_cart(sim.x, false)
	_draw_flights()
	_draw_gun_words(font)
	_draw_rack_counts(font)
	_draw_streak_words(font)
	_draw_pair_words(font)
	_draw_pops(font)
	_draw_nums(font)
	_over.draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		_over.draw_rect(Rect2(Vector2.ZERO, field.size), Color(_flash_col, _flash * 0.4))

## Three clouds drifting across the top of the sky, round and round.
func _draw_clouds() -> void:
	var s := field.size
	var w := 84.0 * _u / 2.4
	var mesh := Art.cloud(w)
	var t := 0.0 if Motion.reduce else _clock
	for i in 3:
		var span := s.x + w * 2.0
		var x := fposmod(s.x * (0.1 + 0.37 * i) + t * (5.0 + 2.5 * i), span) - w
		var sc := 1.0 + 0.25 * (i % 2)
		_cast_add(mesh, Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2(x, s.y * (0.07 + 0.11 * i))), Color(1, 1, 1, 0.75))
	_cast_draw()

## The line nothing may reach: soft dashes across the garden, turning red
## and running as something nears it. The dashes are one mesh built with
## the garden; the run is its transform and the red its tint.
func _build_dashes() -> ArrayMesh:
	var b := Face.Builder.new()
	var dash := 9.0 * _u
	var x := -dash * 2.0
	while x < field.size.x + dash * 2.0:
		b.fan(Face.Builder.round_rect(Vector2(x, -1.2 * _u), Vector2(dash, 2.4 * _u), 1.2 * _u), Color.WHITE)
		x += dash * 2.0
	return b.mesh()

func _draw_line() -> void:
	if _dashes == null:
		return
	var y := px(Vector2(0, Sim.DANGER + 6.0)).y
	var col := Color("fffaf0", 0.85).lerp(Color(ALARM, 0.95), _alarm)
	var dash := 9.0 * _u
	var run := 0.0 if Motion.reduce else fmod(_clock * 30.0 * _alarm, dash * 2.0)
	_over.draw_mesh(_dashes, null, Transform2D(0.0, Vector2(run - dash * 2.0, y)), col)

## One MultiMesh a look of shot, as many shown as are in the air; one
## flung sideways (the Fan's, a seed, a conker on its hop) leans the way it
## goes.
func _draw_peas() -> void:
	# a look is a shape (Sim.Shot) in an element's colour: none, then ZAP to GUST
	var shapes := Sim.Shot.size()
	var looks := shapes * (2 + Sim.Kind.GUST - Sim.Kind.ZAP)
	if _pea_mm.is_empty():
		for k in looks:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_2D
			_pea_mm.append(mm)
			_pea_buf.append(PackedFloat32Array())
	var counts: Array = []
	counts.resize(looks)
	counts.fill(0)
	# a heavier pea is a bigger one
	var heavy := minf(1.9, 1.0 + 0.2 * log(float(maxi(1, sim.power))))
	var u := _u
	var ox := _origin.x
	var oy := _origin.y
	for p: Dictionary in sim.shots:
		var el: int = p.el
		var k: int = int(p.k) + shapes * (0 if el == 0 else el - Sim.Kind.ZAP + 1)
		var buf: PackedFloat32Array = _pea_buf[k]
		var o: int = counts[k] * 8
		if o + 8 > buf.size():
			buf.resize(o + 8 * 64)
		var fat := minf(3.0, heavy * float(p.sz))
		var vx: float = p.vx
		if vx == 0.0:
			buf[o] = fat
			buf[o + 1] = 0.0
			buf[o + 4] = 0.0
			buf[o + 5] = fat
		else:
			var a := atan2(vx, -float(p.vy))
			buf[o] = cos(a) * fat
			buf[o + 1] = -sin(a) * fat
			buf[o + 4] = sin(a) * fat
			buf[o + 5] = cos(a) * fat
		buf[o + 3] = ox + float(p.x) * u
		buf[o + 7] = oy + float(p.y) * u
		_pea_buf[k] = buf
		counts[k] += 1
	for k in looks:
		if counts[k] == 0:
			continue
		var mm: MultiMesh = _pea_mm[k]
		var buf: PackedFloat32Array = _pea_buf[k]
		var mesh := Art.shot(k % shapes, _u, 0 if k < shapes else Sim.Kind.ZAP + int(k / float(shapes)) - 1)
		if mm.mesh != mesh:
			mm.mesh = mesh
		if mm.instance_count * 8 != buf.size():
			mm.instance_count = buf.size() / 8
		mm.visible_instance_count = counts[k]
		mm.buffer = buf
		_over.draw_multimesh(mm, null)

## How a crate or a plate sits this frame, as [its squeeze, how fresh the
## knock is 1..0]: squeezed by the pea that just landed, else as it is. The
## knock is shown by a white blink laid over the piece, never by its paint.
func _knocked(id: int) -> Array:
	var since: float = _clock - float(_hit_at.get(id, -10.0))
	if since > 0.12:
		return [Vector2.ONE, 0.0]
	var k := 1.0 - since / 0.12
	var sc := Vector2.ONE if Motion.reduce else Vector2(1.0 + 0.08 * k, 1.0 - 0.1 * k)
	return [sc, k]

## One more of `mesh` this frame, under `xf` and tinted `col`. What is
## gathered is drawn by the next `_cast_draw`, and each of a frame's draws
## keeps MultiMeshes of its own (`_casts`, by the draw's turn): a MultiMesh
## holds one buffer, so the same mesh drawn twice in a frame from one of
## them showed the second draw's copies both times.
func _cast_add(mesh: ArrayMesh, xf: Transform2D, col: Color) -> void:
	while _casts.size() <= _cast_turn:
		_casts.append({})
	var cast: Dictionary = _casts[_cast_turn]
	var g: Array = cast.get(mesh, [])
	if g.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = mesh
		g = [mm, PackedFloat32Array(), 0]
		cast[mesh] = g
	var buf: PackedFloat32Array = g[1]
	var o: int = int(g[2]) * 12
	if o + 12 > buf.size():
		buf.resize(o + 12 * 8)
	buf[o] = xf.x.x
	buf[o + 1] = xf.y.x
	buf[o + 3] = xf.origin.x
	buf[o + 4] = xf.x.y
	buf[o + 5] = xf.y.y
	buf[o + 7] = xf.origin.y
	buf[o + 8] = col.r
	buf[o + 9] = col.g
	buf[o + 10] = col.b
	buf[o + 11] = col.a
	g[1] = buf
	g[2] = int(g[2]) + 1

## Draws what `_cast_add` gathered since the last one and moves on to the
## frame's next draw. Called the same number of times every frame, whether
## or not anything was gathered, so a draw keeps its MultiMeshes.
func _cast_draw() -> void:
	if _casts.size() <= _cast_turn:
		_cast_turn += 1
		return
	var cast: Dictionary = _casts[_cast_turn]
	_cast_turn += 1
	for mesh in cast:
		var g: Array = cast[mesh]
		var n: int = g[2]
		if n == 0:
			continue
		var mm: MultiMesh = g[0]
		var buf: PackedFloat32Array = g[1]
		if mm.instance_count * 12 != buf.size():
			mm.instance_count = buf.size() / 12
		mm.visible_instance_count = n
		mm.buffer = buf
		_over.draw_multimesh(mm, null)
		g[2] = 0

## The shapes crates and plates just gone leave: swelling and thinning away.
func _draw_ghosts() -> void:
	for g: Dictionary in _ghosts:
		var k: float = g.t / GHOST_T
		var sc := 1.0 if Motion.reduce else 1.0 + 0.3 * (1.0 - (1.0 - k) * (1.0 - k))
		if g.big:
			sc *= Sim.HEAD_R / Sim.SEG_R
		var col: Color = g.col
		_cast_add(Art.blank(g.round, _u), Transform2D(0.0, Vector2(sc, sc), 0.0, px(g.pos)), Color(col, 0.7 * (1.0 - k)))

## Over the pieces and under their numbers: the break in each one worn
## down (`cracked`: [where it is drawn, how worn 1..Art.WORN, its id]) --
## one of Art.CRACK_LOOKS breaks by its id, turned the other way round for
## every other, in ink with a pale edge, never a shade of its paint -- and
## the white blink over each a pea just landed on (`lit`: [where it is
## drawn, how fresh the knock is]).
func _draw_blinks(lit: Array, round: bool, cracked: Array = []) -> void:
	for c: Array in cracked:
		var id: int = c[2]
		var flip := Transform2D(0.0, Vector2(-1.0 if int(id / float(Art.CRACK_LOOKS)) % 2 == 1 else 1.0, 1.0), 0.0, Vector2.ZERO)
		_cast_add(Art.cracks(round, id % Art.CRACK_LOOKS, int(c[1]), _u), (c[0] as Transform2D) * flip, Color.WHITE)
	var blank := Art.blank(round, _u)
	for l: Array in lit:
		_cast_add(blank, l[0], Color(1, 1, 1, 0.55 * float(l[1])))
	_cast_draw()

## The numbers, in ink: `numbered` is [where, the number, the kind, how
## fresh a knock is], and one just knocked swells a little.
func _letter(font: Font, numbered: Array, s: float) -> void:
	for n: Array in numbered:
		var c := px(n[0])
		var k: float = n[3]
		if k > 0.0 and not Motion.reduce:
			var sc := 1.0 + 0.18 * k
			_over.draw_set_transform(_shake_off + c, 0.0, Vector2(sc, sc))
			Art.number(_over, font, Vector2.ZERO, n[1], s, 1.0, n[2])
			_over.draw_set_transform(_shake_off)
		else:
			Art.number(_over, font, c, n[1], s, 1.0, n[2])

func _draw_wall(font: Font) -> void:
	var numbered: Array = []
	var lit: Array = []
	var cracked: Array = []
	var alight: Array = []
	var stung: Array = []
	var rimed: Array = []
	for r in sim.rows.size():
		var row: Array = sim.rows[r]
		for c in Sim.COLS:
			if row[c] == null:
				continue
			var cell: Dictionary = row[c]
			var at: Vector2 = sim.cell_pos(r, c)
			if at.y < -Sim.CELL_H - _origin.y / _u:
				continue
			var kn := _knocked(cell.id)
			var kind: int = cell.kind
			var tier := Art.tier_of(cell.hp) if kind == Sim.Kind.CRATE else 0
			var xf := Transform2D(0.0, kn[0], 0.0, px(at))
			var worn := Art.worn(cell.hp, cell.max)
			if float(cell.burn_t) > 0.0:
				alight.append([at + Vector2(Sim.CELL_W * 0.5 - 11.0, -Sim.CELL_H * 0.5 + 11.0), cell.id])
			if float(cell.sting_t) > 0.0:
				stung.append([at + Vector2(-Sim.CELL_W * 0.5 + 9.0, -Sim.CELL_H * 0.5 + 10.0), cell.id])
			if float(cell.brittle) > sim.t:
				rimed.append([at + Vector2(-Sim.CELL_W * 0.5 + 9.5, Sim.CELL_H * 0.5 - 12.0), cell.id])
			if Sim.holds_gift(kind) and not Motion.reduce:
				# a parcel sways and breathes, to be noticed
				var ph: float = _clock * 3.2 + c * 1.7 + r
				xf = Transform2D(sin(ph) * 0.04, kn[0] * (1.0 + 0.025 * sin(ph * 1.3)), 0.0, px(at))
			elif worn == Art.WORN and not Motion.reduce:
				# one about to break trembles
				xf = Transform2D(sin(_clock * 34.0 + float(cell.id)) * 0.014, kn[0], 0.0, px(at))
			_cast_add(Art.crate(kind, tier, _u), xf, Color.WHITE)
			if worn > 0:
				cracked.append([xf, worn, cell.id])
			if float(kn[1]) > 0.0:
				lit.append([xf, kn[1]])
			if kind == Sim.Kind.CRATE or kind == Sim.Kind.GOLD or kind == Sim.Kind.IRON:
				numbered.append([at + Vector2(0, -Art.LIP * 0.5), cell.hp, kind, kn[1]])
	_cast_draw()
	_draw_blinks(lit, false, cracked)
	_letter(font, numbered, (Sim.CELL_H - 3.0) * _u)
	_draw_fires(alight)
	_draw_marks(stung, rimed)

func _draw_milli(font: Font, top: Face.Builder) -> void:
	var numbered: Array = []
	var lit: Array = []
	var cracked: Array = []
	var alight: Array = []
	var stung: Array = []
	var rimed: Array = []
	var head_at: Array = []
	# tail first, so each plate laps the one behind it and the head laps all
	for i in range(sim.segs.size() - 1, -1, -1):
		var sg: Dictionary = sim.segs[i]
		var s: float = sg.s
		if s < -Sim.SEG_R - _origin.x / _u:
			continue
		var at: Vector2 = Sim.path_at(s)
		if float(sg.burn_t) > 0.0:
			alight.append([at + Vector2(Sim.SEG_R * 0.6, -Sim.SEG_R * 0.3), sg.id])
		if float(sg.sting_t) > 0.0:
			stung.append([at + Vector2(-Sim.SEG_R * 0.66, -Sim.SEG_R * 0.5), sg.id])
		if float(sg.brittle) > sim.t:
			rimed.append([at + Vector2(-Sim.SEG_R * 0.6, Sim.SEG_R * 0.56), sg.id])
		var kn := _knocked(sg.id)
		var sc: Vector2 = kn[0]
		var jitter := Vector2.ZERO
		var waddle := 0.0
		if not Motion.reduce:
			var beat := 1.0 + 0.04 * sin(_clock * 7.0 - i * 0.9)
			sc *= Vector2(beat, beat)
			# its legs go, a plate after the one before
			waddle = 0.1 * sin(_clock * 9.0 - i * 1.3)
			if float(sg.dying) >= 0.0:
				jitter = Vector2(sin(_clock * 90.0 + i), cos(_clock * 70.0 + i)) * 1.5
		if sg.kind == Sim.Kind.HEAD:
			var ahead: Vector2 = Sim.path_at(s + 3.0) - at
			var ang := ahead.angle() if ahead.length_squared() > 0.0001 else 0.0
			var cross: bool = sim.danger() > 0.35 or sim.is_over()
			head_at = [Art.head(_u, cross), Transform2D(ang, sc, 0.0, px(at))]
			if float(kn[1]) > 0.0:
				var big := Sim.HEAD_R / Sim.SEG_R
				lit.append([Transform2D(0.0, sc * big, 0.0, px(at)), kn[1]])
			# the pupils, turned with the head and watching the cart
			var look := (Vector2(sim.x, Sim.CART_Y) - at).normalized()
			var r := Sim.HEAD_R * _u
			for side in [-1.0, 1.0]:
				var eye := px(at) + Vector2(r * 0.36, side * r * 0.4 - 1.0 * _u).rotated(ang)
				top.disc(eye + look * r * 0.12, r * 0.15, Art.FEELER)
			# its number on a paper tag over it, lettered last so nothing laps it
			var tag := at + Vector2(0, -Sim.HEAD_R - 9.0)
			var wide := (9.0 + 5.0 * Art.short(sg.hp).length()) * _u
			var tag_at := px(tag) - Vector2(wide, 7.5 * _u)
			top.fan(Face.Builder.round_rect(tag_at + Vector2(0, 1.6 * _u), Vector2(wide * 2.0, 15.0 * _u), 7.5 * _u), Color(Art.HEAD_DEEP, 0.5))
			top.fan(Face.Builder.round_rect(tag_at, Vector2(wide * 2.0, 15.0 * _u), 7.5 * _u), Art.PAPER)
			_head_tag = [tag, sg.hp]
			continue
		var kind: int = sg.kind
		var tier := Art.tier_of(sg.hp) if kind == Sim.Kind.CRATE else 0
		var xf := Transform2D(waddle, sc, 0.0, px(at + jitter))
		_cast_add(Art.plate(kind, tier, _u), xf, Color.WHITE)
		var worn := Art.worn(sg.hp, sg.max)
		if worn > 0:
			cracked.append([xf, worn, sg.id])
		if float(kn[1]) > 0.0:
			lit.append([xf, kn[1]])
		if kind == Sim.Kind.CRATE or kind == Sim.Kind.GOLD or kind == Sim.Kind.IRON:
			numbered.append([at + Vector2(0, -Sim.SEG_R * 0.09), sg.hp, kind, kn[1]])
	_cast_draw()
	if not head_at.is_empty():
		_over.draw_mesh(head_at[0], null, head_at[1])
	_draw_blinks(lit, true, cracked)
	_letter(font, numbered, Sim.SEG_R * 1.7 * _u)
	_draw_fires(alight)
	_draw_marks(stung, rimed)

## The flame on each thing alight ([where its foot is, the thing's id]),
## never a tint of the thing: a crate's paint is its number.
func _draw_fires(alight: Array) -> void:
	var mesh := Art.fire(_u)
	for a: Array in alight:
		var ph: float = _clock * 13.0 + float(a[1])
		var xf := Transform2D(0.0, px(a[0]))
		if not Motion.reduce:
			xf = Transform2D(sin(ph) * 0.14, Vector2(1.0 + 0.08 * sin(ph * 1.7), 1.0 + 0.14 * sin(ph * 1.3)), 0.0, px(a[0]))
		_cast_add(mesh, xf, Color.WHITE)
	_cast_draw()

## The nettle's leaf on each thing stung and the hail's crystal on each left
## brittle ([where, the thing's id]), and the gust's puffs: marks at a
## corner, never a tint of the thing.
func _draw_marks(stung: Array, rimed: Array) -> void:
	var leaf := Art.sting(_u)
	for a: Array in stung:
		var sway := 0.0 if Motion.reduce else sin(_clock * 6.0 + float(a[1])) * 0.16
		_cast_add(leaf, Transform2D(-0.4 + sway, px(a[0])), Color.WHITE)
	var ice := Art.rime(_u)
	for a: Array in rimed:
		var sc := 1.0 if Motion.reduce else 1.0 + 0.08 * sin(_clock * 5.0 + float(a[1]))
		_cast_add(ice, Transform2D(0.0, Vector2(sc, sc), 0.0, px(a[0])), Color.WHITE)
	var puff := Art.puff(_u)
	for pf: Dictionary in _puffs:
		var k: float = float(pf.t) / PUFF_T
		var sc := 0.6 + 0.7 * k
		_cast_add(puff, Transform2D(0.0, Vector2(sc * float(pf.way), sc), 0.0, px(pf.pos + Vector2(0, -14.0 * k))), Color(1, 1, 1, 0.85 * (1.0 - k * k)))
	_cast_draw()

## Lightning along each chain: a jagged line from one thing to the next, a
## white core in a yellow one, gone in a blink.
func _draw_bolts(b: Face.Builder) -> void:
	for bo: Dictionary in _bolts:
		var k: float = float(bo.t) / BOLT_T
		var pts: Array = bo.pts
		var line := PackedVector2Array()
		for i in pts.size():
			var at := px(pts[i])
			if i > 0:
				# two kinks on the way, the same for the bolt's whole life
				var from := px(pts[i - 1])
				var side := (at - from).orthogonal().normalized()
				for j in [1, 2]:
					var off := sin(float(i * 7 + j * 13) + float(pts[0].x)) * 7.0 * _u
					line.append(from.lerp(at, j / 3.0) + side * off)
			line.append(at)
		b.stroke(line, (4.6 - 2.0 * k) * _u, Color(Art.BOLT, 0.85 * (1.0 - k)))
		b.stroke(line, (1.8 - 0.8 * k) * _u, Color(1, 1, 1, 1.0 - k))

func _draw_sparks() -> void:
	if _sparks.is_empty():
		return
	if _spark_mm == null:
		_spark_mm = MultiMesh.new()
		_spark_mm.transform_format = MultiMesh.TRANSFORM_2D
		_spark_mm.use_colors = true
		_spark_mm.mesh = Art.spark()
		_spark_mm.instance_count = MAX_SPARKS
		_spark_buf.resize(MAX_SPARKS * 12)
	var n := mini(_sparks.size(), MAX_SPARKS)
	for i in n:
		var sp: Dictionary = _sparks[i]
		var k: float = sp.t / 0.22
		var c := px(sp.pos)
		var r := (4.0 + 7.0 * k) * _u
		var ca := cos(float(sp.turn)) * r
		var sa := sin(float(sp.turn)) * r
		var col: Color = sp.col
		var o := i * 12
		_spark_buf[o] = ca
		_spark_buf[o + 1] = -sa
		_spark_buf[o + 3] = c.x
		_spark_buf[o + 4] = sa
		_spark_buf[o + 5] = ca
		_spark_buf[o + 7] = c.y
		_spark_buf[o + 8] = col.r
		_spark_buf[o + 9] = col.g
		_spark_buf[o + 10] = col.b
		_spark_buf[o + 11] = 1.0 - k
	_spark_mm.visible_instance_count = n
	_spark_mm.buffer = _spark_buf
	_over.draw_multimesh(_spark_mm, null)

## The puff at each pod's mouth just after a volley: a pale ring opening
## and going, one a pea.
func _draw_muzzle(b: Face.Builder) -> void:
	var since := _clock - _shot_at
	if since > 0.1 or Motion.reduce or sim.phase != Sim.Phase.PLAY:
		return
	var k := since / 0.1
	var n := _pods()
	var size: float = POD_SIZE[n - 1]
	for i in n:
		var c := px(Vector2(sim.x + Sim.pea_off(i, n), Sim.CART_Y - 41.0))
		var r := (5.0 + 7.0 * k) * _u * size
		b.stroke(Face.Builder.ring(c, r, r * 0.55), (2.6 - 2.0 * k) * _u, Color(Art.PAPER, 0.9 * (1.0 - k)), true)
		b.disc(c, 3.0 * _u * size * (1.0 - k), Color(Art.POD_HI, 0.9 * (1.0 - k)))

## The pods on the cart: one a pea of the pea gun's volley, four at most
## (the peas past that leave from the same row), and one gun on any other.
func _pods() -> int:
	return clampi(sim.peas, 1, POD_SIZE.size()) if sim.cart == Sim.Cart.PEA else 1

## How far the cart is off the grass this frame, in pixels: a small hop as
## a gift is caught, two bounces as a wave is cleared.
func _hop_now() -> float:
	if _hop.is_empty() or Motion.reduce:
		return 0.0
	var k: float = (_clock - float(_hop.at)) / float(_hop.time)
	if k >= 1.0:
		_hop = {}
		return 0.0
	if _hop.twice:
		return absf(sin(k * TAU)) * float(_hop.tall) * _u * (1.0 - 0.5 * k)
	return sin(k * PI) * float(_hop.tall) * _u

## A cart: its pods sunk into the cradle by the volley just fired, the box,
## and two wheels turned as far as it has rolled. A volley of more peas than
## one is as many pods, side by side and leaning apart, each mouth under its
## pea. The pods are the colour of the element running, and wear what the
## shapes running give them (`_dress`): the Fan two small pods leaning out
## from behind, the Dart a brass nozzle on each mouth, the Berry a bunch
## either side of the cradle; lightning plays round the mouth, the flame
## leaves a pilot light on each lip. A gift swallowed swells the lot
## (`_gulp_now`). The helper's is smaller and plain. The middle pod wears
## the crown once the best is passed.
func _draw_cart(x: float, helper: bool) -> void:
	var u := _u * (0.8 if helper else 1.0)
	var hop := _hop_now()
	var foot := px(Vector2(x, TURF)) - Vector2(0, 9.0 * u + hop)
	var since := _clock - _shot_at
	var kick := 0.0
	if since < RECOIL and not Motion.reduce and sim.phase == Sim.Phase.PLAY:
		kick = 1.0 - since / RECOIL
		kick *= kick
	var gulp := 0.0 if helper else _gulp_now()
	var lean := Transform2D(_lean, foot)
	var el := 0 if helper else _pod_el
	var n := 1 if helper else _pods()
	var size: float = POD_SIZE[n - 1]
	var squash := Vector2(1.0 + 0.08 * kick + 0.22 * gulp, 1.0 - 0.12 * kick - 0.16 * gulp) * size
	var sink := (-12.0 + 3.5 * kick) * u
	var barrel := Art.barrel(u, helper, el, sim.cart)
	var fan := 0.0 if helper else Motion.back_out(float(_dress[0]))
	var dart := 0.0 if helper else Motion.back_out(float(_dress[1]))
	var berry := 0.0 if helper else Motion.back_out(float(_dress[2]))
	if fan > 0.01:
		var out := Sim.pea_off(n - 1, n) * 0.75 + 5.5
		for side: float in [-1.0, 1.0]:
			_over.draw_mesh(barrel, null, lean * Transform2D(side * 0.62, squash * 0.64 * fan, 0.0, Vector2(side * out * u, sink + 2.5 * u)))
	var pod := lean
	# the outermost first, so the middle pod laps its neighbours
	for j in n:
		var i: int = (j >> 1) if j % 2 == 0 else n - 1 - (j >> 1)
		var off := Sim.pea_off(i, n)
		# its foot nearer the middle than its mouth, which is under its pea
		pod = lean * Transform2D(0.25 * off / (30.0 * size), squash, 0.0, Vector2(off * 0.75 * u, sink))
		_over.draw_mesh(barrel, null, pod)
		var mouth := pod * Transform2D(0.0, Vector2(0, -30.0 * u))
		if dart > 0.01:
			_over.draw_mesh(Art.nozzle(u), null, mouth * Transform2D(0.0, Vector2(dart, dart), 0.0, Vector2.ZERO))
		if el == Sim.Kind.FLAME:
			var ph := _clock * 13.0 + i * 2.1
			var lick := Transform2D(0.0, Vector2(0.62, 0.62), 0.0, Vector2(0, (-1.0 - 6.5 * dart) * u))
			if not Motion.reduce:
				lick = Transform2D(sin(ph) * 0.14, Vector2(0.62 + 0.05 * sin(ph * 1.7), 0.62 + 0.1 * sin(ph * 1.3)), 0.0, lick.origin)
			_over.draw_mesh(Art.fire(u), null, mouth * lick)
	_over.draw_mesh(Art.cart(u, helper), null, lean)
	if berry > 0.01:
		_over.draw_mesh(Art.berries(u), null, lean * Transform2D(0.0, Vector2(berry, berry), 0.0, Vector2(0, -11.0 * u)))
	var spin := _wheel + (hop / _u) * 0.2
	for side: float in [-1.0, 1.0]:
		_over.draw_mesh(Art.wheel(u), null, Transform2D(spin, foot + Vector2(side * 13.0 * u, 0)))
	if el == Sim.Kind.ZAP:
		# a new crackle every blink, now one way round and now the other
		var tick := 0 if Motion.reduce else int(_clock * 14.0)
		var wide := (1.0 + 0.3 * (n - 1)) * (-1.0 if tick % 2 == 1 else 1.0)
		_over.draw_mesh(Art.crackle(tick % Art.CRACKLES, u), null, lean * Transform2D(0.0, Vector2(wide, 1.0), 0.0, Vector2(0, sink - 30.0 * u * size)))
	if not helper and _crown_at >= 0.0:
		# it drops onto the pod's lip and sits there, a little askew
		var k := 1.0 if Motion.reduce else clampf((_clock - _crown_at) / 0.5, 0.0, 1.0)
		var drop := (1.0 - Motion.back_out(k)) * 40.0 * u
		_over.draw_mesh(Art.crown(u), null, pod * Transform2D(-0.3, Vector2(-6.5 * u, -30.5 * u - drop)))

## The gun's line on the grass: a paper pill each for the pea's weight, the
## rate and the crit, a medallion on it and its number beside that.
func _gun_chip(k: int) -> Vector2:
	return px(Vector2(_gun_from() + 52.0 * k, Sim.H - 13.0))

## Where the gun's line begins, in field units (a tutorial page's rack
## stands over the garden's left, and the line begins past it).
func _gun_from() -> float:
	return 18.0

func _build_chips() -> ArrayMesh:
	var b := Face.Builder.new()
	for k in 3:
		var at := _gun_chip(k) + Vector2(-12.0, -9.5) * _u
		var size := Vector2(48.0, 19.0) * _u
		b.fan(Face.Builder.round_rect(at + Vector2(0, 1.8 * _u), size, 9.5 * _u), Color(0.2, 0.32, 0.1, 0.2))
		b.fan(Face.Builder.round_rect(at, size, 9.5 * _u), Art.CREAM)
	return b.mesh()

func _draw_gun_words(font: Font) -> void:
	var values := ["x%s" % Art.short(sim.power), "x%d" % (sim.rate_lv + 1), "x%d" % Sim.crit_mult(sim.crit_lv) if sim.crit_lv > 0 else "-"]
	var ink := Art.INK
	for k in 3:
		var text: String = values[k]
		var at := _gun_chip(k) + Vector2(10.5 * _u, _text_fs * 0.36)
		var sc := _bump(CHIP + int(GUN[k]))
		if sc != 1.0:
			_over.draw_set_transform(_shake_off + at, 0.0, Vector2(sc, sc))
			_over.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _text_fs, ink)
			_over.draw_set_transform(_shake_off)
		else:
			_over.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _text_fs, ink)

## The flowers the run has grown, each popping up out of the grass and
## nodding after.
func _draw_blooms() -> void:
	for bl: Dictionary in _blooms:
		var since: float = _clock - float(bl.at)
		var sc: float = bl.size
		var sway := 0.0
		if not Motion.reduce:
			sc *= Motion.back_out(clampf(since / 0.4, 0.0, 1.0))
			sway = sin(_clock * 1.7 + float(bl.x)) * 0.08 + 0.5 * exp(-since * 5.0) * sin(since * 16.0)
		if sc <= 0.01:
			continue
		_cast_add(Art.flower(bl.look, _u), Transform2D(sway, Vector2(sc, sc), 0.0, px(Vector2(bl.x, TURF + float(bl.y)))), Color.WHITE)

## The streak's pill, top and middle: paper, the count in ink (lettered by
## `_draw_streak_words`) and under it the time the streak has left, running
## down.
func _streak_rect() -> Rect2:
	var w := 78.0 * _u
	var h := 17.0 * _u
	var k := _streak_in if Motion.reduce else Motion.back_out(_streak_in)
	return Rect2(Vector2(_mid(0.0).x - w * 0.5, 7.0 * _u - (1.0 - k) * 30.0 * _u), Vector2(w, h))

func _draw_streak_pill(b: Face.Builder) -> void:
	if _streak_in <= 0.01:
		return
	var rect := _streak_rect()
	var r := rect.size.y * 0.5
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0, 1.8 * _u), rect.size, r), Color(0.3, 0.2, 0.08, 0.16))
	b.fan(Face.Builder.round_rect(rect.position, rect.size, r), Art.CREAM)
	var left := clampf(float(sim._streak_t) / Sim.STREAK_GAP, 0.0, 1.0) if sim.streak >= STREAK_FROM else 0.0
	var bar := Vector2(rect.size.x - r * 2.0, 2.0 * _u)
	var at := rect.position + Vector2(r, rect.size.y - 4.0 * _u)
	b.fan(Face.Builder.round_rect(at, bar, bar.y * 0.5), Color(Art.CREAM_DEEP, 0.7))
	if left > 0.03:
		b.fan(Face.Builder.round_rect(at, Vector2(bar.x * left, bar.y), bar.y * 0.5), HEAT.lerp(ALARM, _heat))

func _draw_streak_words(font: Font) -> void:
	if _streak_in <= 0.01 or _streak_n < STREAK_FROM:
		return
	var rect := _streak_rect()
	var text := tr("PP_STREAK") % _streak_n
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _text_fs).x
	var since := _clock - _streak_at
	var sc := 1.0 if Motion.reduce or since > 0.3 else 1.0 + 0.22 * exp(-since * 12.0)
	var c := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 - 1.2 * _u)
	_over.draw_set_transform(_shake_off + c, 0.0, Vector2(sc, sc))
	_over.draw_string(font, Vector2(-w * 0.5, _text_fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _text_fs, Art.INK.lerp(ALARM.darkened(0.35), _heat))
	_over.draw_set_transform(_shake_off)

## The pods' pill, under the streak's: what a crate's energy is times while
## two pods or more run together.
func _pair_rect() -> Rect2:
	var w := 78.0 * _u
	var h := 15.0 * _u
	var k := _pair_in if Motion.reduce else Motion.back_out(_pair_in)
	return Rect2(Vector2(_mid(0.0).x - w * 0.5, 27.0 * _u - (1.0 - k) * 50.0 * _u), Vector2(w, h))

func _draw_pair_pill(b: Face.Builder) -> void:
	if _pair_in <= 0.01:
		return
	var rect := _pair_rect()
	var r := rect.size.y * 0.5
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0, 1.8 * _u), rect.size, r), Color(0.3, 0.2, 0.08, 0.16))
	b.fan(Face.Builder.round_rect(rect.position, rect.size, r), Art.CREAM)

func _draw_pair_words(font: Font) -> void:
	if _pair_in <= 0.01:
		return
	var rect := _pair_rect()
	var text := tr("PP_PAIR") % _fig(1.0 + Sim.PAIR_PAY * (_pair_n - 1))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _text_fs).x
	_over.draw_string(font, rect.position + Vector2((rect.size.x - w) * 0.5, rect.size.y * 0.5 + _text_fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _text_fs, Art.INK)

## The stars a cleared wave is stamped, under its bonus: three seats, and a
## gold star popping onto each one earned.
func _draw_stars(b: Face.Builder) -> void:
	if _clear.is_empty():
		return
	var since: float = _clock - float(_clear.at)
	# they leave by shrinking: gold thinned over the sky goes to mud
	var out := 1.0 - clampf((since - 1.25) / 0.25, 0.0, 1.0)
	out *= out
	var seat := out if Motion.reduce else clampf((since - 0.15) / 0.2, 0.0, 1.0) * out
	for k in 3:
		var c := _star_at(k)
		var t := since - 0.35 - STAR_STEP * k
		var earned: bool = k < int(_clear.stars) and t > 0.0
		if seat > 0.02 and not (earned and t > 0.3):
			Rewards.star(b, c, 11.5 * _u * seat, STAR_OFF)
		if earned and out > 0.02:
			var sc := 1.0 if Motion.reduce else Motion.back_out(minf(1.0, t / 0.3))
			var turn := 0.0 if Motion.reduce else 0.5 * exp(-t * 6.0) * cos(t * 14.0)
			Rewards.star(b, c, 14.0 * _u * sc * out, Art.GOLD, turn)

## The gifts in the air: up off a crate and round in an arc to its button,
## or a short hop from a button into the pod's mouth, shrinking as it goes in.
func _draw_flights() -> void:
	for f: Dictionary in _flights:
		var k := clampf(float(f.t) / float(f.time), 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var from: Vector2 = f.from
		var used: bool = f.used
		var to := _flight_home(f)
		var bow := from.lerp(to, 0.35) + Vector2(0, (-22.0 if used else -48.0) * _u)
		var at := from.lerp(bow, e).lerp(bow.lerp(to, e), e)
		var sc := (lerpf(0.83, 0.34, e) if used else lerpf(1.0, 0.83, e)) * (1.0 + 0.25 * sin(e * PI))
		_cast_add(Art.token(f.kind, _u), Transform2D(0.0, Vector2(sc, sc), 0.0, at), Color.WHITE)
		if int(f.t * 60.0) % 3 == 0:
			_spark((at - _origin) / _u, (Art.GIFT[int(f.kind)] as Color).lerp(Color("fffaf0"), 0.4))
	_cast_draw()

## The numbers off a crate gone, lettered like stickers: popping big and
## settling, rising and drifting as they fade. One size of letter, swelled
## by the transform, so no glyph is cut twice.
func _draw_pops(font: Font) -> void:
	for p: Dictionary in _pops:
		var a := 1.0 - clampf((p.t - 0.45) / 0.35, 0.0, 1.0)
		var rise := 26.0 * _u * (1.0 - exp(-p.t * 4.5))
		var at := px(p.pos) + Vector2(p.drift * 10.0 * p.t, -rise)
		var fs := int((19.0 if p.big else 14.0) * _u)
		var sc := 1.0 if Motion.reduce else lerpf(0.4, 1.0, Motion.back_out(minf(1.0, p.t / 0.2)))
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var o := Vector2(-w * 0.5, 0)
		_over.draw_set_transform(_shake_off + at, 0.0, Vector2(sc, sc))
		_over.draw_string_outline(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, int(fs * 0.3)), Color(p.rim, a))
		_over.draw_string(font, o, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(p.col, a))
	_over.draw_set_transform(_shake_off)

## What the peas took off, each a hop from where it landed: one size of
## letter a look and no transform of its own, so a full gun's are a handful
## of glyphs in the frame's one run of them.
func _draw_nums(font: Font) -> void:
	if _nums.is_empty():
		return
	_over.draw_set_transform(_shake_off)
	var sizes := [int(8.5 * _u), int(12.0 * _u), int(17.0 * _u)]
	var at: Array = []
	for n: Dictionary in _nums:
		var t: float = n.t
		var hop := Vector2.ZERO
		if not Motion.reduce:
			hop = Vector2(float(n.vx) * t, -46.0 * t + 190.0 * t * t) * _u if n.fall else Vector2(0, -14.0 * t) * _u
		var fs: int = sizes[int(n.big)]
		var w := font.get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		at.append(px(n.pos) + hop + Vector2(-w * 0.5, fs * 0.36))
	for i in _nums.size():
		var n: Dictionary = _nums[i]
		var fs: int = sizes[int(n.big)]
		var a := 1.0 - clampf((float(n.t) - NUM_T * 0.6) / (NUM_T * 0.4), 0.0, 1.0)
		_over.draw_string_outline(font, at[i], n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, int(fs * 0.34)), Color(NUM_RIMS[int(n.look)], a))
	for i in _nums.size():
		var n: Dictionary = _nums[i]
		var fs: int = sizes[int(n.big)]
		var a := 1.0 - clampf((float(n.t) - NUM_T * 0.6) / (NUM_T * 0.4), 0.0, 1.0)
		_over.draw_string(font, at[i], n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(NUM_COLS[int(n.look)], a))

# --- the energy orbs ---

## A point of the garden, in field units, in the orbs' layer.
func _in_orbs(p: Vector2) -> Vector2:
	return _orb_layer.get_global_transform().affine_inverse() * (field.get_global_transform() * (px(p) + _shake_off))

## A crate worth `n` orbs is gone at `at`: its energy drifts out of it every
## way, each mote to hang a moment before it is drawn in.
func _drop_orbs(at: Vector2, n: int) -> void:
	if n <= 0 or _orb_layer == null:
		return
	if Motion.reduce:
		_orb_pulse = _clock
		return
	var shown := mini(mini(n, ORBS_A_CRATE), MAX_ORBS - _orbs.size())
	if shown <= 0:
		return
	var from := _in_orbs(at)
	var each := float(n) / shown
	var fat := sqrt(each)
	for i in shown:
		var way := Vector2.from_angle(randf() * TAU)
		var speed := randf_range(110.0, 380.0) * _u / 2.4 * (1.0 + 0.012 * shown)
		_orbs.append({"pos": from + way * 5.0 * _u, "vel": way * speed, "t": -ORB_GAP * 0.4 * i,
			"out": ORB_OUT * randf_range(1.0, 1.7) + ORB_GAP * i, "from": from, "bend": randf_range(-1.0, 1.0), "val": each,
			"size": randf_range(0.7, 1.2) * fat, "seed": randf() * 100.0, "gone": 0.0})
	_orb_due += n

## Each mote: let go and slowing, lifting a little as warm light does, then
## round its bend to the plate, slow and then quick, a speck of dust left
## every DUST_STEP of the way. One that lands is counted, heard as the next
## note up a short run, and seen as a glow on the plate.
func _step_orbs(delta: float) -> void:
	if _orbs.is_empty():
		_orb_due = 0.0
		return
	var to := _orb_layer.get_global_transform().affine_inverse() * (_energy_l.get_global_transform() * (_energy_l.size * 0.5))
	var landed := 0
	var slow := exp(-5.5 * delta)
	var lift := 26.0 * _u / 2.4 * delta
	var stride := DUST_STEP * _u
	for o: Dictionary in _orbs:
		o.t += delta
		var t: float = o.t
		if t < 0.0:
			continue
		var was: Vector2 = o.pos
		if t < float(o.out):
			var v: Vector2 = o.vel
			v *= slow
			o.vel = v
			o.pos = was + v * delta + Vector2(0, -lift)
			o.from = o.pos
		else:
			var k := clampf((t - float(o.out)) / ORB_IN, 0.0, 1.0)
			var e := k * k * (0.35 + 0.65 * k)
			var from: Vector2 = o.from
			var side := (to - from).orthogonal() * 0.28 * float(o.bend)
			var mid := from.lerp(to, 0.4) + side
			o.pos = from.lerp(mid, e).lerp(mid.lerp(to, e), e)
			o.gone = float(o.gone) + was.distance_to(o.pos)
			if float(o.gone) >= stride:
				o.gone = 0.0
				_leave_dust(was, float(o.size))
			if k >= 1.0:
				o.t = INF
				landed += 1
				_orb_due -= float(o.val)
	if landed > 0:
		_orbs = _orbs.filter(func(o: Dictionary) -> bool: return o.t != INF)
		_orb_pulse = _clock
		if _clock - _orb_heard >= 0.045:
			# a run of notes up the scale while they keep landing
			_orb_note = _orb_note + 1 if _clock - _orb_heard < 0.3 else 0
			_orb_heard = _clock
			_quiet.cue("hit", 1.5 * pow(2.0, mini(_orb_note, 14) / 12.0), -13.0)
		if _energy_l.scale.x <= 1.01:
			_energy_l.pivot_offset = _energy_l.size * 0.5
			_beat(_energy_l, 0.16, 0.16)

## A speck of light left where a mote just was, a little off its line.
func _leave_dust(at: Vector2, size: float) -> void:
	if (_dust.size() >> 2) - _dust_from >= MAX_DUST:
		return
	if _dust_from > 256:
		_dust = _dust.slice(_dust_from * 4)
		_dust_from = 0
	_dust.append(at.x + randf_range(-2.0, 2.0) * _u)
	_dust.append(at.y + randf_range(-2.0, 2.0) * _u)
	_dust.append(_clock)
	_dust.append(size * randf_range(0.26, 0.46))

## Nothing is left in the air: the shop counts what there is.
func _land_orbs() -> void:
	_orbs.clear()
	_orb_due = 0.0
	_dust.clear()
	_dust_from = 0

## The motes, their dust under them and the glow on the plate as one lands,
## all one mesh: a mote swells out of its crate, breathes where it hangs
## (each to its own time) and stays round on its way in, dimming a little as
## it nears the plate; a speck of dust shrinks and goes out.
func _draw_orbs() -> void:
	var glow := 0.0 if Motion.reduce else clampf(1.0 - (_clock - _orb_pulse) / 0.3, 0.0, 1.0)
	if _orbs.is_empty() and (_dust.size() >> 2) <= _dust_from and glow <= 0.0:
		_orb_count = 0
		return
	var most := MAX_ORBS + MAX_DUST + 1
	if _orb_mm == null:
		_orb_mm = MultiMesh.new()
		_orb_mm.transform_format = MultiMesh.TRANSFORM_2D
		_orb_mm.use_colors = true
		_orb_mm.mesh = Art.orb()
		_orb_mm.instance_count = most
		_orb_light_mm = MultiMesh.new()
		_orb_light_mm.transform_format = MultiMesh.TRANSFORM_2D
		_orb_light_mm.use_colors = true
		_orb_light_mm.mesh = Art.orb_light()
		_orb_light_mm.instance_count = most
		_orb_buf.resize(most * 12)
	var n := 0
	var base := 11.5 * _u / Art.ORB_R
	# the dust first, under the motes; what has gone out is passed over for good
	var specks := _dust.size() >> 2
	while _dust_from < specks and _clock - _dust[_dust_from * 4 + 2] >= DUST_T:
		_dust_from += 1
	for d in range(_dust_from, specks):
		var age := (_clock - _dust[d * 4 + 2]) / DUST_T
		n = _orb_put(n, Vector2(_dust[d * 4], _dust[d * 4 + 1] - 7.0 * _u * age), base * _dust[d * 4 + 3] * (1.0 - 0.5 * age), 1.0 - age * age)
	if glow > 0.0:
		var plate := _orb_layer.get_global_transform().affine_inverse() * (_energy_l.get_global_transform() * (_energy_l.size * 0.5))
		n = _orb_put(n, plate, base * (2.2 + 1.6 * (1.0 - glow)), 0.55 * glow * glow)
	for o: Dictionary in _orbs:
		var t: float = o.t
		if t < 0.0 or n >= most:
			continue
		var seed: float = o.seed
		var out: float = o.out
		var swell := 1.0 - pow(1.0 - minf(1.0, t / 0.22), 3.0)
		var breath := 1.0 + 0.13 * sin(_clock * 4.6 + seed)
		var near := clampf((t - out) / ORB_IN, 0.0, 1.0)
		var s: float = base * float(o.size) * swell * breath * (1.0 - 0.3 * near * near)
		var at: Vector2 = o.pos
		# hanging, it wanders a little on the air
		at += Vector2(sin(_clock * 2.3 + seed), cos(_clock * 1.9 + seed * 1.7)) * 1.6 * _u * (1.0 - near)
		n = _orb_put(n, at, s, 0.84 + 0.16 * sin(_clock * 6.1 + seed * 3.0))
	_orb_count = n
	if n == 0:
		return
	_orb_mm.visible_instance_count = n
	_orb_mm.buffer = _orb_buf
	_orb_layer.draw_multimesh(_orb_mm, null)

## One more light this frame: at `at`, `s` times the mesh, `a` of its glow.
func _orb_put(n: int, at: Vector2, s: float, a: float) -> int:
	var i := n * 12
	_orb_buf[i] = s
	_orb_buf[i + 1] = 0.0
	_orb_buf[i + 3] = at.x
	_orb_buf[i + 4] = 0.0
	_orb_buf[i + 5] = s
	_orb_buf[i + 7] = at.y
	_orb_buf[i + 8] = 1.0
	_orb_buf[i + 9] = 1.0
	_orb_buf[i + 10] = 1.0
	_orb_buf[i + 11] = a
	return n + 1

## The light the motes throw: the same lights again, added to what is under
## them. Drawn after `_draw_orbs` (its layer is that one's child), off the
## buffer that filled.
func _draw_orb_light() -> void:
	if _orb_count == 0 or _orb_light_mm == null:
		return
	_orb_light_mm.visible_instance_count = _orb_count
	_orb_light_mm.buffer = _orb_buf
	_orb_light.draw_multimesh(_orb_light_mm, null)

# --- the shop ---

## A wave is cleared and there is energy for something: the shop's card over
## the garden, the run stopped behind it until Go.
func _open_shop() -> void:
	if _shop != null:
		return
	_touch = -1
	_mouse = false
	sim.target_x = NAN
	_land_orbs()
	_shop = _build_shop()
	add_child(_shop)
	_refresh_shop()
	Motion.appear(_shop, 0.0, 1.0, 0.2)
	_fx.cue("gift")

func _close_shop() -> void:
	if _shop == null:
		return
	_shop.queue_free()
	_shop = null
	_shop_rows.clear()
	sim.leave_shop()
	_fx.cue("go")
	_fx.buzz(Haptics.TAP)

func _build_shop() -> Control:
	var scrim := Dialog.scrim()
	scrim.name = "Shop"
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var card := Dialog.card(820)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	card.add_child(col)
	# the energy held, on a pill at the head's right
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 14))
	var held := HBoxContainer.new()
	held.add_theme_constant_override("separation", 10)
	pill.add_child(held)
	held.add_child(_orb_icon(46.0))
	_shop_energy = Label.new()
	_shop_energy.theme_type_variation = "SheetTitle"
	held.add_child(_shop_energy)
	col.add_child(Dialog.head("PP_SHOP", "trend", pill))
	var line := Label.new()
	line.text = tr("PP_SHOP_LINE") % sim.wave
	line.theme_type_variation = "SheetBodyDim"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	_shop_rows.clear()
	for card_id: int in SHOP_ORDER:
		col.add_child(_shop_row(card_id))
	var go := Dialog.primary("play", tr("PP_SHOP_GO"))
	go.name = "Go"
	go.pressed.connect(_close_shop)
	Dialog.buttons(col, go)
	return scrim

## A shop card's medallion, `side` pixels square.
func _card_icon(card: int, side: float) -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(side, side)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		icon.draw_mesh(Art.card_token(card, side / 27.0, sim.cart), null, Transform2D(0.0, icon.size * 0.5)))
	return icon

## A mote of energy, `side` pixels square: what a price is counted in.
func _orb_icon(side: float) -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(side, side)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		var sc := side * 0.9 / Art.ORB_R
		icon.draw_mesh(Art.orb(), null, Transform2D(0.0, Vector2(sc, sc), 0.0, icon.size * 0.5)))
	return icon

## One card of the shop: the whole row is the button. Its medallion, its
## name over what it is now and what one more makes it, and its price.
func _shop_row(card: int) -> Button:
	var b := Button.new()
	b.name = "Card%d" % card
	b.custom_minimum_size = Vector2(0, 132)
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, Dialog.tile(Pal.SURFACE, 16))
	b.add_theme_stylebox_override("pressed", Dialog.tile(Pal.SURFACE.darkened(0.06), 16))
	b.add_theme_stylebox_override("disabled", Dialog.tile(Color(Pal.SURFACE, 0.5), 16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 22.0
	row.offset_right = -26.0
	row.add_child(_card_icon(card, 88.0))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -4)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var title := Label.new()
	title.text = OWN_NAMES[sim.cart] if card == Sim.Card.SHOTS else SHOP_NAMES[card]
	title.theme_type_variation = "SheetTitle"
	words.add_child(title)
	title.clip_text = true
	var value := Label.new()
	value.theme_type_variation = "SheetBodyDim"
	# a long language's line is cut, never the price pushed off the card
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(value)
	row.add_child(_orb_icon(34.0))
	var cost := Label.new()
	cost.theme_type_variation = "SheetTitle"
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.custom_minimum_size.x = 62
	row.add_child(cost)
	b.pressed.connect(_buy.bind(card))
	_shop_rows.append({"card": card, "button": b, "value": value, "price": cost, "row": row})
	return b

## What `card` is now and what one more makes it, in figures only.
func _card_value(card: int) -> String:
	if sim.maxed(card):
		return tr("PP_CARD_MAX")
	match card:
		Sim.Card.DAMAGE:
			return "x%d  >  x%d" % [sim.power, sim.power + 1]
		Sim.Card.SPEED:
			return tr("PP_CARD_SPEED_LINE") % [_fig(sim.rate()), _fig(sim.rate() + sim.rate_step())]
		Sim.Card.CRIT:
			var lv: int = sim.crit_lv
			var line := tr("PP_CARD_CRIT_LINE") % [Sim.crit_mult(lv), Sim.crit_mult(lv + 1), roundi(Sim.crit_chance(lv + 1) * 100.0)]
			# with none bought there is no crit to go on from
			return line if lv > 0 else line.substr(line.find(">") + 1).strip_edges()
		Sim.Card.SHOTS:
			return _own_value()
	return tr("PP_CARD_ENERGY_LINE") % [roundi(sim.energy_lv * Sim.ENERGY_STEP * 100.0), roundi((sim.energy_lv + 1) * Sim.ENERGY_STEP * 100.0)]

## A figure as the shop letters it: whole when it is, else to a tenth.
static func _fig(v: float) -> String:
	return str(roundi(v)) if absf(v - roundf(v)) < 0.05 else "%.1f" % v

## What the cart's own card is now and what one more makes it.
func _own_value() -> String:
	var line := tr(OWN_LINES[sim.cart])
	match sim.cart:
		Sim.Cart.CONKER:
			return line % [sim.hops(), sim.hops() + 1]
		Sim.Cart.PUMPKIN:
			return line % [roundi(sim.blast_r()), roundi(sim.blast_r() + Sim.BLAST_STEP)]
		Sim.Cart.HOSE:
			return line % [_fig(sim.jet_cap()), _fig(sim.jet_cap() + Sim.JET_CAP_STEP)]
		Sim.Cart.DANDELION:
			return line % [sim.seeds(), sim.seeds() + Sim.SEED_STEP]
		Sim.Cart.TWINS:
			return line % [roundi(sim.twin_share() * 100.0), roundi((sim.twin_share() + Sim.TWIN_STEP) * 100.0)]
	return line % [sim.peas, sim.peas + 1]

func _refresh_shop() -> void:
	_shop_energy.text = Record.grouped(int(sim.energy / Sim.ORBS))
	for r: Dictionary in _shop_rows:
		var card: int = r.card
		var open: bool = sim.can_buy(card)
		(r.value as Label).text = _card_value(card)
		(r.price as Label).text = "" if sim.maxed(card) else Record.grouped(int(sim.price(card) / Sim.ORBS))
		(r.button as Button).disabled = not open
		(r.row as Control).modulate.a = 1.0 if open else 0.45

func _buy(card: int) -> void:
	if not sim.buy(card):
		return
	_fx.cue("catch", 1.0 + 0.04 * int(sim.bought[card]))
	_fx.buzz(Haptics.TAP)
	_chip_at[CHIP + card] = _clock
	for r: Dictionary in _shop_rows:
		if int(r.card) == card:
			var b: Button = r.button
			b.pivot_offset = b.size * 0.5
			_beat(b, 0.05, 0.2)
	_refresh_shop()

# --- the rewards ---

## A point of the garden, in field units, in the rewards layer's pixels.
func _in_rw(p: Vector2) -> Vector2:
	return _rw.at(field, px(p) + _shake_off)

func _plate_at(l: Label) -> Vector2:
	return _rw.at(l, l.size * 0.5)

func _new_best_passed() -> void:
	_rw.sticker(tr("FF_NEW_BEST"), _rw.at(field, _mid(0.2)), 66, 1.8, true, Color.WHITE, true, "best")
	_rw.spray(_plate_at(_best_l), Pal.SUN, 14, 620.0, "star", 1.0)
	_rw.spray(_plate_at(_best_l), Art.GOLD, 10, 620.0, "coin", 1.0)
	_rw.ring(_plate_at(_best_l), 160.0, Color(Pal.SUN, 0.9))
	_rw.rain(1.6, ["confetti", "star"], STICKER_COLS)
	_fx.cue("word", 1.3, -3.0)
	_feel(Haptics.BUMP)
	# the pod is crowned, and the sun puts its party hat on
	_crown_at = _clock
	if _sun != null:
		if Motion.reduce:
			_sun.hat = 1.0
		else:
			_sun.create_tween().tween_property(_sun, "hat", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The garden flashes `col`, `amount` at most.
func _flash_now(col: Color, amount: float) -> void:
	if Motion.reduce:
		return
	_flash = maxf(_flash, amount)
	_flash_col = col

# --- the end ---

func _game_over() -> void:
	if _offer_chance():
		return
	var better := Record.add(GAME, sim.score, sim.wave, _boosted)
	_run_gold = Wallet.pay_run(better)
	var secs := int((Time.get_ticks_msec() - _started_at) / 1000.0)
	Analytics.track("arcade_end", {"game": GAME, "score": sim.score, "stage": sim.wave,
		"seconds": secs, "kills": sim.kills, "caught": sim.caught, "used": sim.used, "fired": sim.fired,
		"rate": sim.rate_lv, "power": sim.power, "crit": sim.crit_lv, "peas": sim.peas, "energy": int(sim.earned / Sim.ORBS), "best": better,
		"cart": sim.cart, "own": sim.special})
	Ads.note_finished()
	_show_banner(tr("FF_GAME_OVER"), "", 1.2)
	top_bar.refresh(self)
	get_tree().create_timer(1.6).timeout.connect(_show_end.bind(better))

func _show_end(better: bool) -> void:
	if sim == null or not sim.is_over() or _end != null:
		return
	_fx.cue("new_best" if better else "game_over")
	_end = _build_end(better)
	add_child(_end)
	# the rewards (their rain and bursts) stay over the card
	move_child(_rw, get_child_count() - 1)
	_rw.bounds = Rect2()
	Motion.appear(_end, 0.0, 1.0, 0.3)
	_end_at = _clock
	_celebrate(better)

func _build_end(better: bool) -> Control:
	var scrim := Dialog.scrim()
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var card := Dialog.card(820)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	var seat := Control.new()
	seat.custom_minimum_size = Vector2(0, 226)
	seat.clip_contents = true
	# The cart on a tuft of grass, still firing: peas going up out of the pod
	# in a row, a sunburst turning behind it once the card is up.
	var u := 3.4
	var shown_at := _clock
	var grown: Array = []
	for i in mini(_blooms.size(), 8):
		grown.append(int(_blooms[i].look))
	seat.draw.connect(func() -> void:
		var t := 0.0 if Motion.reduce else _clock
		var c := Vector2(seat.size.x * 0.5, 178.0)
		var b := Face.Builder.new()
		var glow := 1.0 if Motion.reduce else clampf((_clock - shown_at - 0.5) / 0.35, 0.0, 1.0)
		if glow > 0.0:
			var rc := c + Vector2(0, -70.0)
			var rr := 200.0 * Motion.back_out(glow)
			b.disc(rc, rr * 0.5, Color(Color("fff4c2"), 0.45))
			Rewards.sunrays(b, rc, rr * 0.2, rr, 14, t * 0.5, Color(Art.GOLD if better else Pal.SUN, 0.5))
			Rewards.sunrays(b, rc, rr * 0.2, rr * 0.75, 8, -t * 0.3, Color(Color("fffaf0"), 0.4))
		b.ellipse(c + Vector2(0, 34.0), 150.0, 22.0, GRASS_DEEP)
		b.ellipse(c + Vector2(0, 30.0), 142.0, 17.0, GRASS)
		for k in 4:
			var up := fmod(t * 1.6 + k * 0.25, 1.0)
			Art.pea(b, c + Vector2(0, -44.0 * u - up * 120.0), 3.4 * u, 1.0 - up)
		var m := b.mesh()
		seat.set_meta("keep", m)
		seat.draw_mesh(m, null)
		var kick := 0.0 if Motion.reduce else maxf(0.0, 1.0 - fmod(t * 1.6, 0.25) / 0.09)
		var foot := c + Vector2(0, 21.0 - 9.0 * u + 9.0 * u)
		seat.draw_mesh(Art.barrel(u, false, 0, sim.cart), null, Transform2D(0.0, Vector2(1.0 + 0.1 * kick, 1.0 - 0.14 * kick), 0.0, foot + Vector2(0, (-12.0 + 4.0 * kick) * u)))
		seat.draw_mesh(Art.cart(u), null, Transform2D(0.0, foot))
		for side in [-1.0, 1.0]:
			seat.draw_mesh(Art.wheel(u), null, Transform2D(sin(t * 1.3) * 0.4, foot + Vector2(side * 13.0 * u, 0)))
		if better:
			seat.draw_mesh(Art.crown(u), null, Transform2D(-0.3, foot + Vector2(-6.5 * u, (-42.5 + 4.0 * kick) * u)))
		# the flowers the run grew, in a row either side of the cart
		for i in grown.size():
			var side := -1.0 if i % 2 == 0 else 1.0
			var at := c + Vector2(side * (92.0 + 19.0 * (i / 2)), 30.0 + 3.0 * (i % 3))
			seat.draw_mesh(Art.flower(grown[i], 2.6), null, Transform2D(sin(t * 1.7 + i) * 0.08, at)))
	col.add_child(seat)
	_seat = seat
	var head := Label.new()
	head.text = "FF_NEW_BEST" if better else "PP_END_CARD"
	head.theme_type_variation = "WellDone"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# the longer languages take two lines rather than widen the card
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = 740
	col.add_child(head)
	var score := Label.new()
	score.text = Record.grouped(sim.score) if Motion.reduce else "0"
	if not Motion.reduce:
		_end_score = score
	score.theme_type_variation = "DayBig"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(score)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 14)
	for pair in [[str(sim.wave), "PP_STAT_WAVE"], [Record.grouped(sim.kills), "PP_STAT_CRATES"], [str(sim.caught), "PP_STAT_GIFTS"]]:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.add_theme_stylebox_override("panel", Dialog.tile())
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", -4)
		plate.add_child(words)
		var value := Label.new()
		value.text = pair[0]
		value.theme_type_variation = "SheetTitle"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(value)
		var kicker := Label.new()
		kicker.text = pair[1]
		kicker.theme_type_variation = "MenuKicker"
		kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.add_child(kicker)
		stats.add_child(plate)
		if not Motion.reduce:
			var i := stats.get_child_count() - 1
			plate.modulate.a = 0.0
			plate.resized.connect(func() -> void: plate.pivot_offset = plate.size * 0.5)
			plate.scale = Vector2(0.4, 0.4)
			var tw := plate.create_tween().set_parallel(true)
			tw.tween_property(plate, "modulate:a", 1.0, 0.2).set_delay(1.3 + 0.15 * i)
			tw.tween_property(plate, "scale", Vector2.ONE, 0.4).set_delay(1.3 + 0.15 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	col.add_child(stats)
	var best_line := Label.new()
	best_line.text = tr("FF_BEST_LINE") % Record.grouped(Record.best(GAME))
	best_line.theme_type_variation = "SheetBodyDim"
	best_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(best_line)
	var news := _cart_news()
	if news[0] != "":
		var cart_line := Label.new()
		cart_line.name = "CartNews"
		cart_line.text = news[0]
		cart_line.theme_type_variation = "SheetBody" if news[1] else "SheetBodyDim"
		cart_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cart_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cart_line.custom_minimum_size.x = 740
		if news[1]:
			cart_line.add_theme_color_override("font_color", Art.GOLD_INK)
		col.add_child(cart_line)
	var again := Dialog.primary("reset", tr("FF_AGAIN"))
	again.name = "Again"
	again.pressed.connect(_ask)
	var back := Dialog.secondary("chevron_left", tr("FF_BACK"))
	back.pressed.connect(_on_back)
	Dialog.buttons(col, again, back, GoldDoubler.new(_run_gold) if _run_gold > 0 else null)
	return scrim

## The end card's score runs up from nothing to what the run made, with a
## burst of coins when it gets there.
func _count_end() -> void:
	var k := clampf((_clock - _end_at - 0.4) / 1.1, 0.0, 1.0)
	var shown := int(sim.score * (1.0 - pow(1.0 - k, 3.0)))
	var text := Record.grouped(shown)
	if _end_score.text != text:
		_end_score.text = text
		if int(_clock * 20.0) % 2 == 0:
			_quiet.cue("hit", 0.95 + 0.3 * k, -8.0)
	if k >= 1.0:
		_end_score.pivot_offset = _end_score.size * 0.5
		_beat(_end_score, 0.25, 0.4)
		var at := _rw.at(_end_score, _end_score.size * 0.5)
		_rw.spray(at, Pal.SUN, 12, 620.0, "star", 1.1)
		_rw.spray(at, Art.GOLD, 12, 620.0, "coin", 1.1)
		_rw.spray(at, Color("fffaf0"), 8, 480.0, "spark", 1.1)
		_rw.ring(at, 220.0, Color(Pal.SUN, 0.9))
		_end_score = null

func _celebrate(better: bool) -> void:
	var card: Control = _end.get_node("Center/Card")
	if Motion.reduce:
		return
	card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, 200.0)
	card.scale = Vector2.ONE * 0.86
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not better:
		return
	_rw.rain(3.5, ["confetti", "coin", "star"], STICKER_COLS)
	var fx := Fx2D.new()
	_end.add_child(fx)
	var cols := [Art.GOLD, Art.POD, Art.CARD[Sim.Card.CRIT], Pal.FLOWER, Pal.SUN_RAY, Art.CARD[Sim.Card.SPEED]]
	var mid := size * 0.5
	for k in 8:
		var at := mid + Vector2.from_angle(TAU * k / 8.0 - PI * 0.5) * Vector2(400.0, 330.0)
		var t := get_tree().create_timer(0.25 + 0.14 * k)
		t.timeout.connect(func() -> void:
			if is_instance_valid(fx):
				fx.puff(at, cols[k % cols.size()], 12))

# --- chrome ---

func _on_reset() -> void:
	if sim != null and not sim.is_over():
		Analytics.track("board_reset", {"puzzle_id": GAME})
	_ask()

func _on_back() -> void:
	if sim != null and not sim.is_over() and sim.score > 0:
		Analytics.track("arcade_abandon", {"game": GAME, "score": sim.score, "stage": sim.wave})
	closed.emit()

## Android's back, through the menu: a sheet first, then the screen.
func go_back() -> void:
	if tutor.close():
		return
	if _shop != null:
		_close_shop()
		return
	if _cart_card != null:
		_on_back()
		return
	if settings_sheet.is_open():
		settings_sheet.close()
		return
	_on_back()

# --- the carts ---

## Whether cart `c` (Sim.Cart) is this player's to roll out: the furthest
## wave reached is its mark or past it.
static func cart_open(c: int) -> bool:
	return Record.best_stage(GAME) >= int(CART_WAVE[c])

## What the end card says of the carts, as [the line, whether it is news]:
## the cart this run opened, else the next one and the wave it wants, else
## nothing.
func _cart_news() -> Array:
	var stage := Record.best_stage(GAME)
	for c in range(Sim.Cart.size() - 1, 0, -1):
		if _stage_was < int(CART_WAVE[c]) and stage >= int(CART_WAVE[c]):
			return [tr("PP_CART_NEW") % tr(CART_NAMES[c]), true]
	for c in range(1, Sim.Cart.size()):
		if stage < int(CART_WAVE[c]):
			return [tr("PP_CART_NEXT") % [int(CART_WAVE[c]), tr(CART_NAMES[c])], false]
	return ["", false]

## The carts' card: a tile a cart, the open ones to be chosen (the last one
## rolled out first), the rest showing the wave that opens them; under them
## what the chosen one does, and Play.
func _build_carts() -> Control:
	var scrim := Dialog.scrim()
	scrim.name = "CartCard"
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)
	var card := Dialog.card(900)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	card.add_child(col)
	col.add_child(Dialog.head("PP_CART_PICK", "arcade"))
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	col.add_child(grid)
	_cart_tiles.clear()
	for c in Sim.Cart.size():
		grid.add_child(_cart_tile(c))
	_cart_line = Label.new()
	_cart_line.theme_type_variation = "SheetBodyDim"
	_cart_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cart_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cart_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cart_line.custom_minimum_size = Vector2(800, 132)
	col.add_child(_cart_line)
	var go := Dialog.primary("play", tr("PP_CART_GO"))
	go.name = "Go"
	go.pressed.connect(_carts_done)
	Dialog.buttons(col, go)
	_pick_cart(_cart, false)
	return scrim

## One cart's tile: the cart itself, its name, and on one not yet opened the
## wave that opens it. The whole tile is the button.
func _cart_tile(c: int) -> Button:
	var open := cart_open(c)
	var b := Button.new()
	b.name = "Cart%d" % c
	b.custom_minimum_size = Vector2(264, 250)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not open
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	words.offset_top = 10.0
	words.offset_bottom = -14.0
	words.add_theme_constant_override("separation", -4)
	b.add_child(words)
	var pic := Control.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.modulate.a = 1.0 if open else 0.36
	pic.draw.connect(func() -> void:
		var u := 2.7
		var foot := Vector2(pic.size.x * 0.5, pic.size.y - 9.0 * u - 4.0)
		var carts := [[foot, u, false]]
		if c == Sim.Cart.TWINS:
			carts = [[foot + Vector2(-46.0, 3.0), u * 0.8, true], [foot + Vector2(30.0, 0), u, false]]
		for k: Array in carts:
			var at: Vector2 = k[0]
			var ku: float = k[1]
			pic.draw_mesh(Art.barrel(ku, k[2], 0, c), null, Transform2D(0.0, at + Vector2(0, -12.0 * ku)))
			pic.draw_mesh(Art.cart(ku, k[2]), null, Transform2D(0.0, at))
			for side: float in [-1.0, 1.0]:
				pic.draw_mesh(Art.wheel(ku), null, Transform2D(0.3, at + Vector2(side * 13.0 * ku, 0))))
	words.add_child(pic)
	var title := Label.new()
	title.text = CART_NAMES[c]
	title.theme_type_variation = "SheetBody"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(Art.INK, 1.0 if open else 0.5))
	title.clip_text = true
	words.add_child(title)
	var sub := Label.new()
	sub.text = "" if open else tr("PP_CART_LOCKED") % int(CART_WAVE[c])
	sub.theme_type_variation = "MenuKicker"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(sub)
	b.pressed.connect(_pick_cart.bind(c))
	_cart_tiles.append(b)
	return b

## Cart `c` is the one chosen: its tile ringed in its own colour, and what
## it does lettered under the tiles.
func _pick_cart(c: int, by_hand := true) -> void:
	_cart = c
	for k in _cart_tiles.size():
		var b: Button = _cart_tiles[k]
		var box := Dialog.tile(Pal.SURFACE if cart_open(k) else Color(Pal.SURFACE, 0.5), 12)
		if k == c:
			box.set_border_width_all(6)
			box.border_color = Art.deepen(Art.CART[k])
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, box)
	if _cart_line != null:
		_cart_line.text = tr(CART_LINES[c])
	if by_hand:
		_fx.cue("catch", 1.0 + 0.05 * c, -4.0)
		_fx.buzz(Haptics.TAP)
		var b: Button = _cart_tiles[c]
		b.pivot_offset = b.size * 0.5
		_beat(b, 0.05, 0.2)

## Play, on the carts' card: the cart is kept for next time, and the run
## goes on to its boosters.
func _carts_done() -> void:
	Record.set_pick(GAME, _cart)
	if _cart_card != null:
		_cart_card.queue_free()
		_cart_card = null
	_cart_tiles.clear()
	_cart_line = null
	_ask_boosts(true)

# --- boosters (arcade/boosters.gd) ---

## Before a run: the carts' card, once the player has more than one to
## choose from, and then the boosters. A run still going when it is asked
## for stops there.
func _ask(by_hand := true) -> void:
	if get_node_or_null("BoostCard") != null or get_node_or_null("SecondChance") != null or _cart_card != null:
		return
	if _end != null:
		_end.queue_free()
		_end = null
	if force_cart >= 0:
		_cart = force_cart
	else:
		_cart = Record.pick(GAME)
		if _cart < 0 or _cart >= Sim.Cart.size() or not cart_open(_cart):
			_cart = Sim.Cart.PEA
		if cart_open(Sim.Cart.CONKER):
			if sim != null and not sim.is_over():
				sim = null
			_cart_card = _build_carts()
			add_child(_cart_card)
			Motion.appear(_cart_card, 0.0, 1.0, 0.2)
			return
	_ask_boosts(by_hand)

## The boost card, when a booster is held or the gold for one is, else
## straight in.
func _ask_boosts(by_hand := true) -> void:
	if get_node_or_null("BoostCard") != null:
		return
	if not BoostCard.wanted(GAME):
		_boosts = []
		_new_game()
		# Restart and Play again tap; the screen opening says nothing.
		if by_hand:
			_fx.buzz(Haptics.TAP)
		return
	if sim != null and not sim.is_over():
		sim = null
	var card := BoostCard.new(GAME)
	card.name = "BoostCard"
	card.play.connect(func(ids: Array) -> void:
		_boosts = ids
		_new_game()
		_fx.buzz(Haptics.TAP))
	add_child(card)

## At game over, once a run: the Second chance, when one is held or the gold
## for one is. True while it is up; No thanks ends the run as it would have.
func _offer_chance() -> bool:
	if _chance_used or not SecondChance.wanted():
		return false
	_chance_used = true
	var card := SecondChance.new(GAME)
	card.name = "SecondChance"
	card.taken.connect(func() -> void:
		_boosted = true
		Boosters.revive(GAME, sim)
		_fx.buzz(Haptics.GOOD)
		_show_banner(tr("CHANCE_GO"), "", 1.0)
		_play_events()
		top_bar.refresh(self))
	card.declined.connect(_game_over)
	add_child(card)
	return true
