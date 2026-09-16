// Shared body of the cozy cel shader: toon.gdshader, toon_wind.gdshader and
// toon_wood.gdshader #include this so the lighting has one source. Spec:
// 3d-toon-pipeline design section 2. Runs on gl_compatibility: nothing here
// reads depth or screen. A shader that #defines WOOD_GRAIN before the include
// also gets the grain block below; nothing else pays for it.

uniform vec4 albedo : source_color = vec4(1.0);
// Red channel = lit factor across NdotL remapped to 0..1. Nearest filtering
// keeps the bands hard. core/toon.gd ramp() builds the default.
uniform sampler2D ramp : filter_nearest, repeat_disable, hint_default_white;
// Shadow is a hue shift toward this tint, never a multiply toward black.
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.65, 0.77, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.18;
uniform float rim_width : hint_range(0.0, 1.0) = 0.30;
uniform vec4 rim_color : source_color = vec4(1.0);

#ifdef WOOD_GRAIN
// Wood grain, cel. Rings around the piece's own axis with the heart of the
// log sitting off the surface, which is what turns a flat-sawn face's rings
// into cathedral figure and wraps a round post in bands. Four flat tones:
// the wood, a slightly darker zone on some rings, a thin dark streak along
// each ring, and a knot's dark core. Every edge is a hard step with one
// pixel of box-filter coverage, never a gradient.
//
// Streaks break: a slow noise along each line sets its width, and where
// that reaches zero the streak tapers to a point, so the figure is long
// dashes rather than stripes. Knots sit on a jittered lattice over the
// surface and bulge the ring coordinate, so the lines nearby fold around
// them.
//
// Measured in world units (the vertex stage scales by the model's own
// scale), so a deck strip modelled one unit long and stretched tenfold by
// the board gets true along-length figure, and every piece shares one ring
// spacing. Rotation is not applied, so a board that turns keeps its grain.
varying vec3 grain_pos;
// Which log the piece was cut from. Per instance (Scenery.seed_grain) so ten
// strips of one deck mesh do not carry the same figure; the material stays
// shared.
instance uniform float grain_seed = 0.0;
uniform vec3 grain_axis = vec3(0.0, 1.0, 0.0);
// Where the heart sits in the plane across the axis, in world units. Off the
// piece on purpose -- a ring centred inside a plank would read as a target.
uniform vec2 grain_heart = vec2(0.75, 0.9);
uniform float grain_scale = 14.0;                         // rings per world unit
uniform float grain_width : hint_range(0.0, 0.5) = 0.10;  // streak half-width, in rings
uniform float grain_cover : hint_range(0.0, 1.0) = 0.66;  // how much of a ring carries a streak
uniform float grain_wobble = 0.45;                        // rings a line wanders
uniform float grain_darken : hint_range(0.0, 1.0) = 0.72;
uniform float grain_zone_darken : hint_range(0.0, 1.0) = 0.94;
uniform vec2 grain_knot_cell = vec2(2.0, 0.6);            // lattice cell, along x across, world units
uniform float grain_knot_chance : hint_range(0.0, 1.0) = 0.33;
uniform float grain_knot_size = 0.055;                    // core half-length, world units
uniform float grain_knot_darken : hint_range(0.0, 1.0) = 0.64;

void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	grain_pos = VERTEX * s;
}

float wood_hash(vec2 p) {
	p = mod(p, 289.0);
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float wood_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(wood_hash(i), wood_hash(i + vec2(1.0, 0.0)), f.x),
		mix(wood_hash(i + vec2(0.0, 1.0)), wood_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Coverage of the band |x| < hw by a pixel of width w centred at x = d >= 0.
// A band narrower than a pixel fades out instead of leaving a hairline.
float wood_band(float d, float hw, float w) {
	return clamp(min(hw, d + 0.5 * w) - max(-hw, d - 0.5 * w), 0.0, w) / w;
}

// Albedo multiplier at local point p.
float wood_figure(vec3 p) {
	vec3 ax = normalize(grain_axis);
	// A reference never parallel to the axis, so the cross products below
	// give a stable pair of axes across the log.
	vec3 ref = mix(vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), step(0.9, abs(ax.y)));
	vec3 u = normalize(cross(ax, ref));
	vec3 v = cross(ax, u);
	vec2 across = vec2(dot(p, u), dot(p, v));
	// The seed moves the heart and slides the piece along the log.
	vec2 heart = grain_heart
		+ (vec2(wood_hash(vec2(grain_seed, 3.1)), wood_hash(vec2(grain_seed, 7.3))) - 0.5) * 0.5;
	float along = dot(p, ax) + grain_seed * 11.3;
	vec2 rc = across - heart;
	float radius = length(rc);

	// Ring coordinate, wandering along the grain in two octaves so no two
	// lines wave together.
	float r = radius * grain_scale;
	vec2 np = vec2(along, radius);
	r += (wood_noise(np * vec2(0.9, 2.5)) - 0.5) * 2.0 * grain_wobble;
	r += (wood_noise(np * vec2(2.7, 6.0) + 31.0) - 0.5) * 0.7 * grain_wobble;

	// Knots. The surface is charted as (along, arc around the axis), which
	// is a smooth 2D coordinate over a plank's face and a post's side alike.
	// One lattice cell holds at most one knot, jittered but kept inside the
	// cell with its whole bulge, so cells never seam.
	float arc = atan(across.y, across.x) * length(across);
	vec2 kp = vec2(along, arc) / grain_knot_cell;
	vec2 kc = floor(kp);
	float has_knot = step(wood_hash(kc + 41.0), grain_knot_chance);
	vec2 jitter = (vec2(wood_hash(kc + 5.0), wood_hash(kc + 9.0)) - 0.5) * 0.5;
	vec2 to_knot = (kp - kc - 0.5 - jitter) * grain_knot_cell;
	// Elongated along the grain: the core is a 2:1 oval, the bulge that folds
	// the rings around it reaches three times further. No branch here:
	// fwidth needs every neighbouring pixel to have taken the same path.
	float e = length(to_knot / (grain_knot_size * vec2(2.0, 1.0)));
	float bulge = 1.0 - clamp(e / 3.5, 0.0, 1.0);
	r += has_knot * bulge * bulge * (3.0 - 2.0 * bulge) * 2.6;
	float knot_core = has_knot * wood_band(e, 1.0, max(fwidth(e), 0.001));

	// Streaks: a thin band around each ring's centre, drawn where a slow
	// noise along the ring says so and tapering where it fades.
	float d = abs(fract(r) - 0.5);
	float ring = floor(r);
	float presence = wood_noise(vec2(along * 1.3, ring * 0.71 + 17.0));
	float hw = grain_width * smoothstep(1.0 - grain_cover, 1.0 - grain_cover + 0.3, presence);
	float w = max(fwidth(r), 0.0008);
	float streak = wood_band(d, hw, w);

	// Zones: some rings are a shade darker across their whole width, bounded
	// by the streak lines. Blended across the boundary by pixel coverage so a
	// deck seen edge-on does not shimmer.
	float zr = r + 0.5;
	float zid = floor(zr);
	float zf = fract(zr);
	float z0 = step(0.5, wood_hash(vec2(zid, 23.0)));
	float zm = step(0.5, wood_hash(vec2(zid - 1.0, 23.0)));
	float zp = step(0.5, wood_hash(vec2(zid + 1.0, 23.0)));
	float zone = mix(mix(zm, z0, clamp(zf / w + 0.5, 0.0, 1.0)), zp, clamp((zf - 1.0) / w + 0.5, 0.0, 1.0));

	float tone = mix(1.0, grain_zone_darken, zone);
	tone *= mix(1.0, grain_darken, streak);
	return mix(tone, grain_knot_darken, knot_core);
}
#endif

void fragment() {
	vec3 base = albedo.rgb;
#ifdef WOOD_GRAIN
	base *= wood_figure(grain_pos);
#endif
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = step(1.0 - rim_width, 1.0 - facing);
	EMISSION = rim_color.rgb * base * rim * rim_strength;
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
