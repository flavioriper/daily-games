extends RefCounted

## One entry per prototype. Adding a puzzle costs one line here plus its script.
## `sizes` are the per-round difficulty steps we want to feel out on device.

const PUZZLES := [
	{
		"id": "binairo",
		"kind": "puzzle",
		"title": "Binairo",
		"blurb": "Suns and moons. Never three alike in a line.",
		"motto": "Balance brings harmony",
		"footer": "Think · Balance · Complete",
		# The flat 2D board under the flat chrome, on trial against the island
		# below (docs/superpowers/specs/2026-09-18-binairo-flat-design.md).
		"script": "res://puzzles/binairo2d.gd",
		"shell": "flat",
		"difficulties": [0, 1, 2],
	},
	{
		# The island Binairo, kept on the menu while the two are judged. It
		# shares the flat card's day seed, so both show the same puzzle.
		"id": "binairo_island",
		"kind": "puzzle",
		"title": "Binairo",
		"blurb": "The island board, for comparison.",
		"motto": "Balance brings harmony",
		"footer": "Think · Balance · Complete",
		"script": "res://puzzles/binairo3d.gd",
		"seed_as": "binairo",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "mastermind",
		"kind": "puzzle",
		"title": "Code Break",
		"blurb": "Crack the hidden row from the feedback.",
		"motto": "Crack the hidden code",
		"footer": "Small puzzles · Brighter days",
		# The flat 2D board under the flat chrome, on trial against the island
		# below (docs/superpowers/specs/2026-09-18-codebreak-flat-design.md).
		# Its palette is friends, not a brush, so the shell builds the other
		# tray.
		"script": "res://puzzles/codebreak2d.gd",
		"shell": "flat",
		"tray": "friends",
		"difficulties": [0, 1, 2],
	},
	{
		# The island Code Break, kept on the menu while the two are judged. It
		# shares the flat card's day seed, so both hide the same code.
		"id": "mastermind_island",
		"kind": "puzzle",
		"title": "Code Break",
		"blurb": "The island board, for comparison.",
		"motto": "Crack the hidden code",
		"footer": "Small puzzles · Brighter days",
		"script": "res://puzzles/codebreak3d.gd",
		"seed_as": "mastermind",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "balance",
		"kind": "puzzle",
		"title": "Balance",
		"blurb": "Work out what each fruit weighs.",
		"motto": "Find the weight of things",
		"footer": "Weigh · Reason · Settle",
		# The flat 2D board under the flat chrome, on trial against the island
		# below (docs/superpowers/specs/2026-09-18-balance-flat-design.md).
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
		# The island Balance, kept on the menu while the two are judged. It
		# shares the flat card's day seed, so both hide the same weights.
		"id": "balance_island",
		"kind": "puzzle",
		"title": "Balance",
		"blurb": "The island board, for comparison.",
		"motto": "Find the weight of things",
		"footer": "Weigh · Reason · Settle",
		"script": "res://puzzles/balance3d.gd",
		"seed_as": "balance",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "pipes",
		"kind": "puzzle",
		"title": "Pipes",
		"blurb": "Route the water. It won't climb without a pump.",
		"motto": "Make the water flow",
		"footer": "Think · Connect · Flow",
		"script": "res://puzzles/pipes_iso.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "untangle",
		"kind": "puzzle",
		"title": "Untangle",
		"blurb": "Drag the lanterns until no cords cross.",
		"motto": "Every knot comes undone",
		"footer": "Drag · Loosen · Untangle",
		# The flat 2D board under the flat chrome, on trial against the island
		# below (docs/superpowers/specs/2026-09-18-untangle-flat-design.md).
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
		# The island Untangle, kept on the menu while the two are judged. It
		# shares the flat card's day seed, so both hand out the same tangle.
		"id": "untangle_island",
		"kind": "puzzle",
		"title": "Untangle",
		"blurb": "The island board, for comparison.",
		"motto": "Every knot comes undone",
		"footer": "Drag · Loosen · Untangle",
		"script": "res://puzzles/untangle3d.gd",
		"seed_as": "untangle",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "shikaku",
		"kind": "puzzle",
		"title": "Shikaku",
		"blurb": "Cut the field into numbered plots.",
		"motto": "Every plot has its number",
		"footer": "Divide · Count · Enclose",
		# The flat 2D board under the flat chrome, on trial against the island
		# below (docs/superpowers/specs/2026-09-18-shikaku-flat-design.md).
		# It picks nothing up, so it asks for no tray; it does have a Check,
		# so unlike Balance it keeps the actions row.
		"script": "res://puzzles/shikaku2d.gd",
		"shell": "flat",
		"tray": "none",
		"difficulties": [0, 1, 2],
	},
	{
		# The island Shikaku, kept on the menu while the two are judged. It
		# shares the flat card's day seed, so both cut the same field.
		"id": "shikaku_island",
		"kind": "puzzle",
		"title": "Shikaku",
		"blurb": "The island board, for comparison.",
		"motto": "Every plot has its number",
		"footer": "Divide · Count · Enclose",
		"script": "res://puzzles/shikaku3d.gd",
		"seed_as": "shikaku",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "tents",
		"kind": "puzzle",
		"title": "Tents",
		"blurb": "One tent beside every tree.",
		"motto": "A camp for every tree",
		"footer": "Pitch · Count · Rest",
		"script": "res://puzzles/tents3d.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "lightup",
		"kind": "puzzle",
		"title": "Light Up",
		"blurb": "Light every cell, and no bulb may see another.",
		"motto": "Let there be light",
		"footer": "Place · Light · Reveal",
		"script": "res://puzzles/lightup3d.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "oneline",
		"kind": "puzzle",
		"title": "One Line",
		"blurb": "Trace every line in a single stroke.",
		"motto": "One stroke, no lifting",
		"footer": "Walk · Lay · Finish",
		"script": "res://puzzles/oneline3d.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "nonogram",
		"kind": "puzzle",
		"title": "Nonogram",
		"blurb": "Fill the runs and reveal the picture.",
		"motto": "Numbers make a picture",
		"footer": "Count · Lay · Reveal",
		"script": "res://puzzles/nonogram3d.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "horse",
		"kind": "puzzle",
		"title": "Horse Pen",
		"blurb": "Pen the horse in with hay bales. Keep the meadow.",
		"motto": "Pen the wandering horse",
		"footer": "Bale · Enclose · Keep",
		"script": "res://puzzles/horse3d.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "snake",
		"kind": "puzzle",
		"title": "Snake Apple",
		"blurb": "Eat every apple, then slip into the burrow.",
		"motto": "Room to wriggle",
		"footer": "Slide · Eat · Burrow",
		"script": "res://puzzles/snake3d.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "rope",
		"kind": "puzzle",
		"title": "The Rope",
		"blurb": "Lay the rope over every square, pegs in order.",
		"motto": "Every peg in its turn",
		"footer": "Lay · Cover · Finish",
		"script": "res://puzzles/rope3d.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "how_big",
		"kind": "turn",
		"title": "How Big?",
		"blurb": "How tall is a horse beside the scout? Drag it to size, one go.",
		"motto": "Size it up",
		"footer": "Drag · Lock · Reveal",
		"script": "res://turns/how_big.gd",
		"difficulties": [0],
	},
]

static func find(id: String) -> Dictionary:
	for p in PUZZLES:
		if p.id == id:
			return p
	return {}

## "puzzle" or "turn"; an entry without a kind is a puzzle, as all twelve
## were before turns existed.
static func kind(entry: Dictionary) -> String:
	return str(entry.get("kind", "puzzle"))

## Which shell hosts the entry: "island" (ui/puzzle_host.gd, the stage and
## its wood signs) unless the entry asks for "flat" (ui/flat/flat_host.gd).
static func shell(entry: Dictionary) -> String:
	return str(entry.get("shell", "island"))
