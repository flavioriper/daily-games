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
const SKY_TOP     := Color("f9f2e7")
const SKY_HORIZON := Color("f3d9c4")
const AMBIENT     := Color("f3e4d4")

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
