extends RefCounted

## The link the game was opened with. `DeepLink.take()` answers it once and
## "" from then on, so world/main.gd can ask at the start and on every resume
## and a friend link is acted on a single time.
##
## On Android it is the data of the activity's intent: the FriendLink alias
## tools/patch_android_template.sh puts in the manifest sends a
## `peepletdaily://f/<CODE>` or a `https://daily-games-420bf.web.app/f/<CODE>`
## to the game's one activity, at launch or -- the game already open -- through
## onNewIntent, where Godot's activity makes it the current intent
## (GodotActivity.onNewIntent calls setIntent; read off the 4.7 template's
## classes). The intent is still the current one on every later resume, which
## is why what was taken is remembered: by the intent's identity where the
## bridge reaches `hashCode`, so the same link opened a second time counts
## again, and by its text alone where it does not.
##
## Everywhere else it is a `--link=<url>` user argument (after `--` on the
## command line), which is how a harness or a desktop run opens one. iOS has
## no way in without a native plugin. Every step is guarded: no singleton, no
## activity, no intent or no data is "", never an error.
## Notes and what is unproven on a device: docs/agents/friends.md, "The link".

const ARG := "--link="

## The intent (or the argument) already handed out.
static var _taken := ""
static var _arg_read := false

## Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY.
const FROM_HISTORY := 0x00100000

static func take() -> String:
	if OS.get_name() == "Android":
		return _from_intent()
	if _arg_read:
		return ""
	_arg_read = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(ARG):
			return arg.substr(ARG.length())
	return ""

static func _from_intent() -> String:
	if not Engine.has_singleton("AndroidRuntime"):
		return ""
	var runtime := Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		return ""
	var activity: Variant = runtime.getActivity()
	if activity == null:
		return ""
	var intent: Variant = activity.getIntent()
	if intent == null:
		return ""
	# A task brought back from Recents is handed the intent it began with: a
	# link already acted on, perhaps for a friend since removed.
	if intent.has_java_method("getFlags") and (int(intent.getFlags()) & FROM_HISTORY) != 0:
		return ""
	var data: Variant = intent.getDataString()
	if not (data is String) or data == "":
		return ""
	var key: String = data
	if intent.has_java_method("hashCode"):
		# Intent does not override it, so this is the object's identity.
		key = "%s|%s" % [intent.hashCode(), data]
	if key == _taken:
		return ""
	_taken = key
	return data
