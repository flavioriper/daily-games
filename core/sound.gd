extends RefCounted

## Sound on or off, the settings sheet's second switch: the Master bus is
## muted rather than every player stopped, so a board's cues, the clicks and
## the page turn all go quiet at once. Saved beside Motion's `reduce` in the
## same file, so a suite that points Motion.settings_path at a throwaway file
## keeps this out of the player's settings too.

const Motion = preload("res://core/motion.gd")

static var on := true

static func load_settings() -> void:
	var cfg := ConfigFile.new()
	on = true
	if cfg.load(Motion.settings_path) == OK:
		on = bool(cfg.get_value("sound", "on", true))
	apply()

static func set_on(value: bool) -> void:
	on = value
	apply()
	var cfg := ConfigFile.new()
	cfg.load(Motion.settings_path)  # keeps other sections; a missing file is fine
	cfg.set_value("sound", "on", on)
	cfg.save(Motion.settings_path)

static func apply() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not on)
