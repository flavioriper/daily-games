shader_type spatial;
render_mode unshaded;

// Premium iris: the rpg-adventure-2 lab's premium_eye pattern (faceted gem
// with crystal flecks) laid under the same sun-tracking reflex peeplet_eye
// draws, so a gold or ruby eye still catches the light as the day turns
// instead of sitting as a static texture. The lab painted this on a sphere;
// the glb iris carries a full 0..1 UV island, so the pattern maps the same way.
uniform vec4 iris_color : source_color = vec4(0.72, 0.42, 0.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.24, 0.10, 0.0, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.84, 0.28, 1.0);
uniform float pattern_seed = 1.0;
uniform float facet_count = 8.0;
uniform float sparkle_strength = 0.6;
// Shared with peeplet_eye/peeplet_fur: adventure.gd pushes the live clock sun
// through the walker's material chain.
uniform vec3 light_direction = vec3(0.3, 0.8, 0.75);
uniform vec3 glint_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float glint_size : hint_range(0.02, 0.5) = 0.07;
uniform float glint_softness : hint_range(0.005, 0.2) = 0.04;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32 + pattern_seed);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float facet = sin(angle * facet_count + radius * 13.0 + pattern_seed * 2.3) * 0.5 + 0.5;
	float bands = sin((p.y + p.x * 0.34) * 18.0 + pattern_seed * 4.0) * 0.5 + 0.5;
	float cell = hash21(floor(UV * vec2(18.0, 22.0)));
	float fine = hash21(floor(UV * vec2(42.0, 46.0)) + pattern_seed);
	float depth = smoothstep(0.12, 0.88, clamp(UV.y, 0.0, 1.0));
	// Lighter than the lab's mix (0.30 + depth * 0.58) and with a shallower
	// rim falloff (0.54). The lab drew this on a sphere that filled a preview;
	// on the glb's ~35 px iris the deep end of that ramp swallowed the hue and
	// gold read as olive, so the gem sits nearer its own color and only the
	// edge darkens.
	vec3 color = mix(shadow_color.rgb, iris_color.rgb, 0.55 + depth * 0.45);
	color = mix(color, accent_color.rgb, facet * 0.28 + bands * 0.12);
	color *= mix(0.78, 1.0, 1.0 - smoothstep(0.48, 0.98, radius));
	float crystal = step(0.84, cell) * (1.0 - smoothstep(0.20, 0.92, radius));
	float dust = step(0.955, fine) * (1.0 - smoothstep(0.10, 0.86, radius));
	color += accent_color.rgb * (crystal * 0.34 + dust * sparkle_strength);

	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 world_view = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 half_dir = normalize(normalize(light_direction) + world_view);
	float glint = smoothstep(
		1.0 - glint_size, 1.0 - glint_size + glint_softness, dot(world_normal, half_dir));

	ALBEDO = mix(color, glint_color, glint);
	EMISSION = color * (0.04 + dust * 0.22);
}
