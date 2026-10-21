extends HBoxContainer

## The Arcade tab: games played alone for a score rather than against the
## day's board or against someone: Firefly (arcade/firefly_screen.gd), a
## formation shooter, Molehill (arcade/molehill_screen.gd), whack-a-mole,
## Stackwood (arcade/stackwood_screen.gd), falling blocks that merge, Lucky
## Thirteen (arcade/thirteen_screen.gd), chains of pebbles merged up to 13,
## Posy (arcade/posy_screen.gd), a swap-three garden played a day at a
## time, and Peapod (arcade/peapod_screen.gd), a pea cannon against crates
## that come down with a number on each, and Beeline
## (arcade/beeline_screen.gd), a bee flown by taps through the gaps in a
## garden's hedges, and Deckchair (arcade/deckchair_screen.gd), the
## seven-column card game for one, and Eddy (arcade/eddy_screen.gd), a
## whirlpool steered about a pond, and Trivet (arcade/trivet_screen.gd),
## stacks of felt mats sorted on a tray, and Tally (arcade/tally_screen.gd),
## a number factory on squared paper, and Bagatelle
## (arcade/bagatelle_screen.gd), marbles dropped through brass pins into
## cups, and Factory (factory/screen.gd), the
## land of belts, which had a tab of its own until the bottom bar left on
## 2026-10-13, and Marigold (puzzles/marigold2d.gd), a seed shot down through
## a pond garden of buds, which is a daily board with levels and was a card
## of the Puzzles grid until the same day: its entry is the registry's own
## (ui/registry.gd's `ARCADE`), its card is the board's, and it opens in the
## flat host. (Gumdrop was the eleventh for a day and
## became a daily board on 2026-10-11, puzzles/gumdrop2d.gd.) Its body takes the day row's and the grid's room, as Versus, Stats
## and Streak do. (Hedgerow TD, Henhouse and Millstream left for a side
## project on 2026-09-27, ~/dev/garden-games.)
##
## One card a game, and **the cards stand in the Puzzles tab's own grid**
## (ui/menu.gd: one grid, one swipe, one slide, one pager for Puzzles,
## Versus and Arcade). This is the row over that grid, where the day row
## stands on Puzzles -- the gold and the shop -- and the list the grid is
## fed: each game's entry, with a face of its own
## (ui/menu/cards/arc_<game>.gd), and the line its card says under the name
## (the best score and how far the player got).

signal play(game: String)
## The strip's Shop button, or its gold pill: the shop sheet, on `game`.
signal shop(game: String)

const IconButton = preload("res://ui/hud/icon_button.gd")
const Record = preload("res://arcade/arcade_record.gd")
const NightArt = preload("res://arcade/nightlight_art.gd")
const NightSim = preload("res://arcade/nightlight_sim.gd")
const FurrowSim = preload("res://arcade/furrow_sim.gd")
const GriddleSim = preload("res://arcade/griddle_sim.gd")
const TallySim = preload("res://arcade/tally_sim.gd")
const BagatelleSim = preload("res://arcade/bagatelle_sim.gd")
const FactoryArt = preload("res://factory/art.gd")
const GoldPill = preload("res://ui/menu/gold_pill.gd")
const Registry = preload("res://ui/registry.gd")

const GAP := 20
## Best first by how big each game's genre is on the stores (2026-10-20,
## docs/agents/arcade.md); Marigold's `slot` in ui/registry.gd is its index here.
const GAMES := ["deckchair", "posy", "trivet", "stackwood", "thirteen", "beeline", "eddy", "peapod", "marigold", "firefly", "molehill", "furrow", "tally", "factory", "bagatelle", "griddle", "nightlight"]
const NAMES := {"firefly": "Firefly", "molehill": "Molehill", "stackwood": "Stackwood", "thirteen": "Lucky Thirteen", "posy": "Posy", "peapod": "Peapod", "nightlight": "Nightlight", "beeline": "Beeline", "deckchair": "Deckchair", "eddy": "Eddy", "furrow": "Furrow", "griddle": "Griddle", "trivet": "Trivet", "tally": "Tally", "bagatelle": "Bagatelle", "factory": "Factory", "marigold": "Marigold"}
## How far a game went, in its own words: a stage, a wave, or a streak.
const FURTHEST := {"molehill": "ARC_BEST_STREAK", "stackwood": "ARC_BEST_BLOCK", "thirteen": "ARC_BEST_NUMBER", "posy": "ARC_BEST_DAY", "peapod": "ARC_BEST_WAVE", "deckchair": "ARC_BEST_HOME", "eddy": "ARC_BEST_LEVEL", "trivet": "ARC_BEST_TRIVET"}
## Firefly's clears in all: fifteen stages at four difficulties.
const FIREFLY_CLEARS := 60

## What each card says under its name, by game, and which bests were made
## with boosters (the leaf after the score).
var _lines := {}
var _boosted := {}
var gold_pill: Button
## The Factory's hidden tab (ui/menu/factory_tab.gd), which owns the one
## land: its card's line is the coins held there. Set by the menu.
var factory: Control

func _init() -> void:
	name = "GoldStrip"
	add_theme_constant_override("separation", GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_pill = GoldPill.new()
	gold_pill.pressed.connect(func() -> void: shop.emit(""))
	add_child(gold_pill)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spacer)
	var shop_b := IconButton.new("coin", "SHOP_TITLE", "IconButton")
	shop_b.name = "Shop"
	shop_b.custom_minimum_size.y = GoldPill.H
	shop_b.pressed.connect(func() -> void: shop.emit(""))
	add_child(shop_b)
	refresh()

## The list the grid shows: one entry a game, in GAMES' order.
static func entries() -> Array:
	var out: Array = []
	for game: String in GAMES:
		# A board of the registry's (Marigold) is listed by its own entry:
		# its card, its blurb and its levels are the board's.
		var board: Dictionary = Registry.arcade(game)
		if not board.is_empty():
			out.append(board)
			continue
		out.append({"id": game, "title": NAMES[game], "short": "FACTORY_CARD_BLURB" if game == "factory" else "ARC_NO_BEST",
			"card": "res://ui/menu/cards/arc_%s.gd" % game})
	return out

## What `game`'s card says under its name, and whether its best was boosted.
func line(game: String) -> String:
	return String(_lines.get(game, ""))

func boosted(game: String) -> bool:
	return bool(_boosted.get(game, false))

func _say(game: String, best: String, further := "", leaf := false) -> void:
	_lines[game] = best if further.is_empty() else best + "\n" + further
	_boosted[game] = leaf

## Reads every game's line again; the grid builds its cards from them.
func refresh() -> void:
	for game: String in GAMES:
		# A board keeps no best: its card says its blurb and shows the
		# day's levels, as in the Puzzles grid.
		if not Registry.arcade(game).is_empty():
			continue
		# Factory is a floor looked in on (a tab of its own until 2026-10-13):
		# its line is the coins held and the pace, or the blurb before the
		# floor exists.
		if game == "factory":
			var held: RefCounted = factory.sim if factory != null else null
			var coins: String = "" if held == null else (tr("FACTORY_CARD_COINS_ONE") if held.coins == 1 else tr("FACTORY_CARD_COINS_N") % FactoryArt.short(held.coins))
			_say(game, "" if held == null else coins + " · " + FactoryArt.pace_text(held))
			continue
		# Nightlight is kept, not scored: its line is the star as it stands
		if game == "nightlight":
			var star: Dictionary = NightSim.kept()
			var novas := int(star.novas)
			var line: String = tr("NL_CARD_MASS") % NightArt.short(star.mass / NightSim.START, Locale.current() != "en") if star.mass > 0.0 else tr("NL_CARD_NEW")
			var worlds := int(star.worlds)
			if worlds > 0:
				line += " · " + (tr("NL_CARD_WORLDS_ONE") if worlds == 1 else tr("NL_CARD_WORLDS_N") % worlds)
			var relics := int(star.relics)
			if relics > 0:
				line += " · " + (tr("NL_CARD_RELICS_ONE") if relics == 1 else tr("NL_CARD_RELICS_N") % relics)
			_say(game, line, "" if novas == 0 else (tr("NL_CARD_NOVAS_ONE") if novas == 1 else tr("NL_CARD_NOVAS_N") % novas))
			continue
		# Furrow is kept too: its line is the field as it stands
		if game == "furrow":
			var land: Dictionary = FurrowSim.kept()
			var open := int(land.plots)
			_say(game, tr("FW_CARD_NEW") if open == 0 else tr("FW_CARD_SEEDS") % Record.grouped(int(land.seeds)),
				"" if open == 0 else tr("FW_CARD_PLOTS") % open)
			continue
		# and Griddle: its line is the stand as it stands
		if game == "griddle":
			var stand: Dictionary = GriddleSim.kept()
			var sold := int(stand.served)
			var stars := int(stand.stars)
			_say(game, tr("GR_CARD_NEW") if sold == 0 else tr("GR_CARD_SOLD") % Record.grouped(sold),
				"" if stars == 0 else (tr("GR_CARD_STAR_ONE") if stars == 1 else tr("GR_CARD_STAR_N") % stars))
			continue
		# and Tally: its line is the paper as it stands
		if game == "tally":
			var paper: Dictionary = TallySim.kept()
			var lvl := int(paper.level)
			_say(game, tr("TL_CARD_NEW") if lvl == 0 else tr("TL_CARD_LEVEL") % lvl,
				"" if int(paper.made) == 0 else tr("TL_CARD_MADE") % Record.grouped(int(paper.made)))
			continue
		# and Bagatelle: its line is the SP it has earned and its best marble
		if game == "bagatelle":
			var board: Dictionary = BagatelleSim.kept()
			var sp := int(board.sp)
			_say(game, tr("BG_CARD_NEW") if bool(board.new) else tr("BG_CARD_SP") % BagatelleSim.short(float(sp)),
				"" if bool(board.new) else tr("BG_CARD_TIER") % tr("BG_TIER_" + String(BagatelleSim.TIER_IDS[int(board.tier)]).to_upper()))
			continue
		# Firefly is played a stage at a time: its line is the furthest
		# stage cleared and how many of the stages' clears are done
		if game == "firefly":
			var done := Record.clears(game)
			_say(game, tr("ARC_NO_BEST") if done == 0 else (tr("ARC_STAGES_ONE") % [Record.reached(game) - 1, FIREFLY_CLEARS] if done == 1
				else tr("ARC_STAGES_N") % [Record.reached(game) - 1, done, FIREFLY_CLEARS]))
			continue
		var best := Record.best(game)
		var st := Record.best_stage(game)
		_say(game, tr("ARC_BEST") % Record.grouped(best) if best > 0 else tr("ARC_NO_BEST"),
			tr(FURTHEST[game]) % st if st > 0 and FURTHEST.has(game) else "",
			best > 0 and Record.best_boosted(game))
