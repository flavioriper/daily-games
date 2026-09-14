shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// The water inside a pipe. Hard bands and bubble dots travel outward from the
// hub along every arm, lit with the same two-band step as the toon shader so
// the board's shadow still falls on the tube. `wet` mixes the whole thing
// from a flat grey hole to running water, so one uniform carries a cell's
// state and the toon material cache never sees an intermediate colour; the
// motion_scale global stills the current under reduce-motion. Spec:
// docs/superpowers/specs/2026-09-14-pipes-3d-design.md, section 4. Runs on
// gl_compatibility: nothing here reads depth or screen.

global uniform float motion_scale;
uniform vec4 dry_color : source_color = vec4(0.42, 0.48, 0.53, 1.0);
uniform vec4 base_color : source_color = vec4(0.18, 0.56, 0.84, 1.0);
uniform vec4 band_color : source_color = vec4(0.37, 0.69, 0.91, 1.0);
uniform vec4 bubble_color : source_color = vec4(0.96, 0.95, 0.90, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.65, 0.77, 1.0);
// 0 dry, 1 running. The board fades this per cell as the flood reaches it.
uniform float wet : hint_range(0.0, 1.0) = 0.0;
// The win bumps this for a moment, so the water races.
uniform float flow_speed = 1.0;

// Distance along the arm is taken from the model's own space, not a UV map:
// the tube is a cross of axis-aligned arms, so max(|x|, |z|) is how far a
// point is from the hub. Bands therefore travel outward along every arm at
// once -- including the one the water arrived through, which at this scale
// nobody reads as backwards.
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float t = TIME * flow_speed * motion_scale;
	float along = max(abs(local_pos.x), abs(local_pos.z));
	float p = along * 42.0 - t * 4.5;
	float band = step(0.35, sin(p));
	// Bubbles: warp a second phase pair so the dots scatter instead of gridding.
	float wob = sin(local_pos.y * 30.0 + t * 0.7) * 1.4;
	float b = sin(p * 0.8 + wob) * sin(along * 90.0 - t * 1.1);
	float bubble = step(0.992, b);
	vec3 water = mix(base_color.rgb, band_color.rgb, band);
	water = mix(water, bubble_color.rgb, bubble);
	ALBEDO = mix(dry_color.rgb, water, wet);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float t = clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * clamp(ATTENUATION, 0.0, 1.0);
	float band = step(0.5, t);
	// LIGHT_COLOR is colour * energy * PI and the pipeline multiplies by
	// ALBEDO afterwards, so neither factor belongs here (see toon_lit).
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint.rgb, vec3(1.0), band);
}
