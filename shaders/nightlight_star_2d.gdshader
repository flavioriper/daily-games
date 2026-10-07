shader_type canvas_item;

// Nightlight's star (arcade/nightlight_sky.gd), painted the way the rest of
// the game is (docs/art/shading-direction.md; the user on the grained Sun
// seen from space that stood here, 2026-10-06: "improve sun design, polish
// it, cozy, soft toon shade to match rest of the app games"): three flat
// tones with an eased edge between them, a pale heart, the star's own
// colour round it and a deeper limb, and the edges of the three are not
// circles but scallops, pushed in and out by a few big soft dabs that drift
// and swell as slowly as a pot simmering. A handful of paler dabs lie on
// the body, a breath of warm and cool washes over all of it, and past the
// edge there is only a soft fuzz of the star's own light. No grain, no
// shine, no ray. One square of Art.WIDE radii, drawn once; `col` is the
// star's temperature as a colour, `lit` 0 for a star with nothing left to
// burn, `clock` the sky's own seconds (it stands still under reduce motion
// and while a card is up). No texture: everything is worked out from where
// the fragment is.

uniform vec3 col = vec3(1.0, 0.67, 0.28);
uniform float lit = 1.0;
uniform float clock = 0.0;
// How much of the star is there: an end thins it away.
uniform float fade = 1.0;
// Dabs across the star's radius.
uniform float dabs = 2.3;
// The radius the square's mesh is built for.
uniform float built = 64.0;

// A tone's edge is eased over about two pixels, and never over more than
// this much of the light: where the light changes slowly a fixed run was a
// blur across half a dab.
const float EASE = 0.03;
// Where the limb ends and where the heart begins, in the light.
const float LIMB = 0.36;
const float HEART = 0.7;
const vec3 CREAM = vec3(1.0, 0.965, 0.87);

varying vec2 p;

void vertex() {
	p = VERTEX / built;
}

float hash(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 q) {
	return fract(sin(vec2(dot(q, vec2(127.1, 311.7)), dot(q, vec2(269.5, 183.3)))) * 43758.5453);
}

float noise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 q) {
	return noise(q) * 0.6 + noise(q * 2.1 + 11.0) * 0.4;
}

// A field of round dabs, each wandering in its own cell and swelling and
// shrinking on its own time: about 1 on a dab's heart, 0 between them. They
// are added, not laid over one another, so two that touch run together as
// two drops do and a tone cut across the field has no corner in it.
float dab(vec2 q, float t) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	float sum = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 h = hash2(i + g);
			vec2 o = 0.5 + 0.3 * sin(t * (0.6 + 0.8 * h.yx) + 6.2831 * h);
			float big = 0.62 + 0.22 * sin(t * 0.7 + 6.2831 * h.x * h.y + h.y * 3.0);
			float d = min(1.0, length(g + o - f) / big);
			float k = 1.0 - d * d;
			sum += k * k * k;
		}
	}
	return sum;
}

// One tone over another: 0 under `at`, 1 over it, eased.
float tone(float light, float at) {
	float run = clamp(fwidth(light) * 1.6, 0.003, EASE);
	return smoothstep(at - run, at + run, light);
}

void fragment() {
	float t = clock;
	float r = length(p);
	vec2 dir = p / max(r, 0.0001);
	// the star is round, and its edge breathes in a few low lobes
	float lobe = fbm(dir * 1.3 + vec2(t * 0.05, -t * 0.035)) - 0.5;
	float rr = r / (1.0 + 0.03 * lobe);
	float z = sqrt(max(0.0, 1.0 - rr * rr));
	// the face as a ball's, a little: the dabs crowd toward the edge, and
	// all of it turns slowly
	vec2 s = p * (1.0 + 0.22 * (1.0 - z)) + vec2(t * 0.012, 0.0);
	float big = min(1.3, dab(s * dabs + 3.7, t * 0.16));
	float small = dab(s * dabs * 1.2 + 21.0, t * 0.22);
	float drift = fbm(s * 1.5 + vec2(-t * 0.02, t * 0.014));
	// the light: most in the heart, least at the limb, and where a dab lies
	// a little more of it, so each tone's edge is a row of soft scallops
	float light = z * 0.92 + 0.24 * (big - 0.6) + 0.12 * (drift - 0.5);

	// the three tones, out of the star's one colour: deeper and a little
	// redder on a cool star, a dusk blue on a hot one; the heart toward cream
	float blue = smoothstep(0.82, 1.1, col.b / max(col.r, 0.001));
	// a cream or a white star has no body to it: the paler its colour, the
	// deeper it is taken, so the heart still stands off it
	float wan = smoothstep(0.55, 0.9, min(col.r, min(col.g, col.b)));
	vec3 body = mix(col, col * col * col, 0.6 * wan);
	vec3 deep = body * mix(vec3(0.92, 0.66, 0.5), vec3(0.66, 0.7, 0.95), blue);
	vec3 pale = mix(body, CREAM, mix(0.6, 0.72, blue));
	float mid_k = tone(light, LIMB);
	float top_k = tone(light, HEART) * mix(0.45, 1.0, lit);
	vec3 face = mix(deep, body, mid_k);
	// a few paler dabs on the body, half a tone: the paint is not flat
	float fleck = tone(small + 0.3 * (drift - 0.5) - 0.25 * big, 0.62) * mid_k * (1.0 - top_k);
	face = mix(face, mix(body, pale, 0.4), fleck);
	face = mix(face, pale, top_k);
	// and the heart's own heart, another half tone
	face = mix(face, mix(pale, CREAM, 0.6), tone(light + 0.1 * (small - 0.5), 1.02) * lit);
	// a wash, as on everything painted here: warmer where the slow noise is
	// high, cooler where it is low, a few parts in a hundred
	float wash = fbm(s * 2.6 + 50.0) - 0.5;
	face *= vec3(1.0 + 0.07 * wash, 1.0 + 0.02 * wash, 1.0 - 0.07 * wash);
	// a star with nothing to burn is the same star, duller
	face *= mix(0.62, 1.0, lit);

	float disc = 1.0 - smoothstep(0.985, 1.005, rr);
	// past the edge: a soft fuzz of its own light, a little taller where a
	// lobe stands out, and nothing with a shape
	float tall = (0.11 + 0.08 * (lobe + 0.5)) * mix(0.5, 1.0, lit);
	float air = 1.0 - smoothstep(0.0, tall, max(0.0, rr - 0.99));
	vec3 air_col = mix(body, pale, 0.35) * mix(0.62, 1.0, lit);
	vec3 c = mix(air_col, face, disc);
	float a = max(disc, air * air * 0.5);
	COLOR = vec4(c, a * fade);
}
