extends RefCounted

var passed := 0
var failed := 0
var current := ""

func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL [%s] %s" % [current, msg])

func eq(a, b, msg: String) -> void:
	check(a == b, "%s -- got %s, want %s" % [msg, a, b])
