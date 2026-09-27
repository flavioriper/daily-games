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

## Records a finished game; true when it is a new best.
static func add(game: String, score: int, stage: int) -> bool:
	var cfg := _load()
	var was := int(cfg.get_value(game, "best", 0))
	cfg.set_value(game, "plays", int(cfg.get_value(game, "plays", 0)) + 1)
	cfg.set_value(game, "best_stage", maxi(stage, int(cfg.get_value(game, "best_stage", 0))))
	var better := score > was
	if better:
		cfg.set_value(game, "best", score)
	cfg.save(PATH)
	return better

## A score as the player's language groups it: 12,340 or 12.340.
static func grouped(n: int) -> String:
	return Locale.number(n)

## Records a finished game played against the clock, where the best is the
## quickest: `secs` 0 is a game that never finished (it counts a play and
## its stage, never a best). True when it is a new best.
static func add_time(game: String, secs: int, stage: int) -> bool:
	var cfg := _load()
	var was := int(cfg.get_value(game, "best", 0))
	cfg.set_value(game, "plays", int(cfg.get_value(game, "plays", 0)) + 1)
	cfg.set_value(game, "best_stage", maxi(stage, int(cfg.get_value(game, "best_stage", 0))))
	var better := secs > 0 and (was == 0 or secs < was)
	if better:
		cfg.set_value(game, "best", secs)
	cfg.save(PATH)
	return better
