shader_type spatial;
render_mode unshaded;
// daily: the world globals (wind, campfire) are plain uniforms at the
// values ~/dev/peeplet's project.godot gives them; no world here sets them.

#include "res://world/planet_chart.gdshaderinc"

uniform vec4 fur_color : source_color = vec4(0.85, 0.36, 0.32, 1.0);
uniform float fur_length : hint_range(0.0, 0.2) = 0.055;
uniform float shell_ratio : hint_range(0.0, 1.0) = 0.5;
// daily: every shell of a part in one mesh, each copy's ratio in UV2.x
// (peeplet/peeplet_batch.gd stack_shells), one draw for the four next_passes.
uniform bool stacked = false;
varying float shell;
uniform float droop : hint_range(0.0, 1.0) = 0.15;
uniform vec4 belly_color : source_color = vec4(0.96, 0.91, 0.79, 1.0);
uniform float belly_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 belly_direction = vec3(0.0, -0.88, 0.48);
uniform float belly_size : hint_range(0.3, 0.95) = 0.80;
// Wind matches the grass: same units (0-6), same world-space direction, and
// the same traveling gust field, so one gust moves grass and fur together.
uniform float wind_strength : hint_range(0.0, 6.0) = 0.0;
uniform vec2 wind_direction = vec2(1.0, 0.35);
// CPU-integrated scroll of the shared gust field — see
// toon_grass_deform.gdshaderinc; the copies must stay bit-identical.
uniform float wind_gust_phase = 0.0;
uniform float gust_scale = 0.32;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
// Silhouette tufts: the coat interior stays one flat cel tone, but where the
// surface grazes the camera the shells break into a chunky tuft lattice so
// the outline reads as fur without per-strand interior detail.
uniform float rim_tuft_strength : hint_range(0.0, 1.0) = 1.0;
uniform float rim_facing_start : hint_range(0.0, 1.0) = 0.28;
uniform float rim_facing_end : hint_range(0.0, 1.0) = 0.58;
uniform float tuft_density : hint_range(4.0, 80.0) = 13.0;
uniform float face_mask_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 eye_left = vec3(0.0);
uniform vec3 eye_right = vec3(0.0);
uniform vec3 mouth_center = vec3(0.0);
uniform float eye_mask_radius = 0.115;
uniform float mouth_mask_radius = 0.075;
uniform int premium_mode : hint_enum("Solid", "Candy", "Midnight", "Ocean", "Sky") = 0;
uniform int body_mark_mode : hint_enum("None", "Stripes", "Spots", "Starmark") = 0;
// Toon banding (v2 cel look). At 0 the coat keeps the original soft v1 shading;
// at 1 lighting collapses into a hard 2-band cut against a stylized sun.
uniform float toon_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 light_direction = vec3(0.35, 0.8, 0.5);
uniform vec3 shadow_tint : source_color = vec3(0.55, 0.48, 0.54);
// Wobbles the shadow terminator with clump-scale noise so the band edge
// reads as a tufted fur line instead of a clean geometric curve. Same scale
// and coords as the base coat so both layers cut in the same place.
uniform float terminator_fuzz : hint_range(0.0, 0.6) = 0.22;
uniform float terminator_scale : hint_range(2.0, 30.0) = 9.0;
// Same hand-applied world light as peeplet_fur.gdshader — the strand shells are
// unshaded too, so they need the sun fed in or they stay bright after sundown.
uniform vec3 sun_color = vec3(0.984, 0.906, 0.765);
uniform float sun_energy : hint_range(0.0, 3.0) = 1.15;
uniform vec3 ambient_light = vec3(0.275, 0.313, 0.326);
const vec3 DAY_REFERENCE_LIGHT = vec3(1.4070, 1.3547, 1.2055);
// Same hand-applied campfire glow as peeplet_fur.gdshader (see the note
// there) so the strand shells warm up in step with the base coat.
uniform vec3 fire_light_position = vec3(0.0);
uniform vec3 fire_light_color = vec3(1.0, 0.6, 0.3);
uniform float fire_light_energy = 0.0;
uniform float fire_light_range = 4.0;

varying vec3 base_position;
varying vec3 base_normal;

// Identical hash + noise to meadow.gdshader/grass.gdshader so the fur samples
// the exact same gust field as the grass around it.
float wind_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float wind_field_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(wind_hash(cell), wind_hash(cell + vec2(1.0, 0.0)), u.x),
		mix(wind_hash(cell + vec2(0.0, 1.0)), wind_hash(cell + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float hash31(vec3 point) {
	point = fract(point * 0.1031);
	point += dot(point, point.yzx + 33.33);
	return fract((point.x + point.y) * point.z);
}

float value_noise(vec3 point) {
	vec3 cell = floor(point);
	vec3 f = fract(point);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(cell);
	float n100 = hash31(cell + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(cell + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(cell + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(cell + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(cell + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(cell + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(cell + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z
	);
}

float round_spots(vec3 point, float scale, float density) {
	vec3 sample_point = point * scale;
	vec3 cell = floor(sample_point);
	vec3 center = vec3(
		hash31(cell + vec3(13.1, 3.7, 8.3)),
		hash31(cell + vec3(5.9, 17.3, 2.1)),
		hash31(cell + vec3(9.7, 1.3, 21.9))
	) * 0.54 + 0.23;
	float active = step(1.0 - density, hash31(cell + vec3(31.7, 11.9, 4.3)));
	float radius = mix(0.13, 0.27, hash31(cell + vec3(7.1, 23.3, 15.7)));
	return active * (1.0 - smoothstep(radius * 0.68, radius, distance(fract(sample_point), center)));
}

vec3 premium_coat(vec3 point, vec3 base_color) {
	if (premium_mode == 1) {
		float pearl = smoothstep(0.76, 0.96, value_noise(point * 8.0 + vec3(2.4, 5.1, 1.7)));
		float spot = round_spots(point, 11.0, 0.30);
		return mix(base_color, vec3(1.0, 0.80, 0.91), pearl * 0.24) + vec3(spot * 0.24);
	}
	if (premium_mode == 2) {
		float depth = clamp(point.y * 0.38 + 0.50, 0.0, 1.0);
		float spot = round_spots(point + vec3(0.17, 0.31, 0.09), 15.0, 0.22);
		float haze = value_noise(point * 3.2) * 0.08;
		return mix(vec3(0.10, 0.11, 0.20), vec3(0.27, 0.28, 0.42), depth) + vec3(haze + spot * 0.42);
	}
	if (premium_mode == 3) {
		float depth = clamp(point.y * 0.42 + 0.52, 0.0, 1.0);
		vec3 water = mix(vec3(0.02, 0.34, 0.63), vec3(0.24, 0.66, 0.91), depth);
		float wave = sin(point.y * 18.0 + sin(point.x * 11.0) * 1.8 + point.z * 6.0);
		float foam = smoothstep(0.70, 0.94, wave) * smoothstep(0.15, 0.70, depth);
		return mix(water, vec3(0.75, 1.0, 0.91), foam * 0.82);
	}
	if (premium_mode == 4) {
		float height = clamp(point.y * 0.36 + 0.54, 0.0, 1.0);
		vec3 blue = mix(vec3(0.42, 0.70, 0.91), vec3(0.72, 0.87, 1.0), height);
		float cloud_noise = value_noise(vec3(point.x * 3.3, point.y * 2.0, point.z * 3.3) + vec3(4.0));
		float cloud = smoothstep(0.58, 0.72, cloud_noise) * smoothstep(0.08, 0.82, height);
		return mix(blue, vec3(0.96, 0.98, 1.0), cloud * 0.88);
	}
	return base_color;
}

float mark_ellipse(vec2 point, vec2 center, vec2 size, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	vec2 delta = point - center;
	vec2 local = vec2(c * delta.x + s * delta.y, -s * delta.x + c * delta.y);
	return 1.0 - smoothstep(0.82, 1.0, length(local / size));
}

float mark_circle(vec2 point, vec2 center, float radius) {
	return 1.0 - smoothstep(radius * 0.78, radius, distance(point, center));
}

// A small four-point sparkle: two crossed bars, the way the pixel art draws
// the glints around the star mark.
float mark_spark(vec2 point, vec2 center, float radius) {
	float bar = mark_ellipse(point, center, vec2(radius, radius * 0.34), 0.0);
	return max(bar, mark_ellipse(point, center, vec2(radius * 0.34, radius), 0.0));
}

// The markings trait: the collection's painted coat patterns, transcribed from
// the pixel art in web/public/peeplet/src-v2/markings-*.png onto the glb coat.
// Every shape below is a measurement of that art mapped through the two
// silhouettes — the sprite body is 251 px across and 279 px tall, the coat is
// x +/-0.630 and y -0.576..0.864 — which comes out at ~0.0051 units per sprite
// pixel. They replace the rpg-adventure-2 lab's own numbers, which were tuned
// against that blob's flatter body and landed high and small on this mesh.
//
// The mask is a flat front projection: only .xy is sampled, so dead-on the coat
// reproduces the sprite, and the pattern extrudes backward, thinning toward the
// silhouette as the peeplet turns away. Marks are on the peeplet's left side
// only, as the art has them.
const float MARK_FRONT_START = 0.13;
const float MARK_FRONT_END = 0.38;
const vec3 MARK_CREAM = vec3(0.969, 0.886, 0.690);
const vec3 MARK_PEACH = vec3(0.886, 0.678, 0.535);
const vec3 MARK_GOLD = vec3(0.980, 0.780, 0.270);
const vec3 MARK_VIOLET = vec3(0.941, 0.788, 0.984);
const vec3 MARK_SPARK = vec3(0.988, 0.937, 0.520);

vec4 body_mark(vec3 point) {
	vec2 p = point.xy;
	float front = smoothstep(MARK_FRONT_START, MARK_FRONT_END, point.z);
	if (body_mark_mode == 1) {
		// Three tapered stripes raked down the left flank, temple to belly line,
		// each tilted the ~33 degrees the art draws them at.
		float mask = mark_ellipse(p, vec2(-0.280, 0.665), vec2(0.254, 0.058), 0.579);
		mask = max(mask, mark_ellipse(p, vec2(-0.351, 0.390), vec2(0.316, 0.052), 0.555));
		mask = max(mask, mark_ellipse(p, vec2(-0.424, 0.111), vec2(0.264, 0.051), 0.635));
		return vec4(MARK_CREAM, mask * front);
	}
	if (body_mark_mode == 2) {
		// Four cream spots clustered around the left cheek, and two smaller
		// peach ones further down where the belly patch begins.
		float cream = mark_circle(p, vec2(-0.325, 0.404), 0.065);
		cream = max(cream, mark_circle(p, vec2(-0.372, 0.256), 0.043));
		cream = max(cream, mark_circle(p, vec2(-0.233, 0.532), 0.040));
		cream = max(cream, mark_circle(p, vec2(-0.183, 0.430), 0.037));
		float peach = mark_circle(p, vec2(-0.508, -0.059), 0.045);
		peach = max(peach, mark_circle(p, vec2(-0.481, -0.183), 0.032));
		vec3 color = mix(MARK_PEACH, MARK_CREAM, step(peach, cream));
		return vec4(color, max(cream, peach) * front);
	}
	if (body_mark_mode == 3) {
		// The premium mark: a four-ray gold star with a pale core, a violet
		// crescent above and below it, and a sparkle beside each crescent.
		vec2 center = vec2(-0.423, 0.068);
		vec2 q = p - center;
		float angle = atan(q.y, q.x);
		float ray = pow(abs(cos(angle * 2.0)), 10.0);
		// Four long rays, plus the stubby diagonal spikes the sprite draws
		// between them.
		float diagonal = pow(abs(cos(angle * 2.0 + 1.5708)), 14.0);
		float star_radius = mix(0.050, 0.143, ray) + 0.030 * diagonal;
		float star = 1.0 - smoothstep(star_radius * 0.82, star_radius, length(q));
		float core = mark_circle(p, center, 0.052);
		// A crescent is one disc minus a second one shifted toward the star, so
		// the horns point away from it.
		float crescent_a = max(mark_circle(p, vec2(-0.315, 0.203), 0.060)
			- mark_circle(p, vec2(-0.337, 0.181), 0.049), 0.0);
		float crescent_b = max(mark_circle(p, vec2(-0.530, -0.078), 0.058)
			- mark_circle(p, vec2(-0.508, -0.056), 0.047), 0.0);
		float violet = max(crescent_a, crescent_b);
		float spark = mark_spark(p, vec2(-0.498, 0.198), 0.023);
		spark = max(spark, mark_spark(p, vec2(-0.341, -0.051), 0.020));
		vec3 color = mix(MARK_GOLD, MARK_VIOLET, violet);
		color = mix(color, MARK_SPARK, max(core, spark));
		return vec4(color, max(max(star, violet), spark) * front);
	}
	return vec4(0.0);
}

#include "res://peeplet/soft_cel.gdshaderinc"

void vertex() {
	shell = stacked ? UV2.x : shell_ratio;
	base_position = VERTEX;
	base_normal = normalize(NORMAL);
	// Soaked fur is plastered flat where rain hits (top), while water runs
	// down and gathers into long heavy drips on downward-facing surfaces.
	// NORMAL (and so base_normal) is object-space here — Godot feeds vertex()
	// the model-space normal, before MODEL_MATRIX. The peeplet node carries a
	// chart-basis transform (Task 9), so local +Y already IS the wearer's
	// radial up; .y is correct as-is, no chart lookup needed.
	float downness = clamp(0.5 - 0.5 * base_normal.y, 0.0, 1.0);
	float wet_length = mix(0.35, 1.6, pow(downness, 1.4));
	float length_scale = mix(1.0, wet_length, wetness);
	vec3 extruded = VERTEX + NORMAL * fur_length * shell * length_scale;
	// Tips sag a little so the coat looks soft and combed; soaked fur is
	// heavy with water and drags hard toward the ground. extruded is still
	// object-space (built from VERTEX + NORMAL, no MODEL_MATRIX applied yet —
	// see world_pos below, which converts explicitly), so subtracting along
	// .y sags toward the wearer's own feet via the same chart-basis +Y. No
	// change needed.
	float sag = droop + wetness * 1.6;
	extruded.y -= fur_length * sag * shell * shell * length_scale;
	// Wind: sample the shared gust field at this vertex's world position with
	// the same scroll the grass uses — a passing gust ruffles fur and flattens
	// grass in the same instant, from the same direction. The gust field lives
	// in chart space (grass samples chart_from_world too, see
	// toon_grass_deform.gdshaderinc), and the compass direction is built from
	// the wearer's own radial frame — MODEL_MATRIX[1] is the chart-basis Y
	// column, i.e. this peeplet's local up — instead of world X/Z, which
	// stopped being a horizontal ground plane once the coat wraps the sphere.
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wearer_up = normalize(MODEL_MATRIX[1].xyz);
	vec3 chart_e = chart_east(wearer_up);
	vec3 chart_s = chart_south(wearer_up);
	vec2 wind_dir = normalize(wind_direction);
	vec2 gust_perp = vec2(-wind_dir.y, wind_dir.x);
	vec2 gust_rel = chart_from_world(world_pos).xz - wind_dir * wind_gust_phase;
	float front_stretch = mix(1.0, 0.42, clamp(wind_strength * 0.25, 0.0, 1.0));
	vec2 gust_uv = vec2(dot(gust_rel, wind_dir), dot(gust_rel, gust_perp) * front_stretch)
		* gust_scale;
	float gust = wind_field_noise(gust_uv) * 0.7 + wind_field_noise(gust_uv * 2.9 + 37.0) * 0.3;
	gust *= gust;
	float flutter = sin(TIME * 5.5 + dot(base_position, vec3(7.0, 3.0, 5.0)))
		* (0.25 + 0.75 * gust);
	// Linear in the shared wind strength so fur and grass read as one global
	// wind; slope picked to keep the old storm-level (4.0) streaming look.
	float wind_power = wind_strength * 0.47;
	vec3 wind_world = chart_e * wind_dir.x + chart_s * wind_dir.y
		+ (chart_e * -wind_dir.y + chart_s * wind_dir.x) * flutter * 0.3
		+ wearer_up * (0.15 * flutter);
	// World direction into object space so fur wind ignores body rotation.
	vec3 wind_obj = normalize((inverse(MODEL_MATRIX) * vec4(wind_world, 0.0)).xyz);
	float bend = min(wind_power * (0.22 + 2.3 * gust) * 1.2, 4.0);
	extruded += wind_obj * bend * fur_length * shell * shell;
	VERTEX = extruded;
}

void fragment() {
	float max_length = 1.0;

	// Rim mask: 1 where the surface turns away from the camera (silhouette),
	// 0 face-on. Only the rim pays for tuft lattice discards.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = (1.0 - smoothstep(rim_facing_start, rim_facing_end, facing)) * rim_tuft_strength;
	if (rim > 0.001) {
		vec3 p = base_position * tuft_density;
		vec3 cell = floor(p);
		// Jitter each tuft off its cell center so the silhouette fringe reads
		// as organic fluff instead of a regular knitted grid.
		vec3 jitter = (vec3(
			hash31(cell + vec3(3.1, 7.7, 1.3)),
			hash31(cell + vec3(11.9, 2.3, 6.1)),
			hash31(cell + vec3(5.3, 13.7, 19.1))
		) - 0.5) * 0.5;
		vec3 f = fract(p) - 0.5 - jitter;
		float rnd = hash31(cell);
		vec3 tangential = f - dot(f, base_normal) * base_normal;
		// Cone taper: fat at the root, spike at the tip, so gaps between
		// tufts open toward the outline hull behind them.
		float tuft_radius = 0.5 * (1.0 - shell * mix(0.55, 0.85, rnd));
		// Interior radius is huge (never discards); tufts only bite at the rim.
		float radius = mix(4.0, tuft_radius, rim);
		if (length(tangential) > radius) {
			discard;
		}
		// Ragged fringe: some rim tufts stop short of full length.
		max_length *= mix(1.0, mix(0.72, 1.0, rnd), rim);
	}

	// Face mask: shave the coat around the eyes and mouth so the features
	// sit on bare skin instead of being swallowed by strands.
	if (face_mask_strength > 0.0) {
		// Eyes are tall ovals — squash x so the shaved patch matches their
		// shape and fur stays tight against the eye sides.
		vec3 dl = base_position - eye_left;
		vec3 dr = base_position - eye_right;
		dl.x *= 1.55;
		dr.x *= 1.55;
		float eye_dist = min(length(dl), length(dr));
		float eye_trim = smoothstep(eye_mask_radius * 0.72, eye_mask_radius, eye_dist);
		float mouth_trim = smoothstep(mouth_mask_radius * 0.5, mouth_mask_radius, distance(base_position, mouth_center));
		max_length *= mix(1.0, min(eye_trim, mouth_trim), face_mask_strength);
	}
	if (shell > max_length) {
		discard;
	}

	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float ndotl = dot(world_normal, normalize(light_direction));
	float band_wobble = value_noise(base_position * terminator_scale) - 0.5;
	// daily: the soft painted cel (soft_cel.gdshaderinc) in place of the
	// hard two-band cut against shadow_tint.
	vec3 toon_light = soft_cel(world_normal, light_direction, band_wobble, dot(NORMAL, VIEW));

	// Belly patch: strands over the belly grow in the cream color too.
	float belly_facing = dot(normalize(base_position), normalize(belly_direction));
	float belly = smoothstep(belly_size - 0.06, belly_size + 0.02, belly_facing) * belly_strength;
	vec3 textured_coat = premium_coat(base_position, fur_color.rgb);
	vec3 coat = mix(textured_coat, belly_color.rgb, belly);
	vec4 marking = body_mark(base_position);
	coat = mix(coat, marking.rgb, marking.a);
	coat = soft_coat(coat, base_position);

	// Campfire glow, same banded cut as the base coat so both layers warm
	// together (see peeplet_fur.gdshader).
	vec3 world_position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 fire_delta = fire_light_position - world_position;
	// Square falloff + near/far tone, same as the base coat.
	float fire_falloff = pow(clamp(1.0 - length(fire_delta) / fire_light_range, 0.0, 1.0), 2.0);
	float fire_facing = step(-0.15, dot(world_normal, normalize(fire_delta)) + band_wobble * terminator_fuzz);
	vec3 fire_tone = fire_light_color * mix(vec3(1.0, 0.72, 0.5), vec3(1.0, 1.12, 1.25), fire_falloff);
	vec3 fire_light = fire_tone * fire_light_energy * fire_falloff * mix(0.35, 1.0, fire_facing);

	float wet_tone = mix(1.0, 0.55, wetness);
	vec3 world_light = (ambient_light + sun_color * sun_energy * toon_light + fire_light) / DAY_REFERENCE_LIGHT;
	vec3 color = coat * world_light * wet_tone;

	ALBEDO = color;
}
