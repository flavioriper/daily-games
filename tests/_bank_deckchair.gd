extends SceneTree

## Writes arcade/deckchair_deals.gd: seeds the bot wins with no help at all
## and no deckchair, so every deal the game hands out can be won.
##   godot --headless --script tests/_bank_deckchair.gd -- [seeds] [out.gd]
## Rerun only if the sim's shuffle changes.

const Sim = preload("res://arcade/deckchair_sim.gd")
const MOST := 800

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 2000
	var path: String = args[1] if args.size() > 1 else "res://arcade/deckchair_deals.gd"
	var bank := []
	for seed_value in range(1, seeds + 1):
		var s = Sim.new(seed_value)
		s.has_chair = false
		s._plan.clear()
		if _won(s):
			bank.append(seed_value)
			if bank.size() >= MOST:
				break
	var lines := []
	for at in range(0, bank.size(), 14):
		lines.append("\t" + ", ".join(bank.slice(at, at + 14).map(func(v: int) -> String: return str(v))) + ",")
	var out := "extends RefCounted\n\n## Deals of Deckchair the bot won with no help and no deckchair, written by\n## tests/_bank_deckchair.gd: seeds of arcade/deckchair_sim.gd. Every deal the\n## screen hands out comes from here.\n\nconst DEALS := [\n" + "\n".join(lines) + "\n]\n"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(out)
	f.close()
	print("bank %d" % bank.size())
	quit()

func _won(s) -> bool:
	var n := 0
	while s.phase == Sim.Phase.PLAY and n < 3000:
		n += 1
		var m: Dictionary = s.find_move()
		if m.is_empty():
			return false
		if not (s.draw() if m.has("draw") else s.drop(int(m.card), int(m.kind), int(m.i))):
			return false
		s.events.clear()
	return s.phase == Sim.Phase.WON
