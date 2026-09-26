extends RefCounted

## What stands on the first screen.
##
## `PUZZLES` is the grid: **eighteen cards over two pages**, in the order
## they are drawn. **All eighteen open a flat board, and there is no `soon`
## card left on the screen.** Snake Apple's left the grid on 2026-09-19 to make
## room for Queens, Horse Pen's the same day for Hidden Word, and Pipes' on
## 2026-09-20 for Word Trail. The 3D game those island boards lived in was
## removed on 2026-09-24.
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
## A grid entry's `short` is the card's own two-line blurb: at 320 wide a
## card fits about seventeen characters a line, which the registry's longer
## `blurb` (still used by the rules sheet) does not.
## `sizes` are the per-round difficulty steps we want to feel out on device.

const PUZZLES := [
	{
		"id": "binairo",
		"kind": "puzzle",
		"title": "Binairo",
		"blurb": "BN_BLURB",
		"short": "BN_SHORT",
		"motto": "BN_MOTTO",
		"footer": "Think · Balance · Complete",
		"script": "res://puzzles/binairo2d.gd",
		"shell": "flat",
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): easy and medium are 6x6, hard is 8x8,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "6 × 6"},
			{"difficulty": 1, "name": "Medium", "line": "6 × 6"},
			{"difficulty": 2, "name": "Hard", "line": "8 × 8"},
			{"difficulty": 3, "name": "Insane", "line": "8 × 8"},
		],
	},
	{
		"id": "mastermind",
		"kind": "puzzle",
		"title": "Code Break",
		"blurb": "CB_BLURB",
		"short": "CB_SHORT",
		"motto": "CB_MOTTO",
		"footer": "Small puzzles · Brighter days",
		# Its palette is friends, not a brush, so the shell builds the other
		# tray.
		"script": "res://puzzles/codebreak2d.gd",
		"shell": "flat",
		"tray": "friends",
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): four seats of six friends with no one
		# twice in the code, the same with repeats, or five seats of seven;
		# each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "CB_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "CB_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "CB_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "CB_LVL_3"},
		],
	},
	{
		"id": "balance",
		"kind": "puzzle",
		"title": "Balance",
		"blurb": "BAL_BLURB",
		"short": "BAL_SHORT",
		"motto": "BAL_MOTTO",
		"footer": "Weigh · Reason · Settle",
		# Its tray is a card per fruit, and it has **no actions row**: the
		# beams are a continuous check, so there is no Check to put in one and
		# Reset rides in the top bar instead.
		"script": "res://puzzles/balance2d.gd",
		"shell": "flat",
		"tray": "weights",
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): three, four or five kinds of fruit,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "BAL_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "BAL_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "BAL_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "BAL_LVL_3"},
		],
	},
	{
		"id": "untangle",
		"kind": "puzzle",
		"title": "Untangle",
		"blurb": "UT_BLURB",
		"short": "UT_SHORT",
		"motto": "UT_MOTTO",
		"footer": "Drag · Loosen · Untangle",
		# It picks nothing up, so it asks for no tray, and it has **no actions
		# row**: capabilities() here is undo and hint, so there is no Check to
		# put in one and Reset rides in the top bar instead.
		"script": "res://puzzles/untangle2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): seven, ten or fourteen lanterns, and
		# each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "UT_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "UT_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "UT_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "UT_LVL_3"},
		],
	},
	{
		"id": "shikaku",
		"kind": "puzzle",
		"title": "Shikaku",
		"blurb": "SK_BLURB",
		"short": "SK_SHORT",
		"motto": "SK_MOTTO",
		"footer": "Divide · Count · Enclose",
		# It picks nothing up, so it asks for no tray; it does have a Check,
		# so unlike Balance it keeps the actions row.
		"script": "res://puzzles/shikaku2d.gd",
		"shell": "flat",
		"tray": "none",
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): a 5 by 6, 6 by 8 or 7 by 9 field,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "5 × 6"},
			{"difficulty": 1, "name": "Medium", "line": "6 × 8"},
			{"difficulty": 2, "name": "Hard", "line": "7 × 9"},
			{"difficulty": 3, "name": "Insane", "line": "SK_LVL_3"},
		],
	},
	{
		"id": "tents",
		"kind": "puzzle",
		"title": "Tents",
		"blurb": "TN_BLURB",
		"short": "TN_SHORT",
		"motto": "TN_MOTTO",
		"footer": "Pitch · Count · Rest",
		"script": "res://puzzles/tents2d.gd",
		"shell": "flat",
		"tray": "none",
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): a 6 by 6 field with 5 tents, 7 by 7
		# with 7 or 8 by 8 with 9, and each is its own daily with its own
		# done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "6 × 6"},
			{"difficulty": 1, "name": "Medium", "line": "7 × 7"},
			{"difficulty": 2, "name": "Hard", "line": "8 × 8"},
			{"difficulty": 3, "name": "Insane", "line": "10 × 10"},
		],
	},
	{
		"id": "lightup",
		"kind": "puzzle",
		"title": "Light Up",
		"blurb": "LU_BLURB",
		"short": "LU_SHORT",
		"motto": "LU_MOTTO",
		"footer": "Place · Light · Reveal",
		"script": "res://puzzles/lightup2d.gd",
		"shell": "flat",
		"tray": "none",
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): a 5 by 5, 6 by 6 or 7 by 7 court,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "5 × 5"},
			{"difficulty": 1, "name": "Medium", "line": "6 × 6"},
			{"difficulty": 2, "name": "Hard", "line": "7 × 7"},
			{"difficulty": 3, "name": "Insane", "line": "8 × 8"},
		],
	},
	{
		"id": "oneline",
		"kind": "puzzle",
		"title": "One Line",
		"blurb": "OL_BLURB",
		"short": "OL_SHORT",
		"motto": "OL_MOTTO",
		"footer": "Walk · Lay · Finish",
		"script": "res://puzzles/oneline2d.gd",
		"shell": "flat",
		"tray": "none",
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): a 3 by 3, 4 by 3 or 4 by 4 lattice
		# of posts, and each is its own daily with its own done mark. The
		# lattice is named rather than the lines, which vary a lot within a
		# level (4 to 19 on easy, 6 to 29 on hard, over 300 seeds each).
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "OL_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "OL_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "OL_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "OL_LVL_3"},
		],
	},
	{
		"id": "nonogram",
		"kind": "puzzle",
		"title": "Nonogram",
		"blurb": "NG_BLURB",
		"short": "NG_SHORT",
		"motto": "NG_MOTTO",
		"footer": "Count · Lay · Reveal",
		# A stroke paints with one of two chips, so it asks for the tile tray.
		"script": "res://puzzles/nonogram2d.gd",
		"shell": "flat",
		"tray": "tiles",
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): a 5 by 5, 7 by 7 or 9 by 9 picture,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "5 × 5"},
			{"difficulty": 1, "name": "Medium", "line": "7 × 7"},
			{"difficulty": 2, "name": "Hard", "line": "9 × 9"},
			{"difficulty": 3, "name": "Insane", "line": "10 × 10"},
		],
	},
	{
		"id": "queens",
		"kind": "puzzle",
		"title": "Queens",
		"blurb": "QN_BLURB",
		"short": "QN_SHORT",
		"motto": "QN_MOTTO",
		"footer": "Seat · Cross · Reign",
		# Two chips, the queen bee and a cross, so it asks for the tile tray
		# with the queen set.
		"script": "res://puzzles/queens2d.gd",
		"shell": "flat",
		"tray": "queens",
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): a 7 by 7, 8 by 8 or 9 by 9 court,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "7 × 7"},
			{"difficulty": 1, "name": "Medium", "line": "8 × 8"},
			{"difficulty": 2, "name": "Hard", "line": "9 × 9"},
			{"difficulty": 3, "name": "Insane", "line": "9 × 9"},
		],
	},
	{
		"id": "hiddenword",
		"kind": "puzzle",
		"title": "Hidden Word",
		"blurb": "HW_BLURB",
		"short": "HW_SHORT",
		"motto": "HW_MOTTO",
		"footer": "Type · Guess · Find",
		# It types, so its tray is a keyboard; every Enter is the check, so
		# there is no actions row and Reset rides in the top bar; and it is
		# the first board built with no tip card at all.
		"script": "res://puzzles/hidden_word2d.gd",
		"shell": "flat",
		"tray": "keys",
		"actions": false,
		"tip": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): the word comes from the 217
		# commonest answers, the first 467 or all 968 (content/hidden_word.json's
		# bands), and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "HW_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "HW_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "HW_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "HW_LVL_3"},
		],
	},
	{
		"id": "wordtrail",
		"kind": "puzzle",
		"title": "Word Trail",
		"blurb": "WT_BLURB",
		"short": "WT_SHORT",
		"motto": "WT_MOTTO",
		"footer": "Trace · Bend · Fill",
		# It picks nothing up, and there is no Check because nothing wrong can
		# be sitting on the board: only a right word locks. So Reset rides up
		# into the top bar and the bottom slot is the tip card alone.
		"script": "res://puzzles/word_trail2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): four words on a 5 by 5 field, six
		# on 6 by 6 or six longer ones on 7 by 7 (word_trail_state.gd's
		# BANDS), and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "WT_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "WT_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "WT_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "WT_LVL_3"},
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
		"blurb": "MP_BLURB",
		"short": "MP_SHORT",
		"motto": "MP_MOTTO",
		"footer": "Count · Prove · Plant",
		"script": "res://puzzles/mushroom2d.gd",
		"shell": "flat",
		"tray": "patch",
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): 6 mushrooms in a 6 by 6 patch, 9 in
		# 7 by 7 or 12 in 8 by 8 (mushroom_gen.gd's SIZES), and each is its
		# own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "MP_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "MP_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "MP_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "MP_LVL_3"},
		],
	},
	{
		"id": "sudoku",
		"kind": "puzzle",
		"title": "Sudoku",
		"blurb": "SD_BLURB",
		"short": "SD_SHORT",
		"motto": "SD_MOTTO",
		"footer": "Scan · Place · Complete",
		# Ten chips -- 1 to 9 and the pencil -- so it asks for the digit pad.
		# Everything else is the default: it keeps the actions row and the tip
		# card, which makes it the plainest board in the registry to wire.
		"script": "res://puzzles/sudoku2d.gd",
		"shell": "flat",
		"tray": "digits",
		"difficulties": [0, 1, 2, 3],
		# Easy and medium are the 6x6 mini and hard the 9x9, so the card asks
		# which before it opens (ui/menu/difficulty_sheet.gd), and each is its
		# own daily with its own done mark (progress_id below).
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "6 × 6"},
			{"difficulty": 1, "name": "Medium", "line": "6 × 6"},
			{"difficulty": 2, "name": "Hard", "line": "9 × 9"},
			{"difficulty": 3, "name": "Insane", "line": "SD_LVL_3"},
		],
	},
	{
		"id": "bridges",
		"kind": "puzzle",
		"title": "Bridges",
		"blurb": "BR_BLURB",
		"short": "BR_SHORT",
		"motto": "BR_MOTTO",
		"footer": "Link · Count · Cross",
		# It picks nothing up, so it asks for no tray; it has a real Check, so
		# unlike Balance and Untangle it keeps the actions row. The bottom slot
		# is 290, which is Shikaku's, Tents' and Light Up's shape, so the flat
		# host needs nothing new.
		"script": "res://puzzles/bridges2d.gd",
		"shell": "flat",
		"tray": "none",
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): 11 islets on a 7 by 7 sea, 16 on
		# 9 by 9 or 24 on 11 by 11 (bridges_gen.gd's BANDS), and each is its
		# own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "BR_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "BR_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "BR_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "BR_LVL_3"},
		],
	},
	{
		"id": "quilt",
		"kind": "puzzle",
		"title": "Quilt",
		"blurb": "QL_BLURB",
		"short": "QL_SHORT",
		"motto": "QL_MOTTO",
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
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): 5 patches on a 5 by 5 backing, 6 on
		# 6 by 6 or 8 on 7 by 7 (quilt_gen.gd's BANDS), and each is its own
		# daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "QL_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "QL_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "QL_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "QL_LVL_3"},
		],
	},
	{
		"id": "fairylights",
		"kind": "puzzle",
		"title": "Fairy Lights",
		"blurb": "FL_BLURB",
		"short": "FL_SHORT",
		"motto": "FL_MOTTO",
		"footer": "Turn · Join · Light",
		# It picks nothing up and there is no Check: a board is unfinished
		# or it is done. So Reset rides up into the top bar and the bottom
		# slot is the tip card alone.
		"script": "res://puzzles/fairy_lights2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): a 5 by 5, 6 by 6 or 7 by 7 garden
		# (fairy_lights_gen.gd's SIZES), and each is its own daily with its
		# own done mark. The lanterns are not counted on the sheet: Prim
		# lays a different number every day.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "FL_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "FL_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "FL_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "FL_LVL_3"},
		],
	},
	{
		"id": "planes",
		"kind": "puzzle",
		"title": "Paper Planes",
		"blurb": "PP_BLURB",
		"short": "PP_SHORT",
		"motto": "PP_MOTTO",
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
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): a 10 by 14, 13 by 18 or 16 by 22 sky
		# (planes_state.gd's BANDS), and each is its own daily with its own
		# done mark. The planes are not counted on the sheet: 300 seeds a
		# level laid 20-33, 29-47 and 43-68 of them.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "PP_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "PP_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "PP_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "PP_LVL_3"},
		],
	},
	{
		"id": "pinwheel",
		"kind": "puzzle",
		"title": "Pinwheel",
		"blurb": "PW_BLURB",
		"short": "PW_SHORT",
		"motto": "PW_MOTTO",
		"footer": "Turn · Fit · Complete",
		# Nothing is picked up and nothing is hidden, so there is no tray and no
		# Check; Reset rides up into the top bar and the tip card stands alone.
		"script": "res://puzzles/pinwheel2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): 9 pieces on a 5 by 5 frame, 11 on
		# 5 by 7 or 13 on 6 by 8 (pinwheel_gen.gd's BANDS), and each is its
		# own daily with its own done mark. The piece count is fixed per band,
		# so the sheet can name it.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "PW_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "PW_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "PW_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "PW_LVL_3"},
		],
	},
	{
		"id": "rings",
		"kind": "puzzle",
		"title": "Rings",
		"blurb": "RG_BLURB",
		"short": "RG_SHORT",
		"motto": "RG_MOTTO",
		"footer": "Lift · Drop · Sort",
		# It picks nothing up, so it asks for no tray; and there is **no
		# Check** -- a solved board is solved in plain sight and there is no
		# wrong ring to find, only a wasted move -- so it has no actions row
		# either and Reset rides up into the top bar. It was built on
		# 2026-09-20 and fell off the grid in Pinwheel's merge (57c8539), which
		# took Pinwheel's side of every conflict; back on 2026-09-24.
		"script": "res://puzzles/rings2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: rings_gen.gd's BANDS, and each is its own daily
		# with its own done mark. Four rings a peg at every band. Insane is
		# Hard's deal inside a move budget (rings_state.gd's `par`).
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "RG_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "RG_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "RG_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "RG_LVL_3"},
		],
	},
	{
		"id": "caterpillar",
		"kind": "puzzle",
		"title": "Caterpillar",
		"blurb": "CP_BLURB",
		"short": "CP_SHORT",
		"motto": "CP_MOTTO",
		"footer": "Walk · Eat · Fill",
		# Nothing is picked up, and nothing wrong can sit on the garden: a
		# fence, a leaf out of turn and the last leaf too soon are refused at
		# the step. So no tray and no Check; Undo, Reset and Hint ride in the
		# top bar and the tip card stands alone -- Pinwheel's shape.
		"script": "res://puzzles/caterpillar2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: a 5 by 5, 6 by 6, 7 by 7 or 8 by 8 garden
		# (caterpillar_gen.gd's BANDS), each its own daily with its own done
		# mark. The leaves are not counted on the sheet: the proof decides
		# how many a day needs.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "CP_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "CP_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "CP_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "CP_LVL_3"},
		],
	},
	{
		"id": "sunbeam",
		"kind": "puzzle",
		"title": "Sunbeam",
		"blurb": "SB_BLURB",
		"short": "SB_SHORT",
		"motto": "SB_MOTTO",
		"footer": "Slide · Bend · Bloom",
		# Nothing is picked up, and nothing wrong can sit on the floor: the
		# beam is traced after every step of a drag and is the check. So no
		# tray and no Check; Undo, Reset and Hint ride in the top bar and the
		# tip card stands alone -- Pinwheel's shape.
		"script": "res://puzzles/sunbeam2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each floor size (sunbeam_gen.gd's BANDS) is its
		# own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "SB_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "SB_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "SB_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "SB_LVL_3"},
		],
	},
	{
		"id": "knight",
		"kind": "puzzle",
		"title": "Knight",
		"blurb": "KN_BLURB",
		"short": "KN_SHORT",
		"motto": "KN_MOTTO",
		"footer": "Hop · Dodge · Take",
		# Nothing is picked up, and nothing wrong can sit on the board: a
		# catch is undone as it happens. So no tray and no Check; Undo, Reset
		# and Hint ride in the top bar and the tip card stands alone --
		# Pinwheel's shape.
		"script": "res://puzzles/knight2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each board size (knight_gen.gd's BANDS) is its
		# own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "KN_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "KN_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "KN_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "KN_LVL_3"},
		],
	},
	{
		"id": "hedgehogs",
		"kind": "puzzle",
		"title": "Hedgehogs",
		"blurb": "HH_BLURB",
		"short": "HH_SHORT",
		"motto": "HH_MOTTO",
		"footer": "Rake · Count · Flag",
		# Mushroom Patch's rows: the two-chip tray (Rake, Flag) and the
		# actions row (Reset, Check); Undo and Hint ride in the top bar.
		"script": "res://puzzles/hedgehogs2d.gd",
		"shell": "flat",
		"tray": "lawn",
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each lawn (hedgehogs_gen.gd's BANDS) is its own
		# daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "HH_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "HH_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "HH_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "HH_LVL_3"},
		],
	},
]

## Every entry the game knows.
static func all() -> Array:
	return PUZZLES

static func find(id: String) -> Dictionary:
	for p in all():
		if p.id == id:
			return p
	return {}

## "puzzle" or "turn"; an entry without a kind is a puzzle, as all twelve
## were before turns existed.
static func kind(entry: Dictionary) -> String:
	return str(entry.get("kind", "puzzle"))

## Which shell hosts the entry. Only "flat" (ui/flat/flat_host.gd) is left
## since the island shell went with the 3D game on 2026-09-24.
static func shell(entry: Dictionary) -> String:
	return str(entry.get("shell", "flat"))

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
