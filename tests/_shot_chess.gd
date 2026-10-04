extends SceneTree

## The Versus tab and a game of chess, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_chess.gd -- <outdir>
##
## 1 the tab, 2 the set entering, 3 ready, 4 a pawn picked up, 5 mid-hop,
## 6 the computer's reply in the air, 7 a knight mid-leap, 8 a capture
## tumbling to the tray, 9 the promotion picker, 10 check, 11 the mate
## toppling, 12 the end card. Prints the draw calls at each shot. The
## record this machine had is put back at the end.

const Rules = preload("res://versus/chess_rules.gd")

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _wait := 0.0
var _record_before := ""
var _had_record := false

func _initialize() -> void:
	# The first play's tutorial card would stand over the run and eat the taps.
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_had_record = FileAccess.file_exists("user://versus.cfg")
	if _had_record:
		_record_before = FileAccess.get_file_as_string("user://versus.cfg")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/chs_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

func sq(n: String) -> int:
	return "abcdefgh".find(n[0]) + (int(n[1]) - 1) * 8

func find(a: String, b: String, promo := 0) -> int:
	for m in _s.rules.legal_moves():
		if Rules.mv_from(m) == sq(a) and Rules.mv_to(m) == sq(b) and (promo == 0 or Rules.mv_promo(m) == promo):
			return m
	return -1

## A position from a FEN-ish board string, set on the screen's rules and
## the board re-laid without the entrance.
func setup(rows: String, turn: int) -> void:
	var g: RefCounted = Rules.new(true)
	var map := {"p": 1, "n": 2, "b": 3, "r": 4, "q": 5, "k": 6}
	var rs := rows.split("/")
	for i in 8:
		var r := 7 - i
		var f := 0
		for ch in rs[i]:
			if ch.is_valid_int():
				f += int(ch)
			else:
				var t: int = map[ch.to_lower()]
				g.board[r * 8 + f] = t if ch == ch.to_upper() else -t
				f += 1
	g.turn = turn
	g.castling = 0
	g.rehash()
	g.hashes = PackedInt64Array([g.hash])
	_s._game += 1
	_s.rules = g
	_s._history.clear()
	_s.board.setup(g, _s.player, false)
	_s._state = _s.State.YOURS
	_s.board.interactive = true
	_s._refresh_board()

func _process(delta: float) -> bool:
	_t += delta
	if _t < _wait:
		return false
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("versus")
				_step = 1
				_wait = _t + 0.8
		1:
			_shot("01_tab")
			var cfg := ConfigFile.new()
			cfg.load("user://versus.cfg")
			cfg.set_value("colour", "chess", 0)
			cfg.save("user://versus.cfg")
			_menu._open_versus("chess", 1)
			_s = _menu.get_node("Chess")
			_step = 2
			_wait = _t + 0.9
		2:
			_shot("02_enter")
			_step = 3
		3:
			if _s._state == _s.State.YOURS:
				_wait = _t + 0.6
				_step = 4
		4:
			_shot("03_ready")
			_s.board._select(sq("e2"))
			_step = 5
			_wait = _t + 0.5
		5:
			_shot("04_picked")
			_s._on_chosen(find("e2", "e4"))
			_step = 6
			_wait = _t + 0.3
		6:
			_shot("05_hop")
			_step = 7
		7:
			if _s._state == _s.State.ANIM and _s.rules.turn == Rules.BLACK:
				_wait = _t + 0.5
				_step = 8
		8:
			_shot("06_bot_move")
			_step = 9
		9:
			if _s._state == _s.State.YOURS:
				_s._on_chosen(find("g1", "f3"))
				_step = 10
				_wait = _t + 0.4
		10:
			_shot("07_knight_leap")
			_step = 11
		11:
			if _s._state == _s.State.YOURS:
				# A capture: the queen takes a knight that has wandered in.
				setup("r1b1kbnr/pppp1ppp/8/4p3/3nP3/5Q2/PPPP1PPP/RNB1KBNR", Rules.WHITE)
				_wait = _t + 0.4
				_step = 12
		12:
			_s._on_chosen(find("f3", "f7") if find("f3", "f7") >= 0 else find("f3", "d3"))
			_step = 13
			_wait = _t + 0.62
		13:
			_shot("08_capture")
			_step = 14
			_wait = _t + 1.2
		14:
			_shot("08b_tray")
			# A promotion: the pawn on b7 steps to b8.
			setup("4k3/1P6/8/8/8/8/5PPP/6K1", Rules.WHITE)
			_wait = _t + 0.3
			_step = 15
		15:
			_s.board._select(sq("b7"))
			_s.board._choose(sq("b8"))
			_step = 16
			_wait = _t + 0.4
		16:
			_shot("09_promotion")
			_s.board._pick_promotion(_s.board.px(_s.board.cell_of(sq("b8"))))
			_step = 17
			_wait = _t + 0.55
		17:
			_shot("09b_promoting")
			_step = 18
			_wait = _t + 1.4
		18:
			# Check, then mate: the rook comes down to the eighth rank.
			setup("6k1/5ppp/8/8/8/8/5PPP/R5K1", Rules.WHITE)
			_s.level = 0
			_wait = _t + 0.3
			_step = 19
		19:
			_s._on_chosen(find("a1", "a8"))
			_step = 20
			_wait = _t + 1.1
		20:
			_shot("10_mate_topple")
			_step = 21
			_wait = _t + 2.4
		21:
			_shot("11_end")
			if _had_record:
				var f := FileAccess.open("user://versus.cfg", FileAccess.WRITE)
				f.store_string(_record_before)
			else:
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))
			quit()
	if _t > 60.0:
		print("timeout at step ", _step, " state ", _s._state if _s != null else -1)
		quit()
	return false
