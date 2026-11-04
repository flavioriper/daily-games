shader_type canvas_item;
render_mode unshaded;

// The swarm's bloom (ui/menu/swarm_tab.gd): a TextureRect the size of a
// quarter-resolution viewport, showing the swarm drawn small in another,
// blurred with nine taps a texel and a half apart. Bilinear upscaling to
// the screen does the rest of the softening. `texel` is one over the
// viewport's size. No instance uniform.

uniform vec2 texel = vec2(0.005, 0.0028);

void fragment() {
	vec2 s = texel * 1.5;
	vec3 c = texture(TEXTURE, UV).rgb * 0.2;
	c += (texture(TEXTURE, UV + vec2(s.x, 0.0)).rgb + texture(TEXTURE, UV - vec2(s.x, 0.0)).rgb
		+ texture(TEXTURE, UV + vec2(0.0, s.y)).rgb + texture(TEXTURE, UV - vec2(0.0, s.y)).rgb) * 0.125;
	c += (texture(TEXTURE, UV + s).rgb + texture(TEXTURE, UV - s).rgb
		+ texture(TEXTURE, UV + vec2(s.x, -s.y)).rgb + texture(TEXTURE, UV + vec2(-s.x, s.y)).rgb) * 0.075;
	COLOR = vec4(c, 1.0);
}
