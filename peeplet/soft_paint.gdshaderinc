// The house's paint for what a peeplet is and wears (docs/art/shading-
// direction.md): warm muted pastels, no pure black, a hand-painted drift.
// The glbs keep ~/dev/peeplet's hexes as their source; this is applied to
// them on the way in, so a hat, a lens and the coat under them are mixed
// from the same tin. Colours arrive linear (source_color uniforms).

// The house ink (Palette.OUTLINE 3b2f28), linear: the darkest any paint
// goes, so a black frame or a top hat reads as warm brown-black.
const vec3 PAINT_INK = vec3(0.0437, 0.0284, 0.0212);
// Palette.PAPER f6efe3, linear: the cream every colour breathes toward.
const vec3 PAINT_CREAM = vec3(0.922, 0.863, 0.768);

float paint_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float paint_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(paint_hash(i), paint_hash(i + vec3(1, 0, 0)), f.x),
			mix(paint_hash(i + vec3(0, 1, 0)), paint_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(paint_hash(i + vec3(0, 0, 1)), paint_hash(i + vec3(1, 0, 1)), f.x),
			mix(paint_hash(i + vec3(0, 1, 1)), paint_hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

// A swatch muted to the house: the more saturated it starts, the more it
// eases toward its own grey (a neon magenta gives up two fifths, a sage almost
// nothing), then a breath of cream, and never darker than the ink.
vec3 house_mute(vec3 c) {
	float grey = dot(c, vec3(0.2126, 0.7152, 0.0722));
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	float chroma = (hi - lo) / max(hi, 0.0001);
	c = mix(vec3(grey), c, mix(1.0, 0.58, smoothstep(0.45, 0.95, chroma)));
	c = mix(c, PAINT_CREAM, 0.07);
	return max(c, PAINT_INK);
}

// The painterly wash the boards wear: a slow warm-to-cool drift with a finer
// drift in value under it, a few percent, over world position so two hats of
// one colour are two tones.
vec3 paint_wash(vec3 c, vec3 world) {
	float slow = paint_noise(world * 9.0);
	float fine = paint_noise(world * 31.0 + vec3(7.3));
	vec3 tint = mix(vec3(1.025, 1.0, 0.965), vec3(0.97, 0.99, 1.03), slow);
	return c * tint * mix(0.965, 1.03, fine);
}
