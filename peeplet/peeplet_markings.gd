class_name PeepletMarkings
extends RefCounted

## The collection's markings trait: painted coat patterns on the peeplet's left
## flank, ported from the rpg-adventure-2 lab's BODY_MARK_TRAITS table. Three
## patterns plus bare skin, drawn by body_mark() in peeplet_fur.gdshader and
## peeplet_fur_shell.gdshader — the shapes live in the shader, so this table is
## only the trait name -> shader mode mapping plus the rarity tier.
##
## Canon values come from web/src/lib/traitArt.ts, where the empty state of the
## markings trait is "plain"; the lab and the adventure UI both spell the same
## state "none". Both resolve to mode 0, so a wallet writing either gets a bare
## coat rather than a fallback pattern.
##
## Only the body coat carries marks. The limb chains are built from the same
## shader but stay at mode 0: PeepletWalker splits arms and the tail onto their
## own pivots, so their vertex space is shifted out of the space the marks are
## authored in and a mark would land somewhere arbitrary on them.

const DEFAULT_TRAIT := "none"
## The web canon spelling of the same bare-coat state.
const CANON_EMPTY := "plain"

const MARKINGS := {
	"none": {"mode": 0},
	"stripes": {"mode": 1},
	"spots": {"mode": 2},
	"starmark": {"mode": 3, "premium": true},
}


static func names() -> Array:
	return MARKINGS.keys()


## Case-insensitive; "plain", "" and anything unknown come back as "none", the
## way an unknown headgear comes back bare-headed.
static func resolve(trait_name: String) -> String:
	if MARKINGS.has(trait_name):
		return trait_name
	var wanted := trait_name.to_lower()
	if wanted == CANON_EMPTY:
		return DEFAULT_TRAIT
	for canon in MARKINGS:
		if String(canon).to_lower() == wanted:
			return canon
	return DEFAULT_TRAIT


## The body_mark_mode enum value the fur shaders switch on.
static func mode(trait_name: String) -> int:
	return int(MARKINGS[resolve(trait_name)]["mode"])


static func is_premium(trait_name: String) -> bool:
	return MARKINGS[resolve(trait_name)].has("premium")
