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

## What the player last chose before a run of `game` (Peapod's cart), 0
## with nothing chosen yet.
static func pick(game: String) -> int:
	return int(_load().get_value(game, "pick", 0))

static func set_pick(game: String, v: int) -> void:
	var cfg := _load()
	cfg.set_value(game, "pick", v)
	cfg.save(PATH)

## A score as the player's language groups it: 12,340 or 12.340.
static func grouped(n: int) -> String:
	return Locale.number(n)
