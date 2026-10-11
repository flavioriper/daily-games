shader_type canvas_item;

// Gumdrop's syrup (arcade/gumdrop_screen.gd): the sim's grid of squares as
// one small texture, each texel the colour its jelly shows times its
// strength with the strength in alpha (arcade/gumdrop_art.gd's `paint`),
// drawn over the tray as a colour soaked into clear jelly. The grid is 36
// squares a side and a square is twenty pixels on a phone, so it is read
// through a smooth cubic (four taps), not the plain two-by-two that shows
// every square as a diamond, and the point read is bent a little by a
// grain of its own, so a bloom's edge is a soft rag and not a drawn curve.
// Then the colour is taken back out of the strength.

// How far the grain bends the read, in texels, and how fine it is.
const float BEND = 0.28;
const float GRAIN = 23.0;

void fragment() {
	// TEXTURE is read here and not in a function of its own: a built-in
	// sampler handed to a function is refused by the compiler.
	vec2 px = TEXTURE_PIXEL_SIZE;
	// the grain: two sines wound through each other, nothing that needs
	// the precision a phone's fragment shader has not got
	vec2 g = UV * GRAIN;
	vec2 bend = vec2(sin(g.x * 1.7 + sin(g.y * 1.3) * 1.9), sin(g.y * 1.6 + sin(g.x * 1.1 + 2.0) * 1.9)) * BEND;
	vec2 at = UV / px - 0.5 + bend;
	vec2 f = fract(at);
	vec2 i = floor(at);
	vec2 w0 = (1.0 - f) * (1.0 - f) * (1.0 - f) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f * f + 3.0 * f * f * f) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f * f - 3.0 * f * f * f) / 6.0;
	vec2 w3 = f * f * f / 6.0;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i - 0.5 + w1 / g0) * px;
	vec2 h1 = (i + 1.5 + w3 / g1) * px;
	vec4 t = g0.y * (g0.x * texture(TEXTURE, vec2(h0.x, h0.y)) + g1.x * texture(TEXTURE, vec2(h1.x, h0.y)))
		+ g1.y * (g0.x * texture(TEXTURE, vec2(h0.x, h1.y)) + g1.x * texture(TEXTURE, vec2(h1.x, h1.y)));
	float strength = t.a;
	vec3 col = strength > 0.002 ? t.rgb / strength : vec3(1.0);
	COLOR = vec4(col, strength * 0.96);
}
