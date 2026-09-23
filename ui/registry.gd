extends RefCounted

## What stands on the first screen, and what stands behind More.
##
## `PUZZLES` is the grid: **eighteen cards over two pages**, in the order
## they are drawn. **All eighteen open a flat board, and there is no `soon`
## card left on the screen.** Snake Apple's left the grid on 2026-09-19 to make
## room for Queens, Horse Pen's the same day for Hidden Word, and Pipes' on
## 2026-09-20 for Word Trail; all three keep their island board under More.
## The dimmed-card machinery -- the `soon` flag, the `SOON` pill, the 55% ink
## and ui/menu.gd's `blocked` signal -- stays in the code for the next board
## that is named before it is drawn, but nothing exercises it now.
##
## **More than twelve does not fit the three-by-four grid, so the grid
## pages.** The
## fourth row was full at twelve, and a `GridContainer` that is
## SIZE_EXPAND_FILL simply runs to five rows and takes a card from 252 to
## about 210 -- every one of those 42 pixels out of the 92 px picture the
## card-art budget is written against. The answer is the pager the campsite
## menu used to have, rebuilt flat in ui/menu.gd alone (`PER_PAGE` is twelve,
## and the strip is its own pill between the grid and the bar): twelve cards
## on page one, and Mushroom Patch, Sudoku, Bridges, Quilt, Paper Planes and
## Pinwheel on page two, each card still
## 252 with its 92 px picture. See
## docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md, section 2.
##
## Sudoku is the fourteenth, added on 2026-09-20. Its own branch had built a
## pager into the day row; main's, built in parallel, stands in its own strip
## between the grid and the bottom bar instead, because a pager beside
## "Day N" reads as a way to change the day. Main's is the one that shipped
## and the one this entry pages onto; see
## docs/superpowers/specs/2026-09-20-sudoku-flat-design.md, section 9 and its
## amendments. Bridges is the fifteenth and Quilt the sixteenth, both added
## the same day and both onto that same page two.
##
## Paper Planes is the seventeenth, added the same day as all three of them.
## It was designed and built as the fifteenth and landed as the seventeenth,
## because Bridges and Quilt merged ahead of it while it was being built; it
## displaced nothing either way. **`PER_PAGE` is still twelve, so it costs
## the first screen nothing**: page one keeps exactly the same twelve cards
## in the same order, page two simply holds more of them, and the
## pager that arrived for the thirteenth already draws as many dots as it is
## given. See
## docs/superpowers/specs/2026-09-20-paper-planes-flat-design.md, section 12.
##
## Pinwheel is the eighteenth, added the same day again and built in
## parallel with Paper Planes -- it was designed as the seventeenth and
## landed as the eighteenth, because Paper Planes merged ahead of it. It
## displaces nothing either way, and `PER_PAGE` is still twelve, so page
## one keeps exactly the same twelve cards in the same order and page two
## holds six. **At eighteen the short-row filler is not built**: six over
## three columns is two full rows, `6 % COLS` is zero. That path is
## load-bearing at any count the page does *not* come out square on --
## it was running at seventeen, where page two held five -- so nothing may
## delete it just because eighteen happens to be tidy, and nothing may
## write "so no filler is built" as though it were a property of the
## pager rather than of today's card count. See
## docs/superpowers/specs/2026-09-20-pinwheel-flat-design.md, section 7.
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
		# Asks like Sudoku (2026-09-23): easy and medium are 6x6, hard is 8x8,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "6 × 6"},
			{"difficulty": 1, "name": "Medium", "line": "6 × 6"},
			{"difficulty": 2, "name": "Hard", "line": "8 × 8"},
		],
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
		# Asks like Sudoku (2026-09-23): four seats of six friends with no one
		# twice in the code, the same with repeats, or five seats of seven;
		# each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "4 friends, all different"},
			{"difficulty": 1, "name": "Medium", "line": "4 friends, may repeat"},
			{"difficulty": 2, "name": "Hard", "line": "5 friends, may repeat"},
		],
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
		# Asks like Sudoku (2026-09-23): three, four or five kinds of fruit,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "3 fruits"},
			{"difficulty": 1, "name": "Medium", "line": "4 fruits"},
			{"difficulty": 2, "name": "Hard", "line": "5 fruits"},
		],
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
		# Asks like Sudoku (2026-09-23): seven, ten or fourteen lanterns, and
		# each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "7 lanterns"},
			{"difficulty": 1, "name": "Medium", "line": "10 lanterns"},
			{"difficulty": 2, "name": "Hard", "line": "14 lanterns"},
		],
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
		# Asks like Sudoku (2026-09-23): a 5 by 6, 6 by 8 or 7 by 9 field,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "5 × 6"},
			{"difficulty": 1, "name": "Medium", "line": "6 × 8"},
			{"difficulty": 2, "name": "Hard", "line": "7 × 9"},
		],
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
		# Asks like Sudoku (2026-09-23): a 6 by 6 field with 5 tents, 7 by 7
		# with 7 or 8 by 8 with 9, and each is its own daily with its own
		# done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "6 × 6"},
			{"difficulty": 1, "name": "Medium", "line": "7 × 7"},
			{"difficulty": 2, "name": "Hard", "line": "8 × 8"},
		],
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
		# Asks like Sudoku (2026-09-23): a 5 by 5, 6 by 6 or 7 by 7 court,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "5 × 5"},
			{"difficulty": 1, "name": "Medium", "line": "6 × 6"},
			{"difficulty": 2, "name": "Hard", "line": "7 × 7"},
		],
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
		# Asks like Sudoku (2026-09-23): a 3 by 3, 4 by 3 or 4 by 4 lattice
		# of posts, and each is its own daily with its own done mark. The
		# lattice is named rather than the lines, which vary a lot within a
		# level (4 to 19 on easy, 6 to 29 on hard, over 300 seeds each).
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "3 × 3 posts"},
			{"difficulty": 1, "name": "Medium", "line": "4 × 3 posts"},
			{"difficulty": 2, "name": "Hard", "line": "4 × 4 posts"},
		],
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
		# Asks like Sudoku (2026-09-23): a 5 by 5, 7 by 7 or 9 by 9 picture,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "5 × 5"},
			{"difficulty": 1, "name": "Medium", "line": "7 × 7"},
			{"difficulty": 2, "name": "Hard", "line": "9 × 9"},
		],
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
		# Asks like Sudoku (2026-09-23): a 7 by 7, 8 by 8 or 9 by 9 court,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "7 × 7"},
			{"difficulty": 1, "name": "Medium", "line": "8 × 8"},
			{"difficulty": 2, "name": "Hard", "line": "9 × 9"},
		],
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
		# Asks like Sudoku (2026-09-23): the word comes from the 217
		# commonest answers, the first 467 or all 968 (content/hidden_word.json's
		# bands), and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "Everyday words"},
			{"difficulty": 1, "name": "Medium", "line": "Less common words"},
			{"difficulty": 2, "name": "Hard", "line": "Any word"},
		],
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
		# Asks like Sudoku (2026-09-23): four words on a 5 by 5 field, six
		# on 6 by 6 or six longer ones on 7 by 7 (word_trail_state.gd's
		# BANDS), and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "4 words, 5 × 5"},
			{"difficulty": 1, "name": "Medium", "line": "6 words, 6 × 6"},
			{"difficulty": 2, "name": "Hard", "line": "6 words, 7 × 7"},
		],
	},
	# --- page two, from here down: `ui/menu.gd`'s PER_PAGE is twelve, and
	# these are entries thirteen to seventeen. Mushroom Patch was the
	# thirteenth and the first card that was *added* rather than swapped into
	# a `soon` slot, which is what pushed the grid onto a second page at all;
	# Sudoku is the fourteenth, Bridges the fifteenth, Quilt the sixteenth
	# and Paper Planes the seventeenth, and all four join it there without a
	# word changing anywhere else. Twelve a page is not a
	# taste -- it is what four rows of 252 buy -- so the grid grew a page
	# rather than a shorter card, and all of these stay last so page one
	# keeps exactly the twelve cards it has, in exactly the order it has
	# them. Sudoku's own spec (2026-09-20-sudoku-flat-design.md, section 9)
	# argued that pager into the day row; the user ruled otherwise and the
	# strip under the grid is what shipped. See that section's amendments.
	{
		"id": "mushroom",
		"kind": "puzzle",
		"title": "Mushroom Patch",
		"blurb": "Every number counts the mushrooms around it. Find them all.",
		"short": "The numbers count\nwhat is hidden.",
		"motto": "Every patch has its count",
		"footer": "Count · Prove · Plant",
		"script": "res://puzzles/mushroom2d.gd",
		"shell": "flat",
		"tray": "patch",
		"difficulties": [0, 1, 2],
		# Asks like Sudoku (2026-09-23): 6 mushrooms in a 6 by 6 patch, 9 in
		# 7 by 7 or 12 in 8 by 8 (mushroom_gen.gd's SIZES), and each is its
		# own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "6 mushrooms, 6 × 6"},
			{"difficulty": 1, "name": "Medium", "line": "9 mushrooms, 7 × 7"},
			{"difficulty": 2, "name": "Hard", "line": "12 mushrooms, 8 × 8"},
		],
	},
	{
		"id": "sudoku",
		"kind": "puzzle",
		"title": "Sudoku",
		"blurb": "Every number once in every row, column and region.",
		"short": "Every number once,\nevery way you look.",
		"motto": "Every number has its place",
		"footer": "Scan · Place · Complete",
		# Ten chips -- 1 to 9 and the pencil -- so it asks for the digit pad.
		# Everything else is the default: it keeps the actions row and the tip
		# card, which makes it the plainest board in the registry to wire.
		"script": "res://puzzles/sudoku2d.gd",
		"shell": "flat",
		"tray": "digits",
		"difficulties": [0, 1, 2],
		# Easy and medium are the 6x6 mini and hard the 9x9, so the card asks
		# which before it opens (ui/menu/difficulty_sheet.gd), and each is its
		# own daily with its own done mark (progress_id below).
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "6 × 6"},
			{"difficulty": 1, "name": "Medium", "line": "6 × 6"},
			{"difficulty": 2, "name": "Hard", "line": "9 × 9"},
		],
	},
	{
		"id": "bridges",
		"kind": "puzzle",
		"title": "Bridges",
		"blurb": "Plank every islet to its number, and join them all.",
		"short": "Plank every islet\nto its number.",
		"motto": "Join every islet",
		"footer": "Link · Count · Cross",
		# It picks nothing up, so it asks for no tray; it has a real Check, so
		# unlike Balance and Untangle it keeps the actions row. The bottom slot
		# is 290, which is Shikaku's, Tents' and Light Up's shape, so the flat
		# host needs nothing new.
		"script": "res://puzzles/bridges2d.gd",
		"shell": "flat",
		"tray": "none",
		"difficulties": [0, 1, 2],
	},
	{
		"id": "quilt",
		"kind": "puzzle",
		"title": "Quilt",
		"blurb": "Fit every patch onto the quilt, with not a gap left.",
		"short": "Fit every patch.\nLeave no gap.",
		"motto": "Make the blanket whole",
		"footer": "Fit · Sew · Finish",
		# Its rack of patches is **inside the board card**, not a tray row --
		# a patch is dragged from the rack onto the quilt, and the two have to
		# share one coordinate space for that to be one gesture. So it asks
		# for no tray, and it has **no actions row**: nothing wrong can be
		# sitting on the quilt, because an illegal drop is never taken, so
		# there is no Check to put in one and Reset rides up into the top bar.
		# Word Trail's shape exactly: the bottom slot is the tip card alone.
		"script": "res://puzzles/quilt2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2],
	},
	{
		"id": "fairylights",
		"kind": "puzzle",
		"title": "Fairy Lights",
		"blurb": "Turn the wire until every lantern is lit.",
		"short": "Turn the wire,\nlight the garden.",
		"motto": "Wake every lantern",
		"footer": "Turn · Join · Light",
		# It picks nothing up and there is no Check: a board is unfinished
		# or it is done. So Reset rides up into the top bar and the bottom
		# slot is the tip card alone.
		"script": "res://puzzles/fairy_lights2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2],
	},
	{
		"id": "planes",
		"kind": "puzzle",
		"title": "Paper Planes",
		"blurb": "Tap a plane whose lane to the edge is clear, and off it goes.",
		"short": "Send every plane\noff a clear lane.",
		"motto": "A clear lane and away",
		"footer": "Scan · Clear · Launch",
		# It picks nothing up, and there is no Check: a launch only ever
		# empties cells, so nothing wrong can be sitting on the board and the
		# player cannot dead-end it. Reset rides up into the top bar and the
		# bottom slot is the tip card alone, which is Word Trail's and
		# Quilt's shape.
		"script": "res://puzzles/planes2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2],
	},
	{
		"id": "pinwheel",
		"kind": "puzzle",
		"title": "Pinwheel",
		"blurb": "Turn each pinned piece until the frame is full.",
		"short": "Turn each piece\ntill the frame fills.",
		"motto": "Turn it till it fits",
		"footer": "Turn · Fit · Complete",
		# Nothing is picked up and nothing is hidden, so there is no tray and no
		# Check; Reset rides up into the top bar and the tip card stands alone.
		"script": "res://puzzles/pinwheel2d.gd",
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

## The key a board's daily completion is saved under. A card that asks for
## its difficulty keeps one per difficulty, so finishing the easy board does
## not open the hard one as already solved; every other card keeps its id.
static func progress_id(entry: Dictionary, difficulty: int) -> String:
	var id := String(entry.get("id", ""))
	if bool(entry.get("pick_difficulty", false)):
		return "%s_%d" % [id, difficulty]
	return id

## A grid card that names a board nobody has drawn flat yet: it is on the
## screen, and it does not open.
static func is_soon(entry: Dictionary) -> bool:
	return bool(entry.get("soon", false))
