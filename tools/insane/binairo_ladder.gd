extends RefCounted

## Binairo's Insane ladder (tools/insane/README.md's contract). Binairo's
## Insane is not a harder strip of Hard's board but a different one: 10x10,
## twelve signs of which exactly one lies, stripped to minimal clues
## (Gen.generate_liar). Building one proves thirteen readings of the board
## for every clue it tries to take away -- seconds a board on this Mac, far
## past the phone's 194 ms gate -- so it is mined here and the phone only
## reads the answer (Gen.insane_board).
##
## There is no technique ladder to climb, so the "rung" is the board's blank
## cells: Hard's 8x8 with its floor of 12 clues leaves at most 52, and every
## sound 10x10 liar board clears that. `unique` is the board re-proved from
## scratch with Gen.find_liar, which is told nothing: every sign believed
## gives no solution, the single flips' solutions sum to exactly one, and
## that one flip is the liar the generator chose. `work` is how many sign
## readings that proof ran.

const Gen = preload("res://puzzles/binairo_gen.gd")

## The Insane knobs.
const SIZE := 10
const SIGNS := 12
## Blank cells Hard's own board can reach (8x8 less its 12-clue floor).
const HARD_RUNG := 52

static func candidate(rng: RandomNumberGenerator) -> Dictionary:
	return Gen.to_bank(Gen.generate_liar(rng, SIZE, SIGNS, 0))

static func grade(board: Dictionary) -> Dictionary:
	var b := Gen.from_bank(board)
	var n: int = (b["puzzle"] as Array).size()
	var liar_ok: bool = Gen.find_liar(b["puzzle"], b["signs"]) == int(b["liar"])
	return {"rung": n * n - int(b["clues"]), "work": (b["signs"] as Array).size() + 1, "unique": liar_ok}
