extends RefCounted

## Paper Planes' Insane ladder (tools/insane/README.md's contract). Insane is
## Windy Day (docs/superpowers/specs/2026-09-30-paper-planes-polish-design.md,
## section 3): a 10x14 sky with eight one-cell clouds that the wind blows one
## cell along their row every launch, so a launch can leave the sky stuck.
## A candidate is the state's own live Windy Day carve (`PlanesState.carve`
## at band 3), built backwards with the clouds' clock so its stored order
## replays to an empty sky.
##
## The grade is an exact search over every set of launched planes reachable
## from the deal without a gust (`PlanesState.analyse`): `p` is the exact
## chance that a random legal playout -- each launch picked evenly among the
## free planes -- clears the sky rather than getting stuck. The rung is
## floor(-log2 p), so rung 5 is one playout in 32 surviving; `work` is the
## doomed sets the search met (skies from which no order clears), the
## tie-break. A sky passes the gate (`unique`, the contract's word for "keep
## it") when the search finished inside its budget, random playouts get stuck
## at least 95% of the time and the greedy "first free plane in reading
## order" play gets stuck too. HARD_RUNG 3 keeps rung 4 and up, so the gate's
## 5% is the binding line.

const State = preload("res://puzzles/planes_state.gd")

const HARD_RUNG := 3
## Reachable launched sets the exact search may meet before a candidate is
## thrown away (the widest seen took about 1.5 s at 200,000).
const BUDGET := 400000
## The playout gate: at most this chance of a random playout clearing.
const GATE_P := 0.05

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	var st := State.new()
	st.carve(rng, 3)
	return st.to_bank()

static func grade(board: Dictionary) -> Dictionary:
	var st := State.new()
	if not st.from_bank(board):
		return {"rung": -1, "work": 0, "unique": false}
	var a: Dictionary = st.analyse(BUDGET)
	if not bool(a.get("ok", false)):
		return {"rung": -1, "work": 0, "unique": false, "planes": st.planes.size()}
	var p: float = a.p
	var greedy := st.greedy_stuck()
	var rung := 40 if p <= 0.0 else mini(40, int(floor(-log(p) / log(2.0))))
	return {"rung": rung, "work": int(a.doomed), "unique": p <= GATE_P and greedy,
		"p": snappedf(p, 0.000001), "planes": st.planes.size(), "states": int(a.states),
		"dead": int(a.dead), "ways": float(a.ways), "greedy_stuck": greedy}
