extends SceneTree

## Gold, gifts and boosters on screen (spec 2026-09-28-gold-gifts-design.md):
## the gifts sheet opening by itself, a claim in flight, the Arcade tab's
## strip, the shop, a boost card before Molehill (bare and picked), the
## Second chance at time up and the end card with its gold. Runs on a
## throwaway wallet and puts user://arcade.cfg back afterwards.
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_gold.gd -- <outdir>

const STEPS := [
	[2.1, "shot", "gold_1_gifts"],
	[2.2, "claim"],
	[2.45, "shot", "gold_2_claim"],
	[3.3, "shot", "gold_3_claimed"],
	[3.6, "quit"],
]

var _menu: Node
var _t := 0.0
var _i := 0
var _out := "/tmp"
var _arcade_backup := PackedByteArray()
var _had_arcade := false
var _wallet_tmp := ""

func _initialize() -> void:
	# The first play's tutorial card would stand over the run and eat the taps.
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_had_arcade = FileAccess.file_exists("user://arcade.cfg")
	if _had_arcade:
		_arcade_backup = FileAccess.get_file_as_bytes("user://arcade.cfg")
	var wallet: Node = root.get_node("Wallet")
	_wallet_tmp = OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(_wallet_tmp)
	wallet.path = _wallet_tmp
	wallet.reload()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _finish() -> void:
	if _had_arcade:
		var f := FileAccess.open("user://arcade.cfg", FileAccess.WRITE)
		f.store_buffer(_arcade_backup)
		f.close()
	else:
		DirAccess.remove_absolute(OS.get_user_data_dir() + "/arcade.cfg")
	DirAccess.remove_absolute(_wallet_tmp)
	print("restored arcade.cfg")

func _process(delta: float) -> bool:
	_t += delta
	if _t > 30.0:
		_finish()
		return true
	while _i < STEPS.size() and _t >= float(STEPS[_i][0]):
		var step: Array = STEPS[_i]
		_i += 1
		match String(step[1]):
			"shot":
				RenderingServer.force_draw()
				var path := "%s/%s.png" % [_out, step[2]]
				root.get_texture().get_image().save_png(path)
				print("saved %s draw_calls=%d" % [path, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
			"claim":
				print("gifts sheet open: ", _menu.gifts_sheet.is_open())
				_menu.gifts_sheet._claim_day()
			"quit":
				_finish()
				return true
	return false
