class_name PeepletWalker
extends Node3D

## Fires once per tool action at the moment the swing lands (shovel bites,
## water hits). Farm logic applies task effects on this signal.
signal chop_impact

## The frame the hand actually closes on the prop, mid-grab — the prop changes
## parent on this frame and not before. A put-down fires it at the frame the
## prop touches the ground and the hand lets go.
signal grab_contact(prop: Node3D)
## The whole beat is over and the body is back upright.
signal grab_done(prop: Node3D)

## Procedural walking rig for peeplet.glb — no bone rig, per canon. The
## single 15-surface mesh is split into body / feet / arms / tail parts and
## driven with the lab walk gait: alternating foot shuffle, counter-swinging
## arms, waddle roll, breathing squash. Walker origin sits at ground level.

const SOURCE_SCENE := "res://peeplet/models/peeplet.glb"

# Real-world metric: 1 world unit = 1 meter and a peeplet stands 0.6 m tall.
# The glb is authored 1.6 units high, so 0.6 / 1.6. Uniform root scale, so no
# local-rotation shear.
const WALKER_SCALE := 0.375

# Surface indices follow the Blender material slot order (see PeepletFur):
# 0 body, 1-9 face features, 10/11 legs, 12 tail, 13/14 arms.
const BODY_SURFACES := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
const FOOT_SURFACES := [10, 11]
const ARM_SURFACES := [13, 14]
const TAIL_SURFACE := 12
const BODY_COAT_SURFACE := 0

# glb object space: feet soles rest at y -0.736.
const MESH_ORIGIN_HEIGHT := 0.736
# Arms attach at the body flank (inner arm edge x ±0.430, top y +0.105);
# rotating about the shoulder swings the hanging arm forward and back.
const ARM_PIVOTS := [Vector3(-0.52, 0.02, 0.0), Vector3(0.52, 0.02, 0.0)]
# Tail meets the body at the lower back (surface bounds z -0.836..-0.579).
const TAIL_PIVOT := Vector3(0.0, -0.17, -0.58)

# Name of the water contact silhouette proxy (see _build_parts): identified by
# name rather than type so PeepletSpawnEffect can skip it without importing a
# class it has no other reason to know about.
const WATER_CONTACT_PROXY_NAME := "WaterContactProxy"

# Walk gait tuning ported from peeplet_lab.gd move_mode 1: the body keeps its
# idle breathing pose — only the feet shuffle, the arms swing gently and a
# small roll gives the waddle.
const GAIT_CADENCE := 2.2
const FOOT_LIFT := 0.035
const FOOT_STRIDE := 0.045
const ARM_SWING := 0.10
# The glb models the arms straight out in a T pose; droop them at the
# shoulder so they hang relaxed, then wave around that rest angle.
const ARM_DROOP := deg_to_rad(40.0)
const ARM_WAVE := 0.08
const WADDLE_ROLL := 0.05 * (ARM_SWING / 0.38)
const BREATH_RATE := 2.1
const SWAY_LERP := 10.0
const FOOT_LERP := 16.0

# Comfort display: heat slumps the body and quickens the breath into a pant,
# cold shivers it. Values arrive pre-eased (host sim or snapshot), so the
# pose never pops at a band edge. The breath phase is CPU-integrated — a
# live pant rate inside sin(anim_time * rate) would teleport the phase, the
# same trap wind_gust_phase documents.
const PANT_RATE_GAIN := 1.6
const PANT_DEPTH_GAIN := 0.5
const HEAT_SLUMP := deg_to_rad(9.0)
const SHIVER_RATE := 26.0
const SHIVER_SCALE := 0.012

# Run gait: a child sprinting with arms held out — the shoulders lift back to
# the modeled T pose, the torso tips forward and the shuffle doubles up.
const RUN_CADENCE := 3.6
const RUN_FOOT_LIFT := 0.065
const RUN_FOOT_STRIDE := 0.085
const RUN_LEAN := deg_to_rad(14.0)
const RUN_ARM_DROOP := deg_to_rad(6.0)
const RUN_ARM_FLUTTER := 0.04
const LEAN_LERP := 6.0
const ARM_POSE_LERP := 7.0

# --- Sit. No bone rig, so sitting is written in the same vocabulary every
# other pose here uses, keyed off this glb's measured shells. The body keeps
# its PROPORTIONS — a seated peeplet is the same peeplet, lower down, so
# nothing here touches body_mesh.scale. The sit is a drop, the legs out front
# and a rock back off the heels.
#
# The leg stubs span y -0.736..-0.298, and their part origin is the glb origin
# at BODY CENTRE — well above the leg itself. Rotating a stub there sweeps the
# whole thing forward through the belly and lifts its top, which is the buried
# socket, out into open view. So the swing happens about HIP_LOCAL instead, the
# top of the stub, and the node carries a compensating shift.
const SIT_LERP := 3.4
# Lab units (see LAB_TO_GLB), straight down. The body shell spans y -0.576 up
# about its node at MESH_ORIGIN_HEIGHT, so its underside clears the ground by
# exactly 0.160 glb standing — the whole budget a drop has, since no squash
# lifts the belly back — and the idle breath stretches the shell another
# 0.018 glb downward at peak inhale, which comes out of the same budget.
# 0.072 lab = 0.120 glb: vertex-measured, that leaves the lowest point of the
# shell about 4 mm off the ground at full inhale, on ground that is never quite
# level under a seated body. The blob is already sitting as low as it can — its
# standing clearance is only 6 cm to begin with.
const SIT_BODY_DROP := 0.072
# Rocked back off the heels, weight on the seat.
const SIT_LEAN := deg_to_rad(-13.0)
# Hip swing: negative pitch about X arcs the sole forward (+Z, the glb front)
# and up, which is a leg held out in front of a seated body.
# 55 degrees leaves the sole about 2 cm off the ground with the hip still in
# its socket. This blob's legs are simply too short to reach past its own belly
# while staying attached — the toes peek out under the front and that is all
# they can do, which is why the sit reads through the drop and the rock back.
const SIT_LEG_PITCH := deg_to_rad(-55.0)
# The socket, in part space: the stubs are cut off at y -0.298, so this is the
# top of the leg and the point the body keeps swallowed.
const HIP_LOCAL := Vector3(0.0, -0.30, 0.0)
# Knees apart — a rotation about the same hip, not a slide, or the joint walks
# out of its socket sideways the way the old forward push did.
const SIT_LEG_SPLAY := deg_to_rad(9.0)
# The tail slides out from under the seat instead of being sat on.
const SIT_TAIL_LIFT := deg_to_rad(-20.0)

# --- Snack. Eating is the carry pose lifted to the muzzle: the mouth surface
# on this glb spans z 0.635..0.670 at y 0.132..0.192, which is (0, 0.096,
# 0.39) back in the lab units every mount is keyed in. The hands stop short of
# it and the shaft leans the food end — the prop's +Y top — in the rest of the
# way, with the handle sliding back through the grip so a long stick's tip
# actually arrives instead of stopping a fist short.
const SNACK_DURATION := 2.8
# The mouth, in glb body space: surface 9 (the muzzle) centres here. It is
# scaled by the body mesh's own squash every frame before it is used — a
# seated blob's face sits lower and further forward than a standing one's, and
# food aimed at the unsquashed mouth lands on the forehead.
const SNACK_MOUTH := Vector3(0.0, 0.162, 0.652)
# How far proud of the mouth surface the food stops, so it reads as being
# bitten rather than swallowed whole.
const SNACK_BITE_OUT := 0.07
# Where the hand holds while the mouth eats, as an offset from the mouth:
# out front, below and to the carry side. The shaft direction and the handle
# slide both fall out of this and the prop's own "snack_local" — nothing here
# is per-prop, so a stick, a skewer or a corn cob all arrive the same way.
const SNACK_HAND := Vector3(0.29, -0.20, -0.24)
# Fractions of the beat spent raising and lowering; the chomps land between.
const SNACK_LIFT_IN := 0.26
const SNACK_LIFT_OUT := 0.80
const SNACK_CHOMP_PHASES := [0.38, 0.52, 0.66]
const SNACK_CHOMP_WIDTH := 0.055
const SNACK_CHOMP_SPREAD := 0.055
const SNACK_CHOMP_SQUASH := 0.075
const SNACK_LEAN := deg_to_rad(4.0)
const SNACK_CHOMP_NOD := deg_to_rad(7.0)
# Lab units: the body leans in behind the raised hand.
const SNACK_REACH := 0.02

# --- Laugh. A blob has no shoulders to shake, so a laugh is what it does have:
# the whole body bouncing on its own squash, rocked back off the seat, with the
# roll wagging out of phase so it is not a pogo stick. One envelope swells the
# whole beat in and out, which keeps a laugh from starting or stopping on a
# hard frame.
const LAUGH_DURATION := 1.6
## Bounces per second.
const LAUGH_RATE := 6.5
const LAUGH_SQUASH := 0.085
const LAUGH_LEAN := deg_to_rad(-14.0)
const LAUGH_SWAY := 0.055
## Lab units: the bounce lifts the body off its seat a little.
const LAUGH_HOP := 0.018

# --- Grieve. Held like the sit, not timed like the laugh: a mourner stays
# down until the scene lets it up. The pose is the sit collapsed forward —
# the body squashes down and spreads, the lean swings PAST the seated rock-back
# into a slump over whatever is being mourned — with a slow sob riding the
# squash so the grief breathes instead of freezing. Composed after the sit
# block so a seated body grieves from its seat: sit (-13 degrees) plus this
# (+34) nets a forward collapse, and the squashed skull carries the headgear
# down with it (a flower crown droops for free).
const GRIEVE_LERP := 2.6
const GRIEVE_LEAN := deg_to_rad(34.0)
const GRIEVE_SQUASH := 0.13
## Sobs per second, and how much squash each sob adds on top of the slump.
const GRIEVE_SOB_RATE := 1.7
const GRIEVE_SOB := 0.030

# --- Voice. One 3D player per body, positional so a peeplet across the valley
# is quiet without any distance maths here, and the stream is swapped per beat:
# these never overlap on a single body (a laugh is refused mid-bite, and a body
# only sits down once), so a second player would idle forever.
const BITE_SOUND := "res://audio/sfx/marshmallowBite.mp3"
const SETTLE_SOUND := "res://audio/sfx/peepletSettle.mp3"
const LAUGH_SOUNDS := [
	"res://audio/sfx/peepletLaugh1.mp3",
	"res://audio/sfx/peepletLaugh2.mp3",
	"res://audio/sfx/peepletLaugh3.mp3",
]
## The generations came out at wildly different levels (the bite peaks 18 dB
## below the laughs), so each beat carries its own trim.
const BITE_DB := 4.0
const LAUGH_DB := -12.0
const SETTLE_DB := 0.0
const SQUEAK_SOUND := "res://audio/sfx/peepletSqueakSad.mp3"
const SQUEAK_DB := -6.0
const VOICE_HEARD_RANGE := 20.0
const VOICE_UNIT_SIZE := 2.5
## Sitting is a blend, not an event: the flop lands once the body is committed
## to going down rather than the frame the flag flipped.
const SETTLE_AT := 0.3

# --- Tool actions, ported from the lab peeplet (peeplet_lab.gd). The lab
# authored every pose in its own world units around a 0.96 unit peeplet;
# this rig works in glb units (1.6 unit peeplet) under a 0.375 root scale,
# so lab distances convert by (0.6 / 0.96) / 0.375 = 5/3 into part space,
# and by 0.6 / 0.96 into world space.
const LAB_TO_GLB := 5.0 / 3.0
const LAB_TO_WORLD := 0.625

const CHOP_DURATION := 0.98
const CHOP_IMPACT_TIME := 0.49
const DIG_DURATION := 1.30
const DIG_IMPACT_TIME := 0.62
const WATER_DURATION := 1.4
const WATER_IMPACT_TIME := 0.55
const PICK_DURATION := 1.5
# Dig scoop keys: rest -> raise -> thrust -> lever/press -> lift -> toss.
const DIG_PHASE_BOUNDS := [0.20, 0.38, 0.56, 0.74, 0.90]
const TOOL_REST_MOUNT := Vector3(0.0, 0.16, 0.34)
## NOT the arm's length — the arm shell measures 0.167 m from shoulder to hand
## (see arm_tip, read off the mesh at build). This is the older tuning constant
## the eyewear and action mounts were keyed against; the arm solvers use the
## measured reach instead, so the hand lands on what it is holding.
const ARM_GRIP_REST_WORLD := 0.45 * LAB_TO_WORLD
## How far the nub may shorten or extend to put its hand on a grip. Shortening
## is how a rig with no elbow expresses one, so the floor is generous; the
## ceiling is the old carry limit, kept because past it the arm reads as rubber.
const ARM_MIN_STRETCH := 0.55
const ARM_MAX_STRETCH := 2.4

# --- Carry. The peeplet blob stands 0.55 world units tall with its shoulders
# at (+-0.195, 0.2835, 0). A prop authored at full size overruns that: the axe
# measures 0.575 end to end and the shovel 0.742, so at the raw mount they
# cross the face and clear the skull. Long props are shrunk until their
# longest axis lands here; anything already shorter keeps its authored size.
const TOOL_TARGET_LENGTH := 0.36

# Where a prop rests when nothing is being swung, keyed on how long it is.
#
# The action poses key their mount off pitch/yaw/roll because a swing is an
# arc through angles. A carry is not — it is two directions held against the
# body, and the euler triple that produces them is unreadable. So a carry pose
# names them: "shaft" is where the handle (prop-local +Y) points in body
# space, "head" is where the prop's working end — its blade, scoop or spout —
# turns. Aiming the head down +Z carries every tool pointing where the peeplet
# walks; the axis it lives on differs per prop, so each one declares its own
# "head_local" (see carry_basis).
#
# "mount" is lab units in body space (see LAB_TO_GLB); the body sits at world
# y 0.276 and the blob spans x +-0.234, so a mount past x 0.37 lab holds the
# prop clear of the silhouette. "grip_local" is the point on the prop the
# carrying arm reaches for, in the prop's own units.
const SHOULDER_CARRY := {
	"mount": Vector3(0.480, 0.038, 0.096),
	"shaft": Vector3(0.55, 0.72, -0.42),
	"head": Vector3(0.85, 0.0, 1.0),
	"grip_local": Vector3(0.0, -0.12, 0.0),
	"carry_arm": 1,
}
const HIP_CARRY := {
	"mount": Vector3(0.448, -0.058, 0.128),
	"shaft": Vector3(0.30, 0.90, -0.31),
	"head": Vector3(0.85, 0.0, 1.0),
	"grip_local": Vector3(0.0, -0.06, 0.0),
	"carry_arm": 1,
}
# Which prop-local axis a tool's working end sits on, when the prop does not
# say. The tool GLBs hang the blade off +Z with the handle on +Y; a prop whose
# head points elsewhere (the hoe rakes back down -Z, a gadget's spout runs +X)
# sets its own "head_local" meta in its factory.
const DEFAULT_HEAD_LOCAL := Vector3(0.0, 0.0, 1.0)
# A lump with no handle — a rock, a fruit — is not carried on a mount at all.
# It sits IN THE FIST, and the fist goes wherever the arm hangs, so the prop
# follows the arm instead of the arm being aimed at the prop.
#
# This exists because a mount cannot hold one honestly. Every authored carry
# mount puts its grip 0.11-0.22 m from the shoulder, and the arm cannot
# compress below 0.85 of its rest length (0.239 m), so the hand always
# overshoots the thing it is supposed to be holding. For a shafted tool that
# reads as a grip somewhere along the handle and gets away with it. For a rock
# it reads as a rock stuck to a shoulder, which is what it is.
const HAND_CARRY := {
	"mount": Vector3.ZERO,
	"shaft": Vector3(0.2, 0.9, -0.3),
	"head": Vector3(0.85, 0.0, 1.0),
	"grip_local": Vector3.ZERO,
	"carry_arm": 1,
	"in_hand": true,
}
# A prop longer than this shoulders; shorter ones go to the hip.
const SHOULDER_CARRY_MIN_LENGTH := 0.30
# Fraction of an action spent easing between the carry and the swing at each
# end. Short enough that the keyed middle of every arc lands untouched.
const ACTION_BLEND := 0.16

# --- Grab. A prop is taken OFF THE WORLD, never spawned in the fist. The body
# squats until the shoulder is one rest arm-length from the prop's own grip
# point, the carrying arm rotates onto that point — the same aim-and-stretch
# solver the carry already uses, aimed at something that has not moved — and
# only on the frame the hand is actually there does the prop change parent,
# keeping its world transform. Nothing teleports and nothing is duplicated.
#
# The squat DEPTH is solved per target rather than keyed (see solve_grab): a
# rock on the ground gets the whole crouch, a tool leaning at hip height gets
# almost none, and both land the hand with the arm near its rest length. That
# is what keeps the nub from stretching to the floor like rubber, which is the
# thing the arm contract has always refused.
const GRAB_DURATION := 1.25
## Fractions of the beat: dip to the prop, hold while the hand closes, rise.
const GRAB_CONTACT_AT := 0.46
const GRAB_CLOSE_AT := 0.60
## How deep the body may sink. The belly only clears the ground by 0.096 lab
## standing (SIT_BODY_DROP documents the same budget); the squat's own squash
## lifts the shell back up as it drops, which is where the rest of this comes
## from. Worked through at the worst case — full depth, peak inhale, and the
## forward lean tipping the shell onto its front — the lowest point lands about
## 8 mm off level ground. Deepening this eats that margin, and a belly through
## the grass is a worse read than a slightly shallower crouch.
const SQUAT_DROP := 0.128
const SQUAT_SQUASH := 0.20
const SQUAT_LEAN := deg_to_rad(22.0)
const SQUAT_LEG_SPLAY := deg_to_rad(8.0)
const SQUAT_LERP := 9.0
## A carry may stretch the arm to 2.4x because a two-handed swing has no
## choice. A grab has one: walk closer. Anything outside this band is out of
## reach and can_reach() says so, rather than ripping the arm at the object.
##
## The ceiling is not arbitrary: reaching the ground at all costs about 1.1
## even with the shoulder squatted directly over the prop (the vertical gap
## alone is 0.18 m against a 0.167 m arm), so the band has to clear that with
## room for uneven ground and a stand point that is a few centimetres off.
const GRAB_MAX_STRETCH := 1.45
const GRAB_MIN_STRETCH := 0.55
## Where a grab wants the prop, as a bearing off the body's own forward.
##
## Wide, and it has to be. The shoulder sits 0.195 m out to the side while the
## whole arm is only 0.167 m long, so the only way the hand gets near the
## ground is with the shoulder more or less OVER the thing — which means the
## prop forward and well out to the carry side, not in front of the belly.
## Turning the
## torso to bring a front-on prop round costs more than it buys: the twist
## swings the shoulder through an arc of radius 0.52 part units, comparable to
## the entire reach, so a body twisted onto a close target moves its hand away
## from it. Standing on the right side to begin with is the answer.
const GRAB_BEARING := deg_to_rad(69.0)
## How far the torso may turn onto a prop that is off to one side. Past this
## the body has to walk around instead — "the body turns to reach" has a limit,
## and beyond it the arm would be crossing the blob again.
const GRAB_TWIST_CAP := deg_to_rad(55.0)
const GRAB_TWIST_LERP := 7.0
## Where a grab wants the prop to sit relative to the walker, in walker-local
## (part) units.
##
## Keyed against the arm this body actually has. A 0.167 m arm hanging off a
## shoulder that squats to 0.196 m has to come down nearly vertical to touch
## the ground, so the spot a peeplet picks something up from is close in — a
## hand'"'"'s width out and a step in front, near enough that it is standing over
## the thing. That is not a compromise, it is what short arms mean.
const GRAB_PROP_LOCAL := Vector3(0.48, 0.0, 0.18)
## Bisection steps for the squat solve. Eight halvings of [0,1] resolves the
## depth to 0.4%, well under a millimetre of shoulder height.
const SQUAT_SOLVE_STEPS := 8

# Worn pose measured off this glb's own face, not carried over from the lab
# blob (its eyes sit higher on a shallower head). In glb object space the eye
# surfaces centre on y 0.324 and the muzzle skin at eye height reaches
# z 0.588, so the lens plane rides just proud of it at z 0.62; both convert
# back through LAB_TO_GLB here like the tool mount. Scale puts each lens
# centre on an eye centre (x +/-0.244 glb) — 1.55 * LAB_TO_GLB = 2.58, which
# spans the glasses 78% across the head, the same read the lab had.
const EYEWEAR_REST_MOUNT := Vector3(0.0, 0.194, 0.372)
const EYEWEAR_WORN_SCALE := 1.55

# Headgear is authored with its opening ring (radius 0.17) on the model's own
# y 0, so both numbers below come straight from the skull this glb actually
# has, measured on the coat shell: the ring of radius 0.391 sits at glb
# y 0.760, and 0.391 / 0.17 = 2.30 seats the hat on it. These are glb object
# space already (the body node's own space), so unlike the mounts above they
# do not pass through LAB_TO_GLB. The lab blob is no guide here — its proxy
# dome is 2.75x too tall, so anything fitted against it floats.
const HEADGEAR_REST_MOUNT := Vector3(0.0, 0.760, 0.0)
const HEADGEAR_WORN_SCALE := 2.30

var walking := false
var running := false
var chop_time := -1.0
var chop_impact_sent := false
var action_style := 2     # 2 dig scoop, 3 water pour (lab numbering)
var pick_time := -1.0
var snack_time := -1.0
var laugh_time := -1.0
var voice: AudioStreamPlayer3D
## Which chomp of the current bite has been heard, and which laugh take is next.
## The take cycles rather than rolling a die: varied, and still the same film
## every run.
var chomps_heard := 0
var laugh_take := 0
var settled := false
# Same headless contract as RiverPresence: the dummy audio driver leaks a
# playback per play() call at exit, so streams load but never play.
var headless := DisplayServer.get_name() == "headless"
# Sit is a held flag rather than a timed action: a driver hands it off whatever
# the body is doing, and sit_amount eases the pose in and out.
var sitting := false
var sit_amount := 0.0
# Grieve is held the same way sit is: a flag the scene owns, an amount the
# pose eases through.
var grieving := false
var grieve_amount := 0.0
var held_tool: Node3D
var tool_mount: Node3D
# --- Grab state. grab_prop is the thing being reached for (picking up) or put
# down; grab_placing tells the two apart. grab_depth and grab_twist are the
# posture solve_grab() worked out for this particular target, played through
# the beat's curve. grab_blend eases the prop between "wherever the hand had
# it" and its canonical carry pose, which is what keeps the contact frame from
# popping — see update_tool_pose.
var grab_prop: Node3D
var grab_time := -1.0
var grab_placing := false
var grab_taken := false
var grab_depth := 0.0
var grab_twist := 0.0
var grab_blend := 0.0
## Rest transform a put-down is aiming the prop at, in world space.
var grab_rest := Transform3D.IDENTITY
## The prop's pose in the BODY's frame, recorded at contact. Body-relative and
## not hand-relative on purpose: the arm is aimed at the prop, so anchoring the
## prop to the arm would close a feedback loop between the two. The body is
## driven by the squat curve alone, so hanging the hold off it keeps the
## dependency one-way — prop follows body, hand follows prop.
var grab_hold_local := Transform3D.IDENTITY
var squat_amount := 0.0
# Gadget trait: a held prop that shares the single carry pipeline with farm
# tools. The node stays parented to tool_mount and is hidden while a tool is
# out rather than rebuilt each chore — tenders swap tools every few seconds and
# a GLB instantiate per swap is waste.
var gadget_kind := ""
var worn_gadget: Node3D
var eyewear_mount: Node3D
var worn_eyewear: Node3D
var headgear_mount: Node3D
var worn_headgear: Node3D
var eye_trait := PeepletEyes.DEFAULT_TRAIT
var markings := PeepletMarkings.DEFAULT_TRAIT
var chains: Array[ShaderMaterial] = []
# The body coat carries the cream belly patch; feet keep glb object space and
# point straight down the belly direction, so they get a plain coat instead.
var body_chain: Array[ShaderMaterial] = []
var limb_chain: Array[ShaderMaterial] = []

var body: Node3D
var body_mesh: MeshInstance3D
var feet: Array[MeshInstance3D] = []
var foot_rest_positions: Array[Vector3] = []
var arms: Array[Node3D] = []
## Distance from the shoulder to the hand in part units, measured off the arm
## shell at build (see _build_parts). THIS is the arm's length. The rig also
## carries ARM_GRIP_REST_WORLD, which is 69% longer and is a tuning constant
## for how hard the aim solver stretches — reading it as a length puts held
## props 11 cm past the end of the arm, floating.
var arm_tip := 0.0
var tail: Node3D
var dust: CPUParticles3D
var anim_time := 0.0
var gait_phase := 0.0
var breath_phase := 0.0
var heat_comfort := 0.0
var cold_comfort := 0.0
var body_sway := 0.0
var body_lean := 0.0
var body_twist := 0.0
var arm_droop := ARM_DROOP
var battle_pose := ""
# Per-frame arm override for battle moves (BattleActions writes both shoulder
# rotations each frame while a move plays). Wins over battle_pose when set.
var battle_arms: Array[Vector3] = []

## premium_mode is PeepletPalette's patterned-coat selector; it must be built in
## with the chain because the shells are created here, not swapped later. The
## eye trait is baked in the same way — the iris material is chosen while the
## face surfaces are being overridden, so a recolor means a rebuild. Markings
## are a plain uniform on the body chain and could be pushed at any time; they
## come in here so a walker is fully dressed the moment it exists.
static func create(
	fur_color: Color, premium_mode := 0, eye_trait := PeepletEyes.DEFAULT_TRAIT,
	markings := PeepletMarkings.DEFAULT_TRAIT
) -> PeepletWalker:
	var source_mesh := _load_source_mesh()
	var walker := PeepletWalker.new()
	walker.eye_trait = PeepletEyes.resolve(eye_trait)
	walker.markings = PeepletMarkings.resolve(markings)
	walker.body_chain = PeepletFur.build_chain(
		fur_color, PeepletFur.BELLY_STRENGTH, premium_mode,
		PeepletMarkings.mode(walker.markings))
	walker.limb_chain = PeepletFur.build_chain(fur_color, 0.0, premium_mode)
	walker.chains = walker.body_chain + walker.limb_chain
	# Every shell and the outline hang off the base coat's next_pass, so a
	# shadow casting instance drags the whole chain into the shadow map. Break
	# the base away from its shells here; _build_parts puts chain[0] (the
	# base alone) on the casting part and chain[1] onward (still linked) on a
	# sibling with casting off. The array objects are untouched, so wind,
	# wetness, sun and band propagation (walker.chains, adventure.gd's
	# classified chains) keep seeing every material exactly as before.
	PeepletFur.split_shadow_chain(walker.body_chain)
	PeepletFur.split_shadow_chain(walker.limb_chain)
	# daily: a part's four shells drawn as one stacked mesh (PeepletBatch).
	PeepletBatch.stack_chain(walker.body_chain)
	PeepletBatch.stack_chain(walker.limb_chain)
	walker._build_parts(source_mesh)
	walker.scale = Vector3.ONE * WALKER_SCALE
	return walker

static func _load_source_mesh() -> ArrayMesh:
	var scene := load(SOURCE_SCENE) as PackedScene
	var node := scene.instantiate() as Node3D
	var mesh_instance := node.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := mesh_instance.mesh as ArrayMesh
	node.free()
	return mesh

func _build_parts(source: ArrayMesh) -> void:
	body = Node3D.new()
	body.name = "Body"
	body.position = Vector3(0.0, MESH_ORIGIN_HEIGHT, 0.0)
	add_child(body)

	body_mesh = _make_part("BodyMesh", source, BODY_SURFACES, Vector3.ZERO)
	body.add_child(body_mesh)
	_apply_coat(body_mesh, BODY_SURFACES.find(BODY_COAT_SURFACE), body_chain,
		PeepletFur.IRIS_SURFACES, PeepletFur.LOWER_LIGHT_SURFACES)
	# body_mesh carries nine face surfaces beside the coat, so its own mesh
	# cannot be reused whole for the fur decoration (the face surfaces would
	# render twice, once flat shaded and once with whatever default material
	# the shared mesh resource still carries). Extract just the coat surface
	# into its own single surface mesh instead, same source arrays as body_mesh's
	# own surface 0, so the shape is bit for bit identical.
	var body_coat_mesh := _make_part("BodyFur", source, [BODY_COAT_SURFACE], Vector3.ZERO)
	_attach_fur_decoration(body_mesh, body_chain, body_coat_mesh.mesh)
	body_coat_mesh.free()

	# Feet parent to the walker root so they stay planted while the body
	# breathes and rolls; they keep glb object space (translation only).
	for surface in FOOT_SURFACES:
		var foot := _make_part("Foot%d" % feet.size(), source, [surface], Vector3.ZERO)
		foot.position = Vector3(0.0, MESH_ORIGIN_HEIGHT, 0.0)
		add_child(foot)
		_apply_coat(foot, 0, limb_chain)
		_attach_fur_decoration(foot, limb_chain, foot.mesh)
		feet.append(foot)
		foot_rest_positions.append(foot.position)

	for index in ARM_SURFACES.size():
		var pivot: Vector3 = ARM_PIVOTS[index]
		var arm := _make_part("Arm%d" % index, source, [ARM_SURFACES[index]], pivot)
		arm.position = pivot
		# How long the arm ACTUALLY is, read off the shell rather than assumed.
		# _make_part has already put the shoulder at the node origin, so the
		# outer X extent of its bounds is the hand. Measured on this glb it is
		# 0.445 part units = 0.167 m — nowhere near ARM_GRIP_REST_WORLD, which
		# is a solver tuning constant and not a length (see hand_reach_local).
		var bounds := arm.mesh.get_aabb()
		arm_tip = maxf(arm_tip, maxf(absf(bounds.position.x),
			absf(bounds.position.x + bounds.size.x)))
		body.add_child(arm)
		_apply_coat(arm, 0, limb_chain)
		_attach_fur_decoration(arm, limb_chain, arm.mesh)
		arms.append(arm)

	tail = _make_part("Tail", source, [TAIL_SURFACE], TAIL_PIVOT)
	tail.position = TAIL_PIVOT
	body.add_child(tail)
	_apply_coat(tail as MeshInstance3D, 0, limb_chain)
	_attach_fur_decoration(tail as MeshInstance3D, limb_chain, (tail as MeshInstance3D).mesh)

	tool_mount = Node3D.new()
	tool_mount.name = "ToolMount"
	tool_mount.position = TOOL_REST_MOUNT * LAB_TO_GLB
	body.add_child(tool_mount)

	eyewear_mount = Node3D.new()
	eyewear_mount.name = "EyewearMount"
	eyewear_mount.position = EYEWEAR_REST_MOUNT * LAB_TO_GLB
	body.add_child(eyewear_mount)

	headgear_mount = Node3D.new()
	headgear_mount.name = "HeadgearMount"
	headgear_mount.position = HEADGEAR_REST_MOUNT
	body.add_child(headgear_mount)

	dust = _build_run_dust()
	add_child(dust)

	voice = AudioStreamPlayer3D.new()
	voice.name = "PeepletVoice"
	voice.bus = "SFX"
	voice.unit_size = VOICE_UNIT_SIZE
	voice.max_distance = VOICE_HEARD_RANGE
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.max_polyphony = 2
	# The mouth, roughly: the muzzle sits at glb z 0.65 on the body.
	voice.position = Vector3(0.0, MESH_ORIGIN_HEIGHT, 0.45)
	add_child(voice)

	# Walkers dent water: WaterWaveField's contact camera sees whatever wears
	# WATER_CONTACT_LAYER wherever it pierces the surface, so a peeplet
	# fording the river sheds real waves. Tagging the real meshes (as before)
	# dragged the whole six pass fur chain into the mask render for a single
	# silhouette bit; a bare capsule sized to the body's own AABB costs one
	# flat draw call instead. Exactly WATER_CONTACT_LAYER, no other bit, so it
	# never lands in the main camera's view (see game_camera.tscn cull_mask).
	add_child(_build_water_contact_proxy(source))

## Roughly the body's own bounds, read straight off the source mesh rather
## than hand measured. The glb changing shape keeps the proxy honest for
## free. Plain unshaded white: the mask only reads alpha, not colour.
static func _build_water_contact_proxy(source: ArrayMesh) -> MeshInstance3D:
	var bounds := source.get_aabb()
	var proxy := MeshInstance3D.new()
	proxy.name = WATER_CONTACT_PROXY_NAME
	var capsule := CapsuleMesh.new()
	capsule.radius = maxf(bounds.size.x, bounds.size.z) * 0.5
	capsule.height = maxf(bounds.size.y, capsule.radius * 2.0)
	proxy.mesh = capsule
	proxy.position = bounds.get_center()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.WHITE
	proxy.material_override = material
	# BuildingFactory.WATER_CONTACT_LAYER in ~/dev/peeplet; daily has no water.
	proxy.layers = 1 << 10
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return proxy

## Little cartoon dust puffs kicked up behind the heels while sprinting.
## World-space particles so the trail hangs in the air as the peeplet runs on;
## the glb front faces +Z, so puffs spawn low on the -Z side.
static func _build_run_dust() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "RunDust"
	particles.position = Vector3(0.0, 0.05, -0.38)
	particles.emitting = false
	particles.local_coords = false
	particles.amount = 16
	particles.lifetime = 0.7
	particles.direction = Vector3(0.0, 0.45, -1.0)
	particles.spread = 22.0
	particles.initial_velocity_min = 0.35
	particles.initial_velocity_max = 0.75
	particles.gravity = Vector3(0.0, 0.55, 0.0)
	particles.damping_min = 1.2
	particles.damping_max = 2.0
	particles.scale_amount_min = 0.55
	particles.scale_amount_max = 1.1
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.10

	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.98, 0.95, 0.87, 0.9))
	ramp.set_color(1, Color(0.98, 0.95, 0.87, 0.0))
	particles.color_ramp = ramp

	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.34)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	# Radial falloff keeps the puff round — a bare quad reads as a square.
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	falloff.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var puff_texture := GradientTexture2D.new()
	puff_texture.gradient = falloff
	puff_texture.fill = GradientTexture2D.FILL_RADIAL
	puff_texture.fill_from = Vector2(0.5, 0.5)
	puff_texture.fill_to = Vector2(0.5, 0.0)
	material.albedo_texture = puff_texture
	quad.material = material
	particles.mesh = quad
	return particles

## Copies the given surfaces into a standalone mesh, re-origined on the pivot
## so the part rotates about its body attachment instead of the glb origin.
static func _make_part(part_name: String, source: ArrayMesh, surfaces: Array, pivot: Vector3) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for surface in surfaces:
		var arrays := source.surface_get_arrays(surface)
		if pivot != Vector3.ZERO:
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for i in vertices.size():
				vertices[i] -= pivot
			arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, source.surface_get_material(surface))
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	return instance

## Coat surface gets the given fur chain; every other surface is a face
## feature that keeps its imported flat color — except the iris surfaces,
## which take the glint shader and join the walker chains so the reflex
## tracks the live sun band, and the lower-light surfaces, which the eye trait
## retints. Both lists are part-local indices: the body part copies
## BODY_SURFACES 0..9 in order, so they match the source.
func _apply_coat(
	instance: MeshInstance3D,
	coat_surface: int,
	chain: Array[ShaderMaterial],
	iris_surfaces: Array = [],
	lower_light_surfaces: Array = []
) -> void:
	for surface in instance.mesh.get_surface_count():
		if surface == coat_surface:
			instance.set_surface_override_material(surface, chain[0])
		elif surface in iris_surfaces:
			var eye := PeepletEyes.iris_material(eye_trait)
			instance.set_surface_override_material(surface, eye)
			chains.append(eye)
		elif surface in lower_light_surfaces:
			instance.set_surface_override_material(
				surface,
				PeepletFur.flat_color_material(PeepletEyes.lower_light_color(eye_trait)))
		else:
			instance.set_surface_override_material(surface, PeepletFur._flat_face_material(instance.mesh.surface_get_material(surface)))

## The shell and outline half of a coat's chain, split off the shadow map
## (see PeepletFur.split_shadow_chain). Parented directly under the coat
## instance at the identity transform, so its global transform always matches
## the coat's exactly: the same breathing squash, gait sway and pivot
## rotations the coat gets, with no separate bookkeeping. decoration_mesh
## carries only the coat surface (surface index 0): for a part with a single
## surface (foot/arm/tail) that is the part's own mesh, reused rather than
## copied; the body part with multiple surfaces passes in a dedicated single
## surface extraction so its nine face surfaces are never duplicated onto a
## second instance.
func _attach_fur_decoration(
	instance: MeshInstance3D, chain: Array[ShaderMaterial], decoration_mesh: Mesh
) -> void:
	# daily (2026-10-23, the cartoon pass): no fur shells at all; the coat is
	# a flat fill with a clean edge. The shell materials stay in the chain
	# (wind, wetness and the sun still propagate) but nothing draws them.
	# With PeepletFur.ink on, the same slot carries the ink hull instead: the
	# coat mesh once more, pushed out along its normals and drawn back-face
	# in the house ink (peeplet_fur_outline.gdshader, the chain's last).
	if not PeepletFur.ink:
		return
	var decoration := MeshInstance3D.new()
	decoration.name = instance.name + "Ink"
	decoration.mesh = decoration_mesh
	decoration.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decoration.set_surface_override_material(0, chain[chain.size() - 1])
	instance.add_child(decoration)

## Desynchronise idle breathing and footfall across a flock.
func randomize_phase(rng: RandomNumberGenerator) -> void:
	anim_time = rng.randf() * TAU
	gait_phase = rng.randf() * TAU
	breath_phase = anim_time

## Temperature comfort, pre-eased by whoever simulates this body (host sim,
## or the snapshot's tc field on a client): heat pants and slumps, cold
## shivers. Purely a display state — locomotion cost lives in adventure.gd.
func set_comfort(heat: float, cold: float) -> void:
	heat_comfort = clampf(heat, 0.0, 1.0)
	cold_comfort = clampf(cold, 0.0, 1.0)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	anim_time += delta

	# Idle: gentle volume-preserving breathing on the body shell only —
	# non-uniform scale on a rotating parent would shear the limbs. Actions
	# override the breath with their own squash below.
	breath_phase += delta * BREATH_RATE * (1.0 + PANT_RATE_GAIN * heat_comfort)
	var breath := sin(breath_phase)
	var breath_depth := 1.0 + PANT_DEPTH_GAIN * heat_comfort
	var scale_mult := Vector3(1.0 - 0.020 * breath * breath_depth,
		1.0 + 0.032 * breath * breath_depth, 1.0 - 0.020 * breath * breath_depth)
	if cold_comfort > 0.0:
		var shiver := sin(anim_time * SHIVER_RATE) * SHIVER_SCALE * cold_comfort
		scale_mult += Vector3(shiver, -shiver, shiver)
	var body_offset := Vector3.ZERO
	var lean_override := false
	var lean_target := 0.0
	var twist_target := 0.0

	var sprinting := walking and running
	var sway_target := 0.0
	if walking:
		gait_phase += delta * (RUN_CADENCE if running else GAIT_CADENCE) * TAU
		sway_target = sin(gait_phase) * WADDLE_ROLL * (0.6 if running else 1.0)
	else:
		gait_phase = 0.0

	# Pick: crouch down and lean forward to reach the ground, hold, stand up.
	if pick_time >= 0.0:
		pick_time += delta
		var pp := pick_time / PICK_DURATION
		if pp >= 1.0:
			pick_time = -1.0
			# The reach is done; give the gadget back the hand trigger_pick()
			# borrowed from it, same restore attach_tool(null) does at chore end.
			if worn_gadget != null and is_instance_valid(worn_gadget):
				worn_gadget.visible = true
				update_tool_pose()
				pose_arms_on_tool(1.0)
		else:
			var bend := 0.0
			if pp < 0.35:
				bend = smoothstep(0.0, 1.0, pp / 0.35)
			elif pp < 0.6:
				bend = 1.0
			else:
				bend = smoothstep(0.0, 1.0, (1.0 - pp) / 0.4)
			scale_mult = Vector3(lerpf(1.0, 1.12, bend), lerpf(1.0, 0.80, bend), lerpf(1.0, 1.12, bend))
			lean_override = true
			lean_target = deg_to_rad(24.0 * bend)

	# Grab: the real one. The body squats to whatever depth solve_grab() worked
	# out for THIS prop and turns its torso onto it; the arm is aimed at the
	# prop's own grip point down in the arm block below, and the hand-off
	# happens after that, once the hand is drawn where it belongs.
	var grab_progress := -1.0
	if grab_time >= 0.0:
		grab_time += delta
		grab_progress = grab_time / GRAB_DURATION
		var dip := grab_dip(grab_progress)
		squat_amount = grab_depth * dip
		grab_blend = dip
		twist_target = grab_twist * dip
	else:
		squat_amount = lerpf(squat_amount, 0.0, clampf(delta * SQUAT_LERP, 0.0, 1.0))
		grab_blend = 0.0
	if squat_amount > 0.0:
		# Same shape the sit uses: the body sinks between planted feet and
		# spreads as it compresses. The feet do not move — they parent to the
		# walker root, so the legs simply disappear into the squashing blob,
		# which is what a stubby-legged creature crouching actually looks like.
		body_offset.y -= SQUAT_DROP * squat_amount
		scale_mult += Vector3(
			SQUAT_SQUASH * 0.6, -SQUAT_SQUASH, SQUAT_SQUASH * 0.6) * squat_amount
		var upright := lean_target if lean_override else 0.0
		lean_override = true
		lean_target = upright + SQUAT_LEAN * squat_amount

	if chop_time >= 0.0:
		chop_time += delta
		var chop_progress := chop_time / action_duration()
		if not chop_impact_sent and chop_time >= action_impact_time():
			chop_impact_sent = true
			chop_impact.emit()
		if chop_progress >= 1.0:
			chop_time = -1.0
		elif action_style == 0:
			# Chop: wind the axe up over the shoulder, whip through the
			# strike, recoil at impact, then settle back to rest.
			var chop_force := chop_body_force(chop_progress)
			var windup := chop_windup(chop_progress)
			var impact_compression := chop_impact_compression(chop_progress)
			scale_mult = Vector3(
				1.0 + windup * 0.05 + impact_compression * 0.11,
				1.0 - windup * 0.07 + chop_force * 0.03 - impact_compression * 0.15,
				1.0 + windup * 0.03 + impact_compression * 0.08
			)
			lean_override = true
			lean_target = deg_to_rad(-8.0 * windup + 15.0 * chop_force)
			sway_target = -0.045 * windup + 0.055 * chop_force
			twist_target = deg_to_rad(-35.0 * windup + 25.0 * chop_force)
			body_offset = Vector3(
				-0.035 * windup + 0.030 * chop_force,
				-0.018 * impact_compression,
				chop_weight_shift(chop_progress)
			)
		elif action_style == 2:
			# Dig: crouch over the shovel through the thrust and press, weight
			# on the handle, then straighten with the scooped load and twist
			# to fling it aside.
			var bend := dig_phase_blend(chop_progress, [0.0, 0.12, 0.58, 0.72, 0.22, 0.08])
			scale_mult = Vector3(1.0 + 0.13 * bend, 1.0 - 0.20 * bend, 1.0 + 0.13 * bend)
			lean_override = true
			lean_target = deg_to_rad(dig_phase_blend(chop_progress, [0.0, 10.0, 26.0, 30.0, 3.0, -6.0]))
			sway_target = dig_phase_blend(chop_progress, [0.0, 0.0, 0.02, 0.03, -0.01, 0.06])
			twist_target = deg_to_rad(dig_phase_blend(chop_progress, [0.0, 0.0, 0.0, 0.0, 8.0, 30.0]))
			body_offset = Vector3(
				dig_phase_blend(chop_progress, [0.0, 0.0, 0.0, 0.0, 0.0, 0.045]),
				-0.020 * bend,
				dig_phase_blend(chop_progress, [0.0, 0.03, 0.09, 0.11, 0.02, -0.03])
			)
		elif action_style == 3:
			# Water: lean over the plot and tip the can, hold the pour
			# steady, then straighten and settle.
			var pour := water_pour_blend(chop_progress)
			scale_mult = Vector3(1.0 + 0.05 * pour, 1.0 - 0.07 * pour, 1.0 + 0.05 * pour)
			lean_override = true
			lean_target = deg_to_rad(16.0 * pour)
			sway_target = 0.015 * pour
			body_offset = Vector3(0.0, -0.012 * pour, 0.055 * pour)

	# Sit: the body drops onto its seat and rocks back. Blended over the stand, so
	# a body can be told to sit mid-stride without popping — and sitting yields
	# to walking, because a peeplet asked to move stands up first.
	sit_amount = lerpf(
		sit_amount, 1.0 if sitting and not walking else 0.0,
		clampf(delta * SIT_LERP, 0.0, 1.0))
	if sit_amount >= SETTLE_AT and not settled:
		settled = true
		_say(SETTLE_SOUND, SETTLE_DB)
	elif sit_amount < SETTLE_AT * 0.5:
		settled = false
	if sit_amount > 0.0:
		body_offset.y -= SIT_BODY_DROP * sit_amount
		# Fold whatever lean was already asked for into the seated one rather
		# than dropping it: an action mid-sit keeps its arc, just from lower.
		var stand_lean := lean_target if lean_override else HEAT_SLUMP * heat_comfort
		lean_override = true
		lean_target = lerpf(stand_lean, SIT_LEAN, sit_amount)

	# Snack: the held prop comes up to the muzzle, the body chomps it and the
	# jaw works it twice more before the hand comes down. update_tool_pose
	# drives the prop itself; this is only what the body does around it.
	if snack_time >= 0.0:
		snack_time += delta
		if snack_time >= SNACK_DURATION:
			snack_time = -1.0
		else:
			var snack_progress := snack_time / SNACK_DURATION
			var lift := snack_lift(snack_progress)
			var chomp := snack_chomp(snack_progress)
			# One bite sound per chomp, as its phase goes by.
			if chomps_heard < SNACK_CHOMP_PHASES.size() \
					and snack_progress >= float(SNACK_CHOMP_PHASES[chomps_heard]):
				chomps_heard += 1
				_say(BITE_SOUND, BITE_DB)
			scale_mult += Vector3(
				SNACK_CHOMP_SPREAD, -SNACK_CHOMP_SQUASH, SNACK_CHOMP_SPREAD) * chomp
			var snack_lean := lean_target if lean_override else 0.0
			lean_override = true
			lean_target = snack_lean + SNACK_LEAN * lift + SNACK_CHOMP_NOD * chomp
			body_offset.z += SNACK_REACH * lift

	# Laugh: bounce the body on its own squash and rock it back, swelling in
	# and out over the beat. Runs on top of the sit and the carry, so a seated
	# peeplet can laugh with a stick still in its hand.
	if laugh_time >= 0.0:
		laugh_time += delta
		if laugh_time >= LAUGH_DURATION:
			laugh_time = -1.0
		else:
			var swell := sin(PI * laugh_time / LAUGH_DURATION)
			var bounce := sin(laugh_time * TAU * LAUGH_RATE)
			scale_mult += Vector3(
				-LAUGH_SQUASH, LAUGH_SQUASH, -LAUGH_SQUASH) * bounce * swell
			var laugh_lean := lean_target if lean_override else 0.0
			lean_override = true
			lean_target = laugh_lean + LAUGH_LEAN * swell
			sway_target += LAUGH_SWAY * sin(laugh_time * TAU * LAUGH_RATE * 0.5) * swell
			body_offset.y += LAUGH_HOP * maxf(bounce, 0.0) * swell

	# Grieve: the forward collapse, over whatever pose is already playing. The
	# slump folds into the current lean the same way the sit does, so a seated
	# mourner slumps from its seat rather than snapping upright first.
	grieve_amount = lerpf(
		grieve_amount, 1.0 if grieving and not walking else 0.0,
		clampf(delta * GRIEVE_LERP, 0.0, 1.0))
	if grieve_amount > 0.0:
		var sob := (0.5 + 0.5 * sin(anim_time * GRIEVE_SOB_RATE * TAU)) * grieve_amount
		var slump := GRIEVE_SQUASH * grieve_amount + GRIEVE_SOB * sob
		scale_mult += Vector3(slump * 0.5, -slump, slump * 0.5)
		var upright_lean := lean_target if lean_override else 0.0
		lean_override = true
		lean_target = upright_lean + GRIEVE_LEAN * grieve_amount

	body_mesh.scale = scale_mult
	# Worn gear rides the MESH, not the node it hangs off. body_mesh.scale is
	# what squashes the skull, and the mounts are its siblings under `body` —
	# so a mount left at its rest height floats the hat off a flattened head
	# (measured seated: the skull ring drops to y 0.633 glb while the mount
	# stays at 0.760, a 4.8 cm gap on a 60 cm peeplet) and sinks it into a
	# stretched one. Same correction the snack pose makes for the mouth. The
	# tool mount is deliberately not here: update_tool_pose owns it outright.
	headgear_mount.position = HEADGEAR_REST_MOUNT * scale_mult
	eyewear_mount.position = EYEWEAR_REST_MOUNT * LAB_TO_GLB * scale_mult
	# The FIT follows the spread as well as the seat. Both worn scales are
	# ratios against measurements on the unsquashed shell — the skull ring's
	# radius 0.391 for a hat opening of 0.17, and the eye centres at x 0.244
	# for the lens plane — and a squash moves both. Gear left at its authored
	# fit reads undersized on a widened head, with the lenses inboard of the
	# eyes they belong on.
	#
	# Uniform on purpose, off the mean of the two horizontal axes (a chop
	# squashes x and z by different amounts): the ring is circular, and a
	# non-uniform parent scale would shear every rotated child mesh inside a
	# hat, which is the trap the pose attachments already document.
	var gear_spread := (scale_mult.x + scale_mult.z) * 0.5
	if worn_headgear != null and is_instance_valid(worn_headgear):
		worn_headgear.scale = Vector3.ONE * (HEADGEAR_WORN_SCALE * gear_spread)
	if worn_eyewear != null and is_instance_valid(worn_eyewear):
		worn_eyewear.scale = Vector3.ONE \
			* (EYEWEAR_WORN_SCALE * LAB_TO_GLB * gear_spread)
	body.position = Vector3(0.0, MESH_ORIGIN_HEIGHT, 0.0) + body_offset * LAB_TO_GLB
	body_sway = lerpf(body_sway, sway_target, clampf(delta * SWAY_LERP, 0.0, 1.0))
	# Sprinting tips the torso forward like a kid barreling downhill; actions
	# bring their own lean keys.
	if not lean_override:
		# An overheated idle body sags forward under its coat.
		lean_target = RUN_LEAN if sprinting else HEAT_SLUMP * heat_comfort
	body_lean = lerpf(body_lean, lean_target, clampf(delta * LEAN_LERP, 0.0, 1.0))
	body_twist = lerpf(body_twist, twist_target, clampf(delta * 10.0, 0.0, 1.0))
	body.rotation = Vector3(body_lean, body_twist, body_sway)

	# Alternating step cycle: each foot lifts and swings forward half a phase
	# apart; idle feet ease back to their planted rest spot.
	var foot_lift := RUN_FOOT_LIFT if sprinting else FOOT_LIFT
	var foot_stride := RUN_FOOT_STRIDE if sprinting else FOOT_STRIDE
	for index in feet.size():
		var target: Vector3 = foot_rest_positions[index]
		if walking:
			var phase := gait_phase + (0.0 if index == 0 else PI)
			target += Vector3(0.0, maxf(sin(phase), 0.0) * foot_lift, cos(phase) * foot_stride)
		# Seated: swing the leg forward and out ABOUT THE HIP. Rotating the node
		# turns it about its own origin, so the shift below cancels how far that
		# carried the hip — leaving the socket where the body still covers it —
		# and the extra drop is the body's own, so hip and socket fall together.
		var pose := Basis.IDENTITY
		if sit_amount > 0.0:
			var side := -1.0 if index == 0 else 1.0
			pose = Basis.from_euler(Vector3(
				SIT_LEG_PITCH * sit_amount, 0.0, side * SIT_LEG_SPLAY * sit_amount))
			target += HIP_LOCAL - pose * HIP_LOCAL \
				+ Vector3(0.0, -SIT_BODY_DROP * LAB_TO_GLB * sit_amount, 0.0)
		elif squat_amount > 0.0:
			# Knees out. Rotated about the same hip socket the sit uses, so the
			# stub stays swallowed instead of walking out of it sideways — and
			# the soles stay put, because a squat is the body coming down to
			# the feet, not the feet leaving the ground.
			var side := -1.0 if index == 0 else 1.0
			pose = Basis.from_euler(
				Vector3(0.0, 0.0, side * SQUAT_LEG_SPLAY * squat_amount))
			target += HIP_LOCAL - pose * HIP_LOCAL
		feet[index].position = feet[index].position.lerp(target, clampf(delta * FOOT_LERP, 0.0, 1.0))
		feet[index].basis = pose

	# Arms hang from the T-pose droop and counter-swing to the legs (opposite
	# phase); an idle wave keeps them alive between steps. Sprinting eases the
	# shoulders back up toward the modeled T — arms held straight out, no
	# counter-swing, just a light flutter from the footfalls.
	arm_droop = lerpf(arm_droop, RUN_ARM_DROOP if sprinting else ARM_DROOP, clampf(delta * ARM_POSE_LERP, 0.0, 1.0))
	var holding := carried_prop() != null
	if grab_time >= 0.0 and not grab_taken and not grab_placing:
		# Reaching for a prop that is still lying in the world: the arm aims at
		# the prop's real grip point, so the hand travels to the object rather
		# than the object travelling to the hand.
		var reaching := grab_arm()
		for index in arms.size():
			if index == reaching:
				reach_arm_at(index, grab_grip_point(), grab_blend)
			else:
				pose_idle_arm(index)
	elif holding:
		update_tool_pose()
		pose_arms_on_tool(delta)
	else:
		for index in arms.size():
			pose_idle_arm(index)

	# The hand-off, last: the arms above have just been posed for THIS frame, so
	# the hand is where it is about to be drawn, and that is the only honest
	# moment to change a prop's parent.
	if grab_progress >= 0.0:
		resolve_grab(grab_progress)

	dust.emitting = sprinting

	tail.rotation = Vector3(
		0.10 * sin(anim_time * BREATH_RATE + 0.6) + SIT_TAIL_LIFT * sit_amount,
		0.14 * sin(anim_time * 1.7),
		0.0)

## One arm hanging off the T-pose droop: counter-swing to the legs, an idle
## wave between steps, and the pick reach on the right side. Used both when
## the hands are empty and for the free arm of a one-handed carry.
func pose_idle_arm(index: int) -> void:
	var sprinting := walking and running
	var side := -1.0 if index == 0 else 1.0
	arms[index].scale = Vector3.ONE
	if battle_arms.size() == 2:
		arms[index].rotation = battle_arms[index]
		return
	# Clinch is the one battle hold driven by a state flag rather than the
	# animated tracks: both bodies keep the mutual grab for its whole duration.
	if battle_pose == "clinch":
		arms[index].rotation = Vector3(-1.18, 0.0, -side * 0.72)
		return
	var swing := 0.0
	if sprinting:
		swing = sin(gait_phase * 2.0) * RUN_ARM_FLUTTER
	elif walking:
		swing = sin(gait_phase + (PI if index == 0 else 0.0)) * ARM_SWING
	var wave := side * ARM_WAVE * sin(anim_time * BREATH_RATE + 0.4) * (0.3 if sprinting else 1.0)
	var pose := Vector3(swing, 0.0, -side * arm_droop + wave)
	# Pick: the right arm reaches down and forward to the ground, then
	# lifts back up holding the object near the belly.
	if pick_time >= 0.0 and side > 0.0:
		var pp := pick_time / PICK_DURATION
		var reach := 0.0
		if pp < 0.4:
			reach = smoothstep(0.0, 1.0, pp / 0.4)
		elif pp < 0.6:
			reach = 1.0
		else:
			reach = smoothstep(0.0, 1.0, (1.0 - pp) / 0.4)
		pose = pose.lerp(Vector3(-1.1, 0.0, -side * ARM_DROOP - 0.35), reach)
	arms[index].rotation = pose

# --- Tool action API, lab canon names (peeplet_lab.gd). The farm driver
# treats trigger_dig/trigger_water/trigger_pick plus is_chopping and the
# chop_impact signal as the whole animation surface.

func trigger_pick() -> void:
	pick_time = 0.0
	# A worn gadget claims the same arm (carry_arm 1) the pick reach needs;
	# farm chores never attach_tool() for plant/harvest/eat, so nothing else
	# would get it out of the way. Hide it here, same as attach_tool() does
	# for a real tool, and hand it back once the reach finishes above.
	if worn_gadget != null and is_instance_valid(worn_gadget):
		worn_gadget.visible = false

# --- Grab. Everything below is one idea: a prop is a thing in the world, and
# the only way it gets into a hand is that the hand goes to it. There is no
# path here that moves a prop to a hand, spawns one there, or frees one to fake
# a put-down. See WorldProp for the other half of the contract.

## The squat's envelope: dip in, hold at the bottom while the hand closes, rise
## back out. Drives the squat depth, the torso twist and the prop blend all at
## once, so the three can never disagree about where in the beat we are.
func grab_dip(progress: float) -> float:
	if progress <= 0.0:
		return 0.0
	if progress < GRAB_CONTACT_AT:
		return smoothstep(0.0, 1.0, progress / GRAB_CONTACT_AT)
	if progress < GRAB_CLOSE_AT:
		return 1.0
	return smoothstep(0.0, 1.0, clampf((1.0 - progress) / (1.0 - GRAB_CLOSE_AT), 0.0, 1.0))

## The point on a prop a hand closes around, in world space. A prop names it
## with "grip_local"; otherwise its carry pose does.
static func prop_grip_point(prop: Node3D) -> Vector3:
	var carry: Dictionary = prop.get_meta("carry_pose", SHOULDER_CARRY)
	var local: Vector3 = prop.get_meta("grip_local", carry["grip_local"])
	return prop.global_transform * local

## Where this arm's HAND is, in world space.
##
## Not a guess and not a tuned offset. The aim solver's entire contract is that
## a grip point lands at one rest arm-length along the arm's own axis (times
## whatever stretch it is carrying), so that point IS the hand by definition —
## it is where every carried prop's grip already sits. Anything that wants to
## put something in a hand asks here; hand-authored offsets down the nub are
## how a rock ends up parked against a shoulder.
func hand_point(index: int) -> Vector3:
	var arm := arms[index]
	# arm.global_basis.x already carries the arm's stretch and the root scale,
	# so scaling it by the tip's own part-space extent lands on the hand in
	# world space whatever the arm is currently doing.
	var side := -1.0 if index == 0 else 1.0
	return arm.global_position + arm.global_basis.x * (side * arm_tip)

## The arm's reach in the walker's own (part) units, and in world units. Every
## stretch and every reach solve keys off these, so the number the solver aims
## with is the number the shell actually has.
func hand_reach_local() -> float:
	return arm_tip

func hand_reach_world() -> float:
	return arm_tip * global_basis.get_scale().x

## An orthonormal frame at the hand, sized for a prop: the arm's own rotation
## without its reach stretch, which would otherwise squash whatever it holds
## along the nub.
func hand_frame(index: int, prop_scale: float) -> Transform3D:
	return Transform3D(
		arms[index].global_basis.orthonormalized()
			* Basis.from_scale(Vector3.ONE * prop_scale),
		hand_point(index))

## Put `prop` in this hand so its GRIP sits at the hand point — the same anchor
## a real grab closes on. For poses that hold a prop somewhere the carry mount
## does not cover (an offer held out, a raised toast) and that would otherwise
## have to invent a mount.
func pin_prop_to_hand(prop: Node3D, index: int) -> void:
	var frame := hand_frame(index, carry_scale_of(prop))
	var carry: Dictionary = prop.get_meta("carry_pose", SHOULDER_CARRY)
	var grip_local: Vector3 = prop.get_meta("grip_local", carry["grip_local"])
	prop.global_transform = Transform3D(
		frame.basis, frame.origin - frame.basis * grip_local)

## Which arm does the taking — the same one that would carry the prop, so the
## hand that reaches is the hand that keeps it.
func grab_arm() -> int:
	var prop: Node3D = grab_prop if grab_prop != null else carried_prop()
	if prop == null or not is_instance_valid(prop):
		return 1
	var carry: Dictionary = prop.get_meta("carry_pose", SHOULDER_CARRY)
	return int(carry["carry_arm"])

func grab_grip_point() -> Vector3:
	if grab_prop == null or not is_instance_valid(grab_prop):
		return global_position
	return prop_grip_point(grab_prop)

## Where the shoulder of `index` sits, in walker-local (glb) units, for a given
## squat depth and torso twist. Mirrors exactly what advance() does to the body
## node — if one changes the other has to, or the solve aims at a shoulder the
## body never puts there.
func shoulder_local(index: int, squat: float, twist: float) -> Vector3:
	var height := MESH_ORIGIN_HEIGHT - SQUAT_DROP * LAB_TO_GLB * squat
	var turned := Basis.from_euler(Vector3(SQUAT_LEAN * squat, twist, 0.0))
	return Vector3(0.0, height, 0.0) + turned * ARM_PIVOTS[index]

## The posture that puts this body's hand on `point`: how deep to squat, how
## far to turn the torso, and what that costs in arm stretch.
##
## The depth is bisected, not solved in closed form. The squat's lean carries
## the shoulder forward as well as down, and a sign slip in that algebra would
## show up as an arm reaching through a belly — a bug nobody would catch by
## reading. Eight halvings of [0,1] resolve the depth to under a millimetre of
## shoulder height and cannot be wrong.
func solve_grab(point: Vector3) -> Dictionary:
	var local := global_transform.affine_inverse() * point
	var index := grab_arm()
	var side := 1.0 if index == 1 else -1.0
	var twist := clampf(
		atan2(local.x, local.z) - GRAB_BEARING * side,
		-GRAB_TWIST_CAP, GRAB_TWIST_CAP)
	var low := 0.0
	var high := 1.0
	for _step in SQUAT_SOLVE_STEPS:
		var mid := (low + high) * 0.5
		if local.distance_to(shoulder_local(index, mid, twist)) > hand_reach_local():
			low = mid
		else:
			high = mid
	var depth := (low + high) * 0.5
	var stretch := local.distance_to(shoulder_local(index, depth, twist)) \
		/ hand_reach_local()
	return {
		"depth": depth,
		"twist": twist,
		"stretch": stretch,
		"reachable": stretch <= GRAB_MAX_STRETCH and stretch >= GRAB_MIN_STRETCH,
	}

## Can this body, standing exactly where it stands, get a hand onto `point`?
## A driver that gets false walks closer — it does not get to reach further.
func can_reach(point: Vector3) -> bool:
	return bool(solve_grab(point)["reachable"])

## World-space offset from a prop to where a body should stand to take it, in
## the taker's own local frame. A driver adds this (rotated into its space) to
## the prop's position to get the spot to walk to.
static func grab_stand_local() -> Vector3:
	return -GRAB_PROP_LOCAL * WALKER_SCALE

## Reach out and take `prop` off the world. Refused when the hands are full,
## when another beat is running, or when the prop is out of reach — a refusal
## is a driver's cue to walk closer, never a licence to teleport the prop in.
func begin_grab(prop: Node3D) -> bool:
	if prop == null or not is_instance_valid(prop):
		return false
	if grab_time >= 0.0 or chop_time >= 0.0 or snack_time >= 0.0:
		return false
	if held_tool != null and is_instance_valid(held_tool):
		return false
	# A prop in SOMEBODY ELSE'S hand is a legal target — that is what a snatch
	# is, and the reach solver re-aims every frame, so a grip point that walks
	# around is no harder to close on than one lying in the grass. What is not
	# legal is grabbing what this body is already holding.
	if prop is WorldProp and (prop as WorldProp).holder == self:
		return false
	var solved := solve_grab(prop_grip_point(prop))
	if not bool(solved["reachable"]):
		return false
	grab_prop = prop
	grab_placing = false
	grab_taken = false
	grab_time = 0.0
	grab_depth = float(solved["depth"])
	grab_twist = float(solved["twist"])
	# The trait gadget rides the hand the reach needs; hide it for the beat,
	# exactly as trigger_pick() does. attach_tool takes over from there.
	if worn_gadget != null and is_instance_valid(worn_gadget):
		worn_gadget.visible = false
	return true

## Put the held prop down at `rest` — a world transform on the ground, usually
## from WorldProp.rest_transform_at. The body squats it down and the hand only
## opens once the prop is actually resting there.
func begin_place(rest: Transform3D) -> bool:
	var prop := held_tool
	if prop == null or not is_instance_valid(prop):
		return false
	if grab_time >= 0.0 or chop_time >= 0.0 or snack_time >= 0.0:
		return false
	var carry: Dictionary = prop.get_meta("carry_pose", SHOULDER_CARRY)
	var grip_local: Vector3 = prop.get_meta("grip_local", carry["grip_local"])
	var solved := solve_grab(rest * grip_local)
	if not bool(solved["reachable"]):
		return false
	grab_prop = prop
	grab_placing = true
	grab_taken = false
	grab_time = 0.0
	grab_depth = float(solved["depth"])
	grab_twist = float(solved["twist"])
	grab_rest = rest
	return true

## Runs at the end of advance(), after the arms are posed — the hand is where
## it is about to be drawn, and that is the only honest frame to hand a prop
## over. Two events: the contact, and the end of the beat.
func resolve_grab(progress: float) -> void:
	if grab_prop != null and not is_instance_valid(grab_prop):
		cancel_grab()
		return
	if not grab_taken and progress >= GRAB_CONTACT_AT:
		grab_taken = true
		if grab_placing:
			_release_to_rest()
		else:
			_close_hand_on_prop()
		grab_contact.emit(grab_prop)
	if progress >= 1.0:
		var finished := grab_prop
		grab_time = -1.0
		grab_prop = null
		grab_blend = 0.0
		grab_placing = false
		grab_taken = false
		grab_done.emit(finished)

## Abandon a beat mid-flight (the prop was destroyed, the driver dropped the
## task). A prop already taken stays taken: a hand does not un-close.
func cancel_grab() -> void:
	grab_time = -1.0
	grab_prop = null
	grab_placing = false
	grab_taken = false
	grab_blend = 0.0

func is_grabbing() -> bool:
	return grab_time >= 0.0

## The contact frame of a pickup. The prop changes parent and NOTHING ELSE
## changes: reparent keeps the world transform, and the pose it has in the body
## frame right now becomes one end of the blend that eases it into the carry.
func _close_hand_on_prop() -> void:
	var prop := grab_prop
	grab_hold_local = body.global_transform.affine_inverse() * prop.global_transform
	if worn_gadget != null and is_instance_valid(worn_gadget):
		worn_gadget.visible = false
	# Taking it out of somebody else's hand: they lose it on the same frame
	# this hand closes, so the rock is never in two grips and never in none.
	if prop is WorldProp:
		var previous := (prop as WorldProp).holder as PeepletWalker
		if previous != null and is_instance_valid(previous) and previous != self:
			previous.let_go_of(prop)
	prop.reparent(tool_mount, true)
	held_tool = prop
	measure_carry(prop)
	if prop is WorldProp:
		(prop as WorldProp).holder = self
	update_tool_pose()

## Somebody else took what this body was holding. Only the bookkeeping — the
## taker owns the reparent, because the prop is going straight into their hand
## and must not spend a frame anywhere else.
func let_go_of(prop: Node3D) -> void:
	if held_tool != prop:
		return
	if grab_prop == prop:
		cancel_grab()
	held_tool = null
	if worn_gadget != null and is_instance_valid(worn_gadget):
		worn_gadget.visible = true

## The contact frame of a put-down: the prop is already at its resting pose
## (the blend walked it there), so letting go is a reparent and nothing more.
func _release_to_rest() -> void:
	var prop := grab_prop
	prop.reparent(_prop_world_parent(prop), true)
	prop.global_transform = grab_rest
	held_tool = null
	if prop is WorldProp:
		var world_prop := prop as WorldProp
		world_prop.holder = null
		world_prop.settle_here()
	if worn_gadget != null and is_instance_valid(worn_gadget):
		worn_gadget.visible = true
		update_tool_pose()
		pose_arms_on_tool(1.0)

## Let go of the held prop in flight — thrown, knocked loose, or snatched out
## of the hand. It keeps its world transform and arcs to the ground on its own.
## Nothing is freed and nothing is respawned; the prop that lands is the prop
## that was being held.
func release_prop(velocity := Vector3.ZERO) -> Node3D:
	var prop := held_tool
	if prop == null or not is_instance_valid(prop):
		return null
	if grab_prop == prop:
		cancel_grab()
	prop.reparent(_prop_world_parent(prop), true)
	held_tool = null
	if prop is WorldProp:
		(prop as WorldProp).toss(velocity)
	if worn_gadget != null and is_instance_valid(worn_gadget):
		worn_gadget.visible = true
		update_tool_pose()
		pose_arms_on_tool(1.0)
	return prop

## Where a released prop goes back to: its own registry if it has one, else
## whatever holds this walker. Never the walker itself — a prop parented under
## a body it is no longer in the hand of would ride that body around the map.
func _prop_world_parent(prop: Node3D) -> Node:
	if prop is WorldProp:
		var home: Node = (prop as WorldProp).home
		if home != null and is_instance_valid(home):
			return home
	var above := get_parent()
	return above if above != null else get_tree().current_scene

## One beat out of this body's mouth. Streams load on first use and stay in the
## resource cache, so the bodies share them rather than each holding a copy.
func _say(path: String, trim_db: float) -> void:
	if voice == null or headless:
		return
	voice.stream = load(path)
	voice.volume_db = trim_db
	voice.play()

## Sit down, or stand back up. The pose eases over SIT_LERP either way, so
## this can be handed straight off whatever the body is already doing.
func set_sitting(down: bool) -> void:
	sitting = down

## Collapse forward in mourning, or straighten back up. Held like the sit —
## grief has no duration, the scene decides when it ends.
func set_grieving(down: bool) -> void:
	grieving = down

## Raise whatever is in hand to the muzzle and eat from it. Refused while a
## swing or another bite is running, or with an empty pair of hands — the beat
## is a carry pose lifted to the face, so it needs something to lift.
func trigger_snack() -> bool:
	if chop_time >= 0.0 or snack_time >= 0.0 or carried_prop() == null:
		return false
	snack_time = 0.0
	chomps_heard = 0
	return true

func is_snacking() -> bool:
	return snack_time >= 0.0

## Laugh. Refused mid-bite: a body that bounces with food at its mouth reads as
## choking, not laughing — a caller picks somebody with their hands down.
func trigger_laugh() -> bool:
	if snack_time >= 0.0 or laugh_time >= 0.0:
		return false
	laugh_time = 0.0
	_say(String(LAUGH_SOUNDS[laugh_take]), LAUGH_DB)
	laugh_take = (laugh_take + 1) % LAUGH_SOUNDS.size()
	return true

## Startled squeak for being hit by something small — a thrown coin, not a
## fight. Sound only; the scene owns whatever flinch goes with it.
func squeak_hit() -> void:
	_say(SQUEAK_SOUND, SQUEAK_DB)

func is_laughing() -> bool:
	return laugh_time >= 0.0

## Hand up (0 at rest, 1 with the food at the muzzle), held through the chomps.
func snack_lift(progress: float) -> float:
	if progress < SNACK_LIFT_IN:
		return smoothstep(0.0, 1.0, progress / SNACK_LIFT_IN)
	if progress < SNACK_LIFT_OUT:
		return 1.0
	return smoothstep(0.0, 1.0, (1.0 - progress) / (1.0 - SNACK_LIFT_OUT))

## The bites: a squared pulse at each chomp phase, zero between them.
func snack_chomp(progress: float) -> float:
	var pulse := 0.0
	for phase in SNACK_CHOMP_PHASES:
		pulse = maxf(pulse, 1.0 - minf(absf(progress - float(phase)) / SNACK_CHOMP_WIDTH, 1.0))
	return pulse * pulse

func trigger_chop() -> bool:
	return trigger_tool_action(0)

func trigger_dig() -> bool:
	return trigger_tool_action(2)

func trigger_water() -> bool:
	return trigger_tool_action(3)

func trigger_tool_action(style: int) -> bool:
	if chop_time >= 0.0:
		return false
	action_style = style
	chop_time = 0.0
	chop_impact_sent = false
	pick_time = -1.0
	walking = false
	running = false
	return true

func is_chopping() -> bool:
	return chop_time >= 0.0

func action_duration() -> float:
	if action_style == 0:
		return CHOP_DURATION
	return WATER_DURATION if action_style == 3 else DIG_DURATION

func action_impact_time() -> float:
	if action_style == 0:
		return CHOP_IMPACT_TIME
	return WATER_IMPACT_TIME if action_style == 3 else DIG_IMPACT_TIME

## Put a prop straight into the hand, no reach. This is the blunt path and it
## stays for the cases that have no world to reach into: the lab bench, debug
## keys, and a walker built holding something. GAMEPLAY GOES THROUGH
## begin_grab — a prop that appears in a fist is the thing this whole subsystem
## exists to stop.
func attach_tool(tool: Node3D) -> void:
	if held_tool != null and is_instance_valid(held_tool):
		if held_tool is WorldProp:
			# A world prop is never destroyed by the hand that held it. It goes
			# back to the world where it was let go — which is also what makes
			# attach_tool(null) safe as the blunt cleanup path (task aborts,
			# driver reconfigures) without quietly deleting the valley's tools.
			release_prop()
		else:
			held_tool.queue_free()
	held_tool = null
	if tool == null:
		# Chore over: the gadget trait comes back to the hand it was holding.
		if worn_gadget != null and is_instance_valid(worn_gadget):
			worn_gadget.visible = true
			update_tool_pose()
			pose_arms_on_tool(1.0)
		return
	if worn_gadget != null and is_instance_valid(worn_gadget):
		worn_gadget.visible = false
	held_tool = tool
	if tool.get_parent() != null:
		tool.reparent(tool_mount, false)
	else:
		tool_mount.add_child(tool)
	tool.position = Vector3.ZERO
	tool.rotation = Vector3.ZERO
	measure_carry(tool)
	if tool is WorldProp:
		# Even on the blunt path the registry has to know who has it, or
		# nearest_free() will hand the same prop to somebody else as well.
		(tool as WorldProp).holder = self
	update_tool_pose()
	pose_arms_on_tool(1.0)

## The prop the carry pose drives. A held tool preempts the gadget trait; with
## neither out the arms fall back to their idle swing.
func carried_prop() -> Node3D:
	if held_tool != null and is_instance_valid(held_tool):
		return held_tool
	if worn_gadget != null and is_instance_valid(worn_gadget) and worn_gadget.visible:
		return worn_gadget
	return null


## The gadget trait, by canon value ("fishingRod") or GLB stem. "none",
## unknown values and "" leave the peeplet bare-handed.
func set_gadget(kind: String) -> void:
	if worn_gadget != null and is_instance_valid(worn_gadget):
		worn_gadget.queue_free()
	worn_gadget = null
	# The gadgets (items/gadget_item_factory.gd and its models) stayed in
	# ~/dev/peeplet; daily's copy of the walker holds none.
	gadget_kind = ""
	if gadget_kind == "":
		return
	worn_gadget = null
	tool_mount.add_child(worn_gadget)
	worn_gadget.position = Vector3.ZERO
	worn_gadget.rotation = Vector3.ZERO
	measure_carry(worn_gadget)
	worn_gadget.visible = held_tool == null or not is_instance_valid(held_tool)
	if worn_gadget.visible:
		update_tool_pose()
		pose_arms_on_tool(1.0)

## Sizes the prop against the peeplet and picks its resting pose, both cached
## on the prop so the per-frame pose does not re-measure. A prop that already
## carries a "carry_pose" meta keeps it — that is the seam for a bespoke pose.
static func measure_carry(tool: Node3D) -> void:
	var authored := prop_local_length(tool) * LAB_TO_WORLD
	var fit := 1.0 if authored <= 0.0 else minf(1.0, TOOL_TARGET_LENGTH / authored)
	tool.set_meta("carry_scale", LAB_TO_WORLD * fit)
	if tool.has_meta("carry_pose"):
		return
	var carried := authored * fit
	tool.set_meta(
		"carry_pose",
		SHOULDER_CARRY if carried >= SHOULDER_CARRY_MIN_LENGTH else HIP_CARRY
	)

## Transform from `node`'s space into `ancestor`'s, composed from the local
## transforms on the way up. The global_transform route needs both nodes
## already in the tree, and a prop is measured while it is still being built —
## out of tree that route silently returns identity, which reads as a prop
## whose parts are all stacked at its origin and quietly mis-sizes it.
static func transform_between(node: Node3D, ancestor: Node3D) -> Transform3D:
	var composed := Transform3D.IDENTITY
	var walk := node
	while walk != null and walk != ancestor:
		composed = walk.transform * composed
		walk = walk.get_parent() as Node3D
	return composed

## Longest axis of the prop's combined geometry, in the prop's own units. The
## ink hulls sit a hair proud of their source mesh, so they stay out of it.
static func prop_local_length(tool: Node3D) -> float:
	var bounds := AABB()
	var started := false
	for mesh in tool.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if instance.mesh == null or instance.name == "Ink":  # ToonPropLook.INK_CHILD_NAME in ~/dev/peeplet
			continue
		var box := transform_between(instance, tool) * instance.mesh.get_aabb()
		bounds = box if not started else bounds.merge(box)
		started = true
	if not started:
		return 0.0
	return maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))

## Worn eyewear rides the face mount; null detaches. Lab convention: the
## standalone-display temple arms spear out the back of the fur at face
## scale, so the worn copy goes without them.
func attach_eyewear(eyewear: Node3D) -> void:
	if worn_eyewear != null and is_instance_valid(worn_eyewear):
		worn_eyewear.queue_free()
	worn_eyewear = null
	if eyewear == null:
		return
	worn_eyewear = eyewear
	if eyewear.get_parent() != null:
		eyewear.reparent(eyewear_mount, false)
	else:
		eyewear_mount.add_child(eyewear)
	eyewear.position = Vector3.ZERO
	eyewear.rotation = Vector3.ZERO
	eyewear.scale = Vector3.ONE * (EYEWEAR_WORN_SCALE * LAB_TO_GLB)
	for arm in eyewear.find_children("Arm*", "MeshInstance3D", true, false):
		(arm as MeshInstance3D).visible = false

## Worn headgear sits on the skull mount; null detaches. Parenting to `body`
## (through the mount) is what makes the hat breathe and lean with the walk
## cycle instead of hovering over a bobbing head.
func attach_headgear(headgear: Node3D) -> void:
	if worn_headgear != null and is_instance_valid(worn_headgear):
		worn_headgear.queue_free()
	worn_headgear = null
	if headgear == null:
		return
	worn_headgear = headgear
	if headgear.get_parent() != null:
		headgear.reparent(headgear_mount, false)
	else:
		headgear_mount.add_child(headgear)
	headgear.position = Vector3.ZERO
	headgear.rotation = Vector3.ZERO
	headgear.scale = Vector3.ONE * HEADGEAR_WORN_SCALE

func dig_phase_blend(progress: float, keys: Array) -> float:
	var previous_bound := 0.0
	for index in DIG_PHASE_BOUNDS.size():
		var bound: float = DIG_PHASE_BOUNDS[index]
		if progress < bound:
			var t: float = smoothstep(0.0, 1.0, (progress - previous_bound) / (bound - previous_bound))
			return lerpf(keys[index], keys[index + 1], t)
		previous_bound = bound
	return lerpf(keys[5], keys[0], smoothstep(0.0, 1.0, (progress - 0.90) / 0.10))

func water_pour_blend(progress: float) -> float:
	if progress < 0.3:
		return smoothstep(0.0, 1.0, progress / 0.3)
	if progress < 0.75:
		return 1.0
	return smoothstep(0.0, 1.0, (1.0 - progress) / 0.25)

# The blade sits at the tool's +Y top; the thrust swings it right over into
# the dirt, then the lever rocks the handle back to pry the scoop loose.
func dig_tool_pitch(progress: float) -> float:
	return deg_to_rad(dig_phase_blend(progress, [0.0, 40.0, 120.0, 108.0, 60.0, 55.0]))

func dig_tool_yaw(progress: float) -> float:
	return deg_to_rad(dig_phase_blend(progress, [-18.0, -6.0, 0.0, 0.0, 8.0, 64.0]))

func dig_tool_roll(progress: float) -> float:
	return deg_to_rad(dig_phase_blend(progress, [0.0, 0.0, 0.0, 0.0, -5.0, -28.0]))

func dig_handle_slide(progress: float) -> float:
	return dig_phase_blend(progress, [0.0, 0.06, -0.04, -0.02, 0.04, 0.06])

# Lab world units; callers convert through LAB_TO_GLB for mount space.
func dig_mount_position(progress: float) -> Vector3:
	return Vector3(
		dig_phase_blend(progress, [0.0, 0.0, 0.0, 0.0, 0.02, 0.34]),
		dig_phase_blend(progress, [0.16, 0.34, 0.34, 0.20, 0.44, 0.50]),
		dig_phase_blend(progress, [0.34, 0.55, 0.60, 0.48, 0.50, 0.42])
	)

func chop_windup(progress: float) -> float:
	if progress < 0.32:
		return smoothstep(0.0, 1.0, progress / 0.32)
	if progress < 0.50:
		return smoothstep(1.0, 0.0, (progress - 0.32) / 0.18)
	return 0.0

func chop_body_force(progress: float) -> float:
	if progress < 0.32:
		return 0.0
	if progress < 0.50:
		return smoothstep(0.0, 1.0, (progress - 0.32) / 0.18)
	return smoothstep(1.0, 0.0, (progress - 0.50) / 0.38)

func chop_impact_compression(progress: float) -> float:
	if progress < 0.44:
		return 0.0
	if progress < 0.50:
		return smoothstep(0.0, 1.0, (progress - 0.44) / 0.06)
	if progress < 0.68:
		return smoothstep(1.0, 0.0, (progress - 0.50) / 0.18)
	return 0.0

func chop_weight_shift(progress: float) -> float:
	if progress < 0.32:
		return lerpf(0.0, -0.085, smoothstep(0.0, 1.0, progress / 0.32))
	if progress < 0.50:
		return lerpf(-0.085, 0.105, smoothstep(0.0, 1.0, (progress - 0.32) / 0.18))
	if progress < 0.72:
		return lerpf(0.105, 0.060, smoothstep(0.0, 1.0, (progress - 0.50) / 0.22))
	return lerpf(0.060, 0.0, smoothstep(0.0, 1.0, (progress - 0.72) / 0.28))

# Swing keyed on the shared chop phases: rest -> windup (0.32) -> impact
# (0.50) -> follow-through (0.66) -> back to rest.
func chop_phase_blend(progress: float, rest: float, windup: float, impact: float, follow: float) -> float:
	if progress < 0.32:
		return lerpf(rest, windup, smoothstep(0.0, 1.0, progress / 0.32))
	if progress < 0.50:
		return lerpf(windup, impact, smoothstep(0.0, 1.0, (progress - 0.32) / 0.18))
	if progress < 0.66:
		return lerpf(impact, follow, smoothstep(0.0, 1.0, (progress - 0.50) / 0.16))
	return lerpf(follow, rest, smoothstep(0.0, 1.0, (progress - 0.66) / 0.34))

# Baseball-style swing: one angle drives the whole arc. The hands (mount)
# ORBIT the body on this angle while the handle points outward along the
# same angle, so the club sweeps a horizontal arc instead of sliding.
# Wound far behind the shoulder, whipped forward — and STOPPED dead at the
# trunk out front: the blade bites, recoils a hair, then pulls back to
# rest the way it came instead of orbiting through.
func chop_swing_angle(progress: float) -> float:
	return deg_to_rad(chop_phase_blend(progress, -18.0, -140.0, 5.0, -2.0))

func chop_tool_yaw(progress: float) -> float:
	return chop_swing_angle(progress)

# Handle tilt away from vertical: raised diagonally over the shoulder on
# the windup, laid nearly horizontal (head-first into the trunk) through
# the strike.
func chop_tool_pitch(progress: float) -> float:
	return deg_to_rad(chop_phase_blend(progress, 0.0, 32.0, 78.0, 72.0))

func chop_tool_roll(progress: float) -> float:
	return deg_to_rad(chop_phase_blend(progress, 0.0, -10.0, 8.0, 5.0))

# Blade spin about the handle so the cutting edge leads the horizontal
# sweep instead of facing the ground.
func chop_edge_spin(progress: float) -> float:
	return deg_to_rad(chop_phase_blend(progress, 0.0, 90.0, 90.0, 82.0))

# Hands choke down toward the handle base during the swing so the club is
# held by its end — the shaft sweeps outside the body instead of through it.
func chop_handle_slide(progress: float) -> float:
	return chop_phase_blend(progress, 0.0, 0.20, 0.24, 0.22)

const CHOP_PIVOT_Z := 0.19

# Hands orbit the shoulder pivot on the swing angle; height rises over the
# shoulder for the windup and settles to trunk height through the strike.
# Lab world units; callers convert through LAB_TO_GLB for mount space, same
# as dig_mount_position.
#
# Left alone at the carried scale. The keys were authored against a full-size
# axe, but the strike already lands ~0.78 world units out and a tender stands
# only CHOP_STAND_GAP (0.35) off the trunk, so the blade was overshooting into
# the wood; the shorter axe closes that gap rather than opening one. Pushing
# the hands out to compensate would also drag the grip past the arm's 2.4x
# stretch clamp and detach the nub from the shaft.
func chop_reach(progress: float) -> float:
	return chop_phase_blend(progress, 0.45, 0.62, 0.72, 0.70)

func chop_mount_position(progress: float) -> Vector3:
	var angle := chop_swing_angle(progress)
	var reach := chop_reach(progress)
	return Vector3(
		sin(angle) * reach,
		chop_phase_blend(progress, 0.19, 0.55, 0.30, 0.28),
		CHOP_PIVOT_Z + cos(angle) * reach
	)

func update_tool_pose() -> void:
	var prop := carried_prop()
	if tool_mount == null or prop == null:
		return
	var carry: Dictionary = prop.get_meta("carry_pose", SHOULDER_CARRY)
	# An in-hand prop has no mount to compute: it is placed by the hand, after
	# the arms are posed, at the end of pose_arms_on_tool. Nothing to do here
	# unless a swing or a bite has taken the prop off the hand's own pose.
	if is_hand_carried(prop) and chop_time < 0.0 and snack_time < 0.0:
		return
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0
	var edge_spin := 0.0
	var handle_slide := 0.0
	var carry_position: Vector3 = carry["mount"]
	var carry_rotation := carry_basis(
		carry, prop.get_meta("head_local", DEFAULT_HEAD_LOCAL))
	var mount_position := carry_position
	var mount_basis := carry_rotation
	var acting := 0.0
	if chop_time >= 0.0:
		var progress := clampf(chop_time / action_duration(), 0.0, 1.0)
		if action_style == 0:
			var impact_compression := chop_impact_compression(progress)
			yaw = chop_tool_yaw(progress)
			pitch = chop_tool_pitch(progress)
			roll = chop_tool_roll(progress)
			edge_spin = chop_edge_spin(progress)
			handle_slide = chop_handle_slide(progress)
			mount_position = chop_mount_position(progress)
			mount_position.y -= 0.05 * impact_compression
		elif action_style == 3:
			var pour := water_pour_blend(progress)
			yaw = 0.0
			roll = 0.0
			pitch = deg_to_rad(-55.0 * pour)
			mount_position = Vector3(0.0, 0.16 + 0.10 * pour, 0.34 + 0.14 * pour)
		else:
			yaw = dig_tool_yaw(progress)
			pitch = dig_tool_pitch(progress)
			roll = dig_tool_roll(progress)
			handle_slide = dig_handle_slide(progress)
			mount_position = dig_mount_position(progress)
		mount_basis = Basis.from_euler(Vector3(pitch, yaw, roll))
		# The carry holds the prop against the flank and the swing starts it out
		# front, so switching between them on the trigger frame teleports the
		# tool across the body. Ease in and out over the ends of the action
		# instead; the keyed middle of the swing is untouched.
		acting = minf(
			smoothstep(0.0, ACTION_BLEND, progress),
			smoothstep(0.0, ACTION_BLEND, 1.0 - progress)
		)
		mount_position = carry_position.lerp(mount_position, acting)
		mount_basis = Basis(
			carry_rotation.get_rotation_quaternion().slerp(
				mount_basis.get_rotation_quaternion(), acting)
		)
		edge_spin *= acting
		handle_slide *= acting
	elif snack_time >= 0.0:
		# The hands rise toward the muzzle and the shaft tips back so the food
		# end lands at the mouth; the handle slides back through the grip so a
		# long stick's tip gets there instead of stopping a fist short. Only
		# the shaft is re-aimed — the prop keeps its own head_local spin, so a
		# marshmallow arrives the same way up it was roasted.
		var lift := snack_lift(clampf(snack_time / SNACK_DURATION, 0.0, 1.0))
		# Solve the pose instead of keying it: the prop's edible point has to
		# land at the mouth, so the shaft is the line from the hand to it and
		# the slide is however much stick is left over. All glb body space.
		var mouth := SNACK_MOUTH * body_mesh.scale + Vector3(0.0, 0.0, SNACK_BITE_OUT)
		var hand := mouth + SNACK_HAND
		var reach := mouth - hand
		var snack: Dictionary = carry.duplicate()
		snack["shaft"] = reach
		var snack_basis := carry_basis(
			snack, prop.get_meta("head_local", DEFAULT_HEAD_LOCAL))
		mount_position = carry_position.lerp(hand / LAB_TO_GLB, lift)
		mount_basis = Basis(carry_rotation.get_rotation_quaternion().slerp(
			snack_basis.get_rotation_quaternion(), lift))
		# The edible point sits this far up the shaft in glb units; the stick
		# slides back through the fist by the difference, which is what lets a
		# prop longer than the peeplet's own arm reach its face at all.
		var edible: float = (prop.get_meta("snack_local", Vector3.ZERO) as Vector3).y \
			* carry_scale_of(prop) / WALKER_SCALE
		handle_slide = (reach.length() - edible) * WALKER_SCALE / carry_scale_of(prop) * lift
	var held_rotation: Vector3 = prop.get_meta("held_rotation_degrees", Vector3.ZERO)
	prop.rotation = Vector3(
		deg_to_rad(held_rotation.x),
		deg_to_rad(held_rotation.y) + edge_spin,
		deg_to_rad(held_rotation.z)
	)
	var carry_scale: float = prop.get_meta("carry_scale", LAB_TO_WORLD)
	prop.position = Vector3(0.0, handle_slide * carry_scale, 0.0)
	# "mount_offset" corrects the action mounts, which are still keyed off the
	# old grip height. The carry mounts place the prop outright, so the offset
	# fades in with the swing rather than landing twice.
	if acting > 0.0:
		mount_position += prop.get_meta("mount_offset", Vector3.ZERO) * acting
	tool_mount.position = mount_position * LAB_TO_GLB
	# Pose the mount in world space from the body's orthonormalized basis so
	# the swing arc keeps its designed angles regardless of the root scale;
	# the tool then carries the world size itself.
	tool_mount.global_basis = body.global_basis.orthonormalized() * mount_basis
	prop.scale = Vector3.ONE * carry_scale
	apply_grab_blend(prop)

## The grab blend, last word on a held prop's pose. A prop just taken is still
## sitting in the hand exactly the way the fingers closed on it; a prop being
## put down has to arrive at a resting place on the ground. Either way the
## canonical carry is one end of a blend and the world pose is the other, so
## the frame the prop changes parent moves it by nothing at all — which is the
## entire difference between picking something up and having it appear in a
## fist. Applies to both carry paths, mounted and in-hand.
func apply_grab_blend(prop: Node3D) -> void:
	if grab_blend <= 0.0 or grab_prop != prop:
		return
	var anchored := grab_rest if grab_placing \
		else body.global_transform * grab_hold_local
	prop.global_transform = anchored.interpolate_with(
		prop.global_transform, 1.0 - grab_blend)

## Does this prop ride the fist rather than a mount? See HAND_CARRY.
static func is_hand_carried(prop: Node3D) -> bool:
	var carry: Dictionary = prop.get_meta("carry_pose", SHOULDER_CARRY)
	return bool(carry.get("in_hand", false))

## The world size a carried prop was fitted to (see measure_carry).
static func carry_scale_of(prop: Node3D) -> float:
	return float(prop.get_meta("carry_scale", LAB_TO_WORLD))


## The mount basis a carry pose asks for: prop-local +Y down "shaft", and the
## prop's working end — the axis "head_local" names, in the prop's own space —
## turned as close to "head" as staying square to the shaft allows.
##
## Squaring on the shaft alone leaves one degree of freedom, the spin about the
## handle, and pinning the wrong axis there is what used to swing every blade
## inboard across the peeplet's face.
static func carry_basis(carry: Dictionary, head_local: Vector3) -> Basis:
	var shaft: Vector3 = (carry["shaft"] as Vector3).normalized()
	var head: Vector3 = carry["head"]
	var aim := (head - shaft * head.dot(shaft))
	if aim.is_zero_approx():
		# "head" parallel to the shaft leaves no square answer; any aim does.
		aim = shaft.cross(Vector3.UP)
		if aim.is_zero_approx():
			aim = Vector3.RIGHT
	aim = aim.normalized()
	# Square up with the head on prop +Z, then spin about the handle so the
	# prop's own head axis lands on the aim instead. The shaft owns +Y, so
	# every head_local lies in the prop's XZ plane and the correction is a
	# plain rotation about it.
	var square := Basis(shaft.cross(aim), shaft, aim)
	return square * Basis(Vector3.UP, -atan2(head_local.x, head_local.z))

# World-space grip point on the held tool's handle. At rest the single carrying
# arm reaches for the carry pose's own grip; mid-action both arms fall back to
# the two-handed pair the swing was keyed against.
func tool_grip_position(index: int) -> Vector3:
	var prop := carried_prop()
	if tool_mount == null or prop == null:
		return Vector3.ZERO
	var local_grip := (
		Vector3(-0.065, -0.10, 0.16)
		if index == 0
		else Vector3(0.065, -0.13, 0.02)
	)
	if prop.has_meta("grip_local"):
		local_grip = prop.get_meta("grip_local")
	elif chop_time < 0.0:
		var carry: Dictionary = prop.get_meta("carry_pose", SHOULDER_CARRY)
		local_grip = carry["grip_local"]
	return prop.global_transform * local_grip

# Aim and stretch each arm at its grip in world space. The arms extend
# sideways out of the flank (their rest axis is +-X), so the aim maps that
# axis onto the grip direction and the stretch rides X.
#
# A swing needs both hands, but a resting carry only needs the one that pins
# the shaft: the far arm would have to cross the torso to reach, and a stubby
# nub stretched through the blob reads as a glitch. Off-duty arms fall back to
# the idle droop and swing.
func pose_arms_on_tool(delta: float) -> void:
	# battle_arms ALWAYS wins, held prop or not. The arms are nubs riding an
	# internal ball joint — rotation-only, capped swing, and a body that turns
	# when the swing can't reach. The grip stretch below breaks all of that
	# (it rips the arm toward wherever the mount is), so an explicit pose must
	# never fight it. pose_idle_arm applies the override and resets the
	# stretch scale; the prop keeps riding its body-space mount.
	if battle_arms.size() == 2:
		for index in arms.size():
			pose_idle_arm(index)
		return
	var prop := carried_prop()
	var carry: Dictionary = prop.get_meta("carry_pose", SHOULDER_CARRY)
	# In-hand props invert the whole pipeline: the arm swings its ordinary idle
	# swing and the prop rides the fist, rather than the arm being aimed at a
	# prop parked on a mount. So the arms are posed first and the prop goes
	# where the hand ended up — which is the only way the hand is actually on
	# it, and it costs the arm no stretch at all.
	if is_hand_carried(prop) and chop_time < 0.0 and snack_time < 0.0:
		for index in arms.size():
			pose_idle_arm(index)
		pin_prop_to_hand(prop, int(carry["carry_arm"]))
		apply_grab_blend(prop)
		return
	var carry_arm: int = -1 if chop_time >= 0.0 else int(carry["carry_arm"])
	for index in arms.size():
		if carry_arm >= 0 and index != carry_arm:
			pose_idle_arm(index)
			continue
		aim_arm_at(index, tool_grip_position(index), delta)

## Rotate one arm onto a world point and stretch it the rest of the way. The
## arms extend sideways out of the flank (rest axis +-X), so the aim maps that
## axis onto the direction of the point and the stretch rides X.
##
## This is the ONLY way an arm is ever pointed at anything — a rotation about
## the shoulder plus a length, never a translation — which is what keeps the
## nub in its socket. A grab uses it on a prop still lying in the world; a
## carry uses it on a prop already in the hand. Same solver, same contract.
func aim_arm_at(index: int, point: Vector3, delta: float) -> void:
	var arm := arms[index]
	var rest_axis := Vector3(-1.0 if index == 0 else 1.0, 0.0, 0.0)
	var offset := point - arm.global_position
	if offset.is_zero_approx():
		return
	var target := Quaternion(rest_axis, offset.normalized())
	var blended := arm.global_basis.get_rotation_quaternion().slerp(
		target,
		clampf(delta * 20.0, 0.0, 1.0)
	)
	# Against the arm's REAL length, so the stretch puts the shell's own tip on
	# the grip. Dividing by ARM_GRIP_REST_WORLD instead understates the stretch
	# by 69% and leaves the hand short of everything it is supposedly holding.
	var stretch := clampf(offset.length() / hand_reach_world(), ARM_MIN_STRETCH, ARM_MAX_STRETCH)
	# Writing global_basis directly would drop the root's world scale, so
	# fold the parent's scale back in alongside the stretch.
	var parent_scale: Vector3 = (arm.get_parent() as Node3D).global_basis.get_scale()
	arm.global_basis = Basis(blended) * Basis.from_scale(Vector3(stretch, 1.0, 1.0) * parent_scale)

## The grab reach: the arm swings off its idle hang onto `point`, and at
## amount 1 it is EXACTLY on it.
##
## Deliberately not the damped chase aim_arm_at uses for a carry. A carry can
## converge over a few frames because nothing depends on which frame it gets
## there; a reach cannot, because the frame the hand is supposed to be on the
## object is the frame the object changes hands, and "nearly there" at that
## instant is a centimetre of daylight between a fist and a rock. Driving the
## whole swing off the beat's own curve makes the contact frame exact by
## construction rather than by luck.
func reach_arm_at(index: int, point: Vector3, amount: float) -> void:
	pose_idle_arm(index)
	if amount <= 0.0:
		return
	var arm := arms[index]
	var rest_axis := Vector3(-1.0 if index == 0 else 1.0, 0.0, 0.0)
	var offset := point - arm.global_position
	if offset.is_zero_approx():
		return
	var idle := arm.global_basis.get_rotation_quaternion()
	var reached := Quaternion(rest_axis, offset.normalized())
	var stretch := lerpf(1.0,
		clampf(offset.length() / hand_reach_world(), ARM_MIN_STRETCH, ARM_MAX_STRETCH),
		amount)
	var parent_scale: Vector3 = (arm.get_parent() as Node3D).global_basis.get_scale()
	arm.global_basis = Basis(idle.slerp(reached, amount)) \
		* Basis.from_scale(Vector3(stretch, 1.0, 1.0) * parent_scale)
