extends SceneTree

## The Insane miner: runs one board's generator at its Insane band's knobs
## through that board's technique ladder and keeps the hardest, uniquely
## solvable boards Hard's own solver cannot finish.
##
##   godot --headless --path . --script tools/mine_insane.gd -- <puzzle_id> <count> [tries]
##
## tries defaults to count * 50. The ladder contract this script requires is
## in tools/insane/README.md; a ladder script never loads in the game.

const InsaneBank = preload("res://core/insane_bank.gd")

var _exit_code := 0

func _initialize() -> void:
	_exit_code = _run()

func _process(_delta: float) -> bool:
	quit(_exit_code)
	return true

func _run() -> int:
	var usage := "usage: godot --headless --path . --script tools/mine_insane.gd -- <puzzle_id> <count> [tries]"
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args[0].is_empty() or args[1].is_empty() or not args[1].is_valid_int():
		print(usage)
		return 1
	var puzzle_id: String = args[0]
	var count: int = int(args[1])
	if count <= 0:
		print(usage)
		return 1
	var tries := count * 50
	if args.size() >= 3 and args[2].is_valid_int():
		tries = int(args[2])

	var ladder_path := "res://tools/insane/%s_ladder.gd" % puzzle_id
	if not ResourceLoader.exists(ladder_path):
		print("no ladder for %s" % puzzle_id)
		return 1
	var ladder: GDScript = load(ladder_path)
	if ladder == null or not ladder.can_instantiate():
		print("no ladder for %s" % puzzle_id)
		return 1

	var hard_rung: int = ladder.HARD_RUNG
	var kept: Array = []
	var rng := RandomNumberGenerator.new()
	for i in range(tries):
		rng.seed = i
		var board: Dictionary = ladder.candidate(rng)
		var grade: Dictionary = ladder.grade(board)
		if grade.get("unique", false) and int(grade.get("rung", -1)) > hard_rung:
			kept.append({"board": board, "grade": grade})

	kept.sort_custom(func(a, b) -> bool:
		var ga: Dictionary = a["grade"]
		var gb: Dictionary = b["grade"]
		if ga["rung"] != gb["rung"]:
			return ga["rung"] > gb["rung"]
		return ga["work"] > gb["work"])

	var written: Array = kept.slice(0, min(count, kept.size()))
	var out_boards: Array = []
	var min_rung := 0
	var max_rung := 0
	for i in range(written.size()):
		var entry: Dictionary = written[i]
		var b: Dictionary = entry["board"].duplicate()
		b["grade"] = entry["grade"]
		out_boards.append(b)
		var r: int = entry["grade"]["rung"]
		min_rung = r if i == 0 else min(min_rung, r)
		max_rung = r if i == 0 else max(max_rung, r)

	var out_path := InsaneBank.DIR + puzzle_id + ".json"
	_ensure_dir(InsaneBank.DIR)

	# Never overwrite without printing the old file's size first.
	if FileAccess.file_exists(out_path):
		var old_doc = JSON.parse_string(FileAccess.get_file_as_string(out_path))
		var old_count := 0
		if old_doc is Dictionary and old_doc.get("boards") is Array:
			old_count = old_doc["boards"].size()
		print("overwriting %s (had %d boards)" % [out_path, old_count])

	var note := "%s Insane, mined %s, %d/%d kept, rungs %d-%d" % [
		puzzle_id, Time.get_date_string_from_system(), kept.size(), tries, min_rung, max_rung
	]
	var doc := {"version": 1, "note": note, "boards": out_boards}

	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("could not write %s (err %d)" % [out_path, FileAccess.get_open_error()])
		return 1
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()

	print(note)
	print("wrote %d/%d boards to %s" % [out_boards.size(), count, out_path])
	_print_histogram(kept, tries)
	return 0

func _ensure_dir(dir_res_path: String) -> void:
	var abs := ProjectSettings.globalize_path(dir_res_path)
	if not DirAccess.dir_exists_absolute(abs):
		DirAccess.make_dir_recursive_absolute(abs)

## Histograms every candidate that passed the gate, not just the top `count`
## actually written -- a thin ladder should show up here before truncation.
func _print_histogram(kept: Array, tries: int) -> void:
	var counts: Dictionary = {}
	for entry in kept:
		var r: int = entry["grade"]["rung"]
		counts[r] = int(counts.get(r, 0)) + 1
	var rungs := counts.keys()
	rungs.sort()
	print("rung histogram (%d/%d candidates passed the gate):" % [kept.size(), tries])
	for r in rungs:
		print("  rung %d: %d" % [r, counts[r]])
