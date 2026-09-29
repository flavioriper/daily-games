extends RefCounted

## When a full-screen ad may show, and how many rewarded videos are left
## today. Pure: the caller hands in the clock, the date, the day's hearts and
## the age band, so a probe can walk weeks in a loop. core/ads.gd owns one and
## saves `state` after every change. The numbers are the research report's
## starting points (reports/Fair ad monetization for puzzles.md), overridable
## by the remote config/ads document through merge().

const AgeGate = preload("res://core/age_gate.gd")
const Wallet = preload("res://core/wallet.gd")

const DEFAULTS := {
	"interstitial_on": true,
	"grace_days": 3,
	"after_hearts": 3,
	"min_games_today": 6,
	"games_between": 2,
	"minutes_between": 4.0,
	"after_rewarded_minutes": 4.0,
	"max_per_day": 4,
	"rewarded_per_day": 10,
}

var cfg: Dictionary = DEFAULTS.duplicate()
var state := {
	"first_day": 0, "day": 0, "games_today": 0, "games_since": 0,
	"shown_today": 0, "last_full": 0.0, "last_rewarded": 0.0, "rewarded_today": 0,
}

## Takes the remote numbers it knows, of the type it expects; anything else
## is ignored, so a bad document can never switch pacing off by accident.
func merge(remote: Dictionary) -> void:
	for k: String in remote:
		if not cfg.has(k):
			continue
		var want := typeof(DEFAULTS[k])
		var v = remote[k]
		if want == TYPE_BOOL and typeof(v) == TYPE_BOOL:
			cfg[k] = v
		elif want in [TYPE_INT, TYPE_FLOAT] and typeof(v) in [TYPE_INT, TYPE_FLOAT]:
			cfg[k] = maxf(0.0, float(v))

func _roll(today: int) -> void:
	if int(state.first_day) == 0:
		state.first_day = today
	if int(state.day) != today:
		state.day = today
		state.games_today = 0
		state.shown_today = 0
		state.rewarded_today = 0

func note_finished(today: int) -> void:
	_roll(today)
	state.games_today = int(state.games_today) + 1
	state.games_since = int(state.games_since) + 1

func interstitial_verdict(now: float, today: int, hearts: int, band: int) -> String:
	_roll(today)
	if not bool(cfg.interstitial_on):
		return "off"
	if band == AgeGate.CHILD:
		return "child"
	if Wallet._days_between(int(state.first_day), today) < int(cfg.grace_days):
		return "grace"
	if hearts < int(cfg.after_hearts):
		return "hearts"
	if int(state.games_today) < int(cfg.min_games_today):
		return "few_games"
	if int(state.games_since) < int(cfg.games_between):
		return "games_between"
	if now - float(state.last_full) < float(cfg.minutes_between) * 60.0:
		return "minutes_between"
	if now - float(state.last_rewarded) < float(cfg.after_rewarded_minutes) * 60.0:
		return "after_rewarded"
	if int(state.shown_today) >= int(cfg.max_per_day):
		return "day_cap"
	return ""

func note_interstitial(now: float, today: int) -> void:
	_roll(today)
	state.last_full = now
	state.games_since = 0
	state.shown_today = int(state.shown_today) + 1

func rewarded_left(today: int) -> int:
	_roll(today)
	return maxi(0, int(cfg.rewarded_per_day) - int(state.rewarded_today))

func note_rewarded(now: float, today: int) -> void:
	_roll(today)
	state.last_rewarded = now
	state.rewarded_today = int(state.rewarded_today) + 1
