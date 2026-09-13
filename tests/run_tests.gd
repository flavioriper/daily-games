extends SceneTree

func _initialize() -> void:
	var t = load("res://tests/t.gd").new()
	var suites := {
		"palette": "res://tests/test_palette.gd",
		"board_math": "res://tests/test_board_math.gd",
		"toon": "res://tests/test_toon.gd",
		"models": "res://tests/test_models.gd",
		"binairo": "res://tests/test_binairo.gd",
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
		t.current = suite_name
		var script = load(suites[suite_name])
		if script == null:
			t.failed += 1
			print("  FAIL [%s] could not load suite" % suite_name)
			continue
		script.run(t)
	print("\npassed=%d failed=%d" % [t.passed, t.failed])
	quit(1 if t.failed > 0 else 0)
