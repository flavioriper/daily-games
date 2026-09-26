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
