extends Node

## Gumdrop's syrup as a fluid on the GPU (since 2026-10-11, the user over
## the reference's screen: "I want a real high volume liquid effect of
## coloring ... something really really good to look"). The screen
## (puzzles/gumdrop_table.gd) owns one of these, tells it each frame where
## the needle's tip is and whether it is squeezed, draws its `texture()`
## over the tray through shaders/gumdrop_syrup_2d.gdshader, and asks it
## `measure()` when a mould is served.
##
## It is the classic real-time fluid (Stam, "Real-Time Fluid Dynamics for
## Games", 2003) as the GPU demos run it: a velocity field of SIM by SIM
## texels and a dye of DYE by DYE, each pass one small render target with
## a ColorRect and a shader (shaders/gumdrop/). The passes are sibling
## SubViewports in tree order, which this renderer draws in that order
## within one frame, so each reads the one before it; the first of a frame
## reads the last of the frame before. In order: advect (the velocity
## carried, slowed, pushed at the tip), curl, vorticity confinement (the
## marbling), divergence, JACOBI sweeps of pressure, gradient (the
## pressure taken off, nothing into a wall), dye (the pigments carried,
## more squeezed in), copy (the dye's keep), judge (each texel's nearness
## to the card, read back at serve). The mask is the jelly's chunks drawn
## once a deal, the chunk's number plus one in red, the tray black: the
## tray is a solid for the velocity, and a chunk's number is a fence for
## the dye and, since 2026-10-12, for the flow as well (`shut_at` in the
## include): the chunks touch with no wall between, and each is a tank of
## its own. While the flow crossed a seam the dye it carried there was
## lost and what came back in was clear, so a pour stopped short of the
## far end of its chunk until the button was let go.
##
## The render targets are eight bits a channel (no HDR 2D on
## gl_compatibility), so signed values are packed across two bytes; see
## the include. Everything the colour means is puzzles/gumdrop_sim.gd's.

const Mould = preload("res://puzzles/gumdrop_mould.gd")
const Sim = preload("res://puzzles/gumdrop_sim.gd")

const SIM := 128
const DYE := 256
const JACOBI := 14
## The needle: how wide its push and its dye land (in mould widths), how
## hard its jet pushes and swirls (texels a second a second), how far the
## jet turns from the way the needle leans and how fast, and pigment a
## second at the tip's middle.
const PUSH_R := 0.09
const DYE_R := 0.075
const PUSH := 2200.0
const SWIRL := 320.0
const JET_LEAN := 0.55
const JET_TURN := 0.9
const JET_RATE := 0.7
## Pigment a second at the tip's middle into a chunk of Sim.SQUARES_REF
## squares (of the sim's 36 by 36), about 1.2 s of hold to the card's
## shade at 92 squares (2026-10-26, the pour is quick; 3.6 and 2.6 s
## before);
## into a bigger chunk more, as the root of its squares, so a big chunk
## takes longer than a small one and a small one is not a flash (Sim.pace,
## 2026-10-15; from 2026-10-14 every chunk of 23 squares or more took the
## same 2.6 s, and before that 20 into any chunk, the stalk past the
## card's shade in half a second). The grey button draws it out at DRAIN
## times the same, so a big chunk drains slower too.
const RATE := 8.0
const DRAIN := 1.0
## The most the tip pours a texel up to, in amounts: a little past the
## card's shade (1.25), so a pour never goes black under the tip. The dye
## texture holds a pigment's amount over AMOUNT_TOP (the include's).
const POUR_TOP := 2.0
const AMOUNT_TOP := 2.5
## The jelly: how much velocity a second keeps (e^-VISC), plain, under
## reduce motion and with the Softer jelly booster, held or let go alike
## (the user, 2026-10-14: a tint let go "should keep doing the exactly
## same behavior of moving around to fill available space"; for a day
## before, VISC_REST 8 killed the flow in a quarter second at the
## release), so the jet's last push coasts for a few seconds; and the
## vorticity's strength while held, nothing under reduce or at rest (on
## at rest it fed the swirl for good: a top speed of 100 texels a second
## four seconds after the release, half the pour's own). The dye
## settles toward its neighbours (`SETTLE` a frame, read SETTLE_R texels
## off), which irons a fold, and toward eight texels FAR_R off (`FAR` a
## frame), which carries a tint over its chunk in a few seconds; both on
## every texel of every chunk, held or not, each a mean that keeps the
## chunk's pigment as it spreads (FAR was 0.4 and off under the tip: the
## chunk went one flat shade in a second, which read as "auto fill").
const VISC := 0.6
const VISC_CALM := 2.5
const VISC_SOFT := 0.6
const EPS := 7.0
const SETTLE := 0.14
const SETTLE_R := 3.0
const FAR := 0.08
const FAR_R := 14.0
## The chunk under the tip takes no more past the card's shade (the user,
## 2026-10-14: "if 100% no more liquid can be added"): the dye pass eases
## the pour to nothing over the last FULL_EASE of C_FULL as the meter's
## last frame has the chunk, so the ring stops at 100 and the grey button
## is the only way down. On the GPU, a frame behind, so it never waits on
## the meter's readback (a first cut read `level()` here: right in every
## harness, but one readback away from a chunk at 144%). Headless the sim's
## own tally stops the pour.
const FULL_EASE := 0.06

var soft := false
var calm := false
## The frame's state, set by the screen.
var tip := Vector2(0.5, 0.5)
var tip_cell := -1
## Squares the chunk under the tip has (the sim's `count`), for the rate.
var tip_squares := 0
var squeezing := false
var draining := false
var pigment := Vector3(1, 0, 0)
var drag := Vector2.ZERO
var fill_cell := -1
var fill_pig := Vector3.ZERO

var _passes: Array = []
var _mats := {}
var _mask_vp: SubViewport
var _mask_draw: Node2D
var _mould := {}
var _mask_ids := PackedByteArray()
var _mask_fresh := false
var _clear_for := 0
var _time := 0.0
var _running := false
var _last_dye: SubViewport
var _judge: SubViewport
var _meter: SubViewport
var _meter_img: Image
var _meter_at := -10.0
## Seconds between two reads of the meter: a tiny readback, CELLS_TOP
## texels, so the ring on the squeeze button follows the pour.
const METER_GAP := 0.1

func _ready() -> void:
	_build()
	set_running(false)

func _load(name: String) -> Shader:
	return load("res://shaders/gumdrop/%s.gdshader" % name)

## One pass: a render target of `size` (square, or `tall` high) with a
## shader on a rect over it.
func _pass(name: String, size: int, shader: String, params: Dictionary, tall := -1) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = name
	vp.size = Vector2i(size, size if tall < 0 else tall)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.gui_disable_input = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var rect := ColorRect.new()
	rect.size = Vector2(vp.size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _load(shader)
	for k: String in params:
		mat.set_shader_parameter(k, params[k])
	rect.material = mat
	vp.add_child(rect)
	add_child(vp)
	_passes.append(vp)
	_mats[name] = mat
	return vp

func _build() -> void:
	# the mask first: everything else reads it
	_mask_vp = SubViewport.new()
	_mask_vp.name = "Mask"
	_mask_vp.size = Vector2i(DYE, DYE)
	_mask_vp.disable_3d = true
	_mask_vp.transparent_bg = false
	_mask_vp.gui_disable_input = true
	_mask_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_mask_draw = Node2D.new()
	_mask_draw.draw.connect(_draw_mask)
	_mask_vp.add_child(_mask_draw)
	add_child(_mask_vp)
	var mask := _mask_vp.get_texture()
	var n := Vector2i(SIM, SIM)
	var adv := _pass("Advect", SIM, "advect", {"mask": mask, "n": n, "radius": PUSH_R, "push": PUSH, "swirl": SWIRL})
	var curl := _pass("Curl", SIM, "curl", {"vel": adv.get_texture(), "n": n})
	var vort := _pass("Vorticity", SIM, "vorticity", {"vel": adv.get_texture(), "curl": curl.get_texture(), "n": n})
	var div := _pass("Divergence", SIM, "divergence", {"vel": vort.get_texture(), "mask": mask, "n": n})
	var last_p: SubViewport = null
	for k in JACOBI:
		var p := _pass("Pressure%d" % k, SIM, "pressure", {"divg": div.get_texture(), "mask": mask, "n": n})
		if last_p != null:
			_mats["Pressure%d" % k].set_shader_parameter("pres", last_p.get_texture())
		last_p = p
	# the first sweep starts from the last of the frame before
	_mats["Pressure0"].set_shader_parameter("pres", last_p.get_texture())
	var grad := _pass("Gradient", SIM, "gradient", {"vel": vort.get_texture(), "pres": last_p.get_texture(), "mask": mask, "n": n})
	_mats["Advect"].set_shader_parameter("vel", grad.get_texture())
	var dye := _pass("Dye", DYE, "dye", {"vel": grad.get_texture(), "mask": mask, "n": n, "radius": DYE_R, "rate": RATE, "pour_top": POUR_TOP / AMOUNT_TOP, "settle": SETTLE, "settle_r": SETTLE_R, "far": FAR, "far_r": FAR_R})
	_last_dye = _pass("Keep", DYE, "copy", {"from": dye.get_texture()})
	_mats["Dye"].set_shader_parameter("dye", _last_dye.get_texture())
	_judge = _pass("Judge", DYE, "judge", {"dye": _last_dye.get_texture(), "mask": mask})
	# one texel a chunk: its mean pigments, for the ring on the squeeze button
	_meter = _pass("Meter", Mould.CELLS_TOP, "meter", {"dye": _last_dye.get_texture(), "mask": mask}, 1)
	# the dye pass caps the pour on the meter's last frame
	_mats["Dye"].set_shader_parameter("meter", _meter.get_texture())
	_mats["Dye"].set_shader_parameter("full_ease", FULL_EASE)

## Whether a deal's clearing frames are over: a cell filled before that
## would be wiped with them.
func clear_done() -> bool:
	return _clear_for == 0

## The dye as the screen draws it.
func texture() -> Texture2D:
	return _last_dye.get_texture()

## Whether the passes run each frame: off while the screen is paused, a
## tutorial page is held, or nothing is played.
func set_running(on: bool) -> void:
	_running = on
	var mode := SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	for vp: SubViewport in _passes:
		vp.render_target_update_mode = mode

## A mould dealt: its cells drawn into the mask, the fluid and the dye
## cleared.
func lay(mould: Dictionary) -> void:
	_mould = mould
	_mask_draw.queue_redraw()
	_mask_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_mask_fresh = false
	_clear_for = 2
	var want := PackedVector3Array()
	want.resize(Mould.CELLS_TOP)
	for c in mini(Mould.CELLS_TOP, mould.want.size()):
		var col: Color = Sim.FLAVOURS[int(mould.want[c])]
		want[c] = Vector3(col.r, col.g, col.b)
	_mats["Judge"].set_shader_parameter("want", want)

func _draw_mask() -> void:
	if _mould.is_empty():
		return
	var k := float(DYE) / Mould.SIDE
	_mask_draw.draw_rect(Rect2(0, 0, DYE, DYE), Color.BLACK)
	# the chunks in their order, the one on top drawn last; they lie side
	# by side with no wall between, and the number is the fence
	var cells: Array = _mould.cells
	for c in cells.size():
		var p := PackedVector2Array()
		p.resize(cells[c].size())
		for i in p.size():
			p[i] = cells[c][i] * k
		_mask_draw.draw_colored_polygon(p, Color((c + 1) / 255.0, 0, 0, 1))

## A frame: the state into the passes' uniforms.
func tick(delta: float) -> void:
	if not _running:
		return
	var dt := minf(delta, 1.0 / 30.0)
	_time += dt
	var held := squeezing and tip_cell >= 0
	var visc := VISC_CALM if calm else (VISC_SOFT if soft else VISC)
	var clearing := 1.0 if _clear_for > 0 else 0.0
	if _clear_for > 0:
		_clear_for -= 1
	var adv: ShaderMaterial = _mats["Advect"]
	adv.set_shader_parameter("dt", dt)
	adv.set_shader_parameter("keep", exp(-visc * dt))
	adv.set_shader_parameter("tip", tip)
	adv.set_shader_parameter("squeezing", 1.0 if squeezing and tip_cell >= 0 else 0.0)
	adv.set_shader_parameter("drag", drag * SIM)
	adv.set_shader_parameter("jet", Vector2.from_angle(PI * 0.5 + JET_LEAN + JET_TURN * sin(_time * JET_RATE)))
	adv.set_shader_parameter("time", _time)
	adv.set_shader_parameter("clearing", clearing)
	var vort: ShaderMaterial = _mats["Vorticity"]
	vort.set_shader_parameter("dt", dt)
	vort.set_shader_parameter("eps", EPS if held and not calm else 0.0)
	_mats["Pressure0"].set_shader_parameter("clearing", clearing)

	var dye: ShaderMaterial = _mats["Dye"]
	dye.set_shader_parameter("dt", dt)
	dye.set_shader_parameter("tip", tip)
	dye.set_shader_parameter("tip_cell", tip_cell)
	dye.set_shader_parameter("rate", rate_now())
	dye.set_shader_parameter("drain_rate", rate_now() * DRAIN)
	dye.set_shader_parameter("squeezing", 1.0 if squeezing else 0.0)
	dye.set_shader_parameter("draining", 1.0 if draining and not squeezing else 0.0)
	dye.set_shader_parameter("pigment", pigment)
	dye.set_shader_parameter("fill_cell", fill_cell)
	dye.set_shader_parameter("fill_pig", fill_pig)
	dye.set_shader_parameter("clearing", clearing)
	fill_cell = -1

## Pigment a second at the tip's middle into the chunk under it: more
## into a bigger chunk, less than in proportion (Sim.pace is the rate over
## the size). The cap at the card's shade is the dye pass's.
func rate_now() -> float:
	return RATE * Sim.pace(tip_squares) * maxf(1.0, tip_squares) / Sim.SQUARES_REF

## The chunk's mean pigments, in amounts (the card's shade is Sim.C_FULL of
## them in all), from the meter's last frame: read back at most every
## METER_GAP, and nothing headless.
func level(cell: int) -> Vector3:
	if cell < 0 or cell >= Mould.CELLS_TOP or DisplayServer.get_name() == "headless":
		return Vector3.ZERO
	var now := Time.get_ticks_msec() / 1000.0
	if _meter_img == null or now - _meter_at >= METER_GAP:
		_meter_at = now
		_meter_img = _meter.get_texture().get_image()
	if _meter_img == null or _meter_img.get_width() < Mould.CELLS_TOP:
		return Vector3.ZERO
	var c := _meter_img.get_pixel(cell, 0)
	return Vector3(c.r, c.g, c.b) * AMOUNT_TOP

## The mask's cell numbers, read back once a deal.
func _mask_bytes() -> PackedByteArray:
	if not _mask_fresh:
		var img: Image = _mask_vp.get_texture().get_image()
		if img != null and img.get_width() == DYE:
			_mask_ids = img.get_data()
			_mask_fresh = true
	return _mask_ids

## Each cell's match to the card (`near`), how strong it is (`fill`) and
## the whole mould's match (`all`), from the judge's last frame. A read
## back from the GPU: once a serve, or a bot's few times a second.
func measure() -> Dictionary:
	var cells: int = _mould.get("cells", []).size()
	var near := PackedFloat32Array()
	var fill := PackedFloat32Array()
	var count := PackedInt32Array()
	near.resize(cells)
	fill.resize(cells)
	count.resize(cells)
	near.fill(0.0)
	fill.fill(0.0)
	count.fill(0)
	# headless (a probe opening the screen) has no textures to read
	if DisplayServer.get_name() == "headless":
		return {"near": near, "fill": fill, "all": 0.0}
	var ids := _mask_bytes()
	var img: Image = _judge.get_texture().get_image()
	if ids.size() < DYE * DYE * 4 or img == null or img.get_width() != DYE:
		return {"near": near, "fill": fill, "all": 0.0}
	var bytes := img.get_data()
	var total := 0.0
	var all := 0
	for i in DYE * DYE:
		var c := ids[i * 4] - 1
		if c < 0 or c >= cells:
			continue
		var at := i * 4
		near[c] += bytes[at]
		fill[c] += bytes[at + 1]
		count[c] += 1
	for c in cells:
		if count[c] > 0:
			total += near[c]
			all += count[c]
			near[c] = near[c] / (255.0 * count[c])
			fill[c] = fill[c] / (255.0 * count[c])
	return {"near": near, "fill": fill, "all": total / (255.0 * maxf(1.0, float(all)))}
