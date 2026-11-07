@tool
extends EditorPlugin

## Puts the Swarm's call audio plugin (native/swarm_voice, built by
## tools/build_swarm_voice.sh) into Android exports. The game reaches it as
## Engine.get_singleton("SwarmVoice") (bot/call.gd).

var _android: AndroidExport


func _enter_tree() -> void:
	_android = AndroidExport.new()
	add_export_plugin(_android)


func _exit_tree() -> void:
	if _android:
		remove_export_plugin(_android)
		_android = null


class AndroidExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "SwarmVoice"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	## Debug exports only (the Firebase testers' APKs): a release export is the
	## Play build, which must carry no microphone code (tools/release_android.sh).
	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if not debug:
			return PackedStringArray()
		return PackedStringArray(["res://addons/swarm_voice/android/swarm_voice.debug.aar"])
