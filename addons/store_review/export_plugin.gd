@tool
extends EditorPlugin

## Puts the store rating sheet plugin (native/store_review, built by
## tools/build_store_review.sh) into Android exports, with Play's review
## library it calls. iOS takes ios/plugins/store_review through the preset's
## plugins/StoreReview. The game reaches both as
## Engine.get_singleton("StoreReview") (core/review.gd).

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
		return "StoreReview"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray(["res://addons/store_review/android/store_review.debug.aar"])
		return PackedStringArray(["res://addons/store_review/android/store_review.release.aar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["com.google.android.play:review:2.0.2"])
