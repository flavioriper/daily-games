extends RefCounted

## Frames won and lost against the computer, per game and level, kept on the
## device (user://versus.cfg). Nothing here is sent anywhere.

const PATH := "user://versus.cfg"

static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg

static func get_record(game: String, level: int) -> Vector2i:
	var cfg := _load()
	var key := "%s_%d" % [game, level]
	return Vector2i(int(cfg.get_value(key, "won", 0)), int(cfg.get_value(key, "lost", 0)))

static func add(game: String, level: int, won: bool) -> void:
	var cfg := _load()
	var key := "%s_%d" % [game, level]
	var field := "won" if won else "lost"
	cfg.set_value(key, field, int(cfg.get_value(key, field, 0)) + 1)
	cfg.save(PATH)

## The level last played, so the Versus tab opens on it.
static func last_level(game: String) -> int:
	return int(_load().get_value("last", game, 1))

static func set_last_level(game: String, level: int) -> void:
	var cfg := _load()
	cfg.set_value("last", game, level)
	cfg.save(PATH)

## Drawn games, for a game that can draw (chess).
static func add_draw(game: String, level: int) -> void:
	var cfg := _load()
	var key := "%s_%d" % [game, level]
	cfg.set_value(key, "drawn", int(cfg.get_value(key, "drawn", 0)) + 1)
	cfg.save(PATH)

static func get_draws(game: String, level: int) -> int:
	return int(_load().get_value("%s_%d" % [game, level], "drawn", 0))

## The record as one line: won and lost, and drawn once there is one.
static func record_line(game: String, level: int) -> String:
	var rec := get_record(game, level)
	var drawn := get_draws(game, level)
	if drawn > 0:
		return TranslationServer.translate("VS_RECORD_DRAWN") % [rec.x, rec.y, drawn]
	return TranslationServer.translate("VS_RECORD") % [rec.x, rec.y]

## The colour the player moved last game (chess swaps it every game), 0
## white.
static func last_colour(game: String) -> int:
	return int(_load().get_value("colour", game, 0))

static func set_last_colour(game: String, colour: int) -> void:
	var cfg := _load()
	cfg.set_value("colour", game, colour)
	cfg.save(PATH)

## The piece set chosen for a game; skins are to come (versus/chess_skin.gd),
## so for now this reads the house set.
static func skin(game: String) -> String:
	return String(_load().get_value("skin", game, "garden"))
