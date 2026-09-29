extends SceneTree

## The age gate's arithmetic and the request each band makes, headless.
##   godot --headless --script tests/_probe_age_gate.gd

const AgeGate = preload("res://core/age_gate.gd")

var _fails := 0
var _frames := 0

func _check(ok: bool, what: String) -> void:
	_fails += 0 if ok else 1
	print("ok   " if ok else "FAIL ", what)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	var tmp := OS.get_user_data_dir() + "/_probe_age.cfg"
	DirAccess.remove_absolute(tmp)
	AgeGate.path = tmp
	AgeGate.reload()
	_check(not AgeGate.known() and AgeGate.band(2026) == AgeGate.UNKNOWN, "unknown before an answer")
	AgeGate.set_birth_year(2014)
	_check(AgeGate.band(2026) == AgeGate.CHILD, "2014 in 2026 is a child (11 or 12)")
	AgeGate.set_birth_year(2012)
	_check(AgeGate.band(2026) == AgeGate.TEEN, "2012 in 2026 is a teen (13)")
	AgeGate.set_birth_year(2008)
	_check(AgeGate.band(2026) == AgeGate.TEEN, "2008 in 2026 stays a teen (17, the younger age)")
	AgeGate.set_birth_year(2007)
	_check(AgeGate.band(2026) == AgeGate.ADULT, "2007 in 2026 is an adult (18)")
	AgeGate.reload()
	_check(AgeGate.birth_year() == 2007, "the year survives a reload")
	var ads: Node = root.get_node("Ads")
	_check(ads.ad_request().extras.is_empty(), "an adult's request is not flagged npa")
	AgeGate.set_birth_year(2012)
	_check(str(ads.ad_request().extras.get("npa", "")) == "1", "a teen's request is npa=1")
	DirAccess.remove_absolute(tmp)
	print("age gate: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
