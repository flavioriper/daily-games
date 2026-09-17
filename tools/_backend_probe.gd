extends SceneTree

## Drives core/backend.gd against the Firebase emulator suite and prints what
## came back. Not a test: a harness, for reading with your eyes.
##
##   cd server && firebase emulators:start --only auth,firestore,functions &
##   FIREBASE_EMULATOR=127.0.0.1 godot --headless --path . \
##     --script res://tools/_backend_probe.gd

const Backend = preload("res://core/backend.gd")
const DailySeed = preload("res://core/daily.gd")

var _done := false

func _process(_delta: float) -> bool:
	if not _done:
		_done = true
		_run()
	return false

func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	await Backend.start(host)
	print("started=%s uid=%s" % [Backend.started(), Backend.uid()])
	var day := DailySeed.date_key()

	var content := await Backend.day_content("how_big", day)
	print("content ok=%s error=%s data=%s" % [content.ok, content.error, content.data])

	var sent := await Backend.submit("how_big", day,
		{"score": 73, "guess": 1.4, "locale": "es"})
	print("submit ok=%s error=%s data=%s" % [sent.ok, sent.error, sent.data])

	var crowd := await Backend.tally("how_big", day)
	print("tally ok=%s error=%s data=%s" % [crowd.ok, crowd.error, crowd.data])
	print("percentile(73)=%d" % Backend.percentile(crowd.data, 73))
	quit(0)
