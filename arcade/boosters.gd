extends RefCounted

## The Arcade's boosters: two a game, chosen on the boost card before a run
## (arcade/boost_card.gd), and the Second chance every game shares, offered
## once a run at game over (arcade/second_chance.gd). Gold buys them in the
## shop (ui/hud/shop_sheet.gd); core/wallet.gd keeps how many are held.
## Spec docs/superpowers/specs/2026-09-28-gold-gifts-design.md, section 3.
##
## A booster helps a run start or survive and never multiplies its score.

const CHANCE := "second_chance"
const GAMES := ["firefly", "molehill", "stackwood", "thirteen", "posy", "peapod"]
const ITEMS := {
	"ff_spare": {"game": "firefly", "icon": "heart", "price": 120},
	"ff_twin": {"game": "firefly", "icon": "plus", "price": 120},
	"mh_time": {"game": "molehill", "icon": "clock", "price": 120},
	"mh_steady": {"game": "molehill", "icon": "shield", "price": 120},
	"sw_acorns": {"game": "stackwood", "icon": "acorn", "price": 120},
	"sw_low": {"game": "stackwood", "icon": "minus", "price": 120},
	"lt_clovers": {"game": "thirteen", "icon": "leaf", "price": 120},
	"lt_head": {"game": "thirteen", "icon": "trend", "price": 120},
	"po_kit": {"game": "posy", "icon": "gift", "price": 120},
	"po_bloom": {"game": "posy", "icon": "sparkle", "price": 120},
	"pp_pea": {"game": "peapod", "icon": "plus", "price": 120},
	"pp_quick": {"game": "peapod", "icon": "trend", "price": 120},
	"second_chance": {"game": "", "icon": "reset", "price": 200},
}
## Each booster's colour on its disc: the game's, so a chip says whose it is.
const TINT := {"firefly": Color("5b5fa8"), "molehill": Color("8a6a45"), "stackwood": Color("b0773a"),
	"thirteen": Color("5f9a6a"), "posy": Color("c56f8e"), "peapod": Color("5f9f47"), "": Color("d49a2a")}

const FF_SPARE_SHIPS := 1
const MH_TIME := 10.0
const MH_FORGIVE := 2
const MH_CHANCE_TIME := 15.0
const SW_ACORNS := 200
const SW_SMALL := 10
const LT_CLOVERS := 40
const PO_CHANCE_MOVES := 5
const PP_PEAS := 1
const PP_RATE := 2

static func of(game: String) -> Array:
	var out := []
	for id: String in ITEMS:
		if String(ITEMS[id].game) == game:
			out.append(id)
	return out

static func price(id: String) -> int:
	return int(ITEMS.get(id, {}).get("price", 0))

static func icon(id: String) -> String:
	return String(ITEMS.get(id, {}).get("icon", "sparkle"))

static func tint(id: String) -> Color:
	return TINT[String(ITEMS.get(id, {}).get("game", ""))]

## The locale keys: BST_<ID> is the name, BST_<ID>_LINE what it does.
static func name_key(id: String) -> String:
	return "BST_" + id.to_upper()

static func line_key(id: String) -> String:
	return "BST_" + id.to_upper() + "_LINE"

## What the Second chance does in `game`.
static func chance_key(game: String) -> String:
	return "BST_CHANCE_" + game.to_upper()

## The booster a date features in its gifts: the game boosters in turn,
## a day each, the same for everyone.
static func featured(date_key: int) -> String:
	var ids: Array = []
	for g: String in GAMES:
		ids.append_array(of(g))
	var unix := Time.get_unix_time_from_datetime_dict({"year": date_key / 10000, "month": (date_key / 100) % 100,
		"day": date_key % 100, "hour": 12, "minute": 0, "second": 0})
	return ids[posmod(int(unix / 86400.0), ids.size())]

## Sets a fresh run's boosters in its sim, before the screen reads it.
static func apply(game: String, sim: RefCounted, ids: Array) -> void:
	for id: String in ids:
		match id:
			"ff_spare":
				sim.ships += FF_SPARE_SHIPS
			"ff_twin":
				sim.pair = true
			"mh_time":
				sim.bonus += MH_TIME
			"mh_steady":
				sim.forgive += MH_FORGIVE
			"sw_acorns":
				sim.acorns += SW_ACORNS
			"sw_low":
				sim.start_small(SW_SMALL)
			"lt_clovers":
				sim.clovers += LT_CLOVERS
			"lt_head":
				sim.head_start()
			"po_kit":
				for t in sim.tools:
					sim.tools[t] = int(sim.tools[t]) + 1
			"po_bloom":
				sim.opening_bloom()
			"pp_pea":
				sim.peas += PP_PEAS
			"pp_quick":
				sim.rate_lv += PP_RATE

## The Second chance: a run over is taken up again where it ended.
static func revive(game: String, sim: RefCounted) -> void:
	match game:
		"molehill":
			sim.revive(MH_CHANCE_TIME)
		"posy":
			sim.revive(PO_CHANCE_MOVES)
		_:
			sim.revive()
