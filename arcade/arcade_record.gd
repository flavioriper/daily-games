extends RefCounted

## The Arcade tab's scores, per game, kept on the device
## (user://arcade.cfg): the best score and the stage it reached, the best
## stage on its own, and how many games were played. Nothing here is sent
## anywhere.


const PATH := "user://arcade.cfg"

static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg

static func best(game: String) -> int:
	return int(_load().get_value(game, "best", 0))

static func best_stage(game: String) -> int:
	return int(_load().get_value(game, "best_stage", 0))

static func plays(game: String) -> int:
	return int(_load().get_value(game, "plays", 0))

## Whether the best was made with a booster or a Second chance
## (arcade/boosters.gd): the Arcade card marks it with a leaf.
static func best_boosted(game: String) -> bool:
	return bool(_load().get_value(game, "best_boosted", false))

## Records a finished game; true when it is a new best.
static func add(game: String, score: int, stage: int, boosted := false) -> bool:
	var cfg := _load()
	var was := int(cfg.get_value(game, "best", 0))
	cfg.set_value(game, "plays", int(cfg.get_value(game, "plays", 0)) + 1)
	cfg.set_value(game, "best_stage", maxi(stage, int(cfg.get_value(game, "best_stage", 0))))
	var better := score > was
	if better:
		cfg.set_value(game, "best", score)
		cfg.set_value(game, "best_boosted", boosted)
	cfg.save(PATH)
	return better

## A staged game (Firefly) keeps a best and a clear for every stage at
## every difficulty (0 Easy .. 3 Insane), under `s<stage>d<difficulty>_`
## keys in its own section, beside `reached` (the highest stage open) and
## `clears` (how many of those cells are cleared). The old run's `best`
## and `best_stage` are left as they were and not read for it.
static func _cell(stage: int, difficulty: int) -> String:
	return "s%dd%d_" % [stage, difficulty]

static func stage_best(game: String, stage: int, difficulty: int) -> int:
	return int(_load().get_value(game, _cell(stage, difficulty) + "best", 0))

static func stage_cleared(game: String, stage: int, difficulty: int) -> bool:
	return bool(_load().get_value(game, _cell(stage, difficulty) + "clear", false))

## Whether that stage's best was made with a booster or a Second chance.
static func stage_boosted(game: String, stage: int, difficulty: int) -> bool:
	return bool(_load().get_value(game, _cell(stage, difficulty) + "boosted", false))

## The highest stage open, 1 before anything is cleared: clearing stage n
## at any difficulty opens n + 1 (the game caps it at its last stage).
static func reached(game: String) -> int:
	return maxi(1, int(_load().get_value(game, "reached", 1)))

## How many stage and difficulty cells are cleared.
static func clears(game: String) -> int:
	return int(_load().get_value(game, "clears", 0))

## Records a finished attempt at one stage and difficulty: "better" when
## the score is a new best for that cell, "first_clear" when the cell is
## cleared for the first time (its gold is paid on that, once).
static func add_stage(game: String, stage: int, difficulty: int, score: int, cleared: bool, boosted := false) -> Dictionary:
	var cfg := _load()
	var cell := _cell(stage, difficulty)
	cfg.set_value(game, "plays", int(cfg.get_value(game, "plays", 0)) + 1)
	var better := score > int(cfg.get_value(game, cell + "best", 0))
	if better:
		cfg.set_value(game, cell + "best", score)
		cfg.set_value(game, cell + "boosted", boosted)
	var first := cleared and not bool(cfg.get_value(game, cell + "clear", false))
	if first:
		cfg.set_value(game, cell + "clear", true)
		cfg.set_value(game, "clears", int(cfg.get_value(game, "clears", 0)) + 1)
	if cleared:
		cfg.set_value(game, "reached", maxi(stage + 1, int(cfg.get_value(game, "reached", 1))))
	cfg.save(PATH)
	return {"better": better, "first_clear": first}

## What the player last chose before a run of `game` (Peapod's cart), 0
## with nothing chosen yet.
static func pick(game: String) -> int:
	return int(_load().get_value(game, "pick", 0))

static func set_pick(game: String, v: int) -> void:
	var cfg := _load()
	cfg.set_value(game, "pick", v)
	cfg.save(PATH)

## What a game keeps between runs besides its scores (Eddy's bank and its
## upgrades' levels, arcade/eddy_upgrades.gd).
static func kept(game: String, key: String, default: int = 0) -> int:
	return int(_load().get_value(game, key, default))

static func keep(game: String, values: Dictionary) -> void:
	var cfg := _load()
	for key: String in values:
		cfg.set_value(game, key, int(values[key]))
	cfg.save(PATH)

## Everything kept for `game` gone: its best, its plays, its pick, its
## stages and what it keeps between runs (Start over, ui/hud/start_over_sheet.gd).
static func wipe(game: String) -> void:
	var cfg := _load()
	if cfg.has_section(game):
		cfg.erase_section(game)
		cfg.save(PATH)

## A score as the player's language groups it: 12,340 or 12.340.
static func grouped(n: int) -> String:
	return Locale.number(n)
