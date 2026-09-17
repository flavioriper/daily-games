extends MeshInstance3D

## The campsite's depth of field: a quad pinned over the whole frame by its
## shader (shaders/soft_focus.gdshader) that blurs what stands past the
## focus distance by reading the screen's own mip levels, and lightens it a
## little toward the haze. gl_compatibility has no CameraAttributes depth of
## field, so this is the pass instead. It hangs off the stage's camera, is
## shown only with the setting (Stage.show_setting), and is refocused on
## every fit to just behind whatever was framed.
##
## Costs one full-screen fragment pass plus the renderer's screen copy with
## mipmaps and its depth copy: 2.8 ms a frame on the menu at 1080x1920 on
## this Mac (9.2 against 6.5 without, vsync off, 2026-09-17). Full-screen
## work scales badly on a phone, so if the menu drops frames there this
## visibility flag is the first thing to try.

const SHADER := preload("res://shaders/soft_focus.gdshader")
const Pal = preload("res://core/palette.gd")

## How far behind the focused thing the blur begins, and how far it takes to
## reach full: the tent a few units behind the scout is half soft, the tree
## line and the far bank fully.
const START_BEHIND := 1.5
const RANGE := 9.0
## And in front of it: sharp until NEAR_START in front of the focused plane,
## fully soft (and darkened, see the shader) NEAR_FULL in front. The trees
## framing the first screen stand inside the soft band; the fence diorama
## along the frame's bottom stands just outside it, so its motto stays
## legible (world/camp.gd, place_footer).
const NEAR_START := 2.6
const NEAR_FULL := 3.8

var _mat: ShaderMaterial

func _init() -> void:
	name = "SoftFocus"
	mesh = QuadMesh.new()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.render_priority = -100
	_mat.set_shader_parameter("haze_color", Pal.SKY_HORIZON)
	material_override = _mat
	# The shader ignores the transform, so culling must too.
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

## Focuses on a view distance: the blur starts START_BEHIND past it.
## Opens the near band over the top `frac` of the frame's height only, so
## the trees framing the hero strip soften and darken while the fence
## diorama along the bottom edge, as near to the camera as they are, stays
## sharp (see the shader's near_gate).
func gate_near(frac: float) -> void:
	_mat.set_shader_parameter("near_gate", clampf(frac, 0.0, 1.0))

func focus(distance: float) -> void:
	_mat.set_shader_parameter("focus_start", distance + START_BEHIND)
	_mat.set_shader_parameter("focus_range", RANGE)
	_mat.set_shader_parameter("near_start", maxf(distance - NEAR_START, 0.1))
	_mat.set_shader_parameter("near_end", maxf(distance - NEAR_FULL, 0.05))
