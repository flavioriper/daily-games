extends RefCounted

## Firefly's whole game as pure data: the first game on the Arcade tab, a
## formation shooter re-dressed as a night garden (spec
## docs/superpowers/specs/2026-09-27-arcade-firefly-design.md). The screen
## (arcade/firefly_screen.gd) steps it at a fixed DT, hands it the player's
## hands (`target_x`, `axis`, `fire`) and draws what it holds; it reads
## `events` after every step for sounds and bursts.
##
## Field units, not pixels: the field is W by H with y down, and the screen
## scales it to fit. The cast: the firefly (you), gnats (50 in the swarm and
## 100 diving), ladybirds (`Kind.BEETLE` in code: 80 and 160) and moths (150
## in the swarm, 400 diving and doubled for each escort shot down before
## them). A moth may dive alone and spin a silk beam: a firefly caught in it
## is carried up and lost, and hangs under the moth in the swarm; shoot that
## moth while it is diving and the firefly comes back and flies beside yours,
## two shots at once. Shoot it in the swarm instead and the captive turns
## rogue.
##
## In stages (2026-10-17, docs/superpowers/plans/2026-10-17-firefly-stages.md,
## the design as data in docs/brainstorm/firefly-stages.py): a run is one
## stage of STAGES at one of four difficulties (DIFF, 0 Easy to 3 Insane),
## and it ends WON (the swarm shot down, or a flyby flown) or OVER (the last
## firefly lost). There is no shop and nothing grows: the gun is the same on
## every stage, one shot a volley, RATE volleys a second. What a stage brings
## is its swarm, its numbers and its rules, each rule a flag the stage names
## (`has()`); and a goal, counted here, which once met gives a buff for the
## rest of the stage.

const W := 240.0
const H := 372.0
const DT := 1.0 / 120.0

const PLAYER_Y := H - 24.0
const PLAYER_SPEED := 190.0
const PLAYER_R := 6.0
## The half-gap between the two ships of a pair.
const PAIR := 8.0
const SHOT_SPEED := 420.0
const SHOT_R := 2.0
## Volleys a second, and with the Quicker gun.
const RATE := 3.0
const RATE_QUICK := 4.5
## The most volleys one step lets go, however quick the gun.
const FIRE_MOST := 2
## How far apart a volley's shots leave, side by side, and how wide the row
## is at its most.
const SHOT_GAP := 5.0
const SHOT_ROW := 18.0
const ENEMY_R := 7.0
const BULLET_R := 2.0

const COLS := 10
const SLOT_DX := 20.0
const SLOT_DY := 17.0
const FORM_TOP := 46.0
## How far a captive hangs above its moth.
const CAPTIVE_UP := 13.0

## Speeds before the stage's swarm speed: flying in, diving, a beam run, and
## a flyby's passers.
const ENTER_SPEED := 120.0
const DIVE_SPEED := 100.0
const BEAM_SPEED := 90.0
const FLY_SPEED := 138.0
## Seconds between one wave's start and the next: 2.9 until the hot
## entrances of stage 6, 2.6 from there (the page names only stage 6's).
const WAVE_GAP := 2.9
const WAVE_GAP_HOT := 2.6
## Two kills this close together keep a chain going.
const CHAIN_GAP := 1.5
## How wide a ladybird's fan of three seeds opens, and how far apart its two
## side-by-side seeds leave.
const FAN := 38.0
const TWIN_SEED := 3.5
## The beam: opening, held open to, closed by (seconds), and how far either
## side of the moth it catches when full.
const BEAM_OPEN := 0.8
const BEAM_OPEN_SLOW := 1.2
const BEAM_HELD := 3.4
const BEAM_CLOSE := 0.7
const BEAM_REACH := 13.0
## A drifting beam's slide toward the firefly, a second.
const BEAM_DRIFT := 12.0
## A lone moth's dive is a beam run this often, and on stage 13.
const BEAM_CHANCE := 0.55
const BEAM_OFTEN := 0.75
## Stage 9's held moth dives this long after it first sits, and with Easy's
## twist at this share of its speed.
const HELD_WAIT := Vector2(3.0, 9.0)
const HELD_SLOW := 0.7
## The band of the field, top to bottom as fractions, an entering bug fires
## in.
const ENTER_FIRE := Vector2(0.15, 0.5)
## A flyby flown whole pays this; short of it, what was shot.
const FLYBY_ALL := 10000

enum Kind { GNAT, BEETLE, MOTH, ROGUE }
enum St { WAIT, ENTER, FORM, DIVE, RETURN, BEAM, FLYBY, DEAD }
enum Ship { ALIVE, DEAD, CAPTURED }
enum Phase { INTRO, PLAY, WON, OVER }
## What a stage asks: bugs caught before they sit, moths shot diving, a moth
## shot after all its escorts, waves broken, a firefly won back from a beam,
## stage 9's held firefly brought home, a chain, seconds untouched, moths
## shot with their beam open, and a flyby's forty.
enum Goal { CATCH, MOTH_DIVE, ESCORT, BREAK, RESCUE, HELD, CHAIN, UNTOUCHED, BEAM_SHOT, ALL }
## What a goal gives until the stage ends.
enum Buff { NONE, QUICK, DOUBLE, PIERCE, SHIELD, SLOW, SCORE_15, SCORE_2 }

const POINTS_FORM := {Kind.GNAT: 50, Kind.BEETLE: 80, Kind.MOTH: 150, Kind.ROGUE: 500}
const POINTS_DIVE := {Kind.GNAT: 100, Kind.BEETLE: 160, Kind.MOTH: 400, Kind.ROGUE: 1000}

## Entrance paths, in fractions of the field; each ends where the bug turns
## for its seat and flies home. "mirror" flips them across the middle.
const PATH_TOP := [Vector2(0.56, -0.06), Vector2(0.53, 0.12), Vector2(0.42, 0.33), Vector2(0.24, 0.52),
	Vector2(0.17, 0.66), Vector2(0.26, 0.77), Vector2(0.40, 0.71), Vector2(0.44, 0.57), Vector2(0.38, 0.45)]
const PATH_SIDE := [Vector2(-0.08, 0.90), Vector2(0.12, 0.83), Vector2(0.32, 0.70), Vector2(0.45, 0.53),
	Vector2(0.43, 0.38), Vector2(0.31, 0.31), Vector2(0.20, 0.39), Vector2(0.24, 0.51), Vector2(0.34, 0.49)]
## The flyby's paths, which leave the field instead of taking a seat.
const FLY_A := [Vector2(0.45, -0.06), Vector2(0.46, 0.28), Vector2(0.30, 0.52), Vector2(0.14, 0.50),
	Vector2(0.18, 0.30), Vector2(0.38, 0.34), Vector2(0.62, 0.54), Vector2(0.86, 0.60), Vector2(1.12, 0.50)]
const FLY_B := [Vector2(-0.08, 0.80), Vector2(0.28, 0.66), Vector2(0.50, 0.42), Vector2(0.36, 0.20),
	Vector2(0.20, 0.28), Vector2(0.34, 0.50), Vector2(0.70, 0.52), Vector2(0.90, 0.30), Vector2(1.12, 0.12)]
const FLY_C := [Vector2(0.22, -0.06), Vector2(0.30, 0.24), Vector2(0.50, 0.44), Vector2(0.70, 0.26),
	Vector2(0.60, 0.10), Vector2(0.48, 0.24), Vector2(0.50, 0.60), Vector2(0.40, 0.86), Vector2(0.30, 1.12)]
const PATHS := {"TOP": PATH_TOP, "SIDE": PATH_SIDE, "FLY_A": FLY_A, "FLY_B": FLY_B, "FLY_C": FLY_C}

## The full swarm's five waves (the page's FULLW), each its paths (name,
## mirror) and its seats (kind, column, row from the top). A wave's seats are
## shared out in order along its paths, so FW1's four ladybirds fly the left
## loop and its four gnats the mirrored one; within a path they leave in
## seat order, inner pairs first, as the game always flew them.
const FW1 := {"paths": [["TOP", false], ["TOP", true]], "seats": [
	[Kind.BEETLE, 4, 1], [Kind.BEETLE, 5, 1], [Kind.BEETLE, 4, 2], [Kind.BEETLE, 5, 2],
	[Kind.GNAT, 4, 3], [Kind.GNAT, 5, 3], [Kind.GNAT, 4, 4], [Kind.GNAT, 5, 4]]}
const FW2 := {"paths": [["SIDE", false]], "seats": [
	[Kind.MOTH, 3, 0], [Kind.BEETLE, 3, 1], [Kind.MOTH, 4, 0], [Kind.BEETLE, 6, 1],
	[Kind.MOTH, 5, 0], [Kind.BEETLE, 3, 2], [Kind.MOTH, 6, 0], [Kind.BEETLE, 6, 2]]}
const FW3 := {"paths": [["SIDE", true]], "seats": [
	[Kind.BEETLE, 7, 1], [Kind.BEETLE, 8, 1], [Kind.BEETLE, 7, 2], [Kind.BEETLE, 8, 2],
	[Kind.BEETLE, 1, 1], [Kind.BEETLE, 2, 1], [Kind.BEETLE, 1, 2], [Kind.BEETLE, 2, 2]]}
const FW4 := {"paths": [["TOP", true]], "seats": [
	[Kind.GNAT, 6, 3], [Kind.GNAT, 7, 3], [Kind.GNAT, 6, 4], [Kind.GNAT, 7, 4],
	[Kind.GNAT, 8, 3], [Kind.GNAT, 9, 3], [Kind.GNAT, 8, 4], [Kind.GNAT, 9, 4]]}
const FW5 := {"paths": [["TOP", false]], "seats": [
	[Kind.GNAT, 3, 3], [Kind.GNAT, 2, 3], [Kind.GNAT, 3, 4], [Kind.GNAT, 2, 4],
	[Kind.GNAT, 1, 3], [Kind.GNAT, 0, 3], [Kind.GNAT, 1, 4], [Kind.GNAT, 0, 4]]}
## Stage 1's two waves of ten gnats, left half and then right.
const S1_LEFT := {"paths": [["TOP", false]], "seats": [
	[Kind.GNAT, 4, 3], [Kind.GNAT, 3, 3], [Kind.GNAT, 4, 4], [Kind.GNAT, 3, 4], [Kind.GNAT, 2, 3],
	[Kind.GNAT, 1, 3], [Kind.GNAT, 2, 4], [Kind.GNAT, 1, 4], [Kind.GNAT, 0, 3], [Kind.GNAT, 0, 4]]}
const S1_RIGHT := {"paths": [["TOP", true]], "seats": [
	[Kind.GNAT, 5, 3], [Kind.GNAT, 6, 3], [Kind.GNAT, 5, 4], [Kind.GNAT, 6, 4], [Kind.GNAT, 7, 3],
	[Kind.GNAT, 8, 3], [Kind.GNAT, 7, 4], [Kind.GNAT, 8, 4], [Kind.GNAT, 9, 3], [Kind.GNAT, 9, 4]]}

## The fifteen stages, one a Dictionary, transcribed from
## docs/brainstorm/firefly-stages.py's S and WAVES.
##
## A play stage's "groups" are its waves in the order they fly, each group
## the waves that fly in together (stages 10 and 15 send two at once; each is
## still its own wave for Break a wave). "m" is its Medium numbers: seconds
## between dives, divers at once, seeds a dive, swarm speed. "hot" is
## entrance fire on Medium and Hard (from stage 6).
##
## A flyby's "fly" is its five waves of eight, each its paths and the kinds
## dealt round them in turn; "fb" is its Medium seconds between waves and
## flight speed.
##
## "rules" are the stage's own, on every difficulty; "e", "h" and "i" are
## the twists Easy, Hard and Insane add, and "e_off" the rules Easy takes
## away. The flags:
##   pair_dive      gnats dive in pairs, side by side
##   lady_twin      a ladybird's seeds come two side by side
##   pair_start     a flyby starts as a pair
##   ram            a passer that flies into you costs a firefly
##   tough_half     every other passer takes two shots
##   second_pass    a moth that dives and misses loops straight back down
##   escorts        a moth takes ladybirds from the seats below it
##   one_escort     ... one, not two
##   two_escorts    ... always two, looked for wider
##   escort_seeds   escorts drop seeds too
##   enter_all      every entering bug fires once
##   beams          a lone moth may dive to spin its beam
##   beam_slow      the beam opens in BEAM_OPEN_SLOW
##   beam_long      the beam stays open a second longer, catches 25% wider
##   beam_often     three lone moth dives in four are beam runs
##   beam_drift     an open beam drifts toward the firefly
##   two_beams      two moths may beam at once
##   held           the stage starts with a firefly under the second moth
##   held_slow      its moth dives slower
##   held_once      its moth dives once, and a captive brought home turns rogue
##   dive_third     dives start with two thirds of the swarm seated
##   dive_first     dives start once the first wave is seated
##   dive_any       dives never wait for the swarm to sit
##   fan            a ladybird's seeds fan out in three
##   seeds_lead     seeds are aimed where the firefly is going
##   home_seeds     a bug flying home to its seat drops a seed
##   no_pause       the first wave leaves as the banner goes
##   waves_single   the waves that fly together fly one at a time instead
##   wide_breath    the seated swarm breathes wider
##   moth_7         moths take seven shots
const STAGES := [
	{"name": "First light", "kind": "play", "groups": [[S1_LEFT], [S1_RIGHT]],
		"m": [2.6, 1, 0, 1.00], "hot": false, "goal": Goal.CATCH, "need": [4, 5, 6, 8], "buff": Buff.QUICK,
		"rules": [], "i": ["pair_dive"]},
	{"name": "Ladybirds", "kind": "play", "groups": [[FW1], [FW3], [FW4], [FW5]],
		"m": [2.4, 2, 1, 1.03], "hot": false, "goal": Goal.CATCH, "need": [6, 8, 10, 12], "buff": Buff.DOUBLE,
		"rules": [], "i": ["lady_twin"]},
	{"name": "Flyby", "kind": "flyby", "fly": [
			{"paths": [["FLY_A", false], ["FLY_A", true]], "kinds": [Kind.GNAT, Kind.BEETLE]},
			{"paths": [["FLY_B", false]], "kinds": [Kind.BEETLE, Kind.MOTH]},
			{"paths": [["FLY_B", true]], "kinds": [Kind.GNAT]},
			{"paths": [["FLY_C", false], ["FLY_C", true]], "kinds": [Kind.MOTH, Kind.BEETLE]},
			{"paths": [["FLY_A", true]], "kinds": [Kind.BEETLE, Kind.GNAT]}],
		"fb": [3.4, 1.00], "gap_insane": 2.0, "goal": Goal.ALL, "need": [40, 40, 40, 40], "buff": Buff.NONE,
		"rules": [], "e": ["pair_start"], "i": ["ram"]},
	{"name": "Moths", "kind": "play", "groups": [[FW1], [FW2], [FW3], [FW4], [FW5]],
		"m": [2.2, 2, 1, 1.06], "hot": false, "goal": Goal.MOTH_DIVE, "need": [1, 2, 2, 3], "buff": Buff.PIERCE,
		"rules": [], "i": ["second_pass"]},
	{"name": "Escorts", "kind": "play", "groups": [[FW1], [FW2], [FW3], [FW4], [FW5]],
		"m": [2.0, 3, 1, 1.09], "hot": false, "goal": Goal.ESCORT, "need": [1, 1, 1, 2], "buff": Buff.SCORE_15,
		"rules": ["escorts"], "e": ["one_escort"], "i": ["two_escorts", "escort_seeds"]},
	{"name": "Hot entrances", "kind": "play", "groups": [[FW1], [FW2], [FW3], [FW4], [FW5]],
		"m": [1.7, 3, 2, 1.15], "hot": true, "goal": Goal.BREAK, "need": [1, 1, 1, 2], "buff": Buff.SHIELD,
		"rules": ["escorts"], "i": ["enter_all"]},
	{"name": "Flyby, crossing", "kind": "flyby", "fly": [
			{"paths": [["FLY_B", false], ["FLY_B", true]], "kinds": [Kind.GNAT]},
			{"paths": [["FLY_A", false], ["FLY_A", true]], "kinds": [Kind.BEETLE]},
			{"paths": [["FLY_C", false], ["FLY_C", true]], "kinds": [Kind.MOTH, Kind.GNAT]},
			{"paths": [["FLY_B", false], ["FLY_B", true]], "kinds": [Kind.BEETLE, Kind.MOTH]},
			{"paths": [["FLY_A", false], ["FLY_A", true]], "kinds": [Kind.GNAT, Kind.BEETLE, Kind.MOTH]}],
		"fb": [2.8, 1.10], "goal": Goal.ALL, "need": [40, 40, 40, 40], "buff": Buff.NONE,
		"rules": [], "e": ["pair_start"], "i": ["ram"]},
	{"name": "The silk beam", "kind": "play", "groups": [[FW1], [FW2], [FW3], [FW4], [FW5]],
		"m": [1.8, 3, 2, 1.15], "hot": true, "goal": Goal.RESCUE, "need": [1, 1, 1, 1], "buff": Buff.QUICK,
		"rules": ["escorts", "beams"], "e": ["beam_slow"], "i": ["beam_long"]},
	{"name": "Held", "kind": "play", "groups": [[FW1], [FW2], [FW3], [FW4], [FW5]],
		"m": [1.8, 3, 2, 1.15], "hot": true, "goal": Goal.HELD, "need": [1, 1, 1, 1], "buff": Buff.SHIELD,
		"rules": ["escorts", "beams", "held"], "e": ["held_slow"], "i": ["held_once"]},
	{"name": "Busy night", "kind": "play", "groups": [[FW1], [FW2], [FW3], [FW4, FW5]],
		"m": [1.5, 5, 2, 1.20], "hot": true, "goal": Goal.CHAIN, "need": [8, 12, 12, 20], "buff": Buff.QUICK,
		"rules": ["escorts", "beams", "dive_third"], "i": ["dive_any"]},
	{"name": "Flyby, the long way", "kind": "flyby", "fly": [
			{"paths": [["FLY_A", false]], "kinds": [Kind.GNAT]},
			{"paths": [["FLY_C", true]], "kinds": [Kind.BEETLE]},
			{"paths": [["FLY_A", true]], "kinds": [Kind.MOTH, Kind.GNAT]},
			{"paths": [["FLY_C", false]], "kinds": [Kind.BEETLE, Kind.MOTH]},
			{"paths": [["FLY_B", false], ["FLY_B", true]], "kinds": [Kind.GNAT, Kind.BEETLE, Kind.MOTH]}],
		"fb": [2.4, 1.20], "goal": Goal.ALL, "need": [40, 40, 40, 40], "buff": Buff.NONE,
		"rules": [], "e": ["pair_start"], "i": ["ram", "tough_half"]},
	{"name": "Seed rain", "kind": "play", "groups": [[FW1], [FW2], [FW3], [FW4], [FW5]],
		"m": [2.2, 3, 2, 1.18], "hot": true, "goal": Goal.UNTOUCHED, "need": [20, 30, 30, 45], "buff": Buff.SLOW,
		"rules": ["escorts", "beams", "fan"], "e_off": ["fan"], "i": ["seeds_lead"]},
	{"name": "Moths first", "kind": "play", "groups": [[FW2], [FW1], [FW3], [FW4], [FW5]],
		"m": [1.5, 4, 2, 1.25], "hot": true, "goal": Goal.BEAM_SHOT, "need": [1, 2, 2, 3], "buff": Buff.PIERCE,
		"rules": ["escorts", "beams", "beam_often", "beam_drift"], "e_off": ["beam_drift"], "i": ["two_beams"]},
	{"name": "No rest", "kind": "play", "groups": [[FW5], [FW4], [FW3], [FW1], [FW2]],
		"m": [1.6, 5, 2, 1.22], "hot": true, "goal": Goal.CATCH, "need": [10, 15, 15, 20], "buff": Buff.DOUBLE,
		"rules": ["escorts", "beams", "dive_first", "home_seeds"], "e_off": ["home_seeds"], "i": ["no_pause", "dive_any"]},
	{"name": "Full moon", "kind": "play", "groups": [[FW1, FW2], [FW3, FW4], [FW5]],
		"m": [1.9, 4, 2, 1.15], "hot": true, "goal": Goal.BREAK, "need": [1, 2, 2, 3], "buff": Buff.SCORE_2,
		"rules": ["escorts", "beams", "fan"], "e": ["waves_single"], "e_off": ["fan"], "i": ["wide_breath", "moth_7"]},
]

## How the difficulties scale a stage (the page's table): fireflies, shots a
## gnat / ladybird / moth takes (a rogue as a ladybird), times the swarm's
## speed and the seconds between dives, divers and seeds a dive added, seed
## speed in field units a second, the share of entering bugs that fire (on
## Medium and Hard only on a hot stage, on Insane from stage 2), and a
## flyby's seconds between waves and flight speed.
const DIFF := [
	{"name": "Easy", "ships": 4, "shots": [1, 1, 2], "swarm": 0.85, "gap": 1.4, "divers": -1, "seeds": -1,
		"seed_speed": 125.0, "enter": 0.0, "fly_gap": 1.2, "fly_speed": 0.8},
	{"name": "Medium", "ships": 3, "shots": [1, 2, 3], "swarm": 1.0, "gap": 1.0, "divers": 0, "seeds": 0,
		"seed_speed": 150.0, "enter": 0.25, "fly_gap": 1.0, "fly_speed": 1.0},
	{"name": "Hard", "ships": 3, "shots": [1, 2, 4], "swarm": 1.06, "gap": 0.8, "divers": 1, "seeds": 1,
		"seed_speed": 170.0, "enter": 0.4, "fly_gap": 0.85, "fly_speed": 1.15},
	{"name": "Insane", "ships": 2, "shots": [2, 3, 5], "swarm": 1.25, "gap": 0.75, "divers": 1, "seeds": 1,
		"seed_speed": 195.0, "enter": 0.5, "fly_gap": 0.6, "fly_speed": 1.3},
]
const INSANE := 3

var rng := RandomNumberGenerator.new()
var t := 0.0
## The stage (1..STAGES.size()) and the difficulty (0..3) this run plays.
var stage := 1
var difficulty := 1
var phase := Phase.INTRO
var phase_t := 0.0
var score := 0
var ships := 3

# --- the player ---
var px := W * 0.5
var ship := Ship.ALIVE
var pair := false
var respawn_t := 0.0
## Where a caught ship is while it is carried up, and how far it has turned.
var caught_pos := Vector2.ZERO
var caught_spin := 0.0
var caught_by := -1
## A freed ship flying down to join yours: {pos, spin, held, twin}, or empty.
var freed := {}
## The silk shield is up: the next hit is its.
var shield := false

# --- the hands, set by the screen before each step ---
## The x the firefly heads for (NAN for none) and a keyboard's -1..1.
var target_x := NAN
var axis := 0.0
var fire := false
var _fire_cd := 0.0
## How fast the firefly is sliding, for seeds aimed where it is going.
var _pvx := 0.0

# --- the gun ---
## What a shot takes off and the shots a volley: both fixed now, kept for
## the screen and for the pair.
var power := 1
var volley := 1

var shots: Array = []     # {pos: Vector2, pierce: int, skip: int}
var bullets: Array = []   # {pos: Vector2, vel: Vector2}
var enemies: Array = []   # see _spawn
var events: Array = []    # {type, pos, ...}; cleared by the screen

# --- the swarm ---
var sway := 0.0
var spread := 1.0
var _sway_amp := 10.0
var _breathe := 0.0
var _dive_t := 3.0
var _challenge := false
var flyby_hits := 0
var flyby_total := 0
## Each wave's bugs still up and whether any of them has sat, for Break a
## wave.
var _waves: Array = []    # {left: int, sat: bool}
## The bugs the stage set out, for the two-thirds rule.
var _total := 0

# --- the goal and the buff ---
var goal_kind: int = Goal.CATCH
var goal_need := 1
var goal_have := 0
var goal_done := false
var buff: int = Buff.NONE
## Double fire won while the firefly is down: the twin comes when it is back.
var _twin_due := false
## Seconds untouched since the swarm first sat (Goal.UNTOUCHED), and whether
## it has.
var _calm := 0.0
var _swarm_sat := false

# --- the chain: kills each within CHAIN_GAP of the last ---
var chain := 0
var best_chain := 0
var _last_kill := -10.0

# --- tallies for the end ---
var fired := 0
var hits := 0
var kills := 0

## This stage's row of STAGES and its flags at this difficulty.
var _st: Dictionary = {}
var _rules: Array = []

func _init(the_seed := 0, the_stage := 1, the_difficulty := 1) -> void:
	if the_seed == 0:
		rng.randomize()
	else:
		rng.seed = the_seed
	stage = clampi(the_stage, 1, STAGES.size())
	difficulty = clampi(the_difficulty, 0, DIFF.size() - 1)
	_st = STAGES[stage - 1]
	_rules = rules_of(stage, difficulty)
	ships = int(DIFF[difficulty].ships)
	goal_kind = _st.goal
	goal_need = int(_st.need[difficulty])
	_start_stage()

## The flags stage `n` plays with at difficulty `d`.
static func rules_of(n: int, d: int) -> Array:
	var st: Dictionary = STAGES[n - 1]
	var out: Array = (st.get("rules", []) as Array).duplicate()
	if d != 1:
		# Medium is the stage as it stands; the others add their twists
		out.append_array(st.get(["e", "", "h", "i"][d], []))
	if d == 0:
		for f: String in st.get("e_off", []):
			out.erase(f)
	return out

func has(flag: String) -> bool:
	return _rules.has(flag)

static func stage_count() -> int:
	return STAGES.size()

static func is_flyby(n: int) -> bool:
	return STAGES[n - 1].kind == "flyby"

## The goal's count on stage `n` at difficulty `d`.
static func need_of(n: int, d: int) -> int:
	return int(STAGES[n - 1].need[d])

# --- the gun ---

## Volleys a second.
func rate() -> float:
	return RATE_QUICK if buff == Buff.QUICK else RATE

## Where shot `i` of a volley of `n` leaves, left or right of the firefly.
static func shot_off(i: int, n: int) -> float:
	if n <= 1:
		return 0.0
	return (i - (n - 1) * 0.5) * minf(SHOT_GAP, SHOT_ROW / (n - 1))

# --- the stage ---

func _start_stage() -> void:
	_challenge = _st.kind == "flyby"
	phase = Phase.INTRO
	phase_t = 0.0
	enemies.clear()
	bullets.clear()
	_sway_amp = 10.0
	_breathe = 0.0
	_dive_t = 2.5
	flyby_hits = 0
	flyby_total = 0
	events.append({"type": "challenge_start" if _challenge else "stage_start", "stage": stage})
	if _challenge:
		_plan_flyby()
		if has("pair_start"):
			pair = true
	else:
		_plan_stage()
	_total = enemies.size()

## The share of entering bugs that fire once on their way in.
func _enter_chance() -> float:
	if has("enter_all"):
		return 1.0
	var d: Dictionary = DIFF[difficulty]
	if difficulty == INSANE:
		return float(d.enter) if stage >= 2 else 0.0
	return float(d.enter) if _st.hot else 0.0

func _plan_stage() -> void:
	var groups: Array = _st.groups
	if has("waves_single"):
		var one: Array = []
		for g: Array in groups:
			for wave: Dictionary in g:
				one.append([wave])
		groups = one
	var start := 0.2 if has("no_pause") else 1.6
	var gap := WAVE_GAP_HOT if _st.hot else WAVE_GAP
	var enter := _enter_chance()
	for g in groups.size():
		for wave: Dictionary in groups[g]:
			var paths: Array = wave.paths
			var seats: Array = wave.seats
			var per := seats.size() / paths.size()
			for p in paths.size():
				var path := _path(PATHS[paths[p][0]], paths[p][1])
				for i in per:
					var s: Array = seats[p * per + i]
					var e := _spawn(s[0], Vector2i(s[1], s[2]), path, St.ENTER, _waves.size())
					e.delay = start + g * gap + i * 0.12
					e.fire_left = 1 if rng.randf() < enter else 0
					enemies.append(e)
			_waves.append({"left": seats.size(), "sat": false})
	if has("held"):
		# The second moth from the left carries one of yours from the start;
		# it costs no firefly.
		for e: Dictionary in enemies:
			if e.kind == Kind.MOTH and e.slot == Vector2i(4, 0):
				e.captive = true
				e.held = true

func _plan_flyby() -> void:
	var d: Dictionary = DIFF[difficulty]
	var gap: float = float(_st.fb[0]) * float(d.fly_gap)
	if difficulty == INSANE and _st.has("gap_insane"):
		gap = _st.gap_insane
	var speed: float = FLY_SPEED * float(_st.fb[1]) * float(d.fly_speed)
	var plan: Array = _st.fly
	for w in plan.size():
		var paths: Array = plan[w].paths
		var kinds: Array = plan[w].kinds
		var per := 8 / paths.size()
		var idx := 0
		for p in paths.size():
			var path := _path(PATHS[paths[p][0]], paths[p][1])
			for i in per:
				var e := _spawn(kinds[idx % kinds.size()], Vector2i(-1, -1), path, St.FLYBY, w)
				idx += 1
				e.hp = 2 if has("tough_half") and flyby_total % 2 == 1 else 1
				e.max = e.hp
				e.speed = speed
				e.delay = 1.8 + w * gap + i * 0.16
				enemies.append(e)
				flyby_total += 1

## The shots a bug of `kind` takes at this difficulty.
func hp_of(kind: int) -> int:
	var shots_of: Array = DIFF[difficulty].shots
	match kind:
		Kind.GNAT:
			return shots_of[0]
		Kind.MOTH:
			return 7 if has("moth_7") else shots_of[2]
	return shots_of[1]

func _spawn(kind: int, slot: Vector2i, path: PackedVector2Array, st: int, wave := -1) -> Dictionary:
	var hp := hp_of(kind)
	return {"kind": kind, "slot": slot, "hp": hp, "max": hp, "st": St.WAIT, "next": st,
		"pos": path[0], "heading": PI * 0.5, "path": path, "pd": 0.0, "pi": 0, "pbase": 0.0, "delay": 0.0,
		"speed": (FLY_SPEED if st == St.FLYBY else ENTER_SPEED) * _pace(), "fire_left": 0, "fire_t": 0.0,
		"fire_at": [], "captive": false, "leader": -1, "escorts": 0, "escorts_down": 0, "beam": 0.0,
		"beam_t": 0.0, "flash": 0.0, "id": rng.randi(), "hurt": false, "beam_run": false,
		"wave": wave, "seated": false, "held": false, "held_t": -1.0, "dived": false, "second": false}

## The swarm's speed: the stage's, times the difficulty's.
func _pace() -> float:
	if not _st.has("m"):
		return 1.0
	return float(_st.m[3]) * float(DIFF[difficulty].swarm)

## Seconds between dives, divers at once, and seeds a dive at most.
func _dive_gap() -> float:
	return float(_st.m[0]) * float(DIFF[difficulty].gap)

func _divers_most() -> int:
	return maxi(1, int(_st.m[1]) + int(DIFF[difficulty].divers))

func _seeds_most() -> int:
	return clampi(int(_st.m[2]) + int(DIFF[difficulty].seeds), 0, 4)

## How fast a seed falls, the Slow seeds halving it.
func seed_speed() -> float:
	return float(DIFF[difficulty].seed_speed) * (0.5 if buff == Buff.SLOW else 1.0)

## A path from fractions of the field, smoothed through Catmull-Rom.
func _path(fracs: Array, mirror: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for f: Vector2 in fracs:
		pts.append(Vector2((1.0 - f.x) if mirror else f.x, f.y) * Vector2(W, H))
	return smooth(pts)

static func smooth(pts: PackedVector2Array, steps := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, n - 1)]
		for k in steps:
			var u := float(k) / steps
			var u2 := u * u
			var u3 := u2 * u
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3))
	out.append(pts[n - 1])
	return out

## Where a seat in the swarm is right now: the swarm sways while it
## gathers and breathes in and out once it has.
func home(slot: Vector2i) -> Vector2:
	var x := W * 0.5 + sway + (slot.x - (COLS - 1) * 0.5) * SLOT_DX * spread
	var y := FORM_TOP + slot.y * SLOT_DY * (1.0 + (spread - 1.0) * 0.6)
	return Vector2(x, y)

# --- the step ---

func step() -> void:
	t += DT
	phase_t += DT
	if phase == Phase.INTRO and phase_t > 1.2:
		phase = Phase.PLAY
		phase_t = 0.0
	_swarm()
	_player()
	_shots()
	_enemies()
	_bullets()
	_freed()
	_collide()
	_respawn()
	if chain > 0 and t - _last_kill > CHAIN_GAP:
		chain = 0
	if phase == Phase.PLAY:
		_attack()
		_held()
		_untouched()
		_check_clear()

func _swarm() -> void:
	var gathering := false
	for e: Dictionary in enemies:
		if e.st == St.WAIT or e.st == St.ENTER:
			if e.next != St.FLYBY:
				gathering = true
				break
	_sway_amp = move_toward(_sway_amp, 10.0 if gathering else 0.0, DT * 6.0)
	_breathe = move_toward(_breathe, 0.0 if gathering else 1.0, DT * 0.8)
	sway = sin(t * 1.15) * _sway_amp
	spread = 1.0 + (0.22 if has("wide_breath") else 0.13) * (0.5 - 0.5 * cos(t * 1.7)) * _breathe

func _player() -> void:
	if ship != Ship.ALIVE or phase == Phase.OVER:
		return
	var lo := PLAYER_R + 4.0 + (PAIR if pair else 0.0)
	var hi := W - lo
	var want := px
	if not is_nan(target_x):
		want = target_x
	if absf(axis) > 0.01:
		want = px + axis * 1000.0
	var was := px
	px = move_toward(px, clampf(want, lo, hi), PLAYER_SPEED * (1.6 if not is_nan(target_x) else 1.0) * DT)
	_pvx = lerpf(_pvx, (px - was) / DT, 0.2)
	_fire_cd = maxf(_fire_cd - DT, -DT)
	if fire and phase == Phase.PLAY:
		var gap := 1.0 / rate()
		for k in FIRE_MOST:
			if _fire_cd > 0.0:
				break
			_fire_cd += gap
			for x: float in _ship_xs():
				for i in volley:
					shots.append({"pos": Vector2(x + shot_off(i, volley), PLAYER_Y - 8.0),
						"pierce": 1 if buff == Buff.PIERCE else 0, "skip": -1})
					fired += 1
			events.append({"type": "shoot", "pos": Vector2(px, PLAYER_Y)})

func _shots() -> void:
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		s.pos.y -= SHOT_SPEED * DT
		if s.pos.y < -10.0:
			shots.remove_at(i)

func _bullets() -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b.pos += b.vel * DT
		if b.pos.y > H + 10.0 or b.pos.x < -10.0 or b.pos.x > W + 10.0:
			bullets.remove_at(i)

## Moves `e` `dist` along its path; true once it has run out.
func _follow(e: Dictionary, dist: float) -> bool:
	var path: PackedVector2Array = e.path
	e.pd += dist
	var d: float = e.pd
	var i: int = e.pi
	var base: float = e.pbase
	while i < path.size() - 1:
		var seg := path[i].distance_to(path[i + 1])
		if d - base <= seg:
			_move(e, path[i].lerp(path[i + 1], (d - base) / maxf(seg, 0.001)))
			e.pi = i
			e.pbase = base
			return false
		base += seg
		i += 1
	_move(e, path[path.size() - 1])
	return true

func _set_path(e: Dictionary, path: PackedVector2Array) -> void:
	e.path = path
	e.pd = 0.0
	e.pi = 0
	e.pbase = 0.0

func _move(e: Dictionary, p: Vector2) -> void:
	var d: Vector2 = p - e.pos
	if d.length_squared() > 1e-6:
		e.heading = lerp_angle(e.heading, d.angle(), 0.35)
	e.pos = p

## Flies `e` toward its seat; true once it is in it.
func _home_in(e: Dictionary, speed: float) -> bool:
	var to := home(e.slot)
	var d: Vector2 = to - e.pos
	var step := speed * DT
	if d.length() <= step:
		e.pos = to
		return true
	_move(e, e.pos + d.normalized() * step)
	return false

func _enemies() -> void:
	var turning: Array = []
	for e: Dictionary in enemies:
		e.flash = maxf(0.0, e.flash - DT)
		match e.st:
			St.WAIT:
				if phase == Phase.PLAY or phase == Phase.INTRO:
					e.delay -= DT
					if e.delay <= 0.0:
						e.st = e.next
						e.pos = (e.path as PackedVector2Array)[0]
						e.fire_t = rng.randf_range(0.5, 1.6)
			St.ENTER:
				if _follow(e, e.speed * DT):
					e.st = St.RETURN
				_enter_fire(e)
			St.FLYBY:
				if _follow(e, e.speed * DT):
					e.st = St.DEAD
					e["escaped"] = true
			St.RETURN:
				_maybe_fire(e)
				if _home_in(e, e.speed * 1.1):
					_sit(e)
			St.FORM:
				e.pos = home(e.slot)
				e.heading = lerp_angle(e.heading, PI * 0.5, 0.12)
			St.DIVE:
				var done := _follow(e, e.speed * 1.15 * DT)
				_maybe_fire(e)
				if e.beam_run and (done or e.pd >= float(e.get("beam_at", 1e9))):
					e.st = St.BEAM
					e.beam_t = 0.0
					events.append({"type": "beam", "pos": e.pos})
				elif done:
					_off_the_bottom(e)
			St.BEAM:
				_beam(e)
		if e.get("rogue_due", false):
			turning.append(e)
	for e: Dictionary in turning:
		_turn_rogue(e)
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].st == St.DEAD:
			enemies.remove_at(i)

## A bug reaches its seat. The first time, its wave can no longer be broken;
## stage 9's held moth starts the count to its early dive, and on Insane,
## home from that one dive with its captive, the captive turns rogue.
func _sit(e: Dictionary) -> void:
	e.st = St.FORM
	e.leader = -1
	e.second = false
	if not e.seated:
		e.seated = true
		if e.wave >= 0 and e.wave < _waves.size():
			_waves[e.wave].sat = true
		if e.held:
			e.held_t = rng.randf_range(HELD_WAIT.x, HELD_WAIT.y)
	elif e.held and e.captive and e.dived and has("held_once"):
		e["rogue_due"] = true

## A dive run off the bottom: back in at the top over its seat (dropping a
## seed on the way, on stage 14), or with Insane's second pass on stage 4, a
## moth loops straight back down at the firefly once more.
func _off_the_bottom(e: Dictionary) -> void:
	var top := Vector2(home(e.slot).x, -14.0)
	e.beam_run = false
	if has("second_pass") and e.kind == Kind.MOTH and not e.second:
		e.second = true
		e.pos = top
		_set_path(e, _dive_line(top, -1.0 if top.x < W * 0.5 else 1.0, _aim()))
		e.fire_at = _seed_heights(_seeds_most())
		return
	e.pos = top
	e.st = St.RETURN
	if has("home_seeds"):
		e.fire_at = [rng.randf_range(4.0, 24.0)]

## The captive under `e` turns rogue where it hangs and flies to a seat of
## its own above the moths.
func _turn_rogue(e: Dictionary) -> void:
	e.erase("rogue_due")
	if not e.captive:
		return
	var hang: Vector2 = e.pos + _captive_offset(e)
	e.captive = false
	e.held = false
	var rogue := _spawn(Kind.ROGUE, Vector2i(e.slot.x, -1), PackedVector2Array([hang]), St.RETURN)
	rogue.st = St.RETURN
	rogue.seated = true
	enemies.append(rogue)
	events.append({"type": "rogue", "pos": rogue.pos})

func _beam(e: Dictionary) -> void:
	e.heading = lerp_angle(e.heading, PI * 0.5, 0.2)
	if caught_by == e.id:
		e.beam = 1.0
		return
	e.beam_t += DT
	var bt: float = e.beam_t
	var open := BEAM_OPEN_SLOW if has("beam_slow") else BEAM_OPEN
	var held := BEAM_HELD + (1.0 if has("beam_long") else 0.0)
	if bt < open:
		e.beam = bt / open
	elif bt < held:
		e.beam = 1.0
	elif bt < held + BEAM_CLOSE:
		e.beam = 1.0 - (bt - held) / BEAM_CLOSE
	else:
		e.beam = 0.0
		_leave_down(e)
		return
	if has("beam_drift") and e.beam >= 1.0 and ship == Ship.ALIVE:
		e.pos.x = move_toward(e.pos.x, px, BEAM_DRIFT * DT)
	var reach := BEAM_REACH * (1.25 if has("beam_long") else 1.0)
	if ship == Ship.ALIVE and not pair and e.beam > 0.6 and phase == Phase.PLAY:
		if absf(px - e.pos.x) < reach * e.beam and not _captive_exists():
			ship = Ship.CAPTURED
			caught_by = e.id
			caught_pos = Vector2(px, PLAYER_Y)
			caught_spin = 0.0
			shots.clear()
			_touched()
			events.append({"type": "captured", "pos": caught_pos})

## Down and out after a beam, then back in over its seat.
func _leave_down(e: Dictionary) -> void:
	e.st = St.DIVE
	e.beam_run = false
	e.beam = 0.0
	_set_path(e, PackedVector2Array([e.pos, Vector2(e.pos.x, H + 30.0)]))

func _captive_exists() -> bool:
	for e: Dictionary in enemies:
		if e.captive or e.kind == Kind.ROGUE:
			return true
	return ship == Ship.CAPTURED

## An entering bug that fires does so once, a moment into its flight, and
## only while it is in the upper half of the field: a loop's foot comes down
## near the firefly, and a seed from there would be on it before it could
## move.
func _enter_fire(e: Dictionary) -> void:
	if e.fire_left <= 0 or ship != Ship.ALIVE:
		return
	e.fire_t -= DT
	if e.fire_t <= 0.0 and e.pos.y > H * ENTER_FIRE.x and e.pos.y < H * ENTER_FIRE.y:
		e.fire_left = 0
		_seed(e)

func _maybe_fire(e: Dictionary) -> void:
	var at: Array = e.fire_at
	if at.is_empty() or ship != Ship.ALIVE:
		return
	if e.pos.y >= float(at[0]):
		at.pop_front()
		if e.pos.y < PLAYER_Y - 60.0:
			_seed(e)

## `e` drops a seed at the firefly (or where it is going, on stage 12's
## Insane): a ladybird's in a fan of three where the stage has fans, or two
## side by side on stage 2's Insane.
func _seed(e: Dictionary) -> void:
	var speed := seed_speed()
	var time: float = (PLAYER_Y - e.pos.y) / speed
	var aim := px
	if has("seeds_lead"):
		aim = clampf(px + _pvx * time, PLAYER_R + 4.0, W - PLAYER_R - 4.0)
	var vx := clampf((aim - e.pos.x) / time, -55.0, 55.0)
	var from: Vector2 = e.pos + Vector2(0, 6)
	if e.kind == Kind.BEETLE and has("fan"):
		for f in [-1.0, 0.0, 1.0]:
			bullets.append({"pos": from, "vel": Vector2(vx + f * FAN, speed)})
	elif e.kind == Kind.BEETLE and has("lady_twin"):
		for f in [-1.0, 1.0]:
			bullets.append({"pos": from + Vector2(f * TWIN_SEED, 0), "vel": Vector2(vx, speed)})
	else:
		bullets.append({"pos": from, "vel": Vector2(vx, speed)})

# --- attacks ---

func _divers() -> int:
	var n := 0
	for e: Dictionary in enemies:
		if e.st == St.DIVE or e.st == St.BEAM:
			n += 1
	return n

## Moths on a beam run or with the beam open.
func _beams() -> int:
	var n := 0
	for e: Dictionary in enemies:
		if e.st == St.BEAM or (e.st == St.DIVE and e.beam_run):
			n += 1
	return n

## Whether the swarm may dive yet: once it has all flown in, or on the
## stages that say so once two thirds of it is seated, once the first wave
## is, or at once.
func _may_dive() -> bool:
	if has("dive_any"):
		return true
	if has("dive_third"):
		var unseated := 0
		for e: Dictionary in enemies:
			if not e.seated:
				unseated += 1
		return unseated * 3 <= _total
	if has("dive_first"):
		for e: Dictionary in enemies:
			if e.wave == 0 and not e.seated:
				return false
		return true
	for e: Dictionary in enemies:
		if e.st == St.WAIT or e.st == St.ENTER:
			return false
	return true

func _attack() -> void:
	if _challenge or ship != Ship.ALIVE:
		return
	if not _may_dive():
		return
	var formed: Array = []
	for e: Dictionary in enemies:
		if e.st == St.FORM:
			formed.append(e)
	if formed.is_empty():
		return
	_dive_t -= DT
	if _dive_t > 0.0:
		return
	# the last few bugs up dive quicker and more at once, so a stage ends;
	# counted over the whole swarm, not the seated, or a stage that dives
	# before it has sat would count its first arrivals as the last
	var few := enemies.size() <= 6
	_dive_t = rng.randf_range(0.7, 1.3) * _dive_gap() * (0.6 if few else 1.0)
	if _divers() >= _divers_most() + (2 if few else 0):
		return
	var roll := rng.randf()
	var pick: Dictionary = {}
	if roll < 0.24:
		pick = _pick_kind(formed, Kind.MOTH)
	if pick.is_empty() and roll < 0.32:
		pick = _pick_kind(formed, Kind.ROGUE)
	if pick.is_empty() and roll < 0.62:
		pick = _pick_kind(formed, Kind.BEETLE)
	if pick.is_empty():
		pick = _pick_kind(formed, Kind.GNAT)
	if pick.is_empty():
		pick = formed[rng.randi() % formed.size()]
	if pick.kind == Kind.MOTH:
		if has("beams") and not pick.captive and not pair and not _captive_exists() \
				and _beams() < (2 if has("two_beams") else 1) \
				and rng.randf() < (BEAM_OFTEN if has("beam_often") else BEAM_CHANCE):
			_dive_beam(pick)
		elif has("escorts"):
			_dive_escorted(pick, formed)
		else:
			_dive(pick, {})
		return
	_dive(pick, {})
	if pick.kind == Kind.GNAT and has("pair_dive"):
		# its neighbour in the row flies the same line beside it
		for o: Dictionary in formed:
			if o.kind == Kind.GNAT and o.slot.y == pick.slot.y and absi(o.slot.x - pick.slot.x) == 1:
				_dive(o, pick)
				break

## Stage 9's held moth dives early: a few seconds after it first sits, if
## nothing has sent it yet.
func _held() -> void:
	if not has("held") or ship != Ship.ALIVE:
		return
	for e: Dictionary in enemies:
		if e.held and e.st == St.FORM and not e.dived and e.held_t >= 0.0:
			e.held_t -= DT
			if e.held_t <= 0.0:
				var formed: Array = []
				for o: Dictionary in enemies:
					if o.st == St.FORM:
						formed.append(o)
				_dive_escorted(e, formed)

## A seat on the swarm's edge is picked before one in its middle.
func _pick_kind(formed: Array, kind: int) -> Dictionary:
	var best: Dictionary = {}
	var best_w := -1.0
	for e: Dictionary in formed:
		if e.kind != kind:
			continue
		var w := absf(e.slot.x - (COLS - 1) * 0.5) + rng.randf() * 4.0
		if w > best_w:
			best_w = w
			best = e
	return best

func _aim() -> float:
	return clampf(px + rng.randf_range(-30.0, 30.0), 20.0, W - 20.0)

func _dive_line(from: Vector2, side: float, aim: float) -> PackedVector2Array:
	var pts := PackedVector2Array([from, from + Vector2(side * 8.0, -10.0), from + Vector2(side * 20.0, -9.0),
		from + Vector2(side * 26.0, 3.0), from + Vector2(side * 21.0, 18.0)])
	var sway_x := rng.randf_range(24.0, 44.0)
	pts.append(Vector2(lerpf(from.x, aim, 0.4) + side * sway_x, from.y + 80.0))
	pts.append(Vector2(aim - side * sway_x * 0.7, H * 0.62))
	pts.append(Vector2(aim + side * sway_x * 0.6, H * 0.86))
	pts.append(Vector2(aim + side * sway_x * 1.6, H + 30.0))
	for i in range(5, pts.size() - 1):
		pts[i].x = clampf(pts[i].x, 8.0, W - 8.0)
	return smooth(pts, 12)

## The heights a diver drops its seeds at: as many as the stage gives
## (one where it gives one, else one up to that many).
func _seed_heights(most: int) -> Array:
	var n := most if most <= 1 else rng.randi_range(0, most)
	var at: Array = []
	for k in n:
		at.append(H * (0.3 + 0.1 * k) + rng.randf_range(0.0, 20.0))
	return at

func _dive(e: Dictionary, lead: Dictionary) -> void:
	var side := -1.0 if e.pos.x < W * 0.5 else 1.0
	if not lead.is_empty():
		var offset: Vector2 = e.pos - lead.pos
		var line := PackedVector2Array()
		for p in (lead.path as PackedVector2Array):
			line.append(p + offset)
		_set_path(e, line)
		e.leader = lead.id
	else:
		_set_path(e, _dive_line(e.pos, side, _aim()))
		e.leader = -1
	e.st = St.DIVE
	e.speed = DIVE_SPEED * _pace() * (HELD_SLOW if e.held and has("held_slow") else 1.0)
	# an escort keeps its seeds unless the stage says otherwise
	var escort: bool = not lead.is_empty() and lead.kind == Kind.MOTH
	e.fire_at = [] if escort and not has("escort_seeds") else _seed_heights(_seeds_most())
	if e.held:
		e.dived = true
	events.append({"type": "dive", "pos": e.pos, "kind": e.kind})

func _dive_escorted(moth: Dictionary, formed: Array) -> void:
	moth.escorts_down = 0
	_dive(moth, {})
	var most := 1 if has("one_escort") else 2
	var taken := 0
	for e: Dictionary in formed:
		if taken >= most:
			break
		if e.st == St.FORM and e.kind == Kind.BEETLE and e.slot.y == 1 and absi(e.slot.x - moth.slot.x) <= 1:
			_dive(e, moth)
			taken += 1
	if has("two_escorts"):
		# Insane's moth always finds its two, from further along or a row down
		for e: Dictionary in formed:
			if taken >= 2:
				break
			if e.st == St.FORM and e.kind == Kind.BEETLE and absi(e.slot.x - moth.slot.x) <= 3:
				_dive(e, moth)
				taken += 1
	moth.escorts = taken

## A moth's beam run: out of its seat, down to the middle of the field above
## the firefly, and the beam opens there.
func _dive_beam(e: Dictionary) -> void:
	var side := -1.0 if e.pos.x < W * 0.5 else 1.0
	var from: Vector2 = e.pos
	var aim := clampf(px, 30.0, W - 30.0)
	var stop := Vector2(aim, H * 0.54)
	var pts := PackedVector2Array([from, from + Vector2(side * 8.0, -10.0), from + Vector2(side * 20.0, -9.0),
		from + Vector2(side * 26.0, 3.0), from + Vector2(side * 21.0, 18.0),
		Vector2(lerpf(from.x, aim, 0.6), H * 0.36), stop, stop + Vector2(0, 1)])
	_set_path(e, smooth(pts, 12))
	var len := 0.0
	var path: PackedVector2Array = e.path
	for i in path.size() - 2:
		len += path[i].distance_to(path[i + 1])
	e["beam_at"] = len
	e.beam_run = true
	e.st = St.DIVE
	e.speed = BEAM_SPEED * _pace()
	e.fire_at = []
	events.append({"type": "dive", "pos": e.pos, "kind": e.kind})

# --- hits ---

func _collide() -> void:
	# Shots against bugs, and against a captive hanging under its moth. A
	# piercing spark goes on through its first bug and skips it after.
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		var gone := false
		for e: Dictionary in enemies:
			if e.st == St.WAIT or e.st == St.DEAD or e.id == s.skip:
				continue
			if e.captive and e.st != St.FORM and (s.pos as Vector2).distance_to(e.pos + _captive_offset(e)) < ENEMY_R:
				e.captive = false
				e.held = false
				events.append({"type": "captive_lost", "pos": e.pos + _captive_offset(e)})
				hits += 1
				gone = true
				break
			if (s.pos as Vector2).distance_to(e.pos) < ENEMY_R + SHOT_R:
				_hurt(e, s.pos)
				hits += 1
				if int(s.pierce) > 0:
					s.pierce -= 1
					s.skip = e.id
				else:
					gone = true
				break
		if gone:
			shots.remove_at(i)
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].st == St.DEAD:
			enemies.remove_at(i)
	if ship != Ship.ALIVE:
		return
	var bodies := _ship_xs()
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		for k in bodies.size():
			if (b.pos as Vector2).distance_to(Vector2(bodies[k], PLAYER_Y)) < PLAYER_R + BULLET_R:
				bullets.remove_at(i)
				_ship_hit(k)
				return
	# A passer only rams where the stage says (a flyby on Insane).
	var passers := has("ram")
	for e: Dictionary in enemies:
		if e.st == St.DIVE or e.st == St.RETURN or e.st == St.ENTER or (e.st == St.FLYBY and passers):
			for k in bodies.size():
				if (e.pos as Vector2).distance_to(Vector2(bodies[k], PLAYER_Y)) < PLAYER_R + ENEMY_R - 1.0:
					_kill(e, true)
					_ship_hit(k)
					return

## A captive hangs behind its moth, whichever way the moth is flying.
static func captive_offset(e: Dictionary) -> Vector2:
	return -Vector2.from_angle(e.heading) * CAPTIVE_UP

func _captive_offset(e: Dictionary) -> Vector2:
	return captive_offset(e)

func ship_xs() -> Array:
	return _ship_xs()

func _ship_xs() -> Array:
	return [px - PAIR, px + PAIR] if pair else [px]

## A shot lands on `e` at `at`, one off it. `hurt` says `half` on the blow
## that leaves it with half or less, which is when it shows it; the blow
## that ends it is a `pop`. (`dmg` and `crit` stay in both for the screen.)
func _hurt(e: Dictionary, at: Vector2) -> void:
	e.hp -= power
	e.flash = 0.12
	if e.hp > 0:
		var half: bool = not e.hurt and int(e.hp) * 2 <= int(e.max)
		if half:
			e.hurt = true
		events.append({"type": "hurt", "pos": e.pos, "at": at, "kind": e.kind, "dmg": power, "crit": false, "half": half})
		return
	_kill(e, false, power)

func _kill(e: Dictionary, rammed: bool, dmg := 0) -> void:
	var was: int = e.st
	var diving: bool = was != St.FORM
	var hang: Vector2 = e.pos + _captive_offset(e)
	e.st = St.DEAD
	kills += 1
	var pts := 0
	if _challenge:
		pts = 100
		flyby_hits += 1
	elif e.kind == Kind.MOTH and diving:
		pts = POINTS_DIVE[Kind.MOTH] * int(pow(2.0, mini(e.escorts_down, 2)))
	else:
		pts = POINTS_DIVE[e.kind] if diving else POINTS_FORM[e.kind]
	# An escort shot down before its moth doubles the moth.
	if e.leader != -1:
		for m: Dictionary in enemies:
			if m.id == e.leader and m.st != St.DEAD:
				m.escorts_down += 1
	pts = roundi(pts * _score_mult())
	score += pts
	events.append({"type": "pop", "pos": e.pos, "kind": e.kind, "points": pts, "rammed": rammed,
		"energy": 0, "dmg": dmg, "crit": false})
	if not rammed:
		chain = chain + 1 if t - _last_kill <= CHAIN_GAP else 1
		_last_kill = t
		best_chain = maxi(best_chain, chain)
	_count_kill(e, was, rammed)
	if e.captive:
		if diving:
			freed = {"pos": hang, "spin": 0.0, "held": e.held, "twin": false}
			events.append({"type": "rescue", "pos": freed.pos})
		else:
			var rogue := _spawn(Kind.ROGUE, Vector2i(e.slot.x, -1), PackedVector2Array([hang]), St.RETURN)
			rogue.st = St.RETURN
			rogue.seated = true
			enemies.append(rogue)
			events.append({"type": "rogue", "pos": rogue.pos})
		e.captive = false
	if caught_by == e.id and ship == Ship.CAPTURED:
		# Shot while it was hauling the firefly up: the firefly drops free.
		ship = Ship.ALIVE
		caught_by = -1
		px = caught_pos.x
		events.append({"type": "rescue", "pos": caught_pos})

func _score_mult() -> float:
	match buff:
		Buff.SCORE_15:
			return 1.5
		Buff.SCORE_2:
			return 2.0
	return 1.0

## What a kill does for the goal. `was` is the state it died in; a bug that
## rams the firefly counts for nothing but its wave.
func _count_kill(e: Dictionary, was: int, rammed: bool) -> void:
	var w: int = e.wave
	var broke := false
	if not _challenge and w >= 0 and w < _waves.size():
		_waves[w].left -= 1
		broke = _waves[w].left == 0 and not _waves[w].sat
	if goal_done:
		return
	var diving := was == St.DIVE or was == St.BEAM
	match goal_kind:
		Goal.CATCH:
			if not rammed and not e.seated and not _challenge:
				_goal_step(goal_have + 1)
		Goal.MOTH_DIVE:
			if not rammed and e.kind == Kind.MOTH and diving:
				_goal_step(goal_have + 1)
		Goal.ESCORT:
			if not rammed and e.kind == Kind.MOTH and diving and e.escorts > 0 and e.escorts_down >= e.escorts:
				_goal_step(goal_have + 1)
		Goal.BEAM_SHOT:
			if not rammed and e.kind == Kind.MOTH and was == St.BEAM and e.beam > 0.0:
				_goal_step(goal_have + 1)
		Goal.BREAK:
			if broke:
				_goal_step(goal_have + 1)
		Goal.CHAIN:
			_goal_step(chain)
		Goal.ALL:
			if _challenge:
				_goal_step(flyby_hits)

## The goal's count went up to `have`: said, and the buff given on the last.
func _goal_step(have: int) -> void:
	if goal_done or have <= goal_have:
		return
	goal_have = mini(have, goal_need)
	events.append({"type": "goal_step", "have": goal_have, "need": goal_need})
	if goal_have >= goal_need:
		goal_done = true
		_give(_st.buff)

## The buff starts at once and lasts the stage. Double fire flies a twin in
## from the side as a rescue does; won while already a pair (or with a
## rescue on its way to make one), it is a Silk shield instead.
func _give(b: int) -> void:
	if b == Buff.DOUBLE and (pair or not freed.is_empty()):
		b = Buff.SHIELD
	buff = b
	match b:
		Buff.DOUBLE:
			if ship == Ship.ALIVE:
				_send_twin()
			else:
				_twin_due = true
		Buff.SHIELD:
			shield = true
		Buff.SLOW:
			for s: Dictionary in bullets:
				s.vel *= 0.5
	events.append({"type": "goal_met", "buff": b})

func _send_twin() -> void:
	var side := -14.0 if px > W * 0.5 else W + 14.0
	freed = {"pos": Vector2(side, PLAYER_Y - 30.0), "spin": 0.0, "held": false, "twin": true}
	events.append({"type": "twin", "pos": freed.pos})

## A hit or a capture: Untouched starts again.
func _touched() -> void:
	_calm = 0.0
	if goal_kind == Goal.UNTOUCHED and not goal_done and goal_have > 0:
		goal_have = 0
		events.append({"type": "goal_step", "have": 0, "need": goal_need})

## Untouched counts once the whole swarm has first sat, while the firefly
## is up.
func _untouched() -> void:
	if goal_kind != Goal.UNTOUCHED or goal_done:
		return
	if not _swarm_sat:
		for e: Dictionary in enemies:
			if not e.seated:
				return
		_swarm_sat = true
		_calm = 0.0
		return
	if ship != Ship.ALIVE:
		return
	_calm += DT
	if int(_calm) > goal_have:
		_goal_step(int(_calm))

func _ship_hit(k: int) -> void:
	var xs := _ship_xs()
	_touched()
	if shield:
		shield = false
		events.append({"type": "shield", "pos": Vector2(xs[k], PLAYER_Y)})
		return
	events.append({"type": "ship_pop", "pos": Vector2(xs[k], PLAYER_Y)})
	if pair:
		pair = false
		px = xs[1 - k]
		return
	ship = Ship.DEAD
	shots.clear()
	respawn_t = 2.2
	_lose_ship()

func _lose_ship() -> void:
	if ships <= 1:
		ships = 0
		phase = Phase.OVER
		phase_t = 0.0
		events.append({"type": "game_over"})
	else:
		ships -= 1

# --- the caught and the freed ---

func _freed() -> void:
	if ship == Ship.CAPTURED:
		var moth: Dictionary = {}
		for e: Dictionary in enemies:
			if e.id == caught_by:
				moth = e
		if moth.is_empty():
			ship = Ship.ALIVE
			caught_by = -1
			return
		var to: Vector2 = moth.pos + Vector2(0, -CAPTIVE_UP + 2.0)
		# Pulled up the beam, turning.
		caught_spin += DT * 9.0
		caught_pos = caught_pos.move_toward(Vector2(moth.pos.x, to.y), 60.0 * DT)
		if caught_pos.distance_to(Vector2(moth.pos.x, to.y)) < 1.0:
			moth.captive = true
			moth.beam_t = maxf(moth.beam_t, BEAM_HELD)
			caught_by = -1
			ship = Ship.DEAD
			respawn_t = 1.6
			events.append({"type": "carried", "pos": caught_pos})
			_lose_ship()
			# The moth takes its prize home rather than on down the field.
			moth.st = St.RETURN
			moth.beam = 0.0
			moth.beam_run = false
		return
	if freed.is_empty():
		return
	# the twin waits off the field while there is no firefly to fly beside
	if freed.twin and ship != Ship.ALIVE:
		return
	freed.spin += DT * 8.0
	var dock := Vector2((px + PAIR * 2.0) if ship == Ship.ALIVE else W * 0.5, PLAYER_Y)
	dock.x = minf(dock.x, W - PLAYER_R - 4.0)
	freed.pos = (freed.pos as Vector2).move_toward(dock, 110.0 * DT)
	if (freed.pos as Vector2).distance_to(dock) < 1.0:
		if ship == Ship.ALIVE:
			pair = true
			px = clampf(dock.x - PAIR, PLAYER_R + 4.0 + PAIR, W - PLAYER_R - 4.0 - PAIR)
		else:
			ship = Ship.ALIVE
			px = dock.x
			ships += 1
			if phase == Phase.OVER:
				phase = Phase.PLAY
		var was: Dictionary = freed
		freed = {}
		events.append({"type": "docked", "pos": dock, "held": was.held, "twin": was.twin})
		if not was.twin and not goal_done:
			if goal_kind == Goal.RESCUE or (goal_kind == Goal.HELD and was.held):
				_goal_step(goal_have + 1)

func _respawn() -> void:
	if ship != Ship.DEAD or phase == Phase.OVER:
		return
	respawn_t -= DT
	if respawn_t > 0.0 or (not freed.is_empty() and not freed.twin):
		return
	for e: Dictionary in enemies:
		if e.st == St.DIVE or e.st == St.BEAM or (e.st == St.RETURN and not _challenge):
			return
	if not bullets.is_empty():
		return
	ship = Ship.ALIVE
	pair = false
	px = W * 0.5
	_dive_t = 2.0
	events.append({"type": "ready"})
	if _twin_due:
		_twin_due = false
		if freed.is_empty():
			_send_twin()

## The swarm is down (and nothing is still being carried or flying in to
## dock): the stage is won. A flyby pays its bonus first.
func _check_clear() -> void:
	if not enemies.is_empty() or ship == Ship.CAPTURED or not freed.is_empty():
		return
	phase = Phase.WON
	phase_t = 0.0
	bullets.clear()
	if _challenge:
		var bonus := FLYBY_ALL if flyby_hits == flyby_total else flyby_hits * 100
		score += bonus
		events.append({"type": "challenge_result", "hits": flyby_hits, "total": flyby_total, "bonus": bonus})
	else:
		events.append({"type": "stage_clear", "stage": stage})
	events.append({"type": "won", "stage": stage, "difficulty": difficulty, "score": score, "goal": goal_done})

func is_over() -> bool:
	return phase == Phase.OVER

func is_won() -> bool:
	return phase == Phase.WON

## The Second chance (arcade/boosters.gd): one firefly back, on the stage
## the game ended on, rising in once the dives have gone home.
func revive() -> void:
	if phase != Phase.OVER:
		return
	ships = 1
	ship = Ship.DEAD
	respawn_t = 1.0
	bullets.clear()
	phase = Phase.PLAY
	phase_t = 0.0
	events.append({"type": "revive"})

func challenge() -> bool:
	return _challenge
