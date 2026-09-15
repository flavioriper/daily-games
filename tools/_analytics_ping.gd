extends SceneTree

## Sends one event to the live stream, tagged so it turns up in GA4's
## DebugView within seconds. Run through tools/analytics_secret.sh.
##
## GA4's collect endpoint answers every request the same way, valid or not, so
## nothing here can prove the secret is good -- DebugView is the proof.

const Analytics = preload("res://core/analytics.gd")

var _start := 0.0
var _sent := false

func _process(_delta: float) -> bool:
	if not _sent:
		_sent = true
		_start = Time.get_unix_time_from_system()
		Analytics.debug_mode = true
		Analytics.start(root)
		if not Analytics.started():
			print("analytics: no secret found, nothing sent")
			return true
		Analytics.track("game_open", {"day": 0})
		print("analytics: sent game_open as install ", Analytics.instance_id())
	return Time.get_unix_time_from_system() - _start > 5.0
