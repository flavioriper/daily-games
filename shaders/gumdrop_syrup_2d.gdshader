shader_type canvas_item;

// Gumdrop's syrup (arcade/gumdrop_screen.gd): the sim's grid of squares as
// one small texture, each texel its colour times its depth with the depth
// in alpha, drawn over the tray as jelly. The grid is 36 squares a side and
// a square is twenty pixels on a phone, so it is read through a smooth
// cubic (four taps), not the plain two-by-two that shows every square as a
// diamond; then the colour is taken back out of the depth, and the depth
// becomes how much of the clear jelly the syrup has taken.

void fragment() {
	// TEXTURE is read here and not in a function of its own: a built-in
	// sampler handed to a function is refused by the compiler.
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 at = UV / px - 0.5;
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
	float depth = t.a;
	vec3 col = depth > 0.002 ? t.rgb / depth : vec3(1.0);
	// thin syrup is a tint, deep syrup the flavour itself, a shade richer
	float took = smoothstep(0.02, 0.5, depth);
	col = mix(col, col * col, 0.18 * smoothstep(0.5, 1.0, depth));
	COLOR = vec4(col, took * 0.96);
}
