extends "res://world/main.gd"

## world/main.gd for a harness that builds the real main scene and must not
## reach the network: everything the scene root does except its `_ready`,
## which is where Analytics, Backend and Ads are started (against the live
## project, since nothing names an emulator). A harness puts this script on
## the instance before it enters the tree:
##
##     var main: Node = load("res://world/main.tscn").instantiate()
##     main.set_script(load("res://tests/_offline_main.gd"))
##     root.add_child(main)
##
## Stopping the three on the harness's first frame is not the same thing: by
## then `_ready` has run, `game_open` has been handed to an HTTPRequest and a
## sign-in has begun, and only the frame's end takes them back.

func _ready() -> void:
	# The lines of the real _ready that are not a start. A link is only
	# taken when the harness has given the game a Social.fake (unstarted,
	# _take_link does nothing): `-- --link=<url>` then opens it offline.
	$UI/BannerHost.tapped.connect(_open_store)
	_take_link()
