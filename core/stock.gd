extends Node

## The Valley's shared inventory, kept on the device (user://stock.cfg): one
## count for each named resource, which every place on the Valley tab reads
## and writes and no place owns. The Grove puts wood in and never takes any
## out; what a place spends on itself (the Grove's energy) is that place's
## own and is not kept here. Gold and boosters stay in the Wallet
## (core/wallet.gd): nothing here is bought, sold or turned into gold.
## Spec docs/superpowers/specs/2026-10-05-valley-grove-design.md, section 2.
##
## Autoload `Stock`. A count that changes says `changed`, so a pill anywhere
## follows without asking. A place adds as fast as trees fall, so the file is
## written at most once every SAVE_GAP seconds and whenever the app is left;
## `flush()` writes it now. `path` may be pointed elsewhere before anything
## reads it, so a harness never touches a real save.

signal changed
## What just came in and from where ("grove"): a pill may fly it home.
signal gained(resource: String, amount: int, source: String)

const SAVE_GAP := 2.0

var path := "user://stock.cfg"

var _cfg: ConfigFile
var _dirty := false
var _since := 0.0

func _ready() -> void:
	set_process(false)

func _cfg_now() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(path)
	return _cfg

## Forget what was read, so the next read comes from `path` (a harness that
## has just pointed `path` somewhere else). Anything unwritten is dropped.
func reload() -> void:
	_cfg = null
	_dirty = false
	set_process(false)
	changed.emit()

func count(resource: String) -> int:
	return int(_cfg_now().get_value("stock", resource, 0))

func add(resource: String, amount: int, source: String) -> void:
	if amount <= 0:
		return
	_cfg_now().set_value("stock", resource, count(resource) + amount)
	_touch()
	gained.emit(resource, amount, source)

## Whether every resource of `cost` ({resource: amount}) is held.
func can_pay(cost: Dictionary) -> bool:
	for resource: String in cost:
		if count(resource) < int(cost[resource]):
			return false
	return true

## Takes `cost` out, all of it or none; false when something is short.
func pay(cost: Dictionary) -> bool:
	if not can_pay(cost):
		return false
	for resource: String in cost:
		_cfg_now().set_value("stock", resource, count(resource) - int(cost[resource]))
	_touch()
	return true

func flush() -> void:
	if _dirty and _cfg != null:
		_cfg.save(path)
	_dirty = false
	set_process(false)

func _touch() -> void:
	if not _dirty:
		_since = 0.0
	_dirty = true
	set_process(true)
	changed.emit()

func _process(delta: float) -> void:
	_since += delta
	if _since >= SAVE_GAP:
		flush()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED,
			NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		flush()
