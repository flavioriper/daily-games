// Shared body of the cozy cel shader: toon.gdshader and toon_wind.gdshader
// #include this so the lighting has one source. Spec: 3d-toon-pipeline design
// section 2. Runs on gl_compatibility: nothing here reads depth or screen.

uniform vec4 albedo : source_color = vec4(1.0);
// Red channel = lit factor across NdotL remapped to 0..1. Nearest filtering
// keeps the bands hard. core/toon.gd ramp() builds the default.
uniform sampler2D ramp : filter_nearest, repeat_disable, hint_default_white;
// Shadow is a hue shift toward this tint, never a multiply toward black.
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.65, 0.77, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.18;
uniform float rim_width : hint_range(0.0, 1.0) = 0.30;
uniform vec4 rim_color : source_color = vec4(1.0);

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = step(1.0 - rim_width, 1.0 - facing);
	EMISSION = rim_color.rgb * albedo.rgb * rim * rim_strength;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float t = clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * clamp(ATTENUATION, 0.0, 1.0);
	float band = texture(ramp, vec2(t, 0.5)).r;
	// LIGHT_COLOR is colour * energy * PI, and the pipeline multiplies this
	// result by ALBEDO afterwards (scene.glsl: diffuse_light *= albedo), so
	// neither factor belongs here.
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint.rgb, vec3(1.0), band);
}
