extends Logger

## Hands the engine's errors and warnings to Crashlytics as breadcrumbs, so a
## crash report carries the last things that went wrong before it. Godot calls
## a Logger from whichever thread printed, and the native Crashlytics bridge is
## only safe on the main thread, so this side only queues: `core/analytics.gd`
## drains the queue from its node once a second.
##
## Capped, because one error repeated every frame once grew godot.log to
## 3.2 GB: a line identical to the one before it is dropped, and after
## `MAX_LINES` in a session the rest are counted, not kept.

const MAX_LINES := 200
const MAX_LEN := 300

var _mutex := Mutex.new()
var _queue: PackedStringArray = []
var _last := ""
var _kept := 0
var _dropped := 0

func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var kind := "WARNING" if error_type == ERROR_TYPE_WARNING else "ERROR"
	var what := rationale if not rationale.is_empty() else code
	# push_error() reports its own C++ line; the script frame that called it
	# is the useful one, when the build tracks script call stacks.
	for bt in script_backtraces:
		if bt.get_frame_count() > 0:
			file = bt.get_frame_file(0)
			line = bt.get_frame_line(0)
			function = bt.get_frame_function(0)
			break
	_push("%s %s (%s:%d %s)" % [kind, what, file.get_file(), line, function])

func _log_message(_message: String, _error: bool) -> void:
	pass  # print() output is not a breadcrumb; the game prints a lot of it

func _push(text: String) -> void:
	_mutex.lock()
	if text != _last:
		_last = text
		if _kept < MAX_LINES:
			_queue.append(text.substr(0, MAX_LEN))
			_kept += 1
		else:
			_dropped += 1
	_mutex.unlock()

## Everything queued since the last call, and how many lines the cap has
## swallowed this session.
func drain() -> Array:
	_mutex.lock()
	var out := [_queue, _dropped]
	_queue = []
	_mutex.unlock()
	return out
