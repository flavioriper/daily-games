extends RefCounted

## Eddy's bank and its four upgrades (spec
## docs/superpowers/specs/2026-10-11-eddy-incremental-design.md): what a run
## scores is banked as drops, kept on the device beside the Arcade's scores
## (user://arcade.cfg, section eddy), and drops buy levels of the four
## upgrades in the shop (arcade/eddy_shop.gd). A fresh run is handed the
## levels (`fit`). Drops are Eddy's own: gold buys none of this.
##
## No upgrade has a top; its price is the brake, each level GROWTH times the
## last.

const Record = preload("res://arcade/arcade_record.gd")
const Sim = preload("res://arcade/eddy_sim.gd")

const GAME := "eddy"
const IDS := ["spin", "pull", "mouth", "reach"]
## Each upgrade's first price in drops, and how much dearer every level is.
const FIRST := {"spin": 40, "pull": 50, "mouth": 60, "reach": 50}
const GROWTH := 1.36
const ICON := {"spin": "clock", "pull": "trend", "mouth": "plus", "reach": "sparkle"}
## The two gold boosters Eddy had before the shop, and what one cost: held
## ones are given back in gold when the screen opens (core/wallet.gd).
const OLD := ["ed_long", "ed_head"]
const OLD_PRICE := 120

## The price of level `lv` + 1 of `id`, rounded to fives.
static func price(id: String, lv: int, growth := GROWTH) -> int:
	return int(round(float(FIRST[id]) * pow(growth, lv) / 5.0)) * 5

static func level(id: String) -> int:
	return Record.kept(GAME, "up_" + id)

static func levels() -> Dictionary:
	var out := {}
	for id: String in IDS:
		out[id] = level(id)
	return out

static func drops() -> int:
	return Record.kept(GAME, "drops")

## A run's score into the bank; the bank after it.
static func bank(score: int) -> int:
	var now := drops() + maxi(score, 0)
	Record.keep(GAME, {"drops": now})
	return now

static func can_buy(id: String) -> bool:
	return drops() >= price(id, level(id))

## Whether the bank covers any upgrade at all.
static func any() -> bool:
	for id: String in IDS:
		if can_buy(id):
			return true
	return false

## Buys the next level of `id`. False, and nothing spent, when the bank is
## short.
static func buy(id: String) -> bool:
	var lv := level(id)
	var cost := price(id, lv)
	if drops() < cost:
		return false
	Record.keep(GAME, {"drops": drops() - cost, "up_" + id: lv + 1})
	return true

## Hands a fresh run the kept levels.
static func fit(sim: RefCounted) -> void:
	sim.fit(levels())

## What level `lv` of `id` is worth, as the shop letters it.
static func worth(id: String, lv: int) -> String:
	match id:
		"spin":
			return "%d s" % int(Sim.SPIN + Sim.SPIN_UP * lv)
		"pull":
			return "%d%%" % int(round((Sim.INFLOW + Sim.PULL_UP * lv) / Sim.INFLOW * 100.0))
		"mouth":
			return "%d%%" % int(round((Sim.CORE + Sim.MOUTH_UP * lv) / Sim.CORE * 100.0))
		_:
			return "%d%%" % int(round((Sim.REACH + Sim.REACH_UP * lv) / Sim.REACH * 100.0))
