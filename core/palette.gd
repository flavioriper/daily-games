class_name Palette
extends RefCounted

## Cozy paper-and-wood palette shared by the 3D stage, the toon materials and
## the 2D chrome. Colour never carries meaning alone (see shapes.gd), so these
## only need to be pleasant and readable.

const PAPER       := Color("f6efe3")
const BG          := PAPER
const SURFACE     := Color("fffdf8")
const SURFACE_HI  := Color("f1e6d2")
const LINE        := Color("b8a892")
const TEXT        := Color("3b3028")
const TEXT_DIM    := Color("8a7b6b")
const ACCENT      := Color("4c9a94")
const ACCENT_2    := Color("e2825f")
const GOOD        := Color("7cb06b")
const BAD         := Color("d9605a")
const BAD_TILE    := Color("f2cfc9")
const WOOD        := Color("c8a17a")
const OUTLINE     := Color("3b2f28")
const SHADOW_TINT := Color("b7a6c4")
const SKY_TOP     := Color("bfe3f5")
const SKY_HORIZON := Color("e8f2f7")
const AMBIENT     := Color("f3e4d4")

# Island world (docs/art/concept-binairo-island.png)
const STONE       := Color("ede2cc")
const STONE_GIVEN := Color("dccfb3")
const SLATE       := Color("3f4652")
const SLATE_GIVEN := Color("2f353e")
const SUN         := Color("f5a623")
const MOON        := Color("f6f1e6")
const MARK        := Color("cbbd9f")
const MOSS        := Color("7fa84a")
const ROCK        := Color("b9ab92")
const WATER       := Color("2f8fd6")
const WATER_HI    := Color("5fb0e8")   # water stripes and splash ring
const SUN_DEEP    := Color("d88a12")   # primary button's bottom edge
const PARCHMENT   := Color("f3e9d2")   # rules card

# Code Break pegs (docs/art/concept-codebreak.png): red, yellow, blue, green,
# purple, pink, orange. Index order is the difficulty's palette order; every
# peg also carries a pip mark, so colour never stands alone.
const PEGS := [
	Color("e5484d"), Color("f7c948"), Color("3d8bfd"), Color("3fb950"),
	Color("9b6cf6"), Color("f472b6"), Color("fb8c3c"),
]
const WOOD_DEEP    := Color("9c7350")   # the colour tray's bottom edge

# Pipes (docs/art/concept-pipes.png): chrome when dry, lit blue when fed. The
# water inside the tube is WATER / WATER_HI, already defined above, and its
# bubbles are MOON.
const STEEL       := Color("aebecb")   # dry pipe shell
const STEEL_HI    := Color("cfdce6")   # dry collar, and the valve rings
const PIPE_WET    := Color("4fa8ef")   # fed pipe shell
const PIPE_WET_HI := Color("9ad3ff")   # fed collar
const FLOW_DRY    := Color("3c4550")   # the water tube with nothing in it -- darkened
	# from 6b7a88 (task 4): the old value sat close enough to STEEL/STEEL_HI
	# that a dry sight hole read as a shadow on the chrome rather than as an
	# empty pipe; see the spec's section 4 amendments.

# Categorical ramp, same order as before so boards keep their index meaning:
# teal, terracotta, sage, lavender, rose, sky, mustard, stone.
const CAT := [
	Color("4c9a94"), Color("e2825f"), Color("7cb06b"), Color("9b86c9"),
	Color("d9605a"), Color("6bb1d6"), Color("d3b04a"), Color("9a948c"),
]

## WCAG contrast ratio between two sRGB colours, 1.0 to 21.0.
static func contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

static func _relative_luminance(c: Color) -> float:
	var lin := c.srgb_to_linear()
	return 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b
