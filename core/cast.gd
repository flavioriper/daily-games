class_name Cast
extends RefCounted

## The day's pair of Peeplets (docs/superpowers/specs/2026-10-27-peeplet-brand-design.md):
## the two the night paints into the day's vistas, so every seat on a screen
## reads one helper. The seed strings and the eligibility rule are a
## contract with server/functions/src/cast.ts; the phone derives the same
## two when the night's document has not arrived.

const PeepletPersonas = preload("res://peeplet/peeplet_personas.gd")

## The hats a painter can say in a few words, "" for none.
const PLAIN_HATS := ["", "bandana", "beanie", "bow", "cap", "chefHat", "earmuffs", "sunhat", "topHat",
		"partyHat", "mushroomCap", "flowerCrown"]
## The flat coats, PeepletPalette.BODY 0..7.
const FLAT_COATS := 8

## The published pair when the day's vistas carry one (they are today's, so
## only for today), else the seeded pair.
static func pair(day: int = Daily.date_key()) -> Array[int]:
	var n := PeepletPersonas.count()
	if day == Daily.date_key() and n > 0:
		var c := ThemedVistas.cast()
		if c.size() == 2:
			return [clampi(int(c[0]), 0, n - 1), clampi(int(c[1]), 0, n - 1)]
	return seeded(day)

## Persona indices (into PeepletPersonas.ALL) with a flat coat and a plain hat.
static func eligible() -> Array[int]:
	var out: Array[int] = []
	for i in PeepletPersonas.count():
		var p: Dictionary = PeepletPersonas.get_persona(i)
		if int(p["coat"]) >= 0 and int(p["coat"]) < FLAT_COATS and String(p["hat"]) in PLAIN_HATS:
			out.append(i)
	return out

## The day's two from the day number alone. With fewer than two eligible the
## pair is [0, 1], as the server's is.
static func seeded(day: int) -> Array[int]:
	var list := eligible()
	var n := list.size()
	if n < 2:
		return [0, 1]
	var a := Daily.fnv1a("cast-a-" + str(day)) % n
	var b := Daily.fnv1a("cast-b-" + str(day)) % n
	if b == a:
		b = (a + 1) % n
	return [list[a], list[b]]

static func persona(which: int, day: int = Daily.date_key()) -> Dictionary:
	return PeepletPersonas.get_persona(pair(day)[clampi(which, 0, 1)])

## Dresses a PeepletView in the day's persona `which` (0 or 1). Each setter
## rebuilds the walker: call this once, before the view enters the tree.
## Returns the persona index the view now wears.
static func dress(view, which: int, day: int = Daily.date_key()) -> int:
	var idx := pair(day)[clampi(which, 0, 1)]
	var p := PeepletPersonas.get_persona(idx)
	view.color_index = int(p["coat"])
	view.headgear = String(p["hat"])
	view.eyewear = String(p["eyes"])
	return idx

## For a seat built earlier that `dress` left wearing persona `held`: dresses
## the view again only when seat `which` is now someone else (the day let go,
## or the night's cast arrived behind the built screen). Returns the persona
## now worn. Cheap when nothing changed: no setter runs, nothing rebuilds.
static func redress(view, which: int, held: int) -> int:
	if not is_instance_valid(view) or pair()[clampi(which, 0, 1)] == held:
		return held
	return dress(view, which)
