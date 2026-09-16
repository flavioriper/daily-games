extends RefCounted

const Toon = preload("res://core/toon.gd")

static func run(t) -> void:
	_test_material_cache(t)
	_test_apply_converts_and_outlines(t)
	_test_flat_gets_no_outline(t)
	_test_shader_material_left_alone(t)
	_test_apply_twice_is_idempotent(t)
	_test_sway_gets_wind(t)
	_test_wind_cache(t)

static func _mesh_with(mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.material = mat
	mi.mesh = box
	return mi

static func _test_material_cache(t) -> void:
	var a = Toon.material(Color("4c9a94"))
	var b = Toon.material(Color("4c9a94"))
	var c = Toon.material(Color("e2825f"))
	t.check(a is ShaderMaterial, "material() builds a ShaderMaterial")
	t.check(a == b, "same colour returns the cached instance")
	t.check(a != c, "different colours are different materials")
	t.check(Color(a.get_shader_parameter("albedo")).is_equal_approx(Color("4c9a94")), "albedo parameter carries the colour")
	t.check(a.get_shader_parameter("ramp") is GradientTexture1D, "ramp texture is wired")
	t.check(Toon.outline() == Toon.outline(), "one shared outline material")

static func _test_apply_converts_and_outlines(t) -> void:
	var std := StandardMaterial3D.new()
	std.albedo_color = Color("c8a17a")
	std.resource_name = "Wood"
	var root := Node3D.new()
	var mi := _mesh_with(std)
	root.add_child(mi)
	Toon.apply_to(root)
	var over = mi.get_surface_override_material(0)
	t.check(over is ShaderMaterial, "StandardMaterial3D surface converted to toon")
	t.check(over != null and Color(over.get_shader_parameter("albedo")).is_equal_approx(Color("c8a17a")), "base colour preserved")
	var shell = mi.get_node_or_null("Outline")
	t.check(shell is MeshInstance3D, "outline shell added")
	t.check(shell != null and shell.mesh == mi.mesh, "shell shares the mesh")
	t.check(shell != null and shell.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "shell casts no shadow")
	t.check(shell != null and shell.material_override == Toon.line(Color("c8a17a")), "a wood shell wears the wood's own line")
	t.check(shell != null and shell.material_override != Toon.outline(), "and not the shared dark outline")
	var line_col: Color = Toon.line_color(Color("c8a17a"))
	t.check(line_col.get_luminance() < Color("c8a17a").get_luminance() and line_col.get_luminance() > Color(Toon.Pal.OUTLINE).get_luminance(), "the line is deeper than the wood and lighter than ink")
	root.free()
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("ede2cc")
	stone.resource_name = "Stone"
	var rock := _mesh_with(stone)
	Toon.apply_to(rock)
	var rock_shell = rock.get_node_or_null("Outline")
	t.check(rock_shell != null and rock_shell.material_override == Toon.outline(), "a non-wood shell keeps the shared outline material")
	rock.free()

static func _test_flat_gets_no_outline(t) -> void:
	var std := StandardMaterial3D.new()
	std.albedo_color = Color("c8a17a")
	std.resource_name = "Wood_flat"
	var mi := _mesh_with(std)
	Toon.apply_to(mi)
	t.check(mi.get_surface_override_material(0) is ShaderMaterial, "_flat surface still gets the toon material")
	t.check(mi.get_node_or_null("Outline") == null, "_flat mesh gets no outline shell")
	mi.free()

static func _test_shader_material_left_alone(t) -> void:
	var custom := ShaderMaterial.new()
	var mi := _mesh_with(custom)
	Toon.apply_to(mi)
	t.check(mi.get_surface_override_material(0) == null, "ShaderMaterial surface is not overridden")
	t.check(mi.get_node_or_null("Outline") != null, "authored ShaderMaterial still gets an outline")
	mi.free()

static func _test_apply_twice_is_idempotent(t) -> void:
	var mi := _mesh_with(StandardMaterial3D.new())
	Toon.apply_to(mi)
	Toon.apply_to(mi)
	var shells := 0
	for child in mi.get_children():
		if String(child.name).begins_with("Outline"):
			shells += 1
	t.eq(shells, 1, "second apply_to adds no second shell")
	mi.free()

## A `_sway` material bends in the wind (polish spec, section 4): it gets the
## wind shader, everything else the plain toon shader, and since a swaying
## mesh must also be `_flat` it gets no outline.
static func _test_sway_gets_wind(t) -> void:
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("a3c95e")
	grass.resource_name = "Grass_sway_flat"
	var mi := _mesh_with(grass)
	Toon.apply_to(mi)
	var over = mi.get_surface_override_material(0)
	t.check(over is ShaderMaterial and over.shader == Toon.WIND_SHADER, "_sway surface gets the wind shader")
	t.check(over != null and Color(over.get_shader_parameter("albedo")).is_equal_approx(Color("a3c95e")), "wind material keeps the base colour")
	t.check(over != null and over.get_shader_parameter("ramp") is GradientTexture1D, "wind material shares the toon ramp")
	t.check(mi.get_node_or_null("Outline") == null, "_sway_flat mesh gets no outline")
	mi.free()
	var moss := StandardMaterial3D.new()
	moss.resource_name = "Moss_flat"
	var still := _mesh_with(moss)
	Toon.apply_to(still)
	t.check(still.get_surface_override_material(0).shader == Toon.TOON_SHADER, "a plain _flat surface keeps the toon shader")
	still.free()
	t.check(Toon.sways("Petal_sway_flat") and not Toon.sways("Petal_flat"), "sways() reads the _sway mark")

static func _test_wind_cache(t) -> void:
	var a = Toon.wind_material(Color("a3c95e"))
	var b = Toon.wind_material(Color("a3c95e"))
	var c = Toon.material(Color("a3c95e"))
	t.check(a == b, "same colour returns the cached wind material")
	t.check(a != c, "wind and plain toon materials of one colour are different objects")
