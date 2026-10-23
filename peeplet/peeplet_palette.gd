class_name PeepletPalette
extends RefCounted

## The collection's twelve bodyColor traits, in one place: adventure.gd, the
## wallet picker and the lab all read this table so a color can never mean two
## different things in two scenes.
##
## Saved rosters store a color_index into BODY, so order is append-only —
## a new color goes on the end, never in the middle.
##
## `premium` selects the patterned coats in peeplet_fur.gdshader's premium_mode
## enum (0 solid, 1 candy, 2 midnight, 3 ocean, 4 cloud). Four of the traits are
## rare and painted, not flat: candy's pearl dots, midnight's starfield, ocean's
## foam-capped water, cloud's puffs. Their `color` is the trait's flat swatch and
## the shader mostly overrides it — it still feeds the UI chips and any surface
## that draws the peeplet without the fur chain.
const BODY := [
	{"name": "coral", "color": Color(1.0, 0.323, 0.258), "premium": 0},
	{"name": "mint", "color": Color("#a8e6cf"), "premium": 0},
	{"name": "sky", "color": Color("#a0d8ef"), "premium": 0},
	{"name": "butter", "color": Color("#ffe9a8"), "premium": 0},
	{"name": "lavender", "color": Color("#c9b6f0"), "premium": 0},
	{"name": "peach", "color": Color("#ffd3b6"), "premium": 0},
	{"name": "sage", "color": Color("#aecca0"), "premium": 0},
	{"name": "coal", "color": Color("#6f6f88"), "premium": 0},
	{"name": "candy", "color": Color("#ff9ff3"), "premium": 1},
	{"name": "midnight", "color": Color("#3a3a5c"), "premium": 2},
	{"name": "ocean", "color": Color("#2ab7e6"), "premium": 3},
	{"name": "cloud", "color": Color("#e9f0fb"), "premium": 4},
]


static func count() -> int:
	return BODY.size()


## Out-of-range indices wrap rather than crash: a save written by a later build
## with more colors still opens.
static func entry(index: int) -> Dictionary:
	return BODY[wrapi(index, 0, BODY.size())]


static func color(index: int) -> Color:
	return entry(index)["color"]


static func premium_mode(index: int) -> int:
	return int(entry(index)["premium"])


static func names() -> Array:
	var labels := []
	for item in BODY:
		labels.append(item["name"])
	return labels


## Trait name -> index. An unknown name falls back to coral.
static func index_of(body_color: String) -> int:
	for index in BODY.size():
		if BODY[index]["name"] == body_color:
			return index
	return 0
