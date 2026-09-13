extends RefCounted

const Toon = preload("res://core/toon.gd")

static func run(t) -> void:
	_test_material_cache(t)
	_test_apply_converts_and_outlines(t)
	_test_flat_gets_no_outline(t)
	_test_shader_material_left_alone(t)
	_test_apply_twice_is_idempotent(t)

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
	t.check(shell != null and shell.material_override == Toon.outline(), "shell uses the shared outline material")
	root.free()

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
