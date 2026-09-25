extends Node

## The scene root. Loads the saved settings in _enter_tree, which runs before
## any child enters the tree, so the stage and its Ambient see the flag on
## their first frame. Nothing else lives here.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 6.

const Motion = preload("res://core/motion.gd")
const Sound = preload("res://core/sound.gd")
const Progress = preload("res://core/progress.gd")
const Analytics = preload("res://core/analytics.gd")
const Backend = preload("res://core/backend.gd")
const Locale = preload("res://core/locale.gd")
const CozyTheme = preload("res://ui/theme.gd")

func _enter_tree() -> void:
	Motion.load_settings()
	Sound.load_settings()
	Locale.apply()
	# Every paper face in the HUD takes its painted wash from here on, the
	# one place that runs before any screen builds (ui/theme.gd dress()).
	CozyTheme.dress(get_tree())

## Telemetry wakes up here and nowhere else, so only a real launch counts;
## tests and harnesses build these screens without ever starting it.
func _ready() -> void:
	Analytics.start(self)
	Analytics.track("game_open", {"day": Progress.day()})
	Ads.start()
	# The backend wakes here and nowhere else, same as telemetry: the suite
	# and the harnesses build these screens and stay offline.
	Backend.start(self)
	$UI/BannerHost.tapped.connect(_open_store)

## The banner's "Remove ads" tab: the purchase sheet over whatever is up --
## the open board's own, else the menu's. BannerHost stands last under UI, so
## its tab would otherwise take taps through any modal already up (a sheet,
## or the first-play card) -- z_index doesn't reorder input, only drawing --
## and do nothing useful underneath it. Does nothing while one is up, the
## same "is anything open" check ui/menu.gd's go_back uses to find the
## topmost thing, minus the closing.
func _open_store() -> void:
	var host: Node = get_tree().get_first_node_in_group("puzzle_host")
	var root: Node = host if (host != null and not host.is_queued_for_deletion()) else $UI/Menu
	if _modal_open(root):
		return
	root.remove_ads_sheet.open_from("banner")

func _modal_open(root: Node) -> bool:
	for node in root.find_children("*", "", true, false):
		if node.has_method("is_open") and node.is_open():
			return true
	return root.get_node_or_null("HowToPlay") != null
