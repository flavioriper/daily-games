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
		"script": "res://puzzles/binairo3d.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "mastermind",
		"kind": "puzzle",
		"title": "Code Break",
		"blurb": "Crack the hidden row from the feedback.",
		"motto": "Crack the hidden code",
		"footer": "Small puzzles · Brighter days",
		"script": "res://puzzles/codebreak3d.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "balance",
		"kind": "puzzle",
		"title": "Balance",
		"blurb": "Work out what each shape weighs.",
		"motto": "Find the weight of things",
		"footer": "Weigh · Reason · Settle",
		"script": "res://puzzles/balance3d.gd",
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
		"blurb": "Drag the dots until no lines cross.",
		"motto": "Every knot comes undone",
		"footer": "Drag · Loosen · Untangle",
		"script": "res://puzzles/untangle3d.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "shikaku",
		"kind": "puzzle",
		"title": "Shikaku",
		"blurb": "Cut the field into numbered plots.",
		"motto": "Every plot has its number",
		"footer": "Divide · Count · Enclose",
		"script": "res://puzzles/shikaku3d.gd",
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
		"id": "guess_number",
		"kind": "turn",
		"title": "Guess",
		"blurb": "One number, one go. How close can you land?",
		"motto": "One number, one go",
		"footer": "Guess · Lock · Reveal",
		"script": "res://turns/guess_number.gd",
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
