shader_type spatial;
render_mode unshaded;

// Iris surface of the imported peeplet eye. Flat cel color like the other
// face features, plus a hard-edged glint that tracks the toon sun band —
// the white spot is a light reflex, not painted-on geometry (the old fixed
// glint shells were removed from peeplet.glb).
uniform vec4 iris_color : source_color = vec4(0.159, 0.036, 0.009, 1.0);
uniform vec3 glint_color : source_color = vec3(1.0, 1.0, 1.0);
// Same stylized sun the fur bands against; adventure.gd pushes the live
// clock sun through the chain cache, so the glint wanders with the day.
uniform vec3 light_direction = vec3(0.3, 0.8, 0.75);
uniform float glint_size : hint_range(0.02, 0.5) = 0.07;
uniform float glint_softness : hint_range(0.005, 0.2) = 0.04;

void fragment() {
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 world_view = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 half_dir = normalize(normalize(light_direction) + world_view);
	float glint = smoothstep(1.0 - glint_size, 1.0 - glint_size + glint_softness, dot(world_normal, half_dir));
	ALBEDO = mix(iris_color.rgb, glint_color, glint);
}
