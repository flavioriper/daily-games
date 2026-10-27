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
## **Five left on 2026-10-13** (the user: "we need to remove some games not
## so good"): Code Break (id `mastermind`), Balance, Tents, One Line and
## Mushroom Patch, with their boards, cards, sounds and banks. The history
## above still counts them; the grid is thirty-three cards now, and a card's
## colour comes off its index here, so every card after Binairo changed
## colour that day.
## Marigold left the grid the same day for the Arcade tab (`ARCADE`, below):
## thirty-two cards.
##
## A grid entry's `short` is the card's own two-line blurb: at 320 wide a
## card fits about seventeen characters a line, which the registry's longer
## `blurb` (still used by the rules sheet) does not.
## `sizes` are the per-round difficulty steps we want to feel out on device.
##
## **Re-sorted by popularity on 2026-10-20** (the user: "check on web
## what are the top rating games we have, and reorder the lists so the best
## ones come first"). The grid now runs by how big each board's genre is on
## the stores (downloads, chart places), best first; the ordinals above
## ("the fourteenth", "page two") are history. Evidence per board is in
## docs/agents/first-screen.md. The old page-two divider that stood between
## Quilt and Sudoku read:
## > --- page two, from here down: `ui/menu.gd`'s PER_PAGE is twelve, and
## these are entries thirteen to seventeen. Mushroom Patch was the
## thirteenth and the first card that was *added* rather than swapped into
## a `soon` slot, which is what pushed the grid onto a second page at all;
## Sudoku is the fourteenth, Bridges the fifteenth, Quilt the sixteenth
## and Paper Planes the seventeenth, and all four join it there without a
## word changing anywhere else. Twelve a page is not a
## taste -- it is what four rows of 252 buy -- so the grid grew a page
## rather than a shorter card, and all of these stay last so page one
## keeps exactly the twelve cards it has, in exactly the order it has
## them. Sudoku's own spec (2026-09-20-sudoku-flat-design.md, section 9)
## argued that pager into the day row; the user ruled otherwise and the
## strip under the grid is what shipped. See that section's amendments.
##
## `skill` is which of core/brain.gd's five skills a board trains, named on
## its win (docs/superpowers/specs/2026-10-22-brain-skills-design.md).

const PUZZLES := [
	{
		"id": "hiddenword",
		"skill": "words",
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
		"card": "res://ui/menu/cards/hiddenword.gd",
		"shell": "flat",
		"tray": "keys",
		"tip": false,
		# Its world is the whole screen (`bleed`, puzzles/hidden_word_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
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
		"id": "sudoku",
		"skill": "logic",
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
		"card": "res://ui/menu/cards/sudoku.gd",
		"shell": "flat",
		"tray": "digits",
		# Its world is the whole screen (`bleed`, puzzles/sudoku_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Easy and medium are the 6x6 mini and hard the 9x9, so the card asks
		# which before it opens (ui/menu/difficulty_sheet.gd, the row last
		# played ringed; retired 2026-10-22, back 2026-10-27), and each is its
		# own daily with its own done mark (progress_id below).
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "6 × 6"},
			{"difficulty": 1, "name": "Medium", "line": "6 × 6"},
			{"difficulty": 2, "name": "Hard", "line": "SD_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "SD_LVL_3"},
		],
	},
	{
		"id": "picket",
		"skill": "logic",
		"kind": "puzzle",
		"title": "Picket Sums",
		"blurb": "PK_BLURB",
		"short": "PK_SHORT",
		"motto": "PK_MOTTO",
		"footer": "Add · Fence · Complete",
		# Sudoku's grid fenced into garden plots, each adding up to its tag
		# (puzzles/picket2d.gd, Sudoku's board with the plots laid over it).
		# The same digit pad, the same bleed world and level card; Hard and
		# Insane come from banks mined on the Mac (content/insane/picket*.json).
		"script": "res://puzzles/picket2d.gd",
		"card": "res://ui/menu/cards/picket.gd",
		"shell": "flat",
		"tray": "digits",
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "6 × 6"},
			{"difficulty": 1, "name": "Medium", "line": "6 × 6"},
			{"difficulty": 2, "name": "Hard", "line": "SD_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "PK_LVL_3"},
		],
	},
	{
		"id": "market",
		"skill": "logic",
		"kind": "puzzle",
		"title": "Market Sums",
		"blurb": "MK_BLURB",
		"short": "MK_SHORT",
		"motto": "MK_MOTTO",
		"footer": "Pick · Sign · Make",
		# Six numbered crates on a garden market stall and an order on the
		# board under the awning: combine two crates with +, take away,
		# times or share until one holds the order (puzzles/market2d.gd).
		# The stall fills the screen and the crates and sign tokens are
		# inside the board, so no tray and no actions row: Undo, the bin
		# and the bulb ride the tools row. No Check: the order board says
		# when it is filled.
		"script": "res://puzzles/market2d.gd",
		"card": "res://ui/menu/cards/market.gd",
		"shell": "flat",
		"tray": "none",
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "MK_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "MK_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "MK_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "MK_LVL_3"},
		],
	},
	{
		"id": "pie",
		"skill": "logic",
		"kind": "puzzle",
		"title": "Who Ate the Pie?",
		"blurb": "PI_BLURB",
		"short": "PI_SHORT",
		"motto": "PI_MOTTO",
		"footer": "Pick · Read · Prove",
		# Bakers in a grid on the bake-sale table at the village fête, some
		# of whom ate the pie: mark each one, and each says one true thing;
		# a mark stands only when the clues prove it (puzzles/pie2d.gd). The
		# table fills the screen and the cards and the verdict buttons are
		# inside the board, so no tray and no actions row. Only the bulb: a
		# proven mark has nothing to undo, and nothing is wrong for a Check.
		"script": "res://puzzles/pie2d.gd",
		"card": "res://ui/menu/cards/pie.gd",
		"shell": "flat",
		"tray": "none",
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "PI_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "PI_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "PI_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "PI_LVL_3"},
		],
	},
	{
		"id": "rings",
		"skill": "planning",
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
		"card": "res://ui/menu/cards/rings.gd",
		"script": "res://puzzles/rings2d.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/rings_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: rings_gen.gd's BANDS, and each is its own daily
		# with its own done mark. Full pegs and two empty ones, taller up
		# the bands; a move carries the run of one colour on top. Insane is
		# ten colours on twelve pegs, seven high (rings_gen.gd), dealt live.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "RG_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "RG_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "RG_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "RG_LVL_3"},
		],
	},
	{
		"id": "planes",
		"skill": "planning",
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
		"card": "res://ui/menu/cards/planes.gd",
		"script": "res://puzzles/planes2d.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/planes_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): a 12 by 17, 16 by 23 or 21 by 30
		# maze (planes_state.gd's BANDS, mazes since 2026-10-02) or Insane's
		# Windy Day sky, and each is its own daily with its own done mark.
		# The planes are not counted on the sheet: 20 seeds a level laid
		# about 37, 50 and 74 of them.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "PP_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "PP_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "PP_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "PP_LVL_3"},
		],
	},
	{
		"id": "quilt",
		"skill": "space",
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
		"card": "res://ui/menu/cards/quilt.gd",
		"script": "res://puzzles/quilt2d.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/quilt_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
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
		"id": "buttons",
		"skill": "focus",
		"kind": "puzzle",
		# Jewel Box since 2026-10-19 (Button Box before; the id and the
		# BB_ keys stay, so a player's progress is kept)
		"title": "Jewel Box",
		"blurb": "BB_BLURB",
		"short": "BB_SHORT",
		"motto": "BB_MOTTO",
		"footer": "Lift · Set · Reveal",
		# The page is the whole screen (`bleed`, ui/flat/flat_host.gd): the
		# picture and the case lie on it, so there is no tray and no
		# actions row, and Undo, the bulb and Reset ride up into the top bar.
		# The board's own toast says what the tip card would.
		"script": "res://puzzles/buttons2d.gd",
		"card": "res://ui/menu/cards/buttons.gd",
		"shell": "flat",
		"bleed": true,
		# The levels stand where the day card was, with the tools row under
		# them (docs/agents/flat-screens.md, "Every board gets a world").
		"level_card": true,
		"tray": "none",
		"actions": false,
		"tip": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each band (a picture of content/pixel_garden.json's
		# band, scrambled off the day's seed) is its own daily with its own
		# done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "BB_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "BB_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "BB_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "BB_LVL_3"},
		],
	},
	{
		"id": "queens",
		"skill": "logic",
		"kind": "puzzle",
		"title": "Queens",
		"blurb": "QN_BLURB",
		"short": "QN_SHORT",
		"motto": "QN_MOTTO",
		"footer": "Seat · Cross · Reign",
		# No tray: a tap cycles a cell blank -> cross -> queen and a drag lays
		# crosses, so there is nothing to pick.
		"script": "res://puzzles/queens2d.gd",
		"card": "res://ui/menu/cards/queens.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/queens_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): a 7 by 7, 8 by 8 or 9 by 9 court, or
		# Insane's 10 by 10 in the morning mist (2026-09-30), and each is its
		# own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "QN_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "QN_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "QN_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "QN_LVL_3"},
		],
	},
	{
		"id": "nonogram",
		"skill": "logic",
		"kind": "puzzle",
		"title": "Nonogram",
		"blurb": "NG_BLURB",
		"short": "NG_SHORT",
		"motto": "NG_MOTTO",
		"footer": "Count · Lay · Reveal",
		# A stroke paints with one of two chips, so it asks for the tile tray.
		"script": "res://puzzles/nonogram2d.gd",
		"card": "res://ui/menu/cards/nonogram.gd",
		"shell": "flat",
		"tray": "tiles",
		# Its world is the whole screen (`bleed`, puzzles/nonogram_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): a 5 by 5, 7 by 7 or 9 by 9 picture,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "NG_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "NG_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "NG_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "NG_LVL_3"},
		],
	},
	{
		"id": "slider",
		"skill": "planning",
		"kind": "puzzle",
		"title": "Super Slider",
		"blurb": "SL_BLURB",
		"short": "SL_SHORT",
		"motto": "SL_MOTTO",
		"footer": "Slide · Shuffle · Out",
		# Nothing is picked up, and nothing wrong can sit in the tray: a
		# block only ever slides into empty cells. So no tray and no Check;
		# Undo, Reset and Hint ride in the top bar -- Pinwheel's shape.
		"script": "res://puzzles/slider2d.gd",
		"card": "res://ui/menu/cards/slider.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/slider_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each band of the bank (slider_gen.gd's BANDS) is
		# its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "SL_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "SL_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "SL_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "SL_LVL_3"},
		],
	},
	{
		"id": "hedgehogs",
		"skill": "logic",
		"kind": "puzzle",
		"title": "Hedgehogs",
		"blurb": "HH_BLURB",
		"short": "HH_SHORT",
		"motto": "HH_MOTTO",
		"footer": "Rake · Count · Flag",
		# Mushroom Patch's rows: the two-chip tray (Rake, Flag) and the
		# actions row (Reset, Check); Undo and Hint ride in the top bar.
		"script": "res://puzzles/hedgehogs2d.gd",
		"card": "res://ui/menu/cards/hedgehogs.gd",
		"shell": "flat",
		"tray": "lawn",
		# Its world is the whole screen (`bleed`, puzzles/hedgehogs_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
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
	{
		"id": "wordtrail",
		"skill": "words",
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
		"card": "res://ui/menu/cards/wordtrail.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/word_trail_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
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
	{
		"id": "honeycomb",
		"skill": "words",
		"kind": "puzzle",
		"title": "Honeycomb",
		"blurb": "HC_BLURB",
		"short": "HC_SHORT",
		"motto": "HC_MOTTO",
		"footer": "Tap · Spell · Pour",
		# Seven letters on a comb of wax cells, the queen bee on the middle
		# one: spell words that hold her letter and pour their honey into the
		# jar until it reaches the day's line (puzzles/honeycomb2d.gd). The
		# meadow fills the screen and the cells and keys are inside the
		# board, so no tray and no actions row: the bin and the bulb ride the
		# tools row. Every band's hives come from banks built on the Mac
		# (tools/build_honeycomb.py, content/insane/honeycomb*.json), in the
		# player's language.
		"script": "res://puzzles/honeycomb2d.gd",
		"card": "res://ui/menu/cards/honeycomb.gd",
		"shell": "flat",
		"tray": "none",
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "HC_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "HC_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "HC_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "HC_LVL_3"},
		],
	},
	{
		"id": "shelves",
		"skill": "words",
		"kind": "puzzle",
		"title": "Four Shelves",
		"blurb": "FS_BLURB",
		"short": "FS_SHORT",
		"motto": "FS_MOTTO",
		"footer": "Pick · Shelve · Sort",
		# Jam jars on a pantry dresser, a word on each, hiding shelves of four
		# that go together: pick four and Shelve them, a heart lost on a wrong
		# four (puzzles/shelves2d.gd). The day's puzzles are written at night
		# by a model and sorted blind by a second (server/functions/src/
		# shelves.ts), in the player's language; the bank deals a phone that
		# never reached them (content/shelves.json). The jars and keys are
		# inside the board, so no tray and no actions row: the bulb rides the
		# tools row.
		"script": "res://puzzles/shelves2d.gd",
		"card": "res://ui/menu/cards/shelves.gd",
		"shell": "flat",
		"tray": "none",
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "FS_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "FS_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "FS_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "FS_LVL_3"},
		],
	},
	{
		"id": "clues",
		"skill": "words",
		"kind": "puzzle",
		"title": "Five Clues",
		"blurb": "FC_BLURB",
		"short": "FC_SHORT",
		"motto": "FC_MOTTO",
		"footer": "Read · Guess · Type",
		# Clue cards pinned to a cork board on the garden shed's wall, turned
		# one at a time; type the idea they share (puzzles/clues2d.gd). The
		# rounds are written at night by a model and named blind by a second
		# (server/functions/src/clues.ts), in the player's language; the bank
		# deals a phone that never reached them (content/clues.json). It
		# types, so its tray is Hidden Word's keyboard, as Pearl Dive's is,
		# and Enter is every move: no actions row and no tip card.
		"script": "res://puzzles/clues2d.gd",
		"card": "res://ui/menu/cards/clues.gd",
		"shell": "flat",
		"tray": "keys",
		"tip": false,
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "FC_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "FC_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "FC_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "FC_LVL_3"},
		],
	},
	{
		"id": "train",
		"skill": "planning",
		"kind": "puzzle",
		"title": "Sand Sweep",
		"blurb": "TT_BLURB",
		"short": "TT_SHORT",
		"motto": "TT_MOTTO",
		"footer": "Send · Pull · Pop",
		# The playroom floor is the whole screen (`bleed`, ui/flat/flat_host.gd):
		# the rug, its loop, the tray and the toy box lie on it, so there is no
		# tray and no actions row, and the bulb and Reset ride up into the top
		# bar. The board's own toast says what the tip card would.
		"script": "res://puzzles/train2d.gd",
		"card": "res://ui/menu/cards/train.gd",
		"shell": "flat",
		"bleed": true,
		# The levels stand where the day card was, with the tools row under
		# them (docs/agents/flat-screens.md, "Every board gets a world").
		"level_card": true,
		"tray": "none",
		"actions": false,
		"tip": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each band (a picture of the bank dealt off the
		# day's seed) is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "TT_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "TT_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "TT_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "TT_LVL_3"},
		],
	},
	{
		"id": "hoop",
		"skill": "focus",
		"kind": "puzzle",
		"title": "Yarn Hoop",
		"blurb": "YH_BLURB",
		"short": "YH_SHORT",
		"motto": "YH_MOTTO",
		"footer": "Pin · Thread · Knit",
		# The sewing table is the whole screen (`bleed`, ui/flat/flat_host.gd):
		# the hoop and its linen lie on it, so there is no tray and no actions
		# row; the bulb and the bin ride in the tools row. The board's own
		# toast says what the tip card would.
		"script": "res://puzzles/hoop2d.gd",
		"card": "res://ui/menu/cards/hoop.gd",
		"shell": "flat",
		"bleed": true,
		# The levels stand where the day card was, with the tools row under
		# them (docs/agents/flat-screens.md, "Every board gets a world").
		"level_card": true,
		"tray": "none",
		"actions": false,
		"tip": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each band (a picture of the bank, or the day's
		# themed one, cut off the day's seed) is its own daily with its own
		# done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "YH_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "YH_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "YH_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "YH_LVL_3"},
		],
	},
	{
		"id": "acorn",
		"skill": "words",
		"kind": "puzzle",
		"title": "Golden Acorn",
		"blurb": "AC_BLURB",
		"short": "AC_SHORT",
		"motto": "AC_MOTTO",
		"footer": "Pick · Lock · Learn",
		# The card is the board: the four answers are tapped where they
		# stand, so no tray. The actions row stays for its third button,
		# which reads Lock and then Next -- a lock is the one move, and final.
		"script": "res://puzzles/acorn2d.gd",
		"card": "res://ui/menu/cards/acorn.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/acorn_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each band (acorn_state.gd's ASKS) is its own
		# daily with its own done mark and its own questions.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "AC_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "AC_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "AC_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "AC_LVL_3"},
		],
	},
	{
		"id": "caterpillar",
		"skill": "planning",
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
		"card": "res://ui/menu/cards/caterpillar.gd",
		"script": "res://puzzles/caterpillar2d.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/caterpillar_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
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
		"id": "hoses",
		"skill": "space",
		"kind": "puzzle",
		"title": "Hosepipes",
		"blurb": "HS_BLURB",
		"short": "HS_SHORT",
		"motto": "HS_MOTTO",
		"footer": "Drag · Join · Water",
		# A raised garden bed: drag a hose from each tap to its flower, hoses
		# never share a square, and every square is watered
		# (puzzles/hoses2d.gd). The garden fills the screen and the hoses are
		# drawn on the bed itself, so no tray and no actions row: Undo, the
		# bin and the bulb ride the tools row. No Check: a flower opens when
		# its hose reaches it and the count line says what is still dry.
		# Easy and Medium are dealt on the phone, Hard and Insane from banks
		# (content/insane/hoses_hard.json, hoses.json).
		"script": "res://puzzles/hoses2d.gd",
		"card": "res://ui/menu/cards/hoses.gd",
		"shell": "flat",
		"tray": "none",
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "HS_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "HS_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "HS_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "HS_LVL_3"},
		],
	},
	{
		"id": "paperbox",
		"skill": "space",
		"kind": "puzzle",
		"title": "Paper Box",
		"blurb": "PB_BLURB",
		"short": "PB_SHORT",
		"motto": "PB_MOTTO",
		"footer": "Look · Fold · Pick",
		# A flat paper net on a cutting mat and three or four boxes under it:
		# pick the one the net folds into, five rounds a day
		# (puzzles/paperbox2d.gd). The craft table fills the screen and the
		# boxes are the board's own controls, so no tray and no actions row.
		# Only the bulb: a pick cannot be taken back (no Undo), the board
		# says itself whether a pick was right (no Check), and the bin would
		# hand back a day already seen.
		"script": "res://puzzles/paperbox2d.gd",
		"card": "res://ui/menu/cards/paperbox.gd",
		"shell": "flat",
		"tray": "none",
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "PB_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "PB_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "PB_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "PB_LVL_3"},
		],
	},
	{
		"id": "binairo",
		"skill": "logic",
		"kind": "puzzle",
		"title": "Binairo",
		"blurb": "BN_BLURB",
		"short": "BN_SHORT",
		"motto": "BN_MOTTO",
		"footer": "Think · Balance · Complete",
		"script": "res://puzzles/binairo2d.gd",
		# Its card on the first screen is its own (ui/menu/cards/card_face.gd).
		"card": "res://ui/menu/cards/binairo.gd",
		"shell": "flat",
		# The day and the night are the whole screen (`bleed`,
		# ui/flat/flat_host.gd). A tap turns a tile from sun to moon to bare,
		# so there is no tray, and no Check, so no actions row: Reset rides in
		# the top bar and the levels lie under the board (`level_card`).
		"bleed": true,
		"tray": "none",
		"actions": false,
		"level_card": true,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): easy and medium are 6x6, hard is 8x8,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "6 × 6"},
			{"difficulty": 1, "name": "Medium", "line": "6 × 6"},
			{"difficulty": 2, "name": "Hard", "line": "8 × 8"},
			{"difficulty": 3, "name": "Insane", "line": "10 × 10"},
		],
	},
	{
		"id": "minigolf",
		"skill": "space",
		"kind": "puzzle",
		"title": "Mini Golf",
		"blurb": "GF_BLURB",
		"short": "GF_SHORT",
		"motto": "GF_MOTTO",
		"footer": "Aim · Putt · Sink",
		# The green is the board: a putt is a drag on the card itself, so no
		# tray and no actions row, and no Undo -- a stroke played is on the
		# card. Hint and Reset ride in the top bar -- Marigold's shape.
		"script": "res://puzzles/minigolf2d.gd",
		"card": "res://ui/menu/cards/minigolf.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/minigolf_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each course (minigolf_gen.gd's BANDS, holes mined
		# into content/minigolf.json) is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "GF_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "GF_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "GF_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "GF_LVL_3"},
		],
	},
	{
		"id": "fairylights",
		"skill": "space",
		"kind": "puzzle",
		"title": "Fairy Lights",
		"blurb": "FL_BLURB",
		"short": "FL_SHORT",
		"motto": "FL_MOTTO",
		"footer": "Turn · Join · Light",
		# It picks nothing up and there is no Check: a board is unfinished
		# or it is done. So Reset rides up into the top bar and the bottom
		# slot is the tip card alone.
		"card": "res://ui/menu/cards/fairylights.gd",
		"script": "res://puzzles/fairy_lights2d.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/fairy_lights_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
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
		"id": "untangle",
		"skill": "space",
		"kind": "puzzle",
		"title": "Untangle",
		"blurb": "UT_BLURB",
		"short": "UT_SHORT",
		"motto": "UT_MOTTO",
		"footer": "Lift · Drop · Untangle",
		# It asks for no tray, and it has **no actions row**: capabilities()
		# here is undo and hint, so there is no Check to put in one and Reset
		# rides in the top bar instead.
		"script": "res://puzzles/untangle2d.gd",
		"card": "res://ui/menu/cards/untangle.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		# The linen is the whole screen (`bleed`, puzzles/untangle_world.gd)
		# and the levels stand where the day card was.
		"bleed": true,
		"level_card": true,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): four, six, eight or nine ropes on a ring
		# of pegs (untangle_gen.gd's BANDS; Hard and Insane run on thread and
		# Insane has a kitten), and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "UT_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "UT_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "UT_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "UT_LVL_3"},
		],
	},
	{
		"id": "bridges",
		"skill": "logic",
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
		"card": "res://ui/menu/cards/bridges.gd",
		"script": "res://puzzles/bridges2d.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/bridges_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
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
		"id": "pixelgarden",
		"skill": "focus",
		"kind": "puzzle",
		"title": "Pixel Garden",
		"blurb": "PG_BLURB",
		"short": "PG_SHORT",
		"motto": "PG_MOTTO",
		"footer": "Pick · Seat · Iron",
		# The kit's chips stand in the board card beside the picture (Quilt's
		# shape: the pieces live in the card), so no tray; the actions row
		# carries Reset and Check, and Undo and Hint ride in the top bar.
		"script": "res://puzzles/pixel_garden2d.gd",
		"card": "res://ui/menu/cards/pixelgarden.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/pixel_garden_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each band of pictures (content/pixel_garden.json)
		# is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "PG_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "PG_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "PG_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "PG_LVL_3"},
		],
	},
	{
		"id": "glimpse",
		"skill": "memory",
		"kind": "puzzle",
		"title": "Glimpse",
		"blurb": "GL_BLURB",
		"short": "GL_SHORT",
		"motto": "GL_MOTTO",
		"footer": "Look · Remember · Seat",
		# Pixel Garden from memory (puzzles/glimpse2d.gd extends its board):
		# the day's little picture is held up for a few seconds, then
		# covered. Its shape is Pixel Garden's: the box in the card, no tray,
		# and only Undo (no hint, no Check, which would read the picture out).
		"script": "res://puzzles/glimpse2d.gd",
		"card": "res://ui/menu/cards/glimpse.gd",
		"shell": "flat",
		"tray": "none",
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each band (glimpse_state.gd's BANDS) is its own
		# daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "GL_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "GL_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "GL_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "GL_LVL_3"},
		],
	},
	{
		"id": "birdsong",
		"skill": "memory",
		"kind": "puzzle",
		"title": "Birdsong",
		"blurb": "BS_BLURB",
		"short": "BS_SHORT",
		"motto": "BS_MOTTO",
		"footer": "Listen · Remember · Knock",
		# A woodpecker knocks a rhythm on the old tree, one knock longer each
		# round; knock it back on one drum (puzzles/birdsong2d.gd; the
		# songbird and its four drums went on 2026-10-22's evening). The
		# garden fills the screen; the drum is its control, so no tray and no
		# actions row. Only the bulb: a knock heard cannot be undone, and
		# nothing is ever wrong on the board for a Check to find.
		"script": "res://puzzles/birdsong2d.gd",
		"card": "res://ui/menu/cards/birdsong.gd",
		"shell": "flat",
		"tray": "none",
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "BS_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "BS_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "BS_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "BS_LVL_3"},
		],
	},
	{
		"id": "patio",
		"skill": "logic",
		"kind": "puzzle",
		"title": "Domino Patio",
		"blurb": "DP_BLURB",
		"short": "DP_SHORT",
		"motto": "DP_MOTTO",
		"footer": "Lay · Turn · Keep",
		# Lay the house's dominoes on a patio of flower beds so every bed
		# keeps the rule on its tag (puzzles/patio2d.gd). The terrace fills
		# the screen and the rack is inside the board, so no tray and no
		# actions row: Undo, the bin and the bulb ride the tools row. No
		# Check: the tags say how each bed stands.
		"script": "res://puzzles/patio2d.gd",
		"card": "res://ui/menu/cards/patio.gd",
		"shell": "flat",
		"tray": "none",
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "DP_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "DP_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "DP_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "DP_LVL_3"},
		],
	},
	{
		"id": "teacups",
		"skill": "memory",
		"kind": "puzzle",
		"title": "Teacups",
		"blurb": "TC_BLURB",
		"short": "TC_SHORT",
		"motto": "TC_MOTTO",
		"footer": "Lift · Remember · Pair",
		# Cups upside down on a garden tea table, a friend under each and
		# every friend under two; lift two a turn to find the pairs
		# (puzzles/teacups2d.gd). The table fills the screen and the cups are
		# its controls, so no tray and no actions row. Only the bulb: a cup
		# seen cannot be unseen (no Undo), nothing is ever wrong for a Check,
		# and the bin would hand back a table already remembered.
		"script": "res://puzzles/teacups2d.gd",
		"card": "res://ui/menu/cards/teacups.gd",
		"shell": "flat",
		"tray": "none",
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "TC_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "TC_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "TC_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "TC_LVL_3"},
		],
	},
	{
		"id": "lattice",
		"skill": "logic",
		"kind": "puzzle",
		"title": "Lattice",
		"blurb": "LA_BLURB",
		"short": "LA_SHORT",
		"motto": "LA_MOTTO",
		"footer": "Swap · Sum · Settle",
		# The tiles are all on the lattice, so there is no tray, and a tile
		# says for itself whether it is home, so there is no Check: Undo, the
		# bulb and Reset ride up into the top bar.
		"script": "res://puzzles/lattice2d.gd",
		"card": "res://ui/menu/cards/lattice.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/lattice_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each band (lattice_gen.gd's BANDS, deals mined
		# into content/lattice.json) is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "LA_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "LA_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "LA_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "LA_LVL_3"},
		],
	},
	{
		"id": "gumdrop",
		"skill": "focus",
		"kind": "puzzle",
		"title": "Gumdrop",
		"blurb": "GD_BLURB",
		"short": "GD_SHORT",
		"motto": "GD_MOTTO",
		"footer": "Squeeze · Soak · Serve",
		# The kitchen table is the whole screen (`bleed`, ui/flat/flat_host.gd):
		# the pots and the Squeeze and Serve buttons lie on it, so there is no
		# tray and no actions row, and Reset rides up into the top bar. It was
		# an Arcade game for a day (2026-10-10 to 10-11).
		"script": "res://puzzles/gumdrop2d.gd",
		"card": "res://ui/menu/cards/gumdrop.gd",
		"shell": "flat",
		"bleed": true,
		# The levels stand where the day card was, with the tools row under
		# them (docs/agents/flat-screens.md, "Every board gets a world").
		"level_card": true,
		"tray": "none",
		"actions": false,
		"tip": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each band (gumdrop_mould.gd's BANDS, a few moulds
		# off the day's seed) is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "GD_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "GD_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "GD_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "GD_LVL_3"},
		],
	},
	{
		"id": "lightup",
		"skill": "logic",
		"kind": "puzzle",
		"title": "Light Up",
		"blurb": "LU_BLURB",
		"short": "LU_SHORT",
		"motto": "LU_MOTTO",
		"footer": "Place · Light · Reveal",
		"script": "res://puzzles/lightup2d.gd",
		"card": "res://ui/menu/cards/lightup.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/lightup_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku (2026-09-23): a 5 by 5, 6 by 6 or 7 by 7 court,
		# and each is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "5 × 5"},
			{"difficulty": 1, "name": "Medium", "line": "6 × 6"},
			{"difficulty": 2, "name": "Hard", "line": "7 × 7"},
			{"difficulty": 3, "name": "Insane", "line": "LU_LVL_3"},
		],
	},
	{
		"id": "shikaku",
		"skill": "logic",
		"kind": "puzzle",
		"title": "Shikaku",
		"blurb": "SK_BLURB",
		"short": "SK_SHORT",
		"motto": "SK_MOTTO",
		"footer": "Divide · Count · Enclose",
		# It picks nothing up, so it asks for no tray; it does have a Check,
		# so unlike Balance it keeps the actions row.
		"script": "res://puzzles/shikaku2d.gd",
		"card": "res://ui/menu/cards/shikaku.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/shikaku_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
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
		"id": "how_big",
		"skill": "words",
		"kind": "puzzle",
		"title": "How Big?",
		"blurb": "HB_BLURB",
		"short": "HB_SHORT",
		"motto": "HB_MOTTO",
		"footer": "Size · Lock · Reveal",
		# The stage is the board: the finger sizes the answer where it stands,
		# so no tray. The actions row stays for its third button, which here
		# reads Lock and then Next -- a lock is the one move, and it is final.
		"script": "res://puzzles/how_big2d.gd",
		"card": "res://ui/menu/cards/how_big.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/how_big_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each band (how_big_state.gd's ROUNDS and SPREAD)
		# is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "HB_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "HB_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "HB_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "HB_LVL_3"},
		],
	},
	{
		"id": "horse",
		"skill": "space",
		"kind": "puzzle",
		"title": "Horse Pen",
		"blurb": "HP_BLURB",
		"short": "HP_SHORT",
		"motto": "HP_MOTTO",
		"footer": "Bale · Enclose · Keep",
		# The meadow is the board: a bale is a tap on the grass itself, so no
		# tray. The actions row stays for its third button, which here reads
		# Submit -- the day ends on that press, not on the pen closing, so a
		# closed pen can still be rebuilt for a bigger one.
		"script": "res://puzzles/horse2d.gd",
		"card": "res://ui/menu/cards/horse.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/horse_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each field (horse_gen.gd's BANDS, meadows mined
		# into content/horse.json) is its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "HP_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "HP_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "HP_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "HP_LVL_3"},
		],
	},
	{
		"id": "pearl",
		"skill": "words",
		"kind": "puzzle",
		"title": "Pearl Dive",
		"blurb": "PD_BLURB",
		"short": "PD_SHORT",
		"motto": "PD_MOTTO",
		"footer": "Type · Dive · Find",
		# It types, so its tray is Hidden Word's keyboard, and Enter is every
		# move there is (dive, offer the answer, the next prompt): no actions
		# row, and no tip card.
		"script": "res://puzzles/pearl2d.gd",
		"card": "res://ui/menu/cards/pearl.gd",
		"shell": "flat",
		"tray": "keys",
		"tip": false,
		# Its world is the whole screen (`bleed`, puzzles/pearl_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each band (pearl_state.gd's ASKS) is its own
		# daily with its own done mark and its own prompts.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "PD_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "PD_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "PD_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "PD_LVL_3"},
		],
	},
	{
		"id": "knight",
		"skill": "planning",
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
		"card": "res://ui/menu/cards/knight.gd",
		"script": "res://puzzles/knight2d.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/knight_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
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
		"id": "pinwheel",
		"skill": "space",
		"kind": "puzzle",
		"title": "Pinwheel",
		"blurb": "PW_BLURB",
		"short": "PW_SHORT",
		"motto": "PW_MOTTO",
		"footer": "Turn · Fit · Complete",
		# Nothing is picked up and nothing is hidden, so there is no tray and no
		# Check; Reset rides up into the top bar and the tip card stands alone.
		"card": "res://ui/menu/cards/pinwheel.gd",
		"script": "res://puzzles/pinwheel2d.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/pinwheel_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
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
		"id": "sunbeam",
		"skill": "space",
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
		"card": "res://ui/menu/cards/sunbeam.gd",
		"script": "res://puzzles/sunbeam2d.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/sunbeam_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
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
		"id": "trestle",
		"skill": "planning",
		"kind": "puzzle",
		"title": "Trestle",
		"blurb": "TR_BLURB",
		"short": "TR_SHORT",
		"motto": "TR_MOTTO",
		"footer": "Build · Test · Cross",
		# The material chips and the budget stand in the board card over the
		# river, so no tray; the actions row carries Reset and Go (the Check
		# button, relabelled: the test is the check), and Undo and Hint ride
		# in the top bar -- Pixel Garden's shape.
		"script": "res://puzzles/trestle2d.gd",
		"card": "res://ui/menu/cards/trestle.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/trestle_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each band of mined gaps (content/trestle.json) is
		# its own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "TR_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "TR_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "TR_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "TR_LVL_3"},
		],
	},
	{
		"id": "drumbeat",
		"skill": "focus",
		"kind": "puzzle",
		"title": "Drumbeat",
		"blurb": "DB_BLURB",
		"short": "DB_SHORT",
		"motto": "DB_MOTTO",
		"footer": "Listen · Strike · Clear",
		# The drum is the board: strokes land on the card itself, so no tray
		# and no actions row, and nothing to take back or check -- the song
		# judges every note as it passes. Reset rides in the top bar.
		"script": "res://puzzles/drumbeat2d.gd",
		"card": "res://ui/menu/cards/drumbeat.gd",
		"shell": "flat",
		"tray": "none",
		# Its world is the whole screen (`bleed`, puzzles/drumbeat_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Marigold: each level is its own daily with its own done
		# mark, and the day's song is dealt from the seed.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "DB_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "DB_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "DB_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "DB_LVL_3"},
		],
	},
]

## Boards that stand on the Arcade tab and not in the grid: the same flat
## board, opened by the same host with its levels, a day at a time, and
## closed back to Arcade (`deck`). **Marigold moved here on 2026-10-13** (the
## user: "move marigold to arcade"): a seed shot at pegs is an arcade game
## in the hand, whatever its daily gardens are. It keeps its four levels,
## its done marks and its place in the day's hearts; it left the Stats grid,
## which lists `PUZZLES`. ui/menu/arcade_tab.gd names it in its list and
## hands the grid this entry.
const ARCADE := [
	{
		"id": "marigold",
		"kind": "puzzle",
		"title": "Marigold",
		"blurb": "MG_BLURB",
		"short": "MG_SHORT",
		"motto": "MG_MOTTO",
		"footer": "Aim · Bounce · Bloom",
		# Nothing is picked up and nothing can be taken back once a seed has
		# flown: no tray, no actions row and no Undo. Hint and Reset ride in
		# the top bar -- Pinwheel's shape.
		"script": "res://puzzles/marigold2d.gd",
		"card": "res://ui/menu/cards/marigold.gd",
		"shell": "flat",
		"tray": "none",
		# It stands on the Arcade tab, and this is its place in that list
		# (ui/menu/arcade_tab.gd's GAMES): the card's colour comes off it
		# there, and the board's accent off it here. The two are kept equal
		# by hand: moving it in GAMES means changing this.
		"deck": "arcade",
		"slot": 8,
		# Its world is the whole screen (`bleed`, puzzles/marigold_world.gd) and the
		# levels stand where the day card was (docs/agents/flat-screens.md).
		"bleed": true,
		"level_card": true,
		"actions": false,
		"difficulties": [0, 1, 2, 3],
		# Asks like Sudoku: each garden (marigold_state.gd's BANDS) is its
		# own daily with its own done mark.
		"pick_difficulty": true,
		"levels": [
			{"difficulty": 0, "name": "Easy", "line": "MG_LVL_0"},
			{"difficulty": 1, "name": "Medium", "line": "MG_LVL_1"},
			{"difficulty": 2, "name": "Hard", "line": "MG_LVL_2"},
			{"difficulty": 3, "name": "Insane", "line": "MG_LVL_3"},
		],
	},
]

## Every entry the game knows: the grid's and the Arcade tab's boards.
static func all() -> Array:
	return PUZZLES + ARCADE

## The Arcade tab's board called `id`, or {} when `id` is one of that tab's
## own games (or nothing).
static func arcade(id: String) -> Dictionary:
	for p in ARCADE:
		if p.id == id:
			return p
	return {}

## The list an entry's card stands in, and the tab its board closes back to:
## "home" (the Puzzles grid) or "arcade".
static func deck(entry: Dictionary) -> String:
	return str(entry.get("deck", "home"))

## Where an entry's colour comes from (`Pal.CAT[slot % size]`): its index in
## the grid, or the `slot` an Arcade board names. -1 if it has none.
static func slot(entry: Dictionary) -> int:
	if entry.has("slot"):
		return int(entry.slot)
	var id := String(entry.get("id", ""))
	for i in PUZZLES.size():
		if String(PUZZLES[i].get("id", "")) == id:
			return i
	return -1

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
