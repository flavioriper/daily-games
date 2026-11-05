extends SceneTree
## Throwaway (2026-11-05): drives the swarm's draw and dots tools headless and
## prints what they did. Touches no user:// save.

var Tab: GDScript
var Picture: GDScript

var _tab: Control
var _f := 0
var _fails := 0

func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1

func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		Tab = load("res://ui/menu/swarm_tab.gd")
		Picture = load("res://ui/menu/swarm_picture.gd")
		var got: Dictionary = Picture.image_of({"name": "bank:strawberry"})
		_check(got.has("image"), "bank picture loads")
		var px: Dictionary = Picture.pixels(got.image, 1200)
		_check(px.n > 40 and px.x.size() == px.n and px.c.size() == px.n, "pixels listed n=%d x=%d c=%d" % [px.n, px.x.size(), px.c.size()])
		var big: Dictionary = Picture.image_of({"name": "bank:cat_in_box"})
		var small: Dictionary = Picture.pixels(big.image, 300)
		_check(small.n <= 300 and small.n > 150, "a 32 shrinks to fit 300 dots: n=%d %dx%d" % [small.n, small.w, small.h])
		_check(Picture.image_of({"rows": ["ab"], "palette": {"a": "red"}}).has("error"), "a char without a colour is refused")
		_check(Picture.image_of({"rows": ["a."], "palette": {"a": "#ff8040"}}).has("image"), "hex colour grid")
		_check(Picture.image_of({"name": "bank:nope"}).has("error"), "unknown bank id refused")
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.ORANGE)
		_check(Picture.image_of({"png": Marshalls.raw_to_base64(img.save_png_to_buffer())}).has("image"), "png payload")
		_tab = Tab.new()
		root.add_child(_tab)
		_tab.size = Vector2(810, 1440)
		_tab.open()
	elif _f == 140:
		_check(_tab._formed, "formed")
		_check(_tab._live_count() == Tab.N, "live %d" % _tab._live_count())
		var r: Dictionary = _tab.apply_dots({"add": 900, "from": "edges"})
		_check(int(r.dots) == Tab.N + 900, "add 900: " + str(r))
		r = _tab.apply_dots({"add": 5000})
		_check(int(r.dots) == Tab.CAP, "capped: " + str(r))
	elif _f == 200:
		_check(_tab._hi == Tab.CAP, "hi at cap %d" % _tab._hi)
		var r: Dictionary = _tab.apply_draw({"name": "bank:cat_in_box", "seconds": 1.0})
		_check(r.has("dots"), "draw: " + str(r))
		var px := 0
		for i in _tab._hi:
			if _tab._role[i] == Tab.Role.PIXEL:
				px += 1
		_check(px == int(r.dots), "pixel dots %d" % px)
		r = _tab.apply_dots({"remove": 99999, "to": "face"})
		_check(int(r.dots) >= Tab.MIN_LIVE, "remove floors: " + str(r))
		var px2 := 0
		for i in _tab._hi:
			if _tab._role[i] == Tab.Role.PIXEL and _tab._dying[i] == Tab.Die.NO:
				px2 += 1
		_check(px2 == px, "no picture dot removed")
	elif _f == 400:
		_check(not _tab._pic_on, "picture timed out back to the face")
		var body := 0
		var eye := 0
		for i in _tab._hi:
			if _tab._role[i] == Tab.Role.BODY: body += 1
			if _tab._role[i] == Tab.Role.EYE: eye += 1
		_check(body == Tab.BODY_N and eye == Tab.EYE_N, "face formed again body=%d eye=%d" % [body, eye])
		_check(_tab._hi < Tab.CAP, "dead slots shed hi=%d live=%d" % [_tab._hi, _tab._live_count()])
		var r: Dictionary = _tab.apply_dots({"total": 1600, "from": "point", "x": 0.2, "y": 0.3})
		_check(int(r.dots) == 1600, "total: " + str(r))
	elif _f == 460:
		print("done fails=%d" % _fails)
		_tab.close()
		quit(1 if _fails else 0)
	return false
