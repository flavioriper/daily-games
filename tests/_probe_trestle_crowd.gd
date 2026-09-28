extends SceneTree

## Trestle's crowd against the Firebase emulator suite: four fresh players
## submit a cost score to trestle_1, a made-up game is refused, and a tally
## written the way rollupTally writes it comes back through Backend.tally.
##
##   cd server && firebase emulators:start --only auth,firestore,functions --project demo-peeplet &
##   FIREBASE_EMULATOR=127.0.0.1 FIREBASE_PROJECT=demo-peeplet godot --headless --path . \
##     --script res://tests/_probe_trestle_crowd.gd
##
## It signs up fresh identities, so user://player.cfg is overwritten: back
## it up first and put it back after (a real refresh token sent to the
## emulator is refused and then dropped).

const Backend = preload("res://core/backend.gd")
const DailySeed = preload("res://core/daily.gd")

var _started := false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _fresh(host: Node) -> void:
	Backend.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Backend.PLAYER_PATH))
	Backend._uid = ""
	Backend._refresh_token = ""
	Backend._id_token = ""
	Backend._expires_at = 0.0
	await Backend.start(host)

func _run() -> void:
	if OS.get_environment("FIREBASE_EMULATOR").is_empty():
		print("FIREBASE_EMULATOR is not set: refusing to touch the live project")
		quit(1)
		return
	var host := Node.new()
	root.add_child(host)
	var day := DailySeed.date_key()
	for score in [60, 70, 80, 90]:
		await _fresh(host)
		var got := await Backend.submit("trestle_1", day, {"score": score, "locale": "pt"})
		print("uid %s submit %d -> ok=%s data=%s error=%s" % [Backend.uid().left(6), score, got.ok, got.data, got.error])
	var bad := await Backend.submit("trestle_9", day, {"score": 50, "locale": "en"})
	print("trestle_9 -> ok=%s error=%s" % [bad.ok, bad.error])
	# the rollup, written as rollupTally writes it
	var hist := []
	hist.resize(101)
	hist.fill(0)
	for s in [60, 70, 80, 90]:
		hist[s] += 1
	var doc := {"fields": {"json": {"stringValue": JSON.stringify({"count": 4, "histogram": hist, "byLocale": {"pt": 4}})}}}
	var url := "%s/days/%d/turns/trestle_1/tally/current" % [Backend._docs(), day]
	var res := await Backend._http(url, HTTPClient.METHOD_PATCH, ["Content-Type: application/json", "Authorization: Bearer owner"], JSON.stringify(doc))
	print("seed tally -> %s %s" % [res.code, res.error])
	var crowd := await Backend.tally("trestle_1", day)
	print("tally ok=%s count=%s nonzero=%s" % [crowd.ok, crowd.data.get("count"), (crowd.data.get("histogram", []) as Array).filter(func(v): return int(v) > 0).size()])
	quit(0)
