shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// The lake, ported from the painted source scene's 42-node water material
// (art/landscape.blend, Material.005) rather than baked from it: the material
// has no image textures at all, so it is cheaper as maths than as a texture in
// the APK. Four layers, in the order the node tree stacks them -- a depth
// gradient out from the middle, a mottle, the white foam curls that make it
// read as painted rather than shaded, and the long streak dashes. Plus the one
// splash ring the stage triggers when a board lands, which is why the pond has
// to stay a single shared material.
//
// The source's stops are far more saturated than this project's direction
// (docs/art/shading-direction.md), so they are muted toward the palette's
// WATER and WATER_HI. Every time term is scaled by the motion_scale global so
// reduce-motion stills the whole lake. Lit with a two-band terminator eased
// the way the toon ramp's are, so the platform's shadow still falls on it as
// a soft coloured shadow. Runs on gl_compatibility: nothing here reads depth
// or screen.
// Spec: docs/superpowers/specs/2026-09-16-low-horizon-design.md, section 5.

global uniform float motion_scale;

// The depth gradient, shallow at the shore to deep in the middle.
uniform vec4 shore_color : source_color = vec4(0.42, 0.78, 0.82, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.37, 0.69, 0.91, 1.0);
uniform vec4 base_color : source_color = vec4(0.18, 0.56, 0.84, 1.0);
uniform vec4 deep_color : source_color = vec4(0.13, 0.42, 0.74, 1.0);
// The foam curls and the streak dashes, both near-white.
uniform vec4 foam_color : source_color = vec4(0.96, 0.98, 0.99, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.65, 0.77, 1.0);
// World units from the pond's middle to its rim, for the depth gradient. If
// this is ever 0, length(p) / 0 is inf, which clamp() pins to 1 -- the water
// degrades to a uniform shore_color instead of producing a NaN.
uniform float pond_radius = 15.0;
// World-space centre of the depth gradient. world/stage.gd sets this to the
// water plane's own position every time a board's fit re-centres the pond;
// it is not the same uniform as splash_origin, which the splash ring alone
// uses and which stays put for the life of one splash.
uniform vec3 pond_center = vec3(0.0);
// The source's own field scales, in the source's units.
uniform float mottle_scale = 3.3;
uniform float foam_scale = 4.4;
uniform float streak_scale = 9.0;
uniform vec3 splash_origin = vec3(0.0);
// Seconds since the splash began; negative means no splash. Driven by
// world/ambient.gd from its own clock so the ring is deterministic.
uniform float splash_age = -1.0;

varying vec3 world_pos;

// Value noise, smoothed. Stands in for Blender's Noise Texture: the port needs
// the same broad mottle, not the same bytes.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Blender's Magic Texture is iterated sin of the coordinates fed back into
// themselves; two iterations is its depth of 2. This is where the curls come
// from.
float magic(vec2 p, float distortion) {
	vec3 v = vec3(p, p.x * 0.5 + p.y * 0.5);
	for (int i = 0; i < 2; i++) {
		v = vec3(sin(v.x + v.z * distortion),
			sin(v.y - v.x * distortion),
			sin(v.z + v.y * distortion));
	}
	return (v.x + v.y + v.z) / 3.0 * 0.5 + 0.5;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * motion_scale;
	vec2 p = world_pos.xz;

	// 1. Depth gradient: the source uses a quadratic-sphere gradient in object
	// space, which on a flat disc is the squared distance from the middle.
	// The four breakpoints below are measured, not the source's own literal
	// stops (0.15 / 0.359 / 0.673 / 1.0 on 1 - r*r): those assumed r would
	// range meaningfully across 0..1, but pond_center was wrong and
	// stage.gd's _fit_ground recentres the pond on every fit, so the true
	// rim (r = 1, pond_radius world units out) is never in the frame for any
	// board. r, painted straight to ALBEDO as vec3(r) on a rendered Binairo
	// and Horse Pen frame and sampled with Python, showed the pond's visible
	// pixels sitting at r of 0 to ~0.10 (p99 0.01 on Binairo's round pond, p99.9
	// 0.33 -- Horse Pen's scattered channel cells reach a little further
	// out, 0 to ~0.35 at the very corners) with the overwhelming majority
	// under 0.1. On the old breakpoints, 1 - r*r never left [0.99, 1.0], an
	// 0.01-wide sliver against stops spread across 0.85 -- every smoothstep
	// saturated to the same edge and the whole pond rendered as deep_color,
	// which is exactly what a from-orbit pixel sample of the previous
	// version found. Written directly against r now instead of 1 - r*r, so
	// the breakpoints can sit in the range that is actually reachable.
	float r = clamp(length(p - pond_center.xz) / pond_radius, 0.0, 1.0);
	vec3 col = mix(deep_color.rgb, base_color.rgb, smoothstep(0.0, 0.03, r));
	col = mix(col, shallow_color.rgb, smoothstep(0.03, 0.06, r));
	col = mix(col, shore_color.rgb, smoothstep(0.06, 0.10, r));

	// 2. Mottle: broad, slow, and barely there -- it only breaks the gradient
	// up so the lake is not a smooth wash.
	float mottle = noise2(p * mottle_scale * 0.06 + vec2(t * 0.012, t * -0.008));
	col = mix(col, shallow_color.rgb, smoothstep(0.55, 0.85, mottle) * 0.25);

	// 3. Foam curls. The constant ramps in the source are hard cuts, which is
	// what makes them read as painted rather than as a gradient. Three things
	// changed from a literal port, all against the same reference frame
	// (docs/art/shading-direction.md's target painting, not the first pass's
	// own screenshot):
	// - The radial weight used to be strongest at the pond's own middle
	//   (smoothstep(0.30, 0.22, r)), which is backwards: the reference's open
	//   water is its clearest part and the foam gathers toward the shore.
	//   Flipped to build outward instead. The endpoints are much smaller than
	//   r's own 0-1 range because stage.gd's _fit_ground recentres the pond
	//   under whichever board is on screen every time it fits the camera --
	//   the true rim at r=1 (pond_radius world units out) is never in frame
	//   for any board; what's actually visible sits within about a tenth of
	//   that, so that is the span the gradient has to work in.
	// - A single-sided threshold (as the source ramp does it) shades in
	//   everything past the cutoff, which is a filled plateau, not a stroke.
	//   Band-passing symmetrically around one curl value keeps only its
	//   crest, the way the streak layer already isolates a slice of its wave.
	// - The magic field's own iterated-sin construction repeats on a regular
	//   lattice once thresholded this narrowly -- it grids. Warping the
	//   sample point with the same value noise used for the mottle, at a
	//   scale close to the curl field's own, breaks that lattice up into
	//   irregular strokes without touching magic() itself.
	vec2 curl_warp = vec2(noise2(p * 0.3 + vec2(11.0, 3.0)),
		noise2(p * 0.3 + vec2(3.0, 11.0))) * 2.0 - 1.0;
	vec2 curl_p = p + curl_warp * 2.2;
	float curl = magic(curl_p * foam_scale * 0.35 + vec2(t * 0.02, t * 0.015), 0.5);
	float curl_band = smoothstep(0.60, 0.64, curl) * smoothstep(0.68, 0.64, curl);
	float shore_weight = smoothstep(0.02, 0.12, r);
	float curl_mask = curl_band * shore_weight;
	col = mix(col, foam_color.rgb, curl_mask);

	// 4. Streak dashes: a wave field half-mixed with noise, through a narrow
	// window, so the streaks come out as long broken dashes rather than
	// stripes. The noise's own coordinate scale (0.4, against the mottle's
	// 0.06) and its weight (5.0, against the source-matched 2.4) are both
	// raised past the source: at the source's numbers the noise only ever
	// bent the wave's phase, never enough to break it, so the dash read as one
	// continuous ring all the way round the pond. Faster, stronger noise
	// folds the wave back on itself and pinches it into separate strokes. The
	// wave's own frequency (0.18, against the source-matched 0.1) is raised
	// too, and the accept window narrowed from a 0.07-wide plateau to a
	// 0.02-wide one, for more, thinner dashes rather than fewer, fatter ones.
	float wave = sin((p.x * 0.55 + p.y * 0.35) * streak_scale * 0.18
		- t * 0.10 + noise2(p * 0.4 + t * 0.01) * 5.0) * 0.5 + 0.5;
	float streak = smoothstep(0.55, 0.575, wave) * smoothstep(0.615, 0.59, wave);
	col = mix(col, foam_color.rgb, streak * 0.9);

	if (splash_age >= 0.0 && splash_age < 2.0) {
		float d = distance(p, splash_origin.xz);
		float ring = step(abs(d - splash_age * 3.0), 0.15) * (1.0 - splash_age / 2.0);
		col = mix(col, foam_color.rgb, ring);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float t = clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * clamp(ATTENUATION, 0.0, 1.0);
	// Eased over the same run as the toon ramp's edges (core/toon.gd ramp()),
	// never a hard step: docs/art/shading-direction.md, soft shadows.
	float band = smoothstep(0.45, 0.55, t);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint.rgb, vec3(1.0), band);
}
