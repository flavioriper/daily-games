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
	var now := int(Time.get_datetime_dict_from_system(true).year)
	var tmp := OS.get_user_data_dir() + "/_probe_age.cfg"
	DirAccess.remove_absolute(tmp)
	AgeGate.path = tmp
	AgeGate.forget()
	_check(not AgeGate.known() and AgeGate.band(now) == AgeGate.UNKNOWN, "unknown before an answer")
	AgeGate.set_birth_year(now - 12)
	_check(AgeGate.band(now) == AgeGate.CHILD, "now-12 is a child (11 or 12)")
	AgeGate.set_birth_year(now - 14)
	_check(AgeGate.band(now) == AgeGate.TEEN, "now-14 is a teen (13)")
	AgeGate.set_birth_year(now - 18)
	_check(AgeGate.band(now) == AgeGate.TEEN, "now-18 stays a teen (17, the younger age)")
	AgeGate.set_birth_year(now - 19)
	_check(AgeGate.band(now) == AgeGate.ADULT, "now-19 is an adult (18)")
	AgeGate.forget()
	_check(AgeGate.birth_year() == now - 19, "the year survives a reload")
	var ads: Node = root.get_node("Ads")
	_check(ads.ad_request().extras.is_empty(), "an adult's request is not flagged npa")
	AgeGate.set_birth_year(now - 14)
	_check(str(ads.ad_request().extras.get("npa", "")) == "1", "a teen's request is npa=1")
	DirAccess.remove_absolute(tmp)
	print("age gate: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
