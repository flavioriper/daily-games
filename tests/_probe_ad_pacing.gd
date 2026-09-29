extends SceneTree

## The ad pacing model's verdicts and state, headless.
##   godot --headless --script tests/_probe_ad_pacing.gd

const AdPacing = preload("res://core/ad_pacing.gd")
const AgeGate = preload("res://core/age_gate.gd")
const Wallet = preload("res://core/wallet.gd")

const D0 := 20261001
const t := 1_000_000.0

var _fails := 0
var _frames := 0

func _check(ok: bool, what: String) -> void:
	_fails += 0 if ok else 1
	print("ok   " if ok else "FAIL ", what)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false

	var p := AdPacing.new()

	# Case 1: Grace period
	p.note_finished(D0)
	_check(p.interstitial_verdict(t, D0, 3, AgeGate.ADULT) == "grace",
		"case 1: first day within grace period returns 'grace'")

	# Case 2: Hearts check, games_today check
	p = AdPacing.new()
	p.note_finished(D0)

	# 3 days later with hearts 2: should be hearts
	_check(p.interstitial_verdict(t, 20261004, 2, AgeGate.ADULT) == "hearts",
		"case 2a: day 4 with hearts 2 returns 'hearts'")

	# With hearts 3 and 5 games finished: should be few_games
	p = AdPacing.new()
	p.note_finished(D0)
	for i in range(5):
		p.note_finished(20261004)
	_check(p.interstitial_verdict(t, 20261004, 3, AgeGate.ADULT) == "few_games",
		"case 2b: day 4 with hearts 3 and 5 games returns 'few_games'")

	# With 6 games: should pass all checks
	p = AdPacing.new()
	p.note_finished(D0)
	for i in range(6):
		p.note_finished(20261004)
	_check(p.interstitial_verdict(t, 20261004, 3, AgeGate.ADULT) == "",
		"case 2c: day 4 with hearts 3 and 6 games returns empty string")

	# Case 3: Games between and minutes between checks
	p = AdPacing.new()
	p.note_finished(D0)
	for i in range(6):
		p.note_finished(20261004)
	p.note_interstitial(t, 20261004)

	# One more game -> games_between
	p.note_finished(20261004)
	_check(p.interstitial_verdict(t, 20261004, 3, AgeGate.ADULT) == "games_between",
		"case 3a: after interstitial, one more game returns 'games_between'")

	# Second game at t + 60 -> minutes_between
	p.note_finished(20261004)
	_check(p.interstitial_verdict(t + 60.0, 20261004, 3, AgeGate.ADULT) == "minutes_between",
		"case 3b: at t+60 returns 'minutes_between'")

	# At t + 241 -> should pass
	_check(p.interstitial_verdict(t + 241.0, 20261004, 3, AgeGate.ADULT) == "",
		"case 3c: at t+241 returns empty string")

	# Case 4: After rewarded check
	p = AdPacing.new()
	p.note_finished(D0)
	for i in range(6):
		p.note_finished(20261004)
	p.note_interstitial(t, 20261004)
	p.note_rewarded(t + 300.0, 20261004)

	# Two more games
	p.note_finished(20261004)
	p.note_finished(20261004)
	_check(p.interstitial_verdict(t + 400.0, 20261004, 3, AgeGate.ADULT) == "after_rewarded",
		"case 4: after rewarded at t+400 returns 'after_rewarded'")

	# Case 5: Daily cap and next day reset
	p = AdPacing.new()
	p.note_finished(D0)
	for i in range(6):
		p.note_finished(20261004)

	# Show 4 interstitials
	for i in range(4):
		p.note_interstitial(t + float(i) * 300.0, 20261004)
		for j in range(2):
			p.note_finished(20261004)

	# Fifth attempt should hit day_cap
	_check(p.interstitial_verdict(t + 1200.0, 20261004, 3, AgeGate.ADULT) == "day_cap",
		"case 5a: fifth interstitial attempt hits 'day_cap'")

	# Next day: shown_today and games_today both reset, so few_games
	_check(p.interstitial_verdict(t, 20261005, 3, AgeGate.ADULT) == "few_games",
		"case 5b: next day returns 'few_games' (reset both counters)")

	# first_day should still be D0
	_check(p.state.first_day == D0,
		"case 5c: first_day still points to original day")

	# Case 6: Child band blocks everything
	p = AdPacing.new()
	p.note_finished(D0)
	for i in range(10):
		p.note_finished(20261004)
	p.note_interstitial(t + 500.0, 20261004)
	_check(p.interstitial_verdict(t + 600.0, 20261004, 10, AgeGate.CHILD) == "child",
		"case 6: CHILD band always returns 'child'")

	# Case 7: Rewarded quota
	p = AdPacing.new()
	_check(p.rewarded_left(D0) == 10,
		"case 7a: rewarded_left starts at 10")

	for i in range(10):
		p.note_rewarded(t + float(i) * 10.0, D0)
	_check(p.rewarded_left(D0) == 0,
		"case 7b: after 10 rewarded videos, rewarded_left is 0")

	# Next day resets
	_check(p.rewarded_left(20261002) == 10,
		"case 7c: next day rewarded_left resets to 10")

	# Case 8: Merge with type checking
	p = AdPacing.new()
	p.merge({"interstitial_on": "yes", "max_per_day": 2, "unknown": 1})
	_check(p.cfg.interstitial_on == true,
		"case 8a: merge ignores non-bool for bool field")
	_check(p.cfg.max_per_day == 2,
		"case 8b: merge accepts int for max_per_day")
	_check(not p.cfg.has("unknown"),
		"case 8c: merge ignores unknown keys")

	print("ad pacing: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
