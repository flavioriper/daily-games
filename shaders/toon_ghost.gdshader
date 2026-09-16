shader_type spatial;
render_mode cull_back, depth_draw_never, depth_prepass_alpha, specular_disabled;

// The toon shader, see-through. Pipes' peek fades the ground so the pipeline
// behind it shows, and a see-through surface needs its own render mode --
// writing ALPHA in toon_lit.gdshaderinc would make every opaque material in
// the game take the transparent path. So the lit body is repeated here rather
// than included: twelve lines against a pipeline-wide cost.
// Spec: docs/superpowers/specs/2026-09-15-pipes-iso-design.md, section 7.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D ramp : filter_nearest, repeat_disable, hint_default_white;
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.65, 0.77, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = alpha;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float t = clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * clamp(ATTENUATION, 0.0, 1.0);
	float band = texture(ramp, vec2(t, 0.5)).r;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint.rgb, vec3(1.0), band);
}
