extends SceneTree

## The Arcade tab and two deals of Deckchair, shot at fixed beats:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_deckchair.gd -- <outdir> [reduce] [en|pt|es]
##
## 1 the Arcade tab, 2 a deal laid (seed 2, which dead-ends), then three
## real fingers through the viewport, each printed: a touch on the stock
## (a card turned), a ScreenDrag carrying a card to a column that takes it
## (3 the carry in the air, its rings up) and a touch on a card that has
## somewhere to go. Then a bot plays the sim's own moves: 4 the table mid
## deal, 5 the bulb's rings, 6 the dead end's card, Finish, 7 the end card.
## A second deal (seed 3, which the bot wins): 8 the sweep, 9 the win, 10
## its end card. The moments are shot as they come up, each once, a tenth of
## a second in (m_home, m_ace, m_suit, m_king, m_seam, m_turn: a card home,
## an ace, a king that ends its suit, a king on an empty column, a run laid
## on a card, a card turned up), with m_tap (the pack tapped square), m_deal (the pack dealt), m_recycle
## (the waste going back), m_sigh (the dead end) and m_win (the kings'
## hop); one that never came up is named at the end. Prints the draw calls
## at each shot. The ends write scores
## to user://arcade.cfg, so the file this machine had is put back on every
## way out, the timeout included.

const Sim = preload("res://arcade/deckchair_sim.gd")
const PATH := "user://arcade.cfg"
const DEAD := 2
const WIN := 3
const TIMEOUT := 150.0

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _step := 0
var _at := 0.0
var _before := ""
var _had := false
var _bot := false
var _bot_gap := 0.1
var _bot_at := 0.0
var _moves := 0
## Fingers still to send, one a frame: [what, where] with what 0 a press, 1
## a drag, 2 a release.
var _touches: Array = []
var _carried := -1
var _carry_to := Vector2i(-1, -1)
## The moments shot so far, and the passes the stock had made.
var _seen := {}
var _passes := 0
var _recycled := -1.0
## world/main.gd reads this Mac's settings as it comes up, so reduce motion
## is set again every frame and not once before it.
var _reduce := false

func _initialize() -> void:
	# The first play's tutorial card would stand over the deal and eat the taps.
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_had = FileAccess.file_exists(PATH)
	if _had:
		_before = FileAccess.get_file_as_string(PATH)
	for a: String in OS.get_cmdline_user_args():
		if a == "reduce":
			_reduce = true
		elif a in ["en", "pt", "es"]:
			# the language for this run only: Locale.set_current would write it
			# to this Mac's settings
			load("res://core/locale.gd")._current = a
		else:
			_out = a
	# A throwaway wallet, so a run never spends or earns this Mac's gold.
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_shot_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/dc_%s.png" % [_out, name])
	var sim = _s.sim if _s != null else null
	print("shot %s at %.1f draws=%d score=%d home=%d moves=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		sim.score if sim != null else 0, sim.home_count() if sim != null else 0, sim.moves if sim != null else 0])

func _put_back() -> void:
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_string(_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

## A point of the table in the window's pixels.
func _win(p: Vector2) -> Vector2:
	var tb: Control = _s.table
	return root.get_final_transform() * (tb.get_global_transform_with_canvas() * p)

func _send() -> void:
	if _touches.is_empty():
		return
	var tc: Array = _touches.pop_front()
	if int(tc[0]) == 1:
		var ev := InputEventScreenDrag.new()
		ev.index = 0
		ev.position = tc[1]
		Input.parse_input_event(ev)
	else:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = int(tc[0]) == 0
		ev.position = tc[1]
		Input.parse_input_event(ev)

func _tap_at(p: Vector2) -> void:
	_touches.append([0, _win(p)])
	_touches.append([2, _win(p)])

## A fresh wallet holds boosters, so the boost card stands before every run
## and Second chance before every end card: play with none, and decline.
func _skip_gold() -> void:
	if _s == null:
		return
	var boost: Node = _s.get_node_or_null("BoostCard")
	if boost != null and not boost.is_queued_for_deletion():
		boost._on_play()
	var chance: Node = _s.get_node_or_null("SecondChance")
	if chance != null and not chance.is_queued_for_deletion():
		chance._on_no()

## One of the sim's own moves, through the table as a finger's would go.
func _play_one() -> void:
	var sim = _s.sim
	if sim == null or sim.phase != Sim.Phase.PLAY or sim.sweeping:
		return
	var m: Dictionary = sim.find_move()
	if m.is_empty():
		return
	if m.has("draw"):
		_s.table.tap_stock()
	else:
		sim.drop(int(m.card), int(m.kind), int(m.i))
		_s.table.play_events()
	_moves += 1

## A card that can be carried onto another column, and that column.
func _find_carry() -> bool:
	var sim = _s.sim
	for c in Sim.COLS:
		var pile: Array = sim.cols[c]
		for i in range(int(sim.down[c]), pile.size()):
			for to in Sim.COLS:
				if sim.can_drop(int(pile[i]), Sim.At.COL, to):
					_carried = int(pile[i])
					_carry_to = Vector2i(Sim.At.COL, to)
					return true
	return false

## Shoots each moment of the table's once, a little way into it.
func _watch() -> void:
	if _s == null or _s.sim == null or _s.table == null:
		return
	var tb: Control = _s.table
	for l: Dictionary in tb._lights:
		var kind: String = "m_" + String(l.kind)
		if not _seen.has(kind) and float(l.t) >= 0.1:
			_seen[kind] = true
			_shot(kind)
	var dealing: float = tb._clock - tb._deal_at
	if dealing > 0.1 and dealing < 0.25 and not _seen.has("m_tap"):
		_seen["m_tap"] = true
		_shot("m_tap")
	if dealing > 0.5 and dealing < 0.7 and not _seen.has("m_deal"):
		_seen["m_deal"] = true
		_shot("m_deal")
	if int(_s.sim.passes) != _passes:
		_passes = int(_s.sim.passes)
		_recycled = _t
	if _recycled >= 0.0 and _t > _recycled + 0.12 and not _seen.has("m_recycle"):
		_seen["m_recycle"] = true
		_shot("m_recycle")
	if not _seen.has("m_sigh") and tb._clock - tb._sigh_at > 0.2 and tb._clock - tb._sigh_at < 0.4:
		_seen["m_sigh"] = true
		_shot("m_sigh")
	if not _seen.has("m_win") and tb._clock - tb._won_at > 0.42 and tb._clock - tb._won_at < 1.0:
		_seen["m_win"] = true
		_shot("m_win")

func _process(delta: float) -> bool:
	_t += delta
	if _t > TIMEOUT:
		print("TIMEOUT at step %d" % _step)
		_put_back()
		return true
	if _reduce:
		load("res://core/motion.gd").reduce = true
	_skip_gold()
	_send()
	_watch()
	if _bot and _s != null and _t >= _bot_at:
		_bot_at = _t + _bot_gap
		_play_one()
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_step = 1
		1:
			if _t > 1.8:
				_shot("1_tab")
				_menu._open_arcade("deckchair")
				_s = _menu.get_node("Deckchair")
				_s.deal_seed = DEAD
				_s._new_game()
				_at = _t
				_step = 2
		2:
			if _t > _at + 1.8:
				_shot("2_dealt")
				var tb: Control = _s.table
				_tap_at(tb.stock_at() + tb.card_size() * 0.5)
				_at = _t
				_step = 3
		3:
			if _t > _at + 0.5:
				print("a touch on the stock turned a card: ", _s.sim.waste.size() == 1)
				# deal on with the bot until a card can be carried between columns
				var guard := 0
				while not _find_carry() and guard < 30:
					_play_one()
					guard += 1
				_at = _t
				_step = 4
		4:
			if _t > _at + 0.6:
				var tb: Control = _s.table
				var from: Vector2 = tb.card_at(_carried) + tb.card_size() * Vector2(0.5, 0.2)
				var to: Vector2 = tb.col_next(_carry_to.y) + tb.card_size() * Vector2(0.5, 0.3)
				_touches.append([0, _win(from)])
				for k in 8:
					_touches.append([1, _win(from.lerp(to, (k + 1) / 8.0))])
				_at = _t
				_step = 5
		5:
			if _touches.is_empty():
				_shot("3_carry")
				print("carrying: ", _s.table._carry.size(), " card(s), rings ", _s.table._targets.size())
				var tb: Control = _s.table
				_touches.append([2, _win(tb.col_next(_carry_to.y) + tb.card_size() * Vector2(0.5, 0.3))])
				_at = _t
				_step = 6
		6:
			if _t > _at + 0.5:
				var w: Vector3i = _s.sim.where(_carried)
				print("the carried card was laid: ", w.x == Sim.At.COL and w.y == _carry_to.y)
				# a touch on a card with somewhere to go
				var sim = _s.sim
				var m: Dictionary = sim.find_move()
				var guard := 0
				while (m.is_empty() or m.has("draw")) and guard < 40:
					_play_one()
					m = sim.find_move()
					guard += 1
				if not m.is_empty() and not m.has("draw"):
					_carried = int(m.card)
					_moves = sim.moves
					var tb: Control = _s.table
					tb._sync(true)
					_tap_at(tb.card_at(_carried) + tb.card_size() * Vector2(0.5, 0.12))
				_at = _t
				_step = 7
		7:
			if _t > _at + 0.5:
				print("a touch on a card moved it: ", _s.sim.moves == _moves + 1)
				_bot = true
				_moves = 0
				_at = _t
				_step = 8
		8:
			if _moves >= 30 or _s.sim.stuck:
				_bot = false
				_at = _t
				_step = 9
		9:
			if _t > _at + 0.6:
				_shot("4_play")
				_s._on_hint()
				_at = _t
				_step = 10
		10:
			if _t > _at + 0.12:
				_shot("5_hint")
				print("hints left: ", _s.sim.hints, " undo: ", _s.can_undo())
				_bot = true
				_bot_gap = 0.03
				_step = 11
		11:
			if _s.sim.stuck:
				_bot = false
				_at = _t
				_step = 12
		12:
			if _t > _at + 0.9:
				_shot("6_stuck")
				print("the dead end's card is up: ", _s._stuck != null, "; unsure ", _s.sim.unsure)
				_s._on_finish()
				_step = 13
		13:
			if _s._end != null:
				_at = _t
				_step = 14
		14:
			if _t > _at + 2.4:
				_shot("7_end")
				_s._end.queue_free()
				_s._end = null
				_s.deal_seed = WIN
				_s._boosts = []
				_s._new_game()
				_bot = true
				_bot_gap = 0.02
				_step = 15
		15:
			if _s.sim.sweeping:
				_bot = false
				_at = _t
				_step = 16
		16:
			if _t > _at + 1.4:
				_shot("8_sweep")
				_step = 17
		17:
			if _s.sim.phase == Sim.Phase.WON:
				_at = _t
				_step = 18
		18:
			if _t > _at + 0.9:
				_shot("9_won")
				print("won: bonus ", _s.sim.bonus, " after ", "%.0f" % _s.sim.t, " s")
				_step = 19
		19:
			if _s._end != null:
				_at = _t
				_step = 20
		20:
			if _t > _at + 2.6:
				_shot("10_end_won")
				for kind in ["m_tap", "m_deal", "m_turn", "m_seam", "m_home", "m_ace", "m_king", "m_suit", "m_recycle", "m_sigh", "m_win"]:
					if not _seen.has(kind):
						print("never came up: ", kind)
				_put_back()
				return true
	return false
