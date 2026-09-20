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
## ACCENT's own pair, the two shades every other chip colour already carries.
## Rings is what wanted them: its sixth ring colour is the palette's teal, and
## a ring needs a deeper edge and a pale tile like every other piece here.
const ACCENT_DEEP  := Color("3a7a75")
const ACCENT_TILE  := Color("dfeceb")
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

# The flat Binairo (docs/superpowers/specs/2026-09-18-binairo-flat-design.md,
# section 4): the sun's rays, the two palette-chip fills, the moon's ink and
# its deeper shade, and the faces' cheeks. A free tile is plain SURFACE.
const SUN_RAY     := Color("f9c04a")
const SUN_TILE    := Color("fff1d6")
const MOON_INK    := Color("7d8fd9")
const MOON_DEEP   := Color("6273c0")
const MOON_TILE   := Color("e9ecfa")
const CHEEK       := Color("f4a7a0")

# The flat Code Break's six friends, one shape and one colour each
# (docs/superpowers/specs/2026-09-18-codebreak-flat-design.md, section 3): the
# sun, the moon and the leaf are already above; these are the rest, plus the
# chip fill each sits on. A seventh, the flower, joins on the hard difficulty.
const LEAF_DEEP   := Color("4f8a31")
const LEAF_TILE   := Color("e6f0da")
const BERRY       := Color("e2645c")
const BERRY_DEEP  := Color("bf4a44")
const BERRY_TILE  := Color("fadcd8")
const CLOUD       := Color("a9c2dd")
const CLOUD_DEEP  := Color("8aa6c4")
const CLOUD_TILE  := Color("e7eff7")
const ACORN       := Color("c99a63")
const ACORN_DEEP  := Color("a57a48")
const ACORN_TILE  := Color("f3e4ce")
const FLOWER      := Color("e58fb5")
const FLOWER_DEEP := Color("c26b93")
const FLOWER_TILE := Color("fbe0ec")
const FLOWER_EYE  := Color("fdeef4")   # the flower's pale centre, under its face

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

# The flat Balance's five camp fruit, one silhouette and one colour each
# (docs/superpowers/specs/2026-09-18-balance-flat-design.md, section 3). The
# apple takes BERRY and the acorn ACORN above -- they are the very colours
# Code Break already draws, which is the point of having a cast -- so only
# the pear, the pumpkin and the mushroom are new here, plus the wood the
# scales are cut from. The wood is a shade warmer than the chrome's WOOD:
# these are the mock's own values, and a scale is the only wood on a flat
# screen, so it never stands beside a tray cut from the other one.
const PEAR         := Color("c3cf62")
const PEAR_TILE    := Color("eef2d6")
const PUMPKIN      := Color("ef9038")
const PUMPKIN_DEEP := Color("c86f22")   # the ribs drawn across its belly
const PUMPKIN_TILE := Color("fde6cf")
const PUMPKIN_STEM := Color("7b8f4a")
const MUSHROOM     := Color("b5705f")   # the cap
const MUSHROOM_STEM := Color("f6ecd9")
const MUSHROOM_TILE := Color("f1ded6")
const SCALE_WOOD   := Color("c9a678")   # the beam
const SCALE_DEEP   := Color("a3814f")   # the post, the dish, the beam's shade
const SCALE_DARK   := Color("8d6c41")   # the base, the hub, the cords

# The flat Shikaku's field (docs/superpowers/specs/2026-09-18-shikaku-flat-design.md,
# section 3): garden beds fenced with rails, under signpost markers. The
# island's PLOT_* and WALL_STONE above are stone and sand, because a board
# out on the water is built of what the island is; a bed drawn flat on
# parchment has to read as dug ground instead, so these are the mock's own
# earth. A settled marker's plaque is LEAF over LEAF_DEEP and a wrong one
# BAD -- the greens and the rose the rest of the family already wears.
const BED_GROUND  := Color("e6d8b8")   # a cell no plot has claimed
const BED_LINE    := Color("d3c19c")   # the faint grid drawn over it
const BED_SOIL    := Color("9e7048")   # a claimed plot's tilled earth
const BED_FURROW  := Color("7d5836")   # the dashed grain along its rows
const BED_BLUSH   := Color("e8b6ad")   # a bed holding two numbers or none
const FENCE_RAIL  := Color("dcbb8c")   # the fence's lit top rail
const FENCE_DARK  := Color("8d6c41")   # its shade, and a marker's stake
const FENCE_POST  := Color("a3814f")   # the posts where fence runs meet
const MARKER_DEEP := Color("b4533f")   # a wrong marker's bottom edge

# The flat Untangle (docs/superpowers/specs/2026-09-18-untangle-flat-design.md,
# section 3): paper lanterns hung on cords over the parchment card, and a knot
# drawn wherever two cords cross. The camp already stands a lantern on its
# path, so the cast is borrowed from the world rather than invented -- these
# are the mock's own papers, five of them, taken by index so a board of
# fourteen repeats a colour rather than inventing a sixth. The cord is hemp a
# shade cooler than ROPE_HEMP: it is drawn hairline-thin against parchment,
# where the island's rope is a solid in sunlight.
const LANTERN_PAPER := [
	[Color("f0a04b"), Color("cf7f2e")],   # amber
	[Color("e2726e"), Color("bd5350")],   # rose
	[Color("7fb37a"), Color("5d8f58")],   # moss
	[Color("6fa8c8"), Color("4d84a3")],   # river
	[Color("b489c4"), Color("8f66a0")],   # plum
]
## What a paper warms toward when its lantern is lit on the win; the deep
## edge goes to SUN over the same run.
const LANTERN_LIT := Color("ffe2a8")
const CORD        := Color("9a7f60")   # a cord at rest
const CORD_DEEP   := Color("7a6248")   # its shade, the ring and the arm
## The knot, and the colour a cord caught in one turns. The family's rose and
## its deep edge -- the same pair Shikaku's wrong marker wears.
const KNOT        := Color("d9705e")
const KNOT_DEEP   := Color("b4533f")

# The flat Tents (docs/superpowers/specs/2026-09-18-tents-flat-design.md,
# section 3): a meadow of pale turf on the parchment card, conifers standing
# on it, canvas tents pitched beside them and a cairn of pebbles on every
# square the player has ruled out. The island's TURF, CANVAS and PEBBLE above
# are the colours of a meadow in sunlight on a stage; drawn flat on parchment
# the same greens go muddy, so these are the mock's own -- paler turf, warmer
# canvas. A count chip that holds exactly its number wears LEAF over
# LEAF_DEEP and one holding too many BAD over MARKER_DEEP, the family's
# green and rose that Shikaku's markers already wear.
const MEADOW      := Color("cfdda6")   # a cell nothing stands on
const MEADOW_LINE := Color("bccf90")   # the faint grid over it
const TENT_CANVAS := Color("e9c48a")   # the lit side of the fabric
const TENT_DEEP   := Color("c69a5c")   # its shaded side
const TENT_DARK   := Color("8d6c41")   # the doorway, the guy lines
const CAIRN_STONE := Color("c3b7a4")   # the pebbles that rule a square out
const CAIRN_DEEP  := Color("9c9083")   # the ones under them

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
const LEAF_LIGHT  := Color("9dc063")   # the sunlit patches on the round tree's crown

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
## The bottom edge under each of those, which the flat board needs and the
## island does not: every card, tile and piece on a flat screen is a fill over
## a slightly deeper shape, and that lip is what keeps a tinted floor from
## reading as flat paint
## (docs/superpowers/specs/2026-09-18-lightup-flat-design.md, section 3).
const FLAGSTONE_DEEP := Color("6f7780")
const BLOCK_DEEP     := Color("332f2a")
const CHIP_DEEP      := SLATE_GIVEN
## And the one colour the flat court does not take from the island: a lit
## stone. LAMPLIGHT above is a pool of light *on* a stone lit from above,
## and it is all but the lantern's own LANTERN_LIT -- so a flat board, which
## draws the shaft of light over the stone in that glass, would swallow the
## beam in the floor. This is a shade more saturated, which is what lets the
## brighter band read over it; measured against the beam, not guessed.
const LAMPLIT_FLOOR := Color("f6d488")
const LAMPLIT_DEEP  := Color("e0b769")

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

## The flat board's own shades (the mock's, ported number for number:
## docs/brainstorm/concepts.html#nonogram). A tile is a real object with a
## bottom edge and a highlight on it, because the picture is something the
## player has built; the highlight leaves with the grout on the win, since
## eighty of them on a finished picture read as noise across it rather than
## as relief. The pebble on a ruled-out socket is drawn against SOCKET_OUT
## and not against parchment, so it is its own deeper shade of the same sand.
const MOSAIC_DEEP := SLATE_GIVEN       # a laid tile's bottom edge
const MOSAIC_HI   := Color("596273")   # the sliver of light on its crown
const MOSAIC_LOCK_DEEP := Color("3a7772")
const SOCKET_PEBBLE := Color("b5a482") # the pebble that rules a cell out
## The clue numbers' ink. Idle they are TEXT; a line that reads exactly as it
## should goes green and one holding too many goes rose, which is the whole
## of this board's feedback.
const CLUE_OK     := Color("4f8532")
const CLUE_OVER   := MARKER_DEEP

# One Line (the design agreed 2026-09-15): a jetty of mooring posts with a
# plank between each pair. A line not yet walked is a dark stone ford; walking
# it lays a warm plank over it. Dark to light, the same language Light Up's
# floor speaks, and for the same measured reason -- a pale-on-pale difference
# does not survive the ramp under the island sun.
const PLANK_BARE := SLATE
const PLANK_LAID := WOOD
const POST_SPENT := STONE_GIVEN   # a post with no line left to walk

## The flat One Line's own shades
## (docs/superpowers/specs/2026-09-18-oneline-flat-design.md, section 3). The
## four post caps, the two plank colours and the spent cap are the island's,
## above; what a flat board adds is a bottom edge under every drum and plank,
## a brighter plank for the finished trail, one colour for a line nothing can
## reach any more -- which the island draws as a rose flash and nothing else,
## because a stage has no room for a fifth state -- and the snail.
const PLANK_HI    := Color("e3c39b")   # a plank on the finished trail
const PLANK_LOST  := Color("8d94a3")   # a line the stroke can no longer reach
const POST_STONE  := Color("c3b7a4")   # the drum a cap sits on
const POST_DEEP   := Color("9c9083")
const SHELL       := Color("e0a257")   # the walker's shell, and its spiral
const SHELL_DEEP  := Color("b87d3a")
const SNAIL_FOOT  := Color("f3e1c4")
const SNAIL_DEEP  := Color("d9c29c")

# Queens (docs/superpowers/specs/2026-09-19-queens-flat-design.md, section
# 5): a court cut into as many coloured regions as it has rows, under an ink
# frame and ink seams, on the parchment card. Nine pastels taken by region
# index and spread round the wheel so no two neighbours share a family: the
# seam does the separating and the colour is the region's name. The ten
# *_TILE chip tints above are too pale to hold nine regions apart on
# parchment, which is why these are their own block. The mock's own values
# (docs/art/concept-queens.png, docs/brainstorm/concepts.html#queens).
const REGION := [
	Color("cfc3ac"),   # tan
	Color("c4a9dc"),   # lavender
	Color("a3c4ec"),   # sky
	Color("b6d9a8"),   # mint
	Color("f0c384"),   # apricot
	Color("dcdcdf"),   # silver
	Color("e3e27c"),   # lemon
	Color("f79a80"),   # coral
	Color("eaa0b8"),   # rose
]
## The gold the wave leaves on a cell for a moment as a queen's reach arrives:
## a paler gold than SUN, so the wash still reads over the apricot and lemon
## regions, where SUN itself sits too close to their own colour to show.
const QUEEN_WASH := Color("f7c25a")

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

# The Rope (the design agreed 2026-09-17): a carved plank ruled into squares
# with numbered pegs turned out of the same timber, and a hemp rope laid over
# the lot. The board is the palest wood there is so the rope has something to
# read against; the pegs take TIMBER, which is on Toon's wood list and so
# comes out turned and grained rather than flat.
const ROPE_FACE  := Color("e7d9bd")   # a square the rope has not reached
const ROPE_UNDER := Color("d2bd95")   # a square it lies on, shaded under it
const ROPE_HEMP  := Color("b98a4e")   # the rope
const ROPE_BAD   := Color("f0cfc6")   # a square the check says to take back

## Hidden Word's three marks. GOOD is the green; the amber is its own rather
## than SUN_RAY, which is a brighter lemon and reads as the sun; the grey is
## warm, because a cool grey goes muddy on cream. KEY_FACE is a shade above
## SURFACE so the keyboard reads as a slab and not as six more cards.
const WORD_NEAR   := Color("e9ba55")
const WORD_MISS   := Color("8a8078")
const KEY_FACE    := Color("fffaf0")

# --- Sudoku (spec 2026-09-20-sudoku-flat-design.md, section 5) ---
## A cell in a shaded region: SURFACE 55% of the way to PARCHMENT. The mock's
## own chequer, and what makes nine columns read as three.
const GRID_TINT   := Color("f9f3e7")
## The heavy rule between regions and round the grid, 6 wide. BARK is too
## dark on cream at that width and LINE too faint to read as a region edge,
## so this is BARK 38% of the way to PARCHMENT.
const GRID_RULE   := Color("a3855f")

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

# The first screen's campsite, lit and coloured to the painted frame
# (docs/art/concept-menu-painted.png) rather than the toy-render banner. Its
# greens are deeper and cooler than the boards' TURF and LEAF, its path a
# real earth brown rather than PLOT_SOIL's sand, so under the camp's low sun
# (Stage.grade_camp) the lit patches glow and the shade goes dark. Only
# world/camp.gd reads these; a board's field cell keeps TURF.
const CAMP_TURF      := Color("62823a")
const CAMP_GRASS     := Color("5d8c3a")   # the blades standing in it, a shade lighter so they read against it
const CAMP_SOIL      := Color("a67f52")
const CAMP_LEAF      := Color("4c8538")
const CAMP_LEAF_DEEP := Color("3d6a2e")   # the trees framing the frame's edges, in shade
