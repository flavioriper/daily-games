extends RefCounted

## Mastermind. The point of including it: this produces Wordle's exact share
## grid -- a per-guess history of coloured markers -- with a one-line generator
## and zero language content.

static func make_code(rng: RandomNumberGenerator, length: int, palette: int, repeats: bool) -> Array:
	if not repeats:
		assert(palette >= length, "need at least as many colours as slots")
		var pool: Array = []
		for i in palette:
			pool.append(i)
		for i in range(pool.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp = pool[i]; pool[i] = pool[j]; pool[j] = tmp
		return pool.slice(0, length)
	var code: Array = []
	for i in length:
		code.append(rng.randi_range(0, palette - 1))
	return code

## Returns {exact, colour}: exact = right colour in the right place,
## colour = right colour in the wrong place. Standard Mastermind scoring,
## where each peg in the code is consumed by at most one peg in the guess.
static func score(guess: Array, code: Array) -> Dictionary:
	var exact := 0
	var code_left: Dictionary = {}
	var guess_left: Dictionary = {}
	for i in guess.size():
		if guess[i] == code[i]:
			exact += 1
		else:
			code_left[code[i]] = code_left.get(code[i], 0) + 1
			guess_left[guess[i]] = guess_left.get(guess[i], 0) + 1
	var colour := 0
	for k in guess_left:
		colour += mini(int(guess_left[k]), int(code_left.get(k, 0)))
	return {"exact": exact, "colour": colour}
