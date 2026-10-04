extends RefCounted

## Frames won and lost, per game and level, kept on the device
## (user://versus.cfg). Levels 0 to 2 are the computer's; level 3 is Online,
## a stranger, and its record sits beside theirs under the same kind of key
## ("chess_3"). Nothing here is sent anywhere.

const PATH := "user://versus.cfg"
## The fourth chip on the Versus tab: a live game against another player.
const ONLINE := 3

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
	# The computer's level is kept apart, so picking Online does not forget it
	# (a save from before Online has only `last`, which is carried over).
	if level < ONLINE:
		cfg.set_value("last_bot", game, level)
	elif not cfg.has_section_key("last_bot", game):
		cfg.set_value("last_bot", game, clampi(int(cfg.get_value("last", game, 1)), 0, ONLINE - 1))
	cfg.set_value("last", game, level)
	cfg.save(PATH)

## The level last picked against the computer, 0 to 2: what the lobby's
## "Play the computer" starts when nobody is around. `last_level` cannot
## answer that, since picking Online is what brought the player there.
static func last_bot_level(game: String) -> int:
	var cfg := _load()
	var last := int(cfg.get_value("last", game, 1))
	return clampi(int(cfg.get_value("last_bot", game, last if last < ONLINE else 1)), 0, ONLINE - 1)

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

## The piece set chosen for a game; skins are to come (versus/chess_skin.gd,
## versus/checkers_skin.gd), so for now this reads the house set.
static func skin(game: String) -> String:
	return String(_load().get_value("skin", game, "garden"))
