extends SceneTree

## One real screen of every game for the website (web/): each board at
## Medium, each Arcade game and each Versus game against the computer, opened
## through the menu the way a player opens it, to build/site_shots/<id>.png.
## `-- <id> ...` shoots only those. Every file in user:// is put back on exit.

const SLOT := 110
const SHOT_AT := 95
const OUT := "res://build/site_shots"
const BACKUP := "user://_site_shots_backup"

var _menu: Node
var _jobs: Array = []
var _idx := 0
var _frames := 0
var _kept: Array = []

func _initialize() -> void:
	_keep_saves()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var progress = load("res://core/progress.gd")
	progress.path = "user://progress_harness.cfg"
	var only := OS.get_cmdline_user_args()
	for e in load("res://ui/registry.gd").all():
		if not e.get("soon", false):
			progress.mark_tutorial_seen(String(e.id))
			_jobs.append({"kind": "board", "id": String(e.id), "entry": e})
	for g in load("res://ui/menu/arcade_tab.gd").GAMES:
		if not load("res://ui/registry.gd").arcade(g).is_empty():
			continue
		_jobs.append({"kind": "arcade", "id": String(g)})
	for g in load("res://ui/menu/versus_tab.gd").GAMES:
		_jobs.append({"kind": "versus", "id": String(g)})
	if not only.is_empty():
		_jobs = _jobs.filter(func(j: Dictionary) -> bool: return only.has(j.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(_delta: float) -> bool:
	_frames += 1
	if _idx >= _jobs.size():
		_restore_saves()
		print("site shots: %d" % _jobs.size())
		return true
	var slot := _frames % SLOT
	var job: Dictionary = _jobs[_idx]
	if slot == 5:
		_open(job)
	elif slot == 8:
		_clear_tutorial()
	elif slot == 20 or slot == 35:
		_get_past_the_start()
	elif slot == SHOT_AT:
		var path := ProjectSettings.globalize_path("%s/%s.png" % [OUT, job.id])
		root.get_texture().get_image().save_png(path)
		print("shot ", job.id)
	elif slot == SHOT_AT + 3:
		_close()
		_idx += 1
	return false

func _open(job: Dictionary) -> void:
	match job.kind:
		"board":
			if job.entry.has("levels"):
				_menu._open_at(job.entry, 1)
			else:
				_menu._open(job.entry)
		"arcade":
			_menu._open_arcade(job.id)
		"versus":
			_menu._open_versus(job.id, 1)

func _clear_tutorial() -> void:
	var top: Node = _menu.get_child(_menu.get_child_count() - 1)
	if top.has_node("HowToPlay"):
		top.get_node("HowToPlay").free()
		if top.has_method("_hold_clock"):
			top._hold_clock(false)
	for n: Node in _menu.get_children():
		var tutor = n.get("tutor")
		if tutor != null and tutor.is_open():
			tutor.close()

## A game's first look is its intro: past Firefly's stage map, an Arcade
## game's boosters and Pearl Dive's ready card, to the game itself.
func _get_past_the_start() -> void:
	var top := _screen()
	if top.has_method("_pick_stage") and top.get("sim") == null:
		top._pick_stage(1)
	for card: Node in top.find_children("BoostCard", "", true, false):
		card._on_play()
	var board = top.get("_puzzle")
	if board != null and board.has_method("start_dive"):
		board.start_dive()

## The open game: the menu raises its card over it, so it is not the last child.
func _screen() -> Node:
	for i in range(_menu.get_child_count() - 1, -1, -1):
		var n: Node = _menu.get_child(i)
		if n.has_signal("closed") and n.get("tutor") != null or n.get("_puzzle") != null:
			return n
	return _menu

func _close() -> void:
	var top := _screen()
	if top.has_signal("closed"):
		top.closed.emit()

func _keep_saves() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP))
	for f in DirAccess.get_files_at("user://"):
		if f.ends_with(".log"):
			continue
		DirAccess.copy_absolute(ProjectSettings.globalize_path("user://" + f),
			ProjectSettings.globalize_path("%s/%s" % [BACKUP, f]))
		_kept.append(f)

func _restore_saves() -> void:
	for f in DirAccess.get_files_at("user://"):
		if not f.ends_with(".log") and not _kept.has(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))
	for f in _kept:
		DirAccess.copy_absolute(ProjectSettings.globalize_path("%s/%s" % [BACKUP, f]),
			ProjectSettings.globalize_path("user://" + f))
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [BACKUP, f]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))
