extends RefCounted

## The Grove's beaver (valley/grove_life.gd; the user, 2026-10-06: "for each
## chop show a beaver that bite the tree"): seen from the side, sitting up on
## its own (0, 0) and looking right, in land units; a holder flips it to look
## left. Three meshes, built once and kept, so a beaver is three draws and
## nothing is rebuilt while it moves:
##
## - `tail()` about its joint, a flat paddle lying behind: the holder turns it
##   to slap.
## - `body()`: the shade under it, the feet, the pear of the body, the belly
##   and the paw it holds the trunk with.
## - `head(biting)` about its neck: ear, muzzle, nose, cheek and the two
##   teeth; open-mouthed and bright-eyed, or (`biting`) shut on the wood with
##   its eye squeezed. The holder nods and lunges it.
##
## It has no outline, like the trees it stands by, and its tones are a
## chestnut warmer than any trunk so it reads against one. Nothing here is
## lit from a side: a beaver is mirrored to face its tree.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

const FUR := Color("b9743e")
const FUR_DEEP := Color("96592c")
const BELLY := Color("f0cf9f")
const TAIL := Color("6b4a3a")
const TAIL_LINE := Color("86604c")
const NOSE := Color("3b2f28")
const TOOTH := Color("fffaf0")
const TOOTH_LINE := Color("d9c9ad")
const MOUTH := Color("8c3f3a")
const EAR_IN := Color("f0a79b")
const SHADE := Color(0.09, 0.27, 0.34, 0.2)

## Where the tail joins the body and the head sits on it, and where the
## teeth meet the wood (from the neck, the head at rest).
const TAIL_AT := Vector2(-17.0, -6.0)
const NECK := Vector2(5.0, -30.0)
const TEETH := Vector2(23.0, 4.0)
## How tall it sits, ear and all.
const TALL := 60.0

static var _tail: ArrayMesh
static var _body: ArrayMesh
static var _heads := {}

static func tail() -> ArrayMesh:
	if _tail == null:
		var b := Face.Builder.new()
		b.ellipse(Vector2(-17.0, 0.0), 19.0, 8.5, TAIL)
		for i in 4:
			var x := -8.0 - i * 6.5
			b.stroke(PackedVector2Array([Vector2(x + 3.0, -5.0), Vector2(x - 3.0, 5.0)]), 1.6, TAIL_LINE)
			b.stroke(PackedVector2Array([Vector2(x - 3.0, -5.0), Vector2(x + 3.0, 5.0)]), 1.6, TAIL_LINE)
		_tail = b.mesh()
	return _tail

static func body() -> ArrayMesh:
	if _body == null:
		var b := Face.Builder.new()
		b.ellipse(Vector2(-2.0, 1.0), 26.0, 6.0, SHADE)
		for x: float in [-10.0, 7.0]:
			b.ellipse(Vector2(x + 3.0, -2.5), 8.0, 4.2, FUR_DEEP)
		b.ellipse(Vector2(-3.0, -16.0), 19.0, 15.5, FUR)
		b.ellipse(Vector2(2.0, -27.0), 13.5, 12.0, FUR)
		b.ellipse(Vector2(6.0, -16.0), 10.0, 11.5, BELLY)
		# the paw on the trunk
		b.stroke(PackedVector2Array([Vector2(8.0, -24.0), Vector2(17.0, -21.0)]), 7.0, FUR_DEEP)
		b.disc(Vector2(18.5, -20.5), 3.4, FUR)
		_body = b.mesh()
	return _body

static func head(biting: bool) -> ArrayMesh:
	if not _heads.has(biting):
		var b := Face.Builder.new()
		# the ear behind the skull
		b.disc(Vector2(-3.0, -21.0), 5.6, FUR_DEEP)
		b.disc(Vector2(-2.6, -20.6), 2.8, EAR_IN)
		if not biting:
			# the open mouth and the jaw under it
			b.ellipse(Vector2(15.0, 4.5), 7.0, 5.5, MOUTH)
			b.ellipse(Vector2(13.0, 8.5), 7.5, 3.4, BELLY)
		b.disc(Vector2(5.0, -9.0), 14.5, FUR)
		b.ellipse(Vector2(15.0, -4.0), 10.0, 7.6, BELLY)
		b.ellipse(Vector2(23.0, -8.5), 3.8, 3.0, NOSE)
		b.disc(Vector2(5.0, -1.5), 3.6, Color(Pal.CHEEK, 0.8))
		# two front teeth, the pair split by a line
		var long := 4.5 if biting else 8.5
		b.polygon(Face.Builder.round_rect(Vector2(16.5, 1.0), Vector2(8.0, long), 2.2), TOOTH)
		b.stroke(PackedVector2Array([Vector2(20.5, 1.6), Vector2(20.5, long)]), 1.0, TOOTH_LINE, false, false)
		if biting:
			# the eye squeezed shut on the effort
			b.stroke(PackedVector2Array([Vector2(5.5, -15.5), Vector2(10.5, -12.5), Vector2(5.5, -10.0)]), 2.2, NOSE)
		else:
			b.disc(Vector2(8.5, -13.0), 3.0, NOSE)
			b.disc(Vector2(7.6, -14.0), 1.0, Color.WHITE)
		_heads[biting] = b.mesh()
	return _heads[biting]
