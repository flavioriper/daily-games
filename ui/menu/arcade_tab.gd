extends VBoxContainer

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
## stacks of felt mats sorted on a tray. (Gumdrop was the eleventh for a day and
## became a daily board on 2026-10-11, puzzles/gumdrop2d.gd.) Its body takes the day row's and the grid's room, as Versus, Stats
## and Streak do. (Hedgerow TD, Henhouse and Millstream left for a side
## project on 2026-09-27, ~/dev/garden-games.)
##
## One card a game, on the Puzzles tab's shell (ui/menu/puzzle_card_2d.gd)
## with a face of its own (ui/menu/cards/arc_<game>.gd): the whole card is
## the tap, the go button is part of its picture, and under the name it
## says the best score and how far the player got. Two a row, eight a page,
## and the pages turn with the pager every list of the first screen wears
## (ui/menu/pager_pill.gd), under the cards.

signal play(game: String)
## The strip's Shop button, or its gold pill: the shop sheet, on `game`.
signal shop(game: String)

const Pal = preload("res://core/palette.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Record = preload("res://arcade/arcade_record.gd")
const NightArt = preload("res://arcade/nightlight_art.gd")
const NightSim = preload("res://arcade/nightlight_sim.gd")
const FurrowSim = preload("res://arcade/furrow_sim.gd")
const GriddleSim = preload("res://arcade/griddle_sim.gd")
const GoldPill = preload("res://ui/menu/gold_pill.gd")
const PuzzleCard = preload("res://ui/menu/puzzle_card_2d.gd")
const PagerPill = preload("res://ui/menu/pager_pill.gd")

const GAP := 20
const COLS := 2
## How much taller than the first screen's a card may grow here.
const GROW := 150.0
const GAMES := ["firefly", "molehill", "stackwood", "thirteen", "posy", "peapod", "nightlight", "beeline", "deckchair", "eddy", "furrow", "griddle", "trivet"]
const NAMES := {"firefly": "Firefly", "molehill": "Molehill", "stackwood": "Stackwood", "thirteen": "Lucky Thirteen", "posy": "Posy", "peapod": "Peapod", "nightlight": "Nightlight", "beeline": "Beeline", "deckchair": "Deckchair", "eddy": "Eddy", "furrow": "Furrow", "griddle": "Griddle", "trivet": "Trivet"}
## How far a game went, in its own words: a stage, a wave, or a streak.
const FURTHEST := {"firefly": "ARC_BEST_STAGE", "molehill": "ARC_BEST_STREAK", "stackwood": "ARC_BEST_BLOCK", "thirteen": "ARC_BEST_NUMBER", "posy": "ARC_BEST_DAY", "peapod": "ARC_BEST_WAVE", "deckchair": "ARC_BEST_HOME", "eddy": "ARC_BEST_LEVEL", "trivet": "ARC_BEST_TRIVET"}

var _cards: Array[Control] = []
## What each card last said under its name, by game.
var _lines := {}
## The gold and the shop, above the cards (spec 2026-09-28-gold-gifts).
var _strip: HBoxContainer
var gold_pill: Button
var _grid: GridContainer
## The cards stand a page at a time since the thirteenth (2026-10-12): the
## menu's cards are paged, never scrolled.
const PER_PAGE := 8
var _page := 0
var _pager: PagerPill
var _pager_row: CenterContainer

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip = HBoxContainer.new()
	_strip.name = "GoldStrip"
	_strip.add_theme_constant_override("separation", GAP)
	gold_pill = GoldPill.new()
	gold_pill.pressed.connect(func() -> void: shop.emit(""))
	_strip.add_child(gold_pill)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(spacer)
	var shop_b := IconButton.new("coin", "SHOP_TITLE", "IconButton")
	shop_b.name = "Shop"
	shop_b.custom_minimum_size.y = GoldPill.H
	shop_b.pressed.connect(func() -> void: shop.emit(""))
	_strip.add_child(shop_b)
	add_child(_strip)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)
	# What a short last page leaves is above the pager, which keeps its place.
	var rest := Control.new()
	rest.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rest)
	_pager_row = CenterContainer.new()
	_pager_row.name = "Pager"
	_pager_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pager = PagerPill.new()
	_pager.turned.connect(turn)
	_pager_row.add_child(_pager)
	add_child(_pager_row)
	for i in GAMES.size():
		_cards.append(_game_card(GAMES[i], Pal.CAT[i % Pal.CAT.size()]))
	_lay_page()

func pages() -> int:
	return maxi(1, ceili(_cards.size() / float(PER_PAGE)))

## The cards of the page shown.
func _shown() -> Array[Control]:
	var out: Array[Control] = []
	for i in range(_page * PER_PAGE, mini((_page + 1) * PER_PAGE, _cards.size())):
		out.append(_cards[i])
	return out

## The next page of cards, or the one before.
func turn(by: int) -> void:
	var to := clampi(_page + by, 0, pages() - 1)
	if to == _page:
		return
	_page = to
	_lay_page()
	_fit.call_deferred()

## Stands the page's cards in the grid and the pager at its page.
func _lay_page() -> void:
	for c in _cards:
		if c.get_parent() != null:
			c.get_parent().remove_child(c)
	for c in _shown():
		_grid.add_child(c)
	_pager_row.visible = pages() > 1
	_pager.show_page(_page, pages())

func _game_card(game: String, colour: Color) -> Control:
	var card := PuzzleCard.new({"id": game, "title": NAMES[game], "short": "ARC_NO_BEST",
		"card": "res://ui/menu/cards/arc_%s.gd" % game}, colour)
	card.name = "Card_" + game
	card.open.connect(func() -> void: play.emit(game))
	return card

## What `game`'s card says under its name.
func said(game: String) -> String:
	return String(_lines.get(game, ""))

func _say(game: String, best: String, further := "", leaf := false) -> void:
	var text := best if further.is_empty() else best + "\n" + further
	_lines[game] = text
	(_cards[GAMES.find(game)] as PuzzleCard).say(text, leaf)

func refresh() -> void:
	for game: String in GAMES:
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
		var best := Record.best(game)
		var st := Record.best_stage(game)
		_say(game, tr("ARC_BEST") % Record.grouped(best) if best > 0 else tr("ARC_NO_BEST"),
			tr(FURTHEST[game]) % st if st > 0 and FURTHEST.has(game) else "",
			best > 0 and Record.best_boosted(game))
	_fit.call_deferred()

func _ready() -> void:
	Ads.banner_changed.connect(func(_v: bool, _h: float) -> void: _fit.call_deferred())
	var outer := _outer()
	if outer != null:
		outer.resized.connect(_fit)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_fit.call_deferred()
	elif what == NOTIFICATION_PREDELETE:
		# the cards of the pages not shown hang on nothing
		for c in _cards:
			if is_instance_valid(c) and c.get_parent() == null:
				c.free()

func _outer() -> Control:
	var parent := get_parent()
	if parent != null and parent.get_parent() is MarginContainer:
		return parent.get_parent().get_parent() as Control
	return null

## The Versus tab's fit: a full page's four rows share the room the strip
## and the pager leave, never under the first screen's card and never more
## than GROW over it.
func _fit() -> void:
	var parent := get_parent() as Control
	if parent == null or not is_visible_in_tree():
		return
	var sep := parent.get_theme_constant("separation") if parent is BoxContainer else 0
	var other := 0.0
	var shown := 0
	for c in parent.get_children():
		if c is Control and c != self and (c as Control).visible and not (c as Control).top_level:
			other += (c as Control).get_combined_minimum_size().y
			shown += 1
	var height := parent.size.y
	var outer := _outer()
	if outer != null:
		var margins := parent.get_parent() as MarginContainer
		height = outer.size.y - margins.get_theme_constant("margin_top") - margins.get_theme_constant("margin_bottom")
	var room := height - other - sep * shown - _strip.get_combined_minimum_size().y - GAP
	if pages() > 1:
		room -= PagerPill.H + GAP * 2
	var rows := ceili(float(mini(PER_PAGE, _cards.size())) / COLS)
	var row_h := clampf(floorf((room - GAP * (rows - 1)) / rows), PuzzleCard.CARD_H, PuzzleCard.CARD_H + GROW)
	for card in _cards:
		(card as PuzzleCard).fit_height(row_h)
