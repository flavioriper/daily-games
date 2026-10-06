extends SceneTree

## Headless probe for Ads' interstitial and rewarded slots (the desktop
## stand-in). Run: godot --headless --script tests/_probe_ads_slots.gd

const PATH := "user://_probe_ads_slots.cfg"
var _frames := 0
var _stage := 0
var _fails := 0
var _left := 0
var _got := -1
var _wait_until := 0

func _check(name: String, cond: bool) -> void:
	print(("ok   " if cond else "FAIL ") + name)
	if not cond:
		_fails += 1

func _fake_layers() -> int:
	var n := 0
	for c in root.get_node("Ads").get_children():
		if c is CanvasLayer:
			n += 1
	return n

func _cb(v: bool) -> void:
	_got = 1 if v else 0

func _process(_dt: float) -> bool:
	_frames += 1
	var ads = root.get_node("Ads")
	if _frames < 3:
		return false
	match _stage:
		0:
			ads.state_path = PATH
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
			ads.pacing = ads.AdPacing.new()
			ads.reload_state()
			ads._fake_full = "1"
			ads.post_play = true
			ads.leaving_game()
			_check("1 leaving with nothing finished shows nothing", _fake_layers() == 0 and not AudioServer.is_bus_mute(0))
			_check("2a can_reward with the fake", ads.can_reward("hint"))
			_left = ads.pacing.rewarded_left(Daily.date_key())
			_got = -1
			ads.show_rewarded("hint", _cb)
			_check("6a bus muted during ad", AudioServer.is_bus_mute(0))
			_stage = 1
			_wait_until = Time.get_ticks_msec() + 4000
		1:
			if _got == -1 and Time.get_ticks_msec() < _wait_until:
				return false
			_check("2b done(true)", _got == 1)
			_check("2c rewarded_left dropped by one", ads.pacing.rewarded_left(Daily.date_key()) == _left - 1)
			_check("6b bus unmuted after", not AudioServer.is_bus_mute(0))
			var prior: bool = ads.Sound.on
			ads.Sound.on = false
			ads.Sound.apply()
			ads._quiet(true)
			ads._quiet(false)
			_check("6c Sound off stays muted after an ad", AudioServer.is_bus_mute(0))
			ads.Sound.on = prior
			ads.Sound.apply()
			ads._fake_full = "skip"
			ads.pacing.state.last_rewarded = 0.0
			_left = ads.pacing.rewarded_left(Daily.date_key())
			_got = -1
			ads.show_rewarded("hint", _cb)
			_stage = 2
			_wait_until = Time.get_ticks_msec() + 4000
		2:
			if _got == -1 and Time.get_ticks_msec() < _wait_until:
				return false
			_check("3a skip gives done(false)", _got == 0)
			_check("3b rewarded_left unchanged", ads.pacing.rewarded_left(Daily.date_key()) == _left)
			_check("3c a skipped video starts the quiet", float(ads.pacing.state.last_rewarded) > 0.0)
			ads._fake_full = "1"
			ads._removed = true
			ads.note_finished()
			ads.leaving_game()
			_check("4a removed: no interstitial", _fake_layers() == 0)
			_check("4b removed: can_reward still true", ads.can_reward("hint"))
			_got = -1
			ads.show_rewarded("hint", _cb)
			_stage = 3
			_wait_until = Time.get_ticks_msec() + 4000
		3:
			if _got == -1 and Time.get_ticks_msec() < _wait_until:
				return false
			_check("4c removed: video earns", _got == 1)
			# spend the rest of the day's videos
			var guard := 0
			while ads.pacing.rewarded_left(Daily.date_key()) > 0 and guard < 50:
				ads.pacing.note_rewarded(Time.get_unix_time_from_system(), Daily.date_key())
				guard += 1
			_check("5 after the cap can_reward is false", not ads.can_reward("hint"))
			ads._removed = false
			ads._fake_full = ""
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
			print("fails=%d" % _fails)
			quit(_fails)
	return false
