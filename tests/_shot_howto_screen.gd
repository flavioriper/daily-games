extends SceneTree

## The tutorial card of a Versus or Arcade screen, every page shot as it plays:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_howto_screen.gd -- <game> <outdir> [lang=pt] [level=2] [secs=6] [every=1.5] [reduce]
##
## <game> is snooker, chess, checkers, hockey, boats, penny, dominoes, reversi, firefly, molehill, stackwood, thirteen,
## posy, peapod or beeline. The screen is built by hand, the card opened as the ? opens
## it (`tutor.show()`), and each page is shot every `every` seconds for `secs`
## before Next is pressed: <outdir>/ht_<game>_p<page>_<n>.png. Prints each
## page's title, how long its body runs against the room it has, and the draw
## calls. The card is freed, never continued, so this Mac's progress file is
## not marked; user://versus.cfg and user://arcade.cfg are put back on every
## way out.

const SCREENS := {
	"snooker": "res://versus/snooker_screen.gd",
	"chess": "res://versus/chess_screen.gd",
	"checkers": "res://versus/checkers_screen.gd",
	"hockey": "res://versus/hockey_screen.gd",
	"boats": "res://versus/boats_screen.gd",
	"penny": "res://versus/penny_screen.gd",
	"dominoes": "res://versus/dominoes_screen.gd",
	"reversi": "res://versus/reversi_screen.gd",
	"firefly": "res://arcade/firefly_screen.gd",
	"molehill": "res://arcade/molehill_screen.gd",
	"stackwood": "res://arcade/stackwood_screen.gd",
	"thirteen": "res://arcade/thirteen_screen.gd",
	"posy": "res://arcade/posy_screen.gd",
	"peapod": "res://arcade/peapod_screen.gd",
	"beeline": "res://arcade/beeline_screen.gd",
}
const SAVES := ["user://versus.cfg", "user://arcade.cfg"]

var _game := ""
var _out := "/tmp"
var _secs := 6.0
var _every := 1.5
var _level := 1
var _s: Control
var _card: Control
var _t := 0.0
var _page := -1
var _page_at := 0.0
var _shots := 0
var _before := {}
var _frames := 0

func _initialize() -> void:
	# Peapod's carts' card would stand before its run
	load("res://arcade/peapod_screen.gd").force_cart = 0
	for path: String in SAVES:
		if FileAccess.file_exists(path):
			_before[path] = FileAccess.get_file_as_string(path)
	var rest: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("lang="):
			TranslationServer.set_locale(a.substr(5))
		elif a.begins_with("level="):
			_level = int(a.substr(6))
		elif a.begins_with("secs="):
			_secs = float(a.substr(5))
		elif a.begins_with("every="):
			_every = float(a.substr(6))
		elif a == "reduce":
			load("res://core/motion.gd").reduce = true
		else:
			rest.append(a)
	if rest.size() < 1 or not SCREENS.has(rest[0]):
		print("usage: -- <game> <outdir> [lang=xx] [level=n] [secs=n] [every=n] [reduce]")
		quit(1)
		return
	_game = rest[0]
	if rest.size() > 1:
		_out = rest[1]
	# A throwaway wallet, so a run never spends or earns this Mac's gold.
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	# load(), not preload: the screens name the Ads autoload.
	var script: GDScript = load(SCREENS[_game])
	_s = script.new(_level) if _game in ["snooker", "chess", "checkers", "hockey", "boats", "penny", "dominoes", "reversi"] else script.new()
	root.add_child(_s)

func _restore() -> void:
	for path: String in SAVES:
		if _before.has(path):
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(_before[path])
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _shot() -> void:
	RenderingServer.force_draw()
	var name := "%s/ht_%s_p%d_%d.png" % [_out, _game, _page, _shots]
	root.get_texture().get_image().save_png(name)
	print("  shot %s at %.1f draws=%d" % [name.get_file(), _t - _page_at,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	_shots += 1

func _open_page(i: int) -> void:
	_page = i
	_page_at = _t
	_shots = 0
	var body: Label = _card._body
	var lines := body.get_line_count()
	var tall := lines * body.get_line_height()
	print("page %d/%d  title=%s  body lines=%d  %.0f px of %.0f%s" % [i + 1, _card._pages.size(),
		_card._title.text, lines, tall, body.custom_minimum_size.y,
		"  OVERFLOWS" if body.custom_minimum_size.y > 0.0 and tall > body.custom_minimum_size.y else ""])

func _process(delta: float) -> bool:
	_t += delta
	_frames += 1
	if _t > 180.0:
		print("timed out on page ", _page)
		_restore()
		return true
	if _card == null:
		# The screen's own entrance first.
		if _frames < 20:
			return false
		_s.tutor.show()
		_card = _s.get_node_or_null("HowToPlay")
		if _card == null:
			print("no card")
			_restore()
			return true
		print("%s: %d pages, card %s" % [_game, _card._pages.size(), "wired" if _s.top_bar.help_button.visible else "? HIDDEN"])
		return false
	if _page < 0:
		_open_page(0)
		return false
	var due := 0.4 + _shots * _every
	if _t - _page_at >= due and due <= _secs:
		_shot()
		return false
	if _t - _page_at > _secs:
		if _page >= _card._pages.size() - 1:
			_card.free()
			print("done; paused=%s" % [str(_s.get("_paused"))])
			_restore()
			return true
		_card._turn(1)
		_open_page(_page + 1)
	return false
