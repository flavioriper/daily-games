extends RefCounted

## One entry per prototype. Adding a puzzle costs one line here plus its script.
## `sizes` are the per-round difficulty steps we want to feel out on device.

const PUZZLES := [
	{
		"id": "binairo",
		"title": "Binairo",
		"blurb": "Suns and moons. Never three alike in a line.",
		"script": "res://puzzles/binairo3d.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "mastermind",
		"title": "Code Break",
		"blurb": "Crack the hidden row from the feedback.",
		"script": "res://puzzles/mastermind.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "balance",
		"title": "Balance",
		"blurb": "Work out what each shape weighs.",
		"script": "res://puzzles/balance.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "pipes",
		"title": "Pipes",
		"blurb": "Turn every piece until nothing leaks.",
		"script": "res://puzzles/pipes.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "untangle",
		"title": "Untangle",
		"blurb": "Drag the dots until no lines cross.",
		"script": "res://puzzles/untangle.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "shikaku",
		"title": "Shikaku",
		"blurb": "Cut the grid into numbered rectangles.",
		"script": "res://puzzles/shikaku.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "tents",
		"title": "Tents",
		"blurb": "One tent beside every tree.",
		"script": "res://puzzles/tents.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "lightup",
		"title": "Light Up",
		"blurb": "Light every cell, and no bulb may see another.",
		"script": "res://puzzles/lightup.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "oneline",
		"title": "One Line",
		"blurb": "Trace every line in a single stroke.",
		"script": "res://puzzles/oneline.gd",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "nonogram",
		"title": "Nonogram",
		"blurb": "Fill the runs and reveal the picture.",
		"script": "res://puzzles/nonogram.gd",
		"difficulties": [0, 1, 2],
	},
]

static func find(id: String) -> Dictionary:
	for p in PUZZLES:
		if p.id == id:
			return p
	return {}
