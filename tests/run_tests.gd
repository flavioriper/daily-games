extends SceneTree

## Headless test runner. Each suite's run(t) executes during _initialize, before
## the root enters the tree, which is fine for pure logic. A suite that needs a
## live tree (nodes with _ready, node-bound tweens) also defines
## run_in_tree(t); those run on the first process frame.

var _t
var _tree_suites: Array = []
var _init_done := false

func _initialize() -> void:
	_t = load("res://tests/t.gd").new()
	var suites := {
		"palette": "res://tests/test_palette.gd",
		"board_math": "res://tests/test_board_math.gd",
		"toon": "res://tests/test_toon.gd",
		"motion": "res://tests/test_motion.gd",
		"ambient": "res://tests/test_ambient.gd",
		"fx": "res://tests/test_fx.gd",
		"models": "res://tests/test_models.gd",
		"platform": "res://tests/test_platform.gd",
		"binairo": "res://tests/test_binairo.gd",
		"binairo3d": "res://tests/test_binairo3d.gd",
		"mastermind": "res://tests/test_mastermind.gd",
		"balance": "res://tests/test_balance.gd",
		"pipes": "res://tests/test_pipes.gd",
		"untangle": "res://tests/test_untangle.gd",
		"shikaku": "res://tests/test_shikaku.gd",
		"tents": "res://tests/test_tents.gd",
		"lightup": "res://tests/test_lightup.gd",
		"oneline": "res://tests/test_oneline.gd",
		"nonogram": "res://tests/test_nonogram.gd",
	}
	for suite_name in suites:
		_t.current = suite_name
		var script = load(suites[suite_name])
		# A suite with a parse error still loads as a GDScript object, but
		# calling into it aborts _initialize before quit() and hangs the run.
		if script == null or not script.can_instantiate():
			_t.failed += 1
			print("  FAIL [%s] could not load suite" % suite_name)
			continue
		if _has_static(script, "run"):
			script.run(_t)
		if _has_static(script, "run_in_tree"):
			_tree_suites.append([suite_name, script])
	_init_done = true

func _process(_delta: float) -> bool:
	if not _init_done:
		# _initialize aborted on a script error; a green exit here would hide it.
		print("\nFAIL runner: _initialize did not complete")
		quit(1)
		return true
	for pair in _tree_suites:
		_t.current = pair[0]
		pair[1].run_in_tree(_t)
	print("\npassed=%d failed=%d" % [_t.passed, _t.failed])
	quit(1 if _t.failed > 0 else 0)
	return true

static func _has_static(script: Script, method: String) -> bool:
	for m in script.get_script_method_list():
		if m.name == method:
			return true
	return false
