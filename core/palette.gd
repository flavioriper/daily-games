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
const WATER_HI    := Color("5fb0e8")   # water's shallow-depth band and splash ring
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

# Code Break's screen (docs/art/concept-codebreak-screen.png): the plank dock
# the board is laid on, the turf bank under it, the boulders beside it, and
# the wood the title signs and the day card are cut from.
const DECK        := Color("b5825a")   # deck planks
const BANK        := Color("8cb050")   # the turf bank and the far bank
const BOULDER     := Color("9ba5ad")   # a rock beside the deck, cool against the turf
const PLAQUE      := Color("9c6b45")   # the title sign's and day card's wood
const PLAQUE_DEEP := Color("6e4a2f")   # its bottom edge

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

# Shikaku (the design agreed 2026-09-15): a field of plot floors divided by
# dry-stone walls. A claimed plot's floor is tilled earth, a bare cell is the
# island's own stone, and every wall and corner post is rock.
const PLOT_BARE  := STONE        # a cell no rectangle has claimed yet
const PLOT_SOIL  := Color("d3b98d")   # a claimed plot's tilled floor
const PLOT_LOCK  := Color("c0a475")   # a plot a hint fixed, so it reads as given
## Deeper than ROCK on purpose: a wall has to read as raised stone against
## the tilled earth beside it, and at b9ab92 the two sat at the same lightness
## so a plot looked bounded by pale tape rather than by a wall.
const WALL_STONE := Color("8f8471")   # the dry-stone walls and their corner posts

# Tents (the design agreed 2026-09-15): a meadow of turf cells with a conifer
# standing on some of them, a canvas tent pitched beside each, and a pebble
# cairn marking the ground the player has ruled out. The row and column counts
# are Shikaku's own marker stones, laid on the stone margin around the field.
const TURF        := Color("93b85c")   # a field cell
const TURF_TREE   := Color("7fa550")   # the cell a tree stands on, so it reads as fixed
const CANVAS      := Color("f2e4c9")   # tent canvas
const CANVAS_LOCK := Color("d9c8a6")   # a tent a hint pitched, so it reads as given
const TENT_DOOR   := Color("6b5a44")   # the shaded doorway
const PEBBLE      := Color("a89a84")   # the cairn that rules a cell out
const BARK        := Color("8a6a4a")
const LEAF        := Color("6ba845")

# Light Up (the design agreed 2026-09-15): a walled court of flagstones with
# rough blocks of stone standing in it, and a lantern on every cell the player
# lights. A stone in the dark is a cold grey; lamplight warms it, which is the
# whole rule made visible. The lit globe is the island's own SUN, and a
# lantern a hint lit wears SUN_DEEP, the language every board uses for a given.
## Cold and warm are far apart on purpose. The first pass had the unlit stone
## at b4ab97, one and a half stops off the lamplight, and the toon ramp ate the
## whole difference under the island sun -- lit and unlit cells came out the
## same cream on the stage. These sit nearly three stops apart, which survives
## the ramp, and the blocks went down to match so a wall still reads as
## something other than an unlit floor. The unlit stone is also the one cool
## colour on the island: against the warm lamplight the difference is a change
## of temperature as well as of value, which is how light has always been
## painted, and it keeps a dark court from reading as mud under the stage's
## warm ambient.
const FLAGSTONE   := Color("8a9199")   # a court stone no lamp reaches
const LAMPLIGHT   := Color("f8e3ad")   # the pool of light a lantern casts
const BLOCK_STONE := Color("4a4740")   # the blocks that stop the light
const BLOCK_NUM   := STONE             # the numeral carved into a block's crown
const LANTERN     := Color("5a5248")   # the lantern's iron foot and cap
## The chip that rules a cell out: cool slate, so it is never read as a small
## block of the court's own warm stone.
const CHIP        := SLATE

# Nonogram (the design agreed 2026-09-15): a mosaic floor being laid. A cell
# is an empty socket of pale stone; a filled one carries a slate tile, and the
# finished grid is the picture in relief. A cell the player has ruled out goes
# a shade darker and takes a pebble mark, so the ruling-out reads twice.
const SOCKET      := STONE        # an empty cell
## A shade the eye can actually catch against SOCKET, which STONE_GIVEN was
## not, and still nowhere near the slate of a laid tile -- a ruled-out cell
## must never be mistaken for a filled one.
const SOCKET_OUT  := Color("c9b998")  # a cell the player has ruled out
const MOSAIC      := SLATE        # a laid tile: the picture
## A tile a hint laid. Teal rather than a darker slate, for the reason Light
## Up's lantern collar is pale stone: two neighbouring darks are the one thing
## the toon ramp will not keep, and a given has to be visible or the player
## cannot tell why the cell refuses to budge.
const MOSAIC_LOCK := ACCENT

# One Line (the design agreed 2026-09-15): a jetty of mooring posts with a
# plank between each pair. A line not yet walked is a dark stone ford; walking
# it lays a warm plank over it. Dark to light, the same language Light Up's
# floor speaks, and for the same measured reason -- a pale-on-pale difference
# does not survive the ramp under the island sun.
const PLANK_BARE := SLATE
const PLANK_LAID := WOOD
const POST_SPENT := STONE_GIVEN   # a post with no line left to walk

# Horse Pen (the design agreed 2026-09-15, polished 2026-09-15 against
# enclose.horse -- docs/brainstorm/concepts.html, the Horse Pen tab): a meadow
# that runs off every edge of the screen, cut by water channels with earth
# banks, with boulders and apples lying on it, a cream horse standing on it
# and the hay bales the player drops. A bale a hint dropped is older, darker
# straw, the language every board uses for a given. The meadow the horse can
# reach is shown as trampled wheat: paler and yellower than the turf, far
# enough off it to survive the toon ramp.
## A chestnut coat with a flaxen mane and tail. Cream was the proposal and it
## lost on the stage: the horse always stands on ground it can reach, which is
## always the pale wheat, and cream against TURF_REACH measures a contrast of
## 1.10 -- the toon ramp then paints the two the same and the horse reads as a
## pale lump. Chestnut measures 4.67 against the wheat and 2.86 against the
## green, so it reads wherever it stands, and the pale mane and tail put the
## cream back where it has the coat behind it to show against.
const HIDE        := Color("8a4f2a")   # the horse's chestnut coat
const MANE        := Color("f4ead3")   # its flaxen mane and tail
const HORSE_EYE   := Color("2a2622")
const TIMBER      := Color("c49a63")   # timber, kept for the fence model
const TIMBER_LOCK := Color("a1825a")
const FRUIT       := Color("e04a3f")
const STEM        := Color("6b4a2e")
const APPLE_LEAF  := Color("5fa04a")
const TURF_REACH  := Color("dde08a")   # meadow the horse can still reach
## The bale that closes a gap. Gold on green grass, and with its two dark
## straps and its outline it still reads on the pale wheat -- which the timber
## fence it replaces never did, being two rails and two posts of mostly air.
const STRAW       := Color("e8bc5a")
const STRAW_LOCK  := Color("bd9440")   # a bale a hint dropped: older straw
const STRAP       := Color("53412d")   # the two straps round a bale
## The ring of meadow beyond the field: darker, so the lighter field and its
## faint plot lines are the whole boundary -- no wall, no lip, because an edge
## cell is open and open is the point of the game.
const TURF_RING   := Color("6f9243")
const TURF_LINE   := Color("a7c96f")   # the faint lines on the field
const WHEAT       := Color("cfc267")   # the standing wheat on a cell the horse can reach
const CUT_EARTH   := Color("9c7850")   # the banks of a water channel
const BLOOM       := Color("ee7fa7")   # the flowers that open over a closed pen

# Snake Apple (the design agreed 2026-09-15): the same meadow, boulders and
# apples as Horse Pen, with a green snake on it and an earth burrow that goes
# mossy once it is open.
const SCALE       := Color("5cb85c")   # the snake's skin, head and body alike
const SCALE_BELLY := Color("d9e8a8")
const TONGUE      := Color("e0607a")
const EARTH       := Color("8a6a4a")   # the burrow's rim while apples remain
const HOLE        := Color("2a231e")   # the dark of the burrow

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
