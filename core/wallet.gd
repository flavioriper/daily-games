extends Node

## Gold, the Arcade's boosters, and the daily gifts, kept on the device
## (user://wallet.cfg) and never sold: gold is earned on the daily boards,
## from the gifts and a little from Arcade runs, and spent in the shop and on
## the boost card (spec docs/superpowers/specs/2026-09-28-gold-gifts-design.md).
##
## Autoload `Wallet`. Every write goes through `_save()` and says `changed`,
## so a gold pill anywhere follows without asking. `path` may be pointed
## elsewhere before anything reads it, so a harness never touches a real save.
##
## Nothing here is random: a gift is the same for everyone on its date and
## shows what it holds before it is claimed.

signal changed
## Gold that just came in, and why ("board", "calendar", "hearts", "arcade",
## "welcome"): a pill may fly coins for it.
signal earned(amount: int, source: String)

const Analytics = preload("res://core/analytics.gd")
const Boosters = preload("res://arcade/boosters.gd")

var path := "user://wallet.cfg"

const WELCOME_GOLD := 150
const BOARD_GOLD := 20
const HEARTS_GOLD := 100
const RUN_GOLD := 5
const BEST_GOLD := 20
const ARCADE_CAP := 60
## The seven days of the calendar. "featured" is that many of the date's
## featured booster (Boosters.featured).
const CALENDAR := [
	{"gold": 50},
	{"gold": 75},
	{"items": {"second_chance": 1}},
	{"gold": 100},
	{"featured": 2},
	{"gold": 150},
	{"gold": 250, "items": {"second_chance": 1}, "featured": 2},
]
## A claim more than this many days after the last one starts the week over:
## one missed day is forgiven, two are not.
const GRACE := 2

var _cfg: ConfigFile

func _cfg_now() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(path)
		if not bool(_cfg.get_value("wallet", "welcomed", false)):
			_cfg.set_value("wallet", "welcomed", true)
			_cfg.set_value("wallet", "gold", WELCOME_GOLD)
			for id: String in Boosters.ITEMS:
				_cfg.set_value("items", id, 1)
			_cfg.save(path)
	return _cfg

## Forget what was read, so the next read comes from `path` (a harness that
## has just pointed `path` somewhere else).
func reload() -> void:
	_cfg = null
	changed.emit()

func _save() -> void:
	_cfg_now().save(path)
	changed.emit()

# --- gold ---

func gold() -> int:
	return int(_cfg_now().get_value("wallet", "gold", 0))

func add_gold(amount: int, source: String) -> void:
	if amount <= 0:
		return
	_cfg_now().set_value("wallet", "gold", gold() + amount)
	_save()
	Analytics.track("gold_earned", {"source": source, "amount": amount, "balance": gold()})
	earned.emit(amount, source)

## Spends gold on `what`; false (and nothing spent) when there is not enough.
func spend(amount: int, what: String) -> bool:
	if amount > gold():
		return false
	_cfg_now().set_value("wallet", "gold", gold() - amount)
	_save()
	Analytics.track("gold_spent", {"item": what, "amount": amount, "balance": gold()})
	return true

# --- items ---

func count(item: String) -> int:
	return int(_cfg_now().get_value("items", item, 0))

func give(item: String, n := 1) -> void:
	if n <= 0:
		return
	_cfg_now().set_value("items", item, count(item) + n)
	_save()

## Buys one of `item` at its price. False when the gold is short.
func buy(item: String) -> bool:
	if not spend(Boosters.price(item), item):
		return false
	give(item, 1)
	return true

## Uses one of `item`, buying it first when none is held and `or_buy`.
## False when there is none and it cannot be bought.
func use(item: String, game: String, or_buy := false) -> bool:
	if count(item) <= 0:
		if not or_buy or not buy(item):
			return false
	_cfg_now().set_value("items", item, count(item) - 1)
	_save()
	Analytics.track("booster_used", {"item": item, "game": game})
	return true

func can_have(item: String) -> bool:
	return count(item) > 0 or gold() >= Boosters.price(item)

# --- a gift, resolved: {gold, items: {id: n}} ---

static func resolve(raw: Dictionary, date_key: int) -> Dictionary:
	var items := {}
	for id: String in raw.get("items", {}):
		items[id] = int(items.get(id, 0)) + int(raw.items[id])
	if int(raw.get("featured", 0)) > 0:
		var f := Boosters.featured(date_key)
		items[f] = int(items.get(f, 0)) + int(raw.featured)
	return {"gold": int(raw.get("gold", 0)), "items": items}

func _grant(gift: Dictionary, source: String) -> void:
	for id: String in gift.items:
		_cfg_now().set_value("items", id, count(id) + int(gift.items[id]))
	_save()
	add_gold(int(gift.gold), source)

# --- the calendar ---

## The day of the week the next claim is (0-6), with the grace applied.
func calendar_step(today: int = Daily.date_key()) -> int:
	var last := int(_cfg_now().get_value("calendar", "last", 0))
	var step := int(_cfg_now().get_value("calendar", "step", 0))
	if last == 0 or _days_between(last, today) > GRACE:
		return 0
	return step

## Whether today's day of the calendar is still to claim.
func calendar_open(today: int = Daily.date_key()) -> bool:
	return today > int(_cfg_now().get_value("calendar", "last", 0))

## Which days of the week shown are claimed: the steps before the next one,
## unless the week has started over.
func calendar_claimed_today(today: int = Daily.date_key()) -> bool:
	return int(_cfg_now().get_value("calendar", "last", 0)) == today

func calendar_gift(step: int, today: int = Daily.date_key()) -> Dictionary:
	return resolve(CALENDAR[clampi(step, 0, CALENDAR.size() - 1)], today)

## Claims today's day; the gift given, or {} when it was already claimed.
func claim_calendar(today: int = Daily.date_key()) -> Dictionary:
	if not calendar_open(today):
		return {}
	var step := calendar_step(today)
	var gift := calendar_gift(step, today)
	_cfg_now().set_value("calendar", "last", today)
	_cfg_now().set_value("calendar", "step", (step + 1) % CALENDAR.size())
	Analytics.track("gift_claimed", {"kind": "calendar", "step": step + 1})
	_grant(gift, "calendar")
	return gift

## The step the week shows as "today" after a claim: the one just claimed.
func calendar_shown_step(today: int = Daily.date_key()) -> int:
	if calendar_claimed_today(today):
		return posmod(int(_cfg_now().get_value("calendar", "step", 0)) - 1, CALENDAR.size())
	return calendar_step(today)

static func _days_between(a: int, b: int) -> int:
	return int(round((_unix(b) - _unix(a)) / 86400.0))

static func _unix(key: int) -> float:
	return Time.get_unix_time_from_datetime_dict({"year": key / 10000, "month": (key / 100) % 100,
		"day": key % 100, "hour": 12, "minute": 0, "second": 0})

# --- the hearts gift ---

func hearts_gift(today: int = Daily.date_key()) -> Dictionary:
	return resolve({"gold": HEARTS_GOLD, "featured": 1}, today)

func hearts_claimed(today: int = Daily.date_key()) -> bool:
	return int(_cfg_now().get_value("hearts", "last", 0)) == today

func hearts_ready(today: int = Daily.date_key()) -> bool:
	return not hearts_claimed(today) and Progress.hearts(today) >= Streak.KEPT

func claim_hearts(today: int = Daily.date_key()) -> Dictionary:
	if not hearts_ready(today):
		return {}
	var gift := hearts_gift(today)
	_cfg_now().set_value("hearts", "last", today)
	Analytics.track("gift_claimed", {"kind": "hearts", "step": 0})
	_grant(gift, "hearts")
	return gift

## Gifts waiting to be claimed: the calendar's day and the hearts gift.
func claimable(today: int = Daily.date_key()) -> int:
	return (1 if calendar_open(today) else 0) + (1 if hearts_ready(today) else 0)

## True once a day, the first time it is asked on a day the calendar is
## open: the menu opens the gifts sheet by itself then.
func should_auto_open(today: int = Daily.date_key()) -> bool:
	if not calendar_open(today) or int(_cfg_now().get_value("calendar", "auto", 0)) == today:
		return false
	_cfg_now().set_value("calendar", "auto", today)
	_cfg_now().save(path)
	return true

# --- earning ---

## Pays for the first solve of `board` on `day`; the gold paid (0 when it
## was already paid for).
func pay_board(board: String, day: int = Daily.date_key()) -> int:
	var paid: Array = _cfg_now().get_value("earn", "boards", [])
	if int(_cfg_now().get_value("earn", "boards_day", 0)) != day:
		paid = []
	if paid.has(board):
		return 0
	paid.append(board)
	_cfg_now().set_value("earn", "boards_day", day)
	_cfg_now().set_value("earn", "boards", paid)
	add_gold(BOARD_GOLD, "board")
	return BOARD_GOLD

## Pays for a finished Arcade run, up to the day's cap; the gold paid.
func pay_run(better: bool, today: int = Daily.date_key()) -> int:
	var got := int(_cfg_now().get_value("earn", "arcade", 0))
	if int(_cfg_now().get_value("earn", "arcade_day", 0)) != today:
		got = 0
	var pay := mini(RUN_GOLD + (BEST_GOLD if better else 0), ARCADE_CAP - got)
	if pay <= 0:
		return 0
	_cfg_now().set_value("earn", "arcade_day", today)
	_cfg_now().set_value("earn", "arcade", got + pay)
	add_gold(pay, "arcade")
	return pay
