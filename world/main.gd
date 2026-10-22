extends Node

## The scene root. Loads the saved settings in _enter_tree, which runs before
## any child enters the tree, so the stage and its Ambient see the flag on
## their first frame. Nothing else lives here.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 6.

const Motion = preload("res://core/motion.gd")
const Sound = preload("res://core/sound.gd")
const Haptics = preload("res://core/haptics.gd")
const Progress = preload("res://core/progress.gd")
const Analytics = preload("res://core/analytics.gd")
const Backend = preload("res://core/backend.gd")
const Social = preload("res://core/social.gd")
const DeepLink = preload("res://core/deep_link.gd")
const Locale = preload("res://core/locale.gd")
const CozyTheme = preload("res://ui/theme.gd")
const AgeGate = preload("res://core/age_gate.gd")
const AgeScreen = preload("res://ui/hud/age_screen.gd")

func _enter_tree() -> void:
	Motion.load_settings()
	Sound.load_settings()
	Haptics.load_settings()
	Locale.apply()
	# Every paper face in the HUD takes its painted wash from here on, the
	# one place that runs before any screen builds (ui/theme.gd dress()).
	CozyTheme.dress(get_tree())
	# Before the menu, a child, reads the day: a new UTC day whose theme
	# this phone does not hold yet is held back until _watch_day has it
	# (core/daily.gd `held`).
	_hold_day()

## What makes a day's theme, fetched before the day is let in.
const THEMED := [ThemedPictures.GAME, ThemedVistas.GAME]
## Everything a day reads off the server, fetched a day ahead: the night
## publishes tomorrow's theme by 00:00 UTC and its quizzes at 03:00.
const AHEAD := [ThemedPictures.GAME, ThemedVistas.GAME, "acorn", "pearl", "shelves", "clues"]
var _watched := 0
var _watching := false

func _hold_day() -> void:
	var today := Daily.utc_key()
	Daily.held = Daily.utc_key(-1) if THEMED.any(func(g: String) -> bool:
		return Backend.cached_day(g, today).is_empty()) else 0

## Today's theme onto this phone, then the day let in, then tomorrow's
## fetched ahead so the next 00:00 UTC finds it here. At boot, on resume
## and every minute; a day whose fetch failed (offline, an error) is
## tried again on the next.
func _watch_day() -> void:
	var today := Daily.utc_key()
	if _watching or today == _watched:
		return
	_watching = true
	_hold_day()
	var known := true
	for g: String in THEMED:
		if Backend.cached_day(g, today).is_empty():
			var got: Dictionary = await Backend.day_content(g, today)
			# A day the night made no theme for is a 404: nothing to wait on.
			known = known and (got.ok or got.error == "HTTP 404")
	if known:
		_watched = today
		Daily.held = 0
		for g: String in AHEAD:
			Backend.day_content(g, Daily.utc_key(1))  # deliberately not awaited
	_watching = false
	if not known:
		return
	ThemedVistas.reload()
	get_tree().call_group(ThemedVistas.GROUP, "vistas_arrived")
	get_tree().call_group(DAY_GROUP, "_check_day")

## A launch that cannot sign in to the server tells the menu, once: the
## games all play offline, but the day's theme does not come (ui/menu.gd).
func _note_offline() -> void:
	if (await Backend.token()).is_empty():
		get_tree().call_group(DAY_GROUP, "note_offline")

## The screens told when the held day is let in (ui/menu.gd).
const DAY_GROUP := "daily_day"

## Telemetry wakes up here and nowhere else, so only a real launch counts;
## tests and harnesses build these screens without ever starting it.
func _ready() -> void:
	Analytics.start(self)
	Analytics.track("game_open", {"day": Progress.day()})
	# The backend wakes here and nowhere else, same as telemetry: the suite
	# and the harnesses build these screens and stay offline.
	Backend.start(self)  # first: Ads.start() reads remote config through it
	# Golden Acorn's questions for today, fetched behind the menu so its card
	# opens on them at once (puzzles/acorn2d.gd waits a moment when it must).
	Backend.day_content("acorn", Daily.utc_key())  # deliberately not awaited
	# Pearl Dive's prompts ride the same way (puzzles/pearl2d.gd).
	Backend.day_content("pearl", Daily.utc_key())  # deliberately not awaited
	# Four Shelves' and Five Clues' (puzzles/shelves2d.gd, clues2d.gd) too.
	Backend.day_content("shelves", Daily.utc_key())  # deliberately not awaited
	Backend.day_content("clues", Daily.utc_key())  # deliberately not awaited
	# The day's themed bead pictures, for Pixel Garden, Button Box and Toy
	# Cannons, and Gumdrop's jellies (core/themed_pictures.gd), and its
	# painted vistas, for the day card and the difficulty rows
	# (core/themed_vistas.gd): the boards deal what is held, never wait, so
	# _watch_day fetches them before the day is let in, and tomorrow's
	# ahead; a card already up is told when they come.
	var watch := Timer.new()
	watch.wait_time = 60.0
	watch.autostart = true
	watch.timeout.connect(_watch_day)
	add_child(watch)
	_watch_day()
	_note_offline()
	# Friends ride on the backend's identity. Started is not connected: it
	# holds no stream until the player has social (core/social.gd).
	Social.start(self)
	if AgeScreen.wanted():
		var age := AgeScreen.new()
		age.name = "AgeScreen"
		age.answered.connect(func(year: int) -> void:
			AgeGate.set_birth_year(year)
			Analytics.track("age_answered", {"band": AgeGate.band_name(AgeGate.band())})
			Ads.start()
			_take_link.call_deferred())
		$UI.add_child(age)
	else:
		Ads.start()
	$UI/BannerHost.tapped.connect(_open_store)
	_take_link()

## The game brought back to the front: a friend link tapped while it was
## open arrives as a new intent and a resume, with no second _ready.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_node_ready():
		_take_link()
		_watch_day()

## A friend link the game was opened with (core/deep_link.gd hands each out
## once): whoever opens it is the sender's friend from here on, with nothing
## to confirm. The new friend card is the menu's, raised by the hub's
## `befriended`, so a success says nothing here. Does nothing while Social is
## unstarted, and leaves the link untaken, so tests/_offline_main.gd can
## call it and stay offline -- and a harness that has given the game a
## Social.fake can open a link with `-- --link=`.
func _take_link() -> void:
	# Not over the age question: the link waits, untaken, for its answer.
	var age := get_node_or_null("UI/AgeScreen")
	if not Social.started() or (age != null and not age.is_queued_for_deletion()):
		return
	var code := Social.code_in(DeepLink.take())
	if code == "":
		return
	Social.enable()
	var res: Dictionary = await Social.add(code)
	if res.get("ok", false):
		Analytics.track("friends_added", {"via": "link"})
		return
	# "already" needs no word; "self", "unknown" and "offline" do, and the
	# word is the menu's to say.
	var why := str(res.get("why", ""))
	var menu := get_node_or_null("UI/Menu")
	if why != "already" and menu != null and menu.has_method("friend_link_failed"):
		menu.friend_link_failed(why)

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
		if node is CanvasItem and node.has_method("is_open") and node.is_open():
			return true
	# A board's host carries the card itself; a Versus or Arcade screen under
	# the menu carries its own.
	return root.find_child("HowToPlay", true, false) != null
