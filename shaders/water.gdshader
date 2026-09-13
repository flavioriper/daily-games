shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// Toon water: hard drifting highlight stripes, a scatter of sparkle dots and
// one splash ring the stage triggers when a board lands. Lit with the same
// two-band step as the toon shader so the platform's shadow still falls on
// it. Every time term is scaled by the motion_scale global so reduce-motion
// stills it. Spec: docs/superpowers/specs/2026-09-13-binairo-polish-design.md,
// section 4. Runs on gl_compatibility: nothing here reads depth or screen.

global uniform float motion_scale;
uniform vec4 base_color : source_color = vec4(0.18, 0.56, 0.84, 1.0);
uniform vec4 band_color : source_color = vec4(0.37, 0.69, 0.91, 1.0);
uniform vec4 sparkle_color : source_color = vec4(0.96, 0.95, 0.90, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.65, 0.77, 1.0);
uniform vec3 splash_origin = vec3(0.0);
// Seconds since the splash began; negative means no splash. Driven by
// world/ambient.gd from its own clock so the ring is deterministic.
uniform float splash_age = -1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * motion_scale;
	vec2 p = world_pos.xz;
	float b = sin(dot(p, vec2(0.80, 0.45)) * 0.9 + t * 0.35)
			+ 0.5 * sin(dot(p, vec2(-0.35, 0.90)) * 1.7 - t * 0.5);
	float band = step(1.1, b);
	float s = sin(p.x * 7.3 + t * 1.3) * sin(p.y * 6.1 - t * 0.9);
	float spark = step(0.985, s);
	vec3 col = mix(base_color.rgb, band_color.rgb, band);
	col = mix(col, sparkle_color.rgb, spark);
	if (splash_age >= 0.0 && splash_age < 2.0) {
		float d = distance(p, splash_origin.xz);
		float ring = step(abs(d - splash_age * 3.0), 0.15) * (1.0 - splash_age / 2.0);
		col = mix(col, band_color.rgb, ring);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float t = clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * clamp(ATTENUATION, 0.0, 1.0);
	float band = step(0.5, t);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint.rgb, vec3(1.0), band);
}
