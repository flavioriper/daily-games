extends RefCounted

## When to ask for a store rating (2026-11-11: one rating on Play, none on the
## App Store). The ask is the stores' own sheet (native/store_review, reached
## as Engine.get_singleton("StoreReview")): the player rates without leaving
## the game, and the store alone decides whether the sheet shows (Apple: three
## times a year at most, never in TestFlight; Play: its own quota, never on a
## build not installed from Play). So this only picks a kind moment and never
## asks often:
##   - after a win, as the player goes back to the list (core/ads.gd
##     leaving_game), never in the middle of a board;
##   - once they have played on THRESHOLD_DAYS days and solved THRESHOLD_SOLVES
##     boards, so the ones asked already like the game;
##   - at most MAX_ASKS times, DAYS_BETWEEN days apart;
##   - never a child (the age gate's band).
## Pure where it decides (verdict), so a probe can walk it with any log.

const AgeGate = preload("res://core/age_gate.gd")
const Analytics = preload("res://core/analytics.gd")
const Wallet = preload("res://core/wallet.gd")

const THRESHOLD_DAYS := 3
const THRESHOLD_SOLVES := 5
const MAX_ASKS := 3
const DAYS_BETWEEN := 90

static var path := "user://review.cfg"

## "" when the sheet may be asked for; otherwise why not.
static func verdict(solves: Dictionary, asks: int, last_ask: int, today: int, band: int) -> String:
	if band == AgeGate.CHILD:
		return "child"
	if asks >= MAX_ASKS:
		return "asked_enough"
	if last_ask != 0 and Wallet._days_between(last_ask, today) < DAYS_BETWEEN:
		return "asked_lately"
	var days := 0
	var count := 0
	for day in solves:
		var records: Array = solves[day]
		if not records.is_empty():
			days += 1
			count += records.size()
	if days < THRESHOLD_DAYS:
		return "few_days"
	if count < THRESHOLD_SOLVES:
		return "few_solves"
	return ""

## A board was won and the player is back on the list.
static func after_win() -> void:
	if not OS.has_feature("mobile") or not Engine.has_singleton("StoreReview"):
		return
	# Debug (App Distribution) and TestFlight (`beta`) builds never get the
	# sheet from the store, and TestFlight shares its save with the App Store
	# build: an ask spent there would cost the player the real one.
	if OS.is_debug_build() or OS.has_feature("beta"):
		return
	if not AgeGate.known():
		return
	var cfg := ConfigFile.new()
	cfg.load(path)
	var asks := int(cfg.get_value("review", "asks", 0))
	var last := int(cfg.get_value("review", "last", 0))
	var today := Daily.date_key()
	if not verdict(Progress.solve_log(), asks, last, today, AgeGate.band()).is_empty():
		return
	cfg.set_value("review", "asks", asks + 1)
	cfg.set_value("review", "last", today)
	cfg.save(path)
	Analytics.track("review_asked", {"n": asks + 1})
	Engine.get_singleton("StoreReview").call("request")
