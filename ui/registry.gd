extends RefCounted

## What stands on the first screen, and what stands behind More.
##
## `PUZZLES` is the grid: twelve cards, three across and four down, in the
## order they are drawn. **All twelve open a flat board, and there is no
## `soon` card left on the screen.** Snake Apple's left the grid on
## 2026-09-19 to make room for Queens, Horse Pen's the same day for Hidden
## Word, and Pipes' on 2026-09-20 for Word Trail; all three keep their island
## board under More. The dimmed-card machinery -- the `soon` flag, the `SOON`
## pill, the 55% ink and ui/menu.gd's `blocked` signal -- stays in the code
## for the next board that is named before it is drawn, but nothing
## exercises it now.
##
## `LEGACY` is the old game: every board that still lives on the 3D stage,
## plus the one turn, reached only through the first screen's More sheet.
## Nothing new belongs in it. Its entries keep `seed_as` pointing at the flat
## card they shadow, so an island and its flat twin still hand out the same
## day's puzzle.
##
## A grid entry's `short` is the card's own two-line blurb: at 320 wide a
## card fits about seventeen characters a line, which the registry's longer
## `blurb` (still used by the rules sheet and the legacy menu) does not.
## `sizes` are the per-round difficulty steps we want to feel out on device.

const PUZZLES := [
	{
		"id": "binairo",
		"kind": "puzzle",
		"title": "Binairo",
		"blurb": "Suns and moons. Never three alike in a line.",
		"short": "Suns and moons,\nnever three alike.",
		"motto": "Balance brings harmony",
		"footer": "Think · Balance · Complete",
		"script": "res://puzzles/binairo2d.gd",
		"shell": "flat",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "mastermind",
		"kind": "puzzle",
		"title": "Code Break",
		"blurb": "Crack the hidden row from the feedback.",
		"short": "Crack the hidden\nrow of friends.",
		"motto": "Crack the hidden code",
		"footer": "Small puzzles · Brighter days",
		# Its palette is friends, not a brush, so the shell builds the other
		# tray.
		"script": "res://puzzles/codebreak2d.gd",
		"shell": "flat",
		"tray": "friends",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "balance",
		"kind": "puzzle",
		"title": "Balance",
		"blurb": "Work out what each fruit weighs.",
		"short": "What does each\nfruit weigh?",
		"motto": "Find the weight of things",
		"footer": "Weigh · Reason · Settle",
		# Its tray is a card per fruit, and it has **no actions row**: the
		# beams are a continuous check, so there is no Check to put in one and
		# Reset rides in the top bar instead.
		"script": "res://puzzles/balance2d.gd",
		"shell": "flat",
		"tray": "weights",
		"actions": false,
		"difficulties": [0, 1, 2],
	},
	{
		"id": "untangle",
		"kind": "puzzle",
		"title": "Untangle",
		"blurb": "Drag the lanterns until no cords cross.",
		"short": "Pull the lanterns\nuntil none cross.",
		"motto": "Every knot comes undone",
		"footer": "Drag · Loosen · Untangle",
		# It picks nothing up, so it asks for no tray, and it has **no actions
		# row**: capabilities() here is undo and hint, so there is no Check to
		# put in one and Reset rides in the top bar instead.
		"script": "res://puzzles/untangle2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2],
	},
	{
		"id": "shikaku",
		"kind": "puzzle",
		"title": "Shikaku",
		"blurb": "Cut the field into numbered plots.",
		"short": "Cut the field into\nnumbered plots.",
		"motto": "Every plot has its number",
		"footer": "Divide · Count · Enclose",
		# It picks nothing up, so it asks for no tray; it does have a Check,
		# so unlike Balance it keeps the actions row.
		"script": "res://puzzles/shikaku2d.gd",
		"shell": "flat",
		"tray": "none",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "tents",
		"kind": "puzzle",
		"title": "Tents",
		"blurb": "One tent beside every tree.",
		"short": "One tent beside\nevery tree.",
		"motto": "A camp for every tree",
		"footer": "Pitch · Count · Rest",
		"script": "res://puzzles/tents2d.gd",
		"shell": "flat",
		"tray": "none",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "lightup",
		"kind": "puzzle",
		"title": "Light Up",
		"blurb": "Light every cell, and no bulb may see another.",
		"short": "Light every cell,\nblind every bulb.",
		"motto": "Let there be light",
		"footer": "Place · Light · Reveal",
		"script": "res://puzzles/lightup2d.gd",
		"shell": "flat",
		"tray": "none",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "oneline",
		"kind": "puzzle",
		"title": "One Line",
		"blurb": "Trace every line in a single stroke.",
		"short": "Every line, walked\nin one stroke.",
		"motto": "One stroke, no lifting",
		"footer": "Walk · Lay · Finish",
		"script": "res://puzzles/oneline2d.gd",
		"shell": "flat",
		"tray": "none",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "nonogram",
		"kind": "puzzle",
		"title": "Nonogram",
		"blurb": "Fill the runs and reveal the picture.",
		"short": "The numbers make\na picture.",
		"motto": "Numbers make a picture",
		"footer": "Count · Lay · Reveal",
		# A stroke paints with one of two chips, so it asks for the tile tray.
		"script": "res://puzzles/nonogram2d.gd",
		"shell": "flat",
		"tray": "tiles",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "queens",
		"kind": "puzzle",
		"title": "Queens",
		"blurb": "Seat one queen in every row, column and colour.",
		"short": "One queen per row,\ncolumn and colour.",
		"motto": "Every queen has her seat",
		"footer": "Seat · Cross · Reign",
		# Two chips, the queen bee and a cross, so it asks for the tile tray
		# with the queen set.
		"script": "res://puzzles/queens2d.gd",
		"shell": "flat",
		"tray": "queens",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "hiddenword",
		"kind": "puzzle",
		"title": "Hidden Word",
		"blurb": "Five letters, six tries. A new word every day.",
		"short": "Five letters,\nsix tries.",
		"motto": "Find the hidden word",
		"footer": "Type · Guess · Find",
		# It types, so its tray is a keyboard; every Enter is the check, so
		# there is no actions row and Reset rides in the top bar; and it is
		# the first board built with no tip card at all.
		"script": "res://puzzles/hidden_word2d.gd",
		"shell": "flat",
		"tray": "keys",
		"actions": false,
		"tip": false,
		"difficulties": [0, 1, 2],
	},
	{
		"id": "wordtrail",
		"kind": "puzzle",
		"title": "Word Trail",
		"blurb": "Trace every hidden word. The lengths are the only clue.",
		"short": "Trace the words,\nfill the field.",
		"motto": "Every letter finds its way",
		"footer": "Trace · Bend · Fill",
		# It picks nothing up, and there is no Check because nothing wrong can
		# be sitting on the board: only a right word locks. So Reset rides up
		# into the top bar and the bottom slot is the tip card alone.
		"script": "res://puzzles/word_trail2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2],
	},
]

## The old game. Every one of these mounts the 3D stage and wears the island
## chrome (legacy/ui/island_host.gd), or in How Big?'s case the turn host.
## Reached from the first screen's More sheet and from nowhere else.
const LEGACY := [
	{
		"id": "binairo_island",
		"kind": "puzzle",
		"title": "Binairo",
		"blurb": "The island board.",
		"motto": "Balance brings harmony",
		"footer": "Think · Balance · Complete",
		"script": "res://legacy/puzzles/binairo3d.gd",
		"seed_as": "binairo",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "mastermind_island",
		"kind": "puzzle",
		"title": "Code Break",
		"blurb": "The island board.",
		"motto": "Crack the hidden code",
		"footer": "Small puzzles · Brighter days",
		"script": "res://legacy/puzzles/codebreak3d.gd",
		"seed_as": "mastermind",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "balance_island",
		"kind": "puzzle",
		"title": "Balance",
		"blurb": "The island board.",
		"motto": "Find the weight of things",
		"footer": "Weigh · Reason · Settle",
		"script": "res://legacy/puzzles/balance3d.gd",
		"seed_as": "balance",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "untangle_island",
		"kind": "puzzle",
		"title": "Untangle",
		"blurb": "The island board.",
		"motto": "Every knot comes undone",
		"footer": "Drag · Loosen · Untangle",
		"script": "res://legacy/puzzles/untangle3d.gd",
		"seed_as": "untangle",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "shikaku_island",
		"kind": "puzzle",
		"title": "Shikaku",
		"blurb": "The island board.",
		"motto": "Every plot has its number",
		"footer": "Divide · Count · Enclose",
		"script": "res://legacy/puzzles/shikaku3d.gd",
		"seed_as": "shikaku",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "tents_island",
		"kind": "puzzle",
		"title": "Tents",
		"blurb": "The island board.",
		"motto": "A camp for every tree",
		"footer": "Pitch · Count · Rest",
		"script": "res://legacy/puzzles/tents3d.gd",
		"seed_as": "tents",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "lightup_island",
		"kind": "puzzle",
		"title": "Light Up",
		"blurb": "The island board.",
		"motto": "Let there be light",
		"footer": "Place · Light · Reveal",
		"script": "res://legacy/puzzles/lightup3d.gd",
		"seed_as": "lightup",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "oneline_island",
		"kind": "puzzle",
		"title": "One Line",
		"blurb": "The island board.",
		"motto": "One stroke, no lifting",
		"footer": "Walk · Lay · Finish",
		"script": "res://legacy/puzzles/oneline3d.gd",
		"seed_as": "oneline",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "nonogram_island",
		"kind": "puzzle",
		"title": "Nonogram",
		"blurb": "The island board.",
		"motto": "Numbers make a picture",
		"footer": "Count · Lay · Reveal",
		"script": "res://legacy/puzzles/nonogram3d.gd",
		"seed_as": "nonogram",
		"difficulties": [0, 1, 2],
	},
	# The four that were never drawn flat. They keep `seed_as` at the grid's
	# id so the day's puzzle does not move when one of them is finally drawn.
	{
		"id": "pipes_island",
		"kind": "puzzle",
		"title": "Pipes",
		"blurb": "Route the water. It won't climb without a pump.",
		"motto": "Make the water flow",
		"footer": "Think · Connect · Flow",
		"script": "res://legacy/puzzles/pipes_iso.gd",
		"seed_as": "pipes",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "horse_island",
		"kind": "puzzle",
		"title": "Horse Pen",
		"blurb": "Pen the horse in with hay bales. Keep the meadow.",
		"motto": "Pen the wandering horse",
		"footer": "Bale · Enclose · Keep",
		"script": "res://legacy/puzzles/horse3d.gd",
		"seed_as": "horse",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "snake_island",
		"kind": "puzzle",
		"title": "Snake Apple",
		"blurb": "Eat every apple, then slip into the burrow.",
		"motto": "Room to wriggle",
		"footer": "Slide · Eat · Burrow",
		"script": "res://legacy/puzzles/snake3d.gd",
		"seed_as": "snake",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "rope",
		"kind": "puzzle",
		"title": "The Rope",
		"blurb": "Lay the rope over every square, pegs in order.",
		"motto": "Every peg in its turn",
		"footer": "Lay · Cover · Finish",
		"script": "res://legacy/puzzles/rope3d.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "how_big",
		"kind": "turn",
		"title": "How Big?",
		"blurb": "How tall is a horse beside the scout? Drag it to size, one go.",
		"motto": "Size it up",
		"footer": "Drag · Lock · Reveal",
		"script": "res://legacy/turns/how_big.gd",
		"difficulties": [0],
	},
]

## Every entry either list holds, the grid first.
static func all() -> Array:
	var out: Array = []
	out.append_array(PUZZLES)
	out.append_array(LEGACY)
	return out

static func find(id: String) -> Dictionary:
	for p in all():
		if p.id == id:
			return p
	return {}

## "puzzle" or "turn"; an entry without a kind is a puzzle, as all twelve
## were before turns existed.
static func kind(entry: Dictionary) -> String:
	return str(entry.get("kind", "puzzle"))

## Which shell hosts the entry: "island" (legacy/ui/island_host.gd, the stage
## and its wood signs) unless the entry asks for "flat" (ui/flat/flat_host.gd).
static func shell(entry: Dictionary) -> String:
	return str(entry.get("shell", "island"))

## A grid card that names a board nobody has drawn flat yet: it is on the
## screen, and it does not open.
static func is_soon(entry: Dictionary) -> bool:
	return bool(entry.get("soon", false))
